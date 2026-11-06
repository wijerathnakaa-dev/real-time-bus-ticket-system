import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/bus_model.dart';
import '../../services/bus_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_constants.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BusService _busService = BusService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Assign Conductor to a Bus
  void _showAssignConductorDialog(BusModel bus) {
    final conductorIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign Conductor to ${bus.plateNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Route ${bus.routeNumber}'),
            const SizedBox(height: 12),
            TextField(
              controller: conductorIdController,
              decoration: const InputDecoration(
                labelText: 'Conductor User UID',
                hintText: 'Enter conductor user UID',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final cid = conductorIdController.text.trim();
              if (cid.isNotEmpty) {
                // Update both bus and conductor user profile
                await FirebaseFirestore.instance.collection('buses').doc(bus.id).update({
                  'conductorId': cid,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                await FirebaseFirestore.instance.collection('users').doc(cid).update({
                  'role': AppConstants.roleConductor,
                  'assignedBusId': bus.id,
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Assigned conductor $cid to ${bus.plateNumber}')),
                  );
                }
              }
            },
            child: const Text('ASSIGN'),
          ),
        ],
      ),
    );
  }

  // Create New Route
  void _showCreateRouteDialog() {
    final routeNumCtrl = TextEditingController();
    final originCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    final fareCtrl = TextEditingController(text: '150.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Bus Route'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: routeNumCtrl, decoration: const InputDecoration(labelText: 'Route Number (e.g. 138)')),
              const SizedBox(height: 8),
              TextField(controller: originCtrl, decoration: const InputDecoration(labelText: 'Origin Terminal (e.g. Colombo Fort)')),
              const SizedBox(height: 8),
              TextField(controller: destCtrl, decoration: const InputDecoration(labelText: 'Destination (e.g. Kottawa)')),
              const SizedBox(height: 8),
              TextField(controller: fareCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Standard Fare (Rs.)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final rNum = routeNumCtrl.text.trim();
              final rId = 'route_$rNum';
              await FirebaseFirestore.instance.collection('routes').doc(rId).set({
                'routeNumber': rNum,
                'origin': originCtrl.text.trim(),
                'destination': destCtrl.text.trim(),
                'standardFare': double.tryParse(fareCtrl.text) ?? 150.0,
                'estimatedDurationMins': 45,
              });
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Route $rNum created successfully!')),
                );
              }
            },
            child: const Text('CREATE ROUTE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Management Admin Console'),
        backgroundColor: Colors.blueGrey.shade900,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(icon: Icon(Icons.directions_bus), text: 'Fleet Buses'),
            Tab(icon: Icon(Icons.alt_route), text: 'Transit Routes'),
            Tab(icon: Icon(Icons.people), text: 'Conductors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. FLEET BUSES TAB
          StreamBuilder<List<BusModel>>(
            stream: _busService.streamActiveBuses(),
            builder: (context, snapshot) {
              final buses = snapshot.data ?? [];
              if (buses.isEmpty) {
                return const Center(child: Text('No buses registered in fleet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: buses.length,
                itemBuilder: (context, index) {
                  final bus = buses[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.primaryDark,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.directions_bus),
                      ),
                      title: Text(bus.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Route ${bus.routeNumber} • Conductor: ${bus.conductorId.isEmpty ? "None" : bus.conductorId}\nCapacity: ${bus.totalSeats} seats'),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                        onPressed: () => _showAssignConductorDialog(bus),
                        child: const Text('Assign Conductor', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // 2. TRANSIT ROUTES TAB
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('routes').snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              return Scaffold(
                floatingActionButton: FloatingActionButton(
                  onPressed: _showCreateRouteDialog,
                  backgroundColor: AppTheme.accentGreen,
                  child: const Icon(Icons.add),
                ),
                body: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.route, color: AppTheme.primaryBlue),
                        title: Text('Route ${data['routeNumber']}: ${data['origin']} ➔ ${data['destination']}'),
                        subtitle: Text('Standard Fare: Rs. ${(data['standardFare'] as num?)?.toStringAsFixed(2) ?? "150.00"} • Est: ${data['estimatedDurationMins']} mins'),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // 3. CONDUCTORS & USER ROLES TAB
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'conductor').snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No approved conductors found.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.badge),
                      ),
                      title: Text(data['name'] ?? 'Conductor', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Email: ${data['email']}\nAssigned Vehicle: ${data['assignedBusId'] ?? "Not Assigned"}'),
                      trailing: const Icon(Icons.verified_user, color: AppTheme.accentGreen),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
