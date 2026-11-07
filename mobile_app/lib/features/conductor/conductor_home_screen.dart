import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bus_model.dart';
import '../../models/eta_model.dart';
import '../authentication/auth_service.dart';
import '../buses/bus_service.dart';
import '../gps/location_service.dart';
import '../tracking/gps_diagnostic_screen.dart';
import 'bus_setup_screen.dart';
import 'conductor_manifest_screen.dart';
import 'conductor_seat_map_screen.dart';
import 'conductor_trip_screen.dart';

class ConductorHomeScreen extends StatefulWidget {
  const ConductorHomeScreen({super.key});

  @override
  State<ConductorHomeScreen> createState() => _ConductorHomeScreenState();
}

class _ConductorHomeScreenState extends State<ConductorHomeScreen> {
  final _service = BusService();
  late Future<BusModel?> _bus = _service.getMyBus();
  bool _busy = false;

  void _reload() => setState(() => _bus = _service.getMyBus());

  Future<void> _toggleTrip(BusModel bus) async {
    final loc = Provider.of<LocationService>(context, listen: false);
    final start = !bus.onTrip;
    if (!start) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('End trip?'),
          content: const Text('All active tickets are completed and every seat is freed for the next trip.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('End trip')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      await _service.setTrip(bus.id, start: start);
      if (start) {
        await loc.startTracking(busId: bus.id);
      } else {
        loc.stopTracking();
      }
      _reload();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppTheme.occupiedRed));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CityBus Go - Conductor'),
        backgroundColor: AppTheme.primaryDark,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: () => auth.logout()),
        ],
      ),
      body: FutureBuilder<BusModel?>(
        future: _bus,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return _message(Icons.cloud_off, 'Cannot load your bus', snap.error.toString(), 'RETRY', _reload);
          final bus = snap.data;
          if (bus == null) {
            return _message(Icons.directions_bus_filled_outlined, 'Set up your bus',
                'Register the bus you operate (number plate, seats and route). An admin approves it before ticketing starts.', 'SET UP BUS', () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BusSetupScreen()));
              await auth.refreshProfile();
              _reload();
            });
          }
          return _dashboard(bus, user?.name ?? 'Conductor');
        },
      ),
    );
  }

  Widget _dashboard(BusModel bus, String name) {
    final loc = Provider.of<LocationService>(context);
    final broadcasting = loc.isBroadcastingFor(bus.id);
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: AppTheme.primaryDark.withValues(alpha: 0.08),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white, child: Icon(Icons.badge_outlined)),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${bus.plateNumber} - Route ${bus.routeNumber.isEmpty ? '(none)' : bus.routeNumber}\n${bus.routeName}'),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit bus profile / route',
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BusSetupScreen(existing: bus)));
                  _reload();
                },
              ),
            ),
          ),
          if (!bus.approved)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Text('Waiting for admin approval. Passengers cannot see or book this bus until it is approved.'),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: bus.onTrip ? AppTheme.occupiedRed : AppTheme.accentGreen, minimumSize: const Size.fromHeight(54)),
            onPressed: _busy || bus.routeId == null ? null : () => _toggleTrip(bus),
            icon: Icon(bus.onTrip ? Icons.stop_circle : Icons.play_circle),
            label: Text(bus.onTrip ? 'END TRIP' : 'START TRIP'),
          ),
          if (bus.routeId == null) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Assign a route to start a trip.', style: TextStyle(color: Colors.black54))),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: broadcasting,
              activeThumbColor: AppTheme.accentGreen,
              secondary: Icon(broadcasting ? Icons.cell_tower : Icons.location_off, color: broadcasting ? AppTheme.accentGreen : Colors.grey),
              title: Text(broadcasting ? 'Broadcasting GPS' : 'GPS broadcast off', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(broadcasting
                  ? '${loc.sentCount} updates sent${loc.errorMessage != null ? ' - ${loc.errorMessage}' : ''}'
                  : 'Turn on so passengers see the bus and arrival times'),
              onChanged: (on) => on ? loc.startTracking(busId: bus.id) : loc.stopTracking(),
            ),
          ),
          const SizedBox(height: 4),
          _tile(Icons.event_seat_rounded, 'Seat map & ticketing', 'Issue cash tickets, free seats when passengers get off', AppTheme.accentGreen,
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConductorSeatMapScreen(bus: bus)))),
          _tile(Icons.timeline, 'Stops & departures', 'Confirm arrival/departure at each stop', AppTheme.primaryBlue,
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConductorTripScreen(bus: bus)))),
          _tile(Icons.people_alt_outlined, 'Passengers & ticket check', 'Advance bookings, manifest, verify a ticket number', Colors.deepPurple,
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConductorManifestScreen(bus: bus)))),
          _tile(Icons.speed, 'GPS diagnostics', 'Raw coordinates and accuracy', Colors.blueGrey,
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GpsDiagnosticScreen()))),
          const SizedBox(height: 8),
          StreamBuilder<BusEta>(
            stream: _service.streamEta(bus.id),
            builder: (context, s) {
              final next = s.data?.nextStop;
              if (next == null) return const SizedBox.shrink();
              return Card(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                child: ListTile(
                  leading: const Icon(Icons.flag, color: AppTheme.primaryBlue),
                  title: Text('Next stop: ${next.stopName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(next.etaMinutes != null ? 'About ${next.etaMinutes!.toStringAsFixed(0)} min - ${next.distanceKm} km' : 'Waiting for GPS'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) => Card(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
      );

  Widget _message(IconData icon, String title, String body, String action, VoidCallback onTap) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: Colors.grey),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onTap, child: Text(action)),
            ],
          ),
        ),
      );
}
