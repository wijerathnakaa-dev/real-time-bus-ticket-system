import 'package:flutter/material.dart';
import '../../models/bus_model.dart';
import '../../models/seat_model.dart';
import '../../models/route_model.dart';
import '../buses/bus_service.dart';
import '../tickets/ticket_service.dart';
import '../../shared/widgets/seat_grid_widget.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ticket_confirmation_screen.dart';

class SeatMapScreen extends StatefulWidget {
  final BusModel bus;
  final String passengerId;
  final String passengerName;

  const SeatMapScreen({
    super.key,
    required this.bus,
    required this.passengerId,
    required this.passengerName,
  });

  @override
  State<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends State<SeatMapScreen> {
  final BusService _busService = BusService();
  final TicketService _ticketService = TicketService();

  String? _selectedSeatNumber;
  bool _isBooking = false;
  RouteModel? _route;

  @override
  void initState() {
    super.initState();
    _loadRouteDetails();
  }

  void _loadRouteDetails() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('routes').doc(widget.bus.routeId).get();
      if (doc.exists && mounted) {
        setState(() {
          _route = RouteModel.fromFirestore(doc);
        });
      }
    } catch (_) {}
  }

  void _handleBooking() async {
    if (_selectedSeatNumber == null) return;

    setState(() => _isBooking = true);
    final fare = _route?.standardFare ?? 150.0;

    try {
      final ticket = await _ticketService.bookSeat(
        busId: widget.bus.id,
        busPlateNumber: widget.bus.plateNumber,
        routeNumber: widget.bus.routeNumber,
        seatNumber: _selectedSeatNumber!,
        passengerId: widget.passengerId,
        passengerName: widget.passengerName,
        issuedByRole: 'passenger',
        fare: fare,
        paymentMethod: 'cash',
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TicketConfirmationScreen(ticket: ticket),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: $e'),
          backgroundColor: AppTheme.occupiedRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fare = _route?.standardFare ?? 150.0;

    return LoadingOverlay(
      isLoading: _isBooking,
      message: 'Reserving seat atomically...',
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.bus.plateNumber} Seat Map'),
        ),
        body: Column(
          children: [
            // Bus summary header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _route != null ? '${_route!.origin} ➔ ${_route!.destination}' : 'Route ${widget.bus.routeNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Plate: ${widget.bus.plateNumber}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Fare: Rs. ${fare.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                      const Text('Cash on Board', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            // Color legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLegendItem('Available', AppTheme.accentGreen),
                  _buildLegendItem('Taken', AppTheme.occupiedRed),
                  _buildLegendItem('Selected', AppTheme.selectedSeat),
                ],
              ),
            ),

            // Live stream of seats with dynamic free seat count
            Expanded(
              child: StreamBuilder<List<SeatModel>>(
                stream: _busService.streamSeatsForBus(widget.bus.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final seats = snapshot.data ?? [];
                  final freeCount = seats.where((s) => s.isAvailable).length;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Available Seats: $freeCount / ${seats.length}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentGreen)),
                            Text('Taken: ${seats.length - freeCount}',
                                style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SeatGridWidget(
                          seats: seats,
                          selectedSeatNumber: _selectedSeatNumber,
                          onSeatSelected: (num) => setState(() => _selectedSeatNumber = num),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom booking action sheet
            if (_selectedSeatNumber != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Selected Seat: #$_selectedSeatNumber', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Total: Rs. ${fare.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _handleBooking,
                      child: const Text('CONFIRM BOOKING'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
