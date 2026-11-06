import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../authentication/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'find_bus_screen.dart';
import 'my_tickets_screen.dart';
import '../tracking/gps_diagnostic_screen.dart';

class PassengerHomeScreen extends StatelessWidget {
  const PassengerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    final userId = user?.uid ?? 'guest_pass_1';
    final userName = user?.name ?? 'Passenger';

    return Scaffold(
      appBar: AppBar(
        title: const Text('CityBus Go — Passenger'),
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
              color: AppTheme.primaryBlue.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      radius: 26,
                      child: Icon(Icons.person, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, $userName!',
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
                              color: AppTheme.accentGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Role: Passenger Mode',
                              style: TextStyle(
                                color: AppTheme.accentGreen,
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
              'Passenger Services',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFeatureTile(
              context,
              icon: Icons.search_rounded,
              title: 'Find Bus & View Seats',
              subtitle: 'Enter plate number or scan plate with camera (RTBT-17)',
              color: AppTheme.primaryBlue,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FindBusScreen(
                      passengerId: userId,
                      passengerName: userName,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildFeatureTile(
              context,
              icon: Icons.confirmation_number_outlined,
              title: 'My Booked Tickets',
              subtitle: 'View active e-tickets and digital QR receipts (RTBT-19)',
              color: Colors.deepPurple,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MyTicketsScreen(passengerId: userId),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildFeatureTile(
              context,
              icon: Icons.gps_fixed_rounded,
              title: 'Live GPS Telemetry Tool',
              subtitle: 'Test mobile device GPS ping and accuracy (RTBT-16)',
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

  Widget _buildFeatureTile(
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
