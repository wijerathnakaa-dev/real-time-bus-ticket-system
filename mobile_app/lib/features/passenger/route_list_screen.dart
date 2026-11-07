import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../buses/bus_service.dart';
import 'bus_tracking_screen.dart';

class RouteListScreen extends StatefulWidget {
  const RouteListScreen({super.key});

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  final _service = BusService();
  late Future<List<RouteModel>> _routes = _service.listRoutes();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expressway routes')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _routes = _service.listRoutes()),
        child: FutureBuilder<List<RouteModel>>(
          future: _routes,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return _error(snap.error.toString());
            final routes = snap.data!;
            if (routes.isEmpty) return const Center(child: Text('No routes yet.'));
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final r in routes)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryDark,
                        foregroundColor: Colors.white,
                        child: Text(r.routeNumber.split('-').first, style: const TextStyle(fontSize: 11)),
                      ),
                      title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Route ${r.routeNumber} - ${r.stopCount} stops - ~${r.estimatedDurationMins} min - from ${AppConstants.money(r.standardFare)}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _RouteBusesScreen(route: r))),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _error(String msg) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(msg, textAlign: TextAlign.center))]);
}

class _RouteBusesScreen extends StatelessWidget {
  final RouteModel route;
  const _RouteBusesScreen({required this.route});

  @override
  Widget build(BuildContext context) {
    final service = BusService();
    return Scaffold(
      appBar: AppBar(title: Text('Route ${route.routeNumber}')),
      body: StreamBuilder<List<BusModel>>(
        stream: service.streamActiveBuses(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(snap.error.toString())));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final buses = snap.data!.where((b) => b.routeId == route.id).toList()
            ..sort((a, b) => (b.onTrip ? 1 : 0) - (a.onTrip ? 1 : 0));
          if (buses.isEmpty) return const Center(child: Text('No buses on this route right now.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(route.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              for (final b in buses)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.directions_bus, color: b.onTrip ? AppTheme.accentGreen : Colors.grey, size: 32),
                    title: Text(b.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(b.onTrip ? 'On trip - ${b.availableSeats} of ${b.totalSeats} seats free' : 'Not on a trip'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BusTrackingScreen(bus: b))),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
