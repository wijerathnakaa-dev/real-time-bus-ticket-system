import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/bus_model.dart';
import '../../models/eta_model.dart';
import '../../models/seat_model.dart';
import '../../shared/widgets/bus_map_view.dart';
import '../../shared/widgets/stop_timeline.dart';
import '../buses/bus_service.dart';
import 'seat_map_screen.dart';

/// Passenger view of one bus: identity card, live position, per-stop ETA and live free-seat count.
class BusTrackingScreen extends StatefulWidget {
  final BusModel bus;
  final String? highlightStopId;
  const BusTrackingScreen({super.key, required this.bus, this.highlightStopId});

  @override
  State<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  final _service = BusService();
  late final Stream<BusEta> _eta;
  late final Stream<List<SeatModel>> _seats;

  @override
  void initState() {
    super.initState();
    _eta = _service.streamEta(widget.bus.id, onEvent: (e) {
      if (e['type'] == 'bus_approaching' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e['title']} - ${e['body']}')));
      }
    }).asBroadcastStream();
    _seats = _service.streamSeatsForBus(widget.bus.id).asBroadcastStream();
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;
    return Scaffold(
      appBar: AppBar(title: Text(bus.plateNumber)),
      body: StreamBuilder<BusEta>(
        stream: _eta,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(snap.error.toString())));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final eta = snap.data!;
          return ListView(
            children: [
              BusMapView(eta: eta, plate: bus.plateNumber),
              _identityCard(bus),
              StreamBuilder<List<SeatModel>>(
                stream: _seats,
                builder: (context, s) {
                  final seats = s.data ?? [];
                  final free = seats.where((x) => x.isAvailable).length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.event_seat, color: free > 0 ? AppTheme.accentGreen : AppTheme.occupiedRed),
                        const SizedBox(width: 8),
                        Text(seats.isEmpty ? 'Loading seats...' : '$free of ${seats.length} seats free',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: free == 0
                              ? null
                              : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SeatMapScreen(bus: bus))),
                          icon: const Icon(Icons.confirmation_number),
                          label: const Text('BOOK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text('Stops and arrival times', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              StopTimeline(eta: eta, highlightStopId: widget.highlightStopId),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _identityCard(BusModel bus) => Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: bus.photoUrl != null
                    ? Image.network(bus.photoUrl!, width: 72, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _photoPlaceholder())
                    : _photoPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber.shade100, border: Border.all(color: Colors.black87), borderRadius: BorderRadius.circular(4)),
                      child: Text(bus.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                    const SizedBox(height: 4),
                    Text('Route ${bus.routeNumber} - ${bus.routeName}', style: const TextStyle(fontSize: 13)),
                    if (bus.conductorName != null) Text('Conductor: ${bus.conductorName}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _photoPlaceholder() => Container(
        width: 72,
        height: 56,
        color: Colors.blueGrey.shade100,
        child: const Icon(Icons.directions_bus, color: Colors.blueGrey),
      );
}
