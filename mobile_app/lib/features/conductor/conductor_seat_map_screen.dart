import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bus_model.dart';
import '../../models/seat_model.dart';
import '../../shared/widgets/seat_grid_widget.dart';
import '../buses/bus_service.dart';
import '../tickets/ticket_service.dart';
import 'issue_ticket_modal.dart';

/// Conductor's live seat map: tap a free seat to issue a cash ticket, tap a taken
/// seat to free it when the passenger alights; long-press for a manual override.
class ConductorSeatMapScreen extends StatefulWidget {
  final BusModel bus;
  final String? conductorId;
  const ConductorSeatMapScreen({super.key, required this.bus, this.conductorId});

  @override
  State<ConductorSeatMapScreen> createState() => _ConductorSeatMapScreenState();
}

class _ConductorSeatMapScreenState extends State<ConductorSeatMapScreen> {
  final BusService _busService = BusService();
  final TicketService _ticketService = TicketService();
  late final Stream<List<SeatModel>> _seats = _busService.streamSeatsForBus(widget.bus.id);
  String? _selectedSeatNumber;

  void _snack(String m, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: error ? AppTheme.occupiedRed : AppTheme.accentGreen));

  void _onSeatTapped(String seatNumber, List<SeatModel> seats) {
    final seat = seats.firstWhere((s) => s.seatNumber == seatNumber);
    if (!seat.isAvailable) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Free seat #$seatNumber?'),
          content: Text(seat.ticketId != null
              ? 'The passenger on seat #$seatNumber has got off. Their ticket is completed and the seat becomes available to everyone.'
              : 'Seat #$seatNumber is marked occupied without a ticket. Mark it available?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _ticketService.releaseSeat(busId: widget.bus.id, seatNumber: seatNumber);
                  if (mounted) _snack('Seat #$seatNumber is now free.');
                } on ApiException catch (e) {
                  if (mounted) _snack(e.message, error: true);
                }
              },
              child: const Text('Free seat'),
            ),
          ],
        ),
      );
      return;
    }
    if (!widget.bus.approved) {
      _snack('This bus is waiting for admin approval - ticketing is disabled.', error: true);
      return;
    }
    setState(() => _selectedSeatNumber = seatNumber);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => IssueTicketModal(bus: widget.bus, seatNumber: seatNumber, onTicketIssued: () {}),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedSeatNumber = null);
    });
  }

  Future<void> _override(List<SeatModel> seats) async {
    final n = _selectedSeatNumber ?? await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Manual seat override'),
          content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seat number')),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Next'))],
        );
      },
    );
    if (n == null || n.isEmpty || !mounted) return;
    final seat = seats.where((s) => s.seatNumber == n).firstOrNull;
    if (seat == null) return _snack('No seat #$n on this bus', error: true);
    try {
      await _ticketService.overrideSeat(busId: widget.bus.id, seatNumber: n, taken: seat.isAvailable);
      _snack('Seat #$n marked ${seat.isAvailable ? 'occupied (no ticket)' : 'available'}');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SeatModel>>(
      stream: _seats,
      builder: (context, snapshot) {
        final seats = snapshot.data ?? [];
        final freeCount = seats.where((s) => s.isAvailable).length;
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.bus.plateNumber} seats'),
            backgroundColor: AppTheme.primaryDark,
            actions: [IconButton(icon: const Icon(Icons.tune), tooltip: 'Manual override', onPressed: seats.isEmpty ? null : () => _override(seats))],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Free: $freeCount / ${seats.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Text('Tap green to issue, red to free', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: snapshot.hasError
                    ? Center(child: Text(snapshot.error.toString()))
                    : !snapshot.hasData
                        ? const Center(child: CircularProgressIndicator())
                        : SeatGridWidget(
                            seats: seats,
                            selectedSeatNumber: _selectedSeatNumber,
                            isConductorView: true,
                            onSeatSelected: (n) => _onSeatTapped(n, seats),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
