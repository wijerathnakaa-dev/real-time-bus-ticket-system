import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bus_model.dart';
import '../../models/eta_model.dart';
import '../../shared/widgets/bus_map_view.dart';
import '../../shared/widgets/stop_timeline.dart';
import '../buses/bus_service.dart';

/// Stop-by-stop console: arrivals are detected automatically from GPS (within 150 m);
/// the conductor confirms the actual departure, which drives the passengers' ETAs.
class ConductorTripScreen extends StatefulWidget {
  final BusModel bus;
  const ConductorTripScreen({super.key, required this.bus});

  @override
  State<ConductorTripScreen> createState() => _ConductorTripScreenState();
}

class _ConductorTripScreenState extends State<ConductorTripScreen> {
  final _service = BusService();
  late final Stream<BusEta> _eta = _service.streamEta(widget.bus.id);
  String? _busyStop;

  Future<void> _confirm(StopEta s, {required bool departure}) async {
    setState(() => _busyStop = s.stopId);
    try {
      await _service.confirmStop(widget.bus.id, s.stopId, departure: departure);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppTheme.occupiedRed));
    } finally {
      if (mounted) setState(() => _busyStop = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stops & departures'), backgroundColor: AppTheme.primaryDark),
      body: StreamBuilder<BusEta>(
        stream: _eta,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final eta = snap.data!;
          return ListView(
            children: [
              BusMapView(eta: eta, plate: widget.bus.plateNumber, height: 180),
              if (!eta.onTrip)
                const Padding(padding: EdgeInsets.all(16), child: Text('Start the trip from the home screen to confirm stops.')),
              StopTimeline(
                eta: eta,
                trailingBuilder: (s) {
                  if (!eta.onTrip || s.state == 'departed' || s.actualDeparture != null) return const SizedBox(width: 8);
                  if (_busyStop == s.stopId) return const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                  final isNext = s.stopId == eta.nextStopId || s.actualArrival != null;
                  if (!isNext) return const SizedBox(width: 8);
                  return s.actualArrival == null
                      ? OutlinedButton(onPressed: () => _confirm(s, departure: false), child: const Text('ARRIVED'))
                      : ElevatedButton(onPressed: () => _confirm(s, departure: true), child: const Text('DEPART'));
                },
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
