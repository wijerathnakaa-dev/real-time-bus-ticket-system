import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/location_service.dart';
import '../../utils/app_theme.dart';

class GpsDiagnosticScreen extends StatefulWidget {
  const GpsDiagnosticScreen({super.key});

  @override
  State<GpsDiagnosticScreen> createState() => _GpsDiagnosticScreenState();
}

class _GpsDiagnosticScreenState extends State<GpsDiagnosticScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locService = Provider.of<LocationService>(context, listen: false);
      locService.checkAndRequestPermission();
      locService.startTracking();
    });
  }

  @override
  void dispose() {
    // Keep location service lifecycle managed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locService = Provider.of<LocationService>(context);
    final loc = locService.currentLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Diagnostics (RTBT-16)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Real-Time Bus Location Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tests GPS accuracy, updates, and permission resilience for conductor tracking.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 20),

            if (locService.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.occupiedRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.occupiedRed.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.occupiedRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        locService.errorMessage!,
                        style: const TextStyle(color: AppTheme.occupiedRed, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Telemetry Status',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: loc != null
                                ? AppTheme.accentGreen.withOpacity(0.15)
                                : Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            loc != null ? 'STREAMING' : 'ACQUIRING FIX',
                            style: TextStyle(
                              color: loc != null ? AppTheme.accentGreen : Colors.amber[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildDataRow(
                      icon: Icons.my_location,
                      label: 'Latitude',
                      value: loc != null ? loc.latitude.toStringAsFixed(6) : 'Waiting...',
                    ),
                    const SizedBox(height: 12),
                    _buildDataRow(
                      icon: Icons.location_searching,
                      label: 'Longitude',
                      value: loc != null ? loc.longitude.toStringAsFixed(6) : 'Waiting...',
                    ),
                    const SizedBox(height: 12),
                    _buildDataRow(
                      icon: Icons.radar,
                      label: 'Accuracy',
                      value: loc != null ? '${loc.accuracy.toStringAsFixed(1)} m' : 'Waiting...',
                    ),
                    const SizedBox(height: 12),
                    _buildDataRow(
                      icon: Icons.speed,
                      label: 'Speed',
                      value: loc != null ? '${(loc.speed * 3.6).toStringAsFixed(1)} km/h' : '0.0 km/h',
                    ),
                    const SizedBox(height: 12),
                    _buildDataRow(
                      icon: Icons.access_time,
                      label: 'Last Update',
                      value: loc != null
                          ? DateFormat('HH:mm:ss').format(loc.timestamp)
                          : 'Waiting for GPS ping...',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => locService.getCurrentLocation(),
              icon: const Icon(Icons.refresh),
              label: const Text('REFRESH FIX NOW'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => locService.checkAndRequestPermission(),
              icon: const Icon(Icons.security),
              label: const Text('RECHECK PERMISSION'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
