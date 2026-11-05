import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bus_model.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import 'conductor_seat_map_screen.dart';
import '../common/gps_diagnostic_screen.dart';

class ConductorHomeScreen extends StatelessWidget {
  const ConductorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    final conductorId = user?.uid ?? 'conductor_demo_uid';

    // Default assigned demo bus
    final assignedBus = BusModel(
      id: 'bus_WP_ND_1024',
      plateNumber: 'WP-ND-1024',
      routeId: 'route_138',
      routeNumber: '138',
      conductorId: conductorId,
      totalSeats: 40,
      availableSeats: 18,
      status: 'on_trip',
      updatedAt: DateTime.now(),
    );

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
                            child: const Text(
                              'Role: Conductor Mode',
                              style: TextStyle(
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
            const Text(
              'Assigned Vehicle (Route 138)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              context,
              icon: Icons.event_seat_rounded,
              title: 'Seat Map & Walk-in Ticketing',
              subtitle: 'View live grid & tap to issue tickets (RTBT-20 & RTBT-21)',
              color: AppTheme.accentGreen,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ConductorSeatMapScreen(
                      bus: assignedBus,
                      conductorId: conductorId,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              context,
              icon: Icons.location_on_rounded,
              title: 'Live GPS Telemetry Broadcast',
              subtitle: 'Check conductor device GPS broadcast (RTBT-16)',
              color: Colors.teal,
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
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
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
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
