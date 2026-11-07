import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/eta_model.dart';

/// Vertical stop list with live ETA / actual arrival-departure times.
class StopTimeline extends StatelessWidget {
  final BusEta eta;
  final String? highlightStopId;
  final Widget Function(StopEta stop)? trailingBuilder;

  const StopTimeline({super.key, required this.eta, this.highlightStopId, this.trailingBuilder});

  static final _time = DateFormat('h:mm a');

  @override
  Widget build(BuildContext context) {
    if (eta.stops.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('This bus has no route stops yet.'));
    }
    return Column(
      children: [
        for (var i = 0; i < eta.stops.length; i++) _row(eta.stops[i], i == 0, i == eta.stops.length - 1),
      ],
    );
  }

  Widget _row(StopEta s, bool first, bool last) {
    final isNext = s.stopId == eta.nextStopId;
    final departed = s.state == 'departed';
    final color = departed ? Colors.grey : (isNext ? AppTheme.primaryBlue : AppTheme.accentGreen);
    final highlight = s.stopId == highlightStopId;

    String detail;
    if (s.actualDeparture != null) {
      detail = 'Departed ${_time.format(s.actualDeparture!)}';
    } else if (s.actualArrival != null) {
      detail = 'Arrived ${_time.format(s.actualArrival!)} - at stop';
    } else if (s.etaMinutes != null && eta.onTrip) {
      final m = s.etaMinutes!;
      detail = m < 1 ? 'Arriving now' : 'Arrives in ${m.toStringAsFixed(0)} min (${_time.format(s.etaAt!)}) - ${s.distanceKm!.toStringAsFixed(1)} km';
    } else if (departed) {
      detail = 'Passed';
    } else {
      detail = eta.onTrip ? 'Waiting for GPS' : 'Bus not on a trip';
    }

    return Container(
      color: highlight ? AppTheme.selectedSeat.withValues(alpha: 0.10) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: IntrinsicHeight(
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Expanded(child: Container(width: 3, color: first ? Colors.transparent : color.withValues(alpha: 0.4))),
                  Icon(isNext ? Icons.directions_bus : (departed ? Icons.check_circle : Icons.circle_outlined), size: isNext ? 22 : 16, color: color),
                  Expanded(child: Container(width: 3, color: last ? Colors.transparent : color.withValues(alpha: 0.4))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.stopName,
                        style: TextStyle(fontWeight: isNext || highlight ? FontWeight.bold : FontWeight.w500, color: departed ? Colors.grey : Colors.black87)),
                    Text(detail, style: TextStyle(fontSize: 12, color: isNext ? AppTheme.primaryBlue : Colors.black54)),
                  ],
                ),
              ),
            ),
            if (trailingBuilder != null) trailingBuilder!(s),
          ],
        ),
      ),
    );
  }
}
