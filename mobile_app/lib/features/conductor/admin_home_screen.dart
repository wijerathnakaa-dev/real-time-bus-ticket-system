import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bus_model.dart';
import '../authentication/auth_service.dart';
import '../buses/bus_service.dart';

/// On-the-go admin view inside the app. Full management (routes, conductors,
/// tickets, payments, live map) lives in the Admin Web Dashboard (admin_web/).
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _service = BusService();
  late Future<(Map<String, dynamic>, List<BusModel>)> _data = _load();

  Future<(Map<String, dynamic>, List<BusModel>)> _load() async {
    final stats = await ApiClient.instance.get('/admin/stats') as Map<String, dynamic>;
    final buses = await _service.listBuses(includeUnapproved: true);
    return (stats, buses);
  }

  Future<void> _approve(BusModel b, bool approved) async {
    try {
      await _service.approveBus(b.id, approved);
      setState(() => _data = _load());
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('CityBus Go - Admin'),
        backgroundColor: Colors.blueGrey.shade900,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => auth.logout())],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _data = _load()),
        child: FutureBuilder<(Map<String, dynamic>, List<BusModel>)>(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(snap.error.toString()))]);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final (stats, buses) = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _stat('Buses on trip', '${stats['buses_on_trip']}/${stats['buses']}'),
                    _stat('Pending approval', '${stats['buses_pending_approval']}'),
                    _stat('Tickets today', '${stats['tickets_today']}'),
                    _stat('Revenue today', 'Rs. ${(stats['revenue_today'] as num).toStringAsFixed(0)}'),
                    _stat('Seats taken', '${stats['seats_taken']}/${stats['seats_total']}'),
                    _stat('Routes', '${stats['routes']}'),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Fleet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                for (final b in buses)
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.directions_bus, color: b.onTrip ? AppTheme.accentGreen : Colors.grey),
                      title: Text(b.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${b.routeNumber.isEmpty ? 'No route' : 'Route ${b.routeNumber}'} - ${b.conductorName ?? 'no conductor'}\n'
                          '${b.status} - ${b.availableSeats}/${b.totalSeats} free'),
                      isThreeLine: true,
                      trailing: b.approved
                          ? const Icon(Icons.verified, color: AppTheme.accentGreen)
                          : ElevatedButton(onPressed: () => _approve(b, true), child: const Text('APPROVE')),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text('Use the Admin Web Dashboard to manage routes, conductors, tickets and payments.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      );
}
