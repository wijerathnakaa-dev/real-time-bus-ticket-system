import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bus_model.dart';
import '../../services/auth_service.dart';
import '../../services/bus_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_theme.dart';
import 'conductor_seat_map_screen.dart';
import '../common/gps_diagnostic_screen.dart';

class ConductorHomeScreen extends StatelessWidget {
  const ConductorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final busId = user?.assignedBusId;

    if (busId == null || busId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Conductor Mode'),
          backgroundColor: AppTheme.primaryDark,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => authService.logout(),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_bus_filled_outlined, size: 72, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No Bus Assigned',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your conductor account (${user?.email}) is not yet linked to an active vehicle.\n\nPlease contact your fleet dispatcher or administrator to set your assignedBusId in Firestore.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => authService.fetchUserData(user?.uid ?? ''),
                  child: const Text('RECHECK ASSIGNMENT'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FutureBuilder<BusModel?>(
      future: BusService().getBusById(busId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final assignedBus = snapshot.data;
        if (assignedBus == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Conductor Mode'),
              backgroundColor: AppTheme.primaryDark,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => authService.logout(),
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Assigned bus "$busId" was not found in the fleet database.'),
              ),
            ),
          );
        }

        final locationService = Provider.of<LocationService>(context);
        final isBroadcasting = locationService.isBroadcastingFor(assignedBus.id);

        return Scaffold(
          appBar: AppBar(
            title: const Text('CityBus Go — Conductor'),
            backgroundColor: AppTheme.primaryDark,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () => authService.logout(),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: AppTheme.primaryDark.withOpacity(0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppTheme.primaryDark,
                          foregroundColor: Colors.white,
                          radius: 26,
                          child: Icon(Icons.badge_outlined, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Conductor: ${user?.name ?? "Officer"}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                              Text(
                                user?.email ?? '',
                                style: const TextStyle(color: Colors.black54, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Assigned: ${assignedBus.plateNumber} (Route ${assignedBus.routeNumber})',
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Route ${assignedBus.routeNumber} Controls',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  context,
                  icon: Icons.event_seat_rounded,
                  title: 'Seat Map & Walk-in Ticketing',
                  subtitle: 'Live seat grid & passenger boarding/departing controls',
                  color: AppTheme.accentGreen,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConductorSeatMapScreen(
                          bus: assignedBus,
                          conductorId: user!.uid,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  context,
                  icon: isBroadcasting ? Icons.cell_tower : Icons.location_on_outlined,
                  title: isBroadcasting ? 'Broadcasting Bus GPS (Active)' : 'Start GPS Broadcast',
                  subtitle: isBroadcasting
                      ? 'Live location streaming to passengers every 10m'
                      : 'Broadcast device GPS to bus_locations collection',
                  color: isBroadcasting ? AppTheme.accentGreen : Colors.teal,
                  trailing: Switch(
                    value: isBroadcasting,
                    activeColor: AppTheme.accentGreen,
                    onChanged: (enabled) {
                      if (enabled) {
                        locationService.startTracking(busId: assignedBus.id);
                      } else {
                        locationService.stopTracking();
                      }
                    },
                  ),
                  onTap: () {
                    if (!isBroadcasting) {
                      locationService.startTracking(busId: assignedBus.id);
                    } else {
                      locationService.stopTracking();
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  context,
                  icon: Icons.speed,
                  title: 'GPS Diagnostics Tool',
                  subtitle: 'View raw GPS coordinates, accuracy, and latency',
                  color: Colors.blueGrey,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GpsDiagnosticScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
