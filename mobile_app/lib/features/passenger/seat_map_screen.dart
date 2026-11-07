import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../../models/seat_model.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../shared/widgets/seat_grid_widget.dart';
import '../buses/bus_service.dart';
import '../tickets/ticket_service.dart';
import 'payment_screen.dart';

/// Live seat map. The passenger picks boarding/destination stops and a free seat;
/// the server reserves it atomically and the seat turns red for everyone instantly.
class SeatMapScreen extends StatefulWidget {
  final BusModel bus;
  // Kept for older call sites; identity now comes from the signed-in token.
  final String? passengerId;
  final String? passengerName;

  const SeatMapScreen({super.key, required this.bus, this.passengerId, this.passengerName});

  @override
  State<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends State<SeatMapScreen> {
  final BusService _busService = BusService();
  final TicketService _ticketService = TicketService();
  late final Stream<List<SeatModel>> _seats = _busService.streamSeatsForBus(widget.bus.id);

  String? _selectedSeatNumber;
  bool _isBooking = false;
  bool _booked = false; // our own seat_booked event must not look like someone else's
  RouteModel? _route;
  StopModel? _from;
  StopModel? _to;

  @override
  void initState() {
    super.initState();
    if (widget.bus.routeId != null) {
      _busService.getRoute(widget.bus.routeId!).then((r) {
        if (!mounted) return;
        setState(() {
          _route = r;
          if (r.stops.length >= 2) {
            _from = r.stops.first;
            _to = r.stops.last;
          }
        });
      }).catchError((_) {});
    }
  }

  double get _fare => _route?.fareBetween(_from, _to) ?? widget.bus.standardFare;

  Future<void> _handleBooking() async {
    if (_selectedSeatNumber == null) return;
    setState(() => _isBooking = true);
    try {
      final ticket = await _ticketService.bookSeat(
        busId: widget.bus.id,
        seatNumber: _selectedSeatNumber!,
        fromStopId: _from?.id,
        toStopId: _to?.id,
      );
      if (!mounted) return;
      _booked = true;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PaymentScreen(ticket: ticket)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConflict) setState(() => _selectedSeatNumber = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppTheme.occupiedRed));
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = _route?.stops ?? const <StopModel>[];
    return LoadingOverlay(
      isLoading: _isBooking,
      message: 'Reserving your seat...',
      child: Scaffold(
        appBar: AppBar(title: Text('${widget.bus.plateNumber} seats')),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: Colors.white,
              child: Column(
                children: [
                  Text(_route?.name ?? 'Route ${widget.bus.routeNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (stops.length >= 2) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _stopPicker('From', _from, stops.sublist(0, stops.length - 1), (s) => setState(() {
                              _from = s;
                              if (_to != null && _to!.sequence <= s.sequence) _to = stops.last;
                            }))),
                        const SizedBox(width: 8),
                        Expanded(child: _stopPicker('To', _to, stops.where((s) => s.sequence > (_from?.sequence ?? 0)).toList(), (s) => setState(() => _to = s))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _legend('Available', AppTheme.accentGreen),
                  _legend('Taken', AppTheme.occupiedRed),
                  _legend('Selected', AppTheme.selectedSeat),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<SeatModel>>(
                stream: _seats,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final seats = snapshot.data!;
                  final freeCount = seats.where((s) => s.isAvailable).length;
                  // Someone else took the seat we were looking at: clear the selection.
                  if (!_isBooking && !_booked && _selectedSeatNumber != null && seats.any((s) => s.seatNumber == _selectedSeatNumber && !s.isAvailable)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _selectedSeatNumber = null);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That seat was just taken by someone else.')));
                    });
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Free: $freeCount / ${seats.length}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentGreen)),
                            const Text('Live', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SeatGridWidget(
                          seats: seats,
                          selectedSeatNumber: _selectedSeatNumber,
                          onSeatSelected: (n) => setState(() => _selectedSeatNumber = n),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_selectedSeatNumber != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Seat #$_selectedSeatNumber', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(AppConstants.money(_fare), style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      ElevatedButton(onPressed: _handleBooking, child: const Text('BOOK & PAY')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stopPicker(String label, StopModel? value, List<StopModel> options, ValueChanged<StopModel> onChanged) {
    final current = options.where((o) => o.id == value?.id).firstOrNull;
    return DropdownButtonFormField<String>(
      initialValue: current?.id,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [for (final s in options) DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))],
      onChanged: (id) => onChanged(options.firstWhere((s) => s.id == id)),
    );
  }

  Widget _legend(String label, Color color) => Row(
        children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      );
}
