import 'package:flutter/material.dart';
import '../../models/bus_model.dart';
import '../../models/seat_model.dart';
import '../../services/bus_service.dart';
import '../../services/ticket_service.dart';
import '../../widgets/seat_grid_widget.dart';
import '../../widgets/loading_overlay.dart';
import '../../utils/app_theme.dart';
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

  void _handleBooking() async {
    if (_selectedSeatNumber == null) return;

    setState(() => _isBooking = true);

    try {
      final ticket = await _ticketService.bookSeat(
        busId: widget.bus.id,
        busPlateNumber: widget.bus.plateNumber,
        routeNumber: widget.bus.routeNumber,
        seatNumber: _selectedSeatNumber!,
        passengerId: widget.passengerId,
        passengerName: widget.passengerName,
        issuedByRole: 'passenger',
        fare: 150.0, // Standard fare for route
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
                        'Route ${widget.bus.routeNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Plate: ${widget.bus.plateNumber}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Fare: Rs. 150.00', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                      Text('Cash on Board', style: TextStyle(color: Colors.grey, fontSize: 12)),
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

            // Live stream of seats
            Expanded(
              child: StreamBuilder<List<SeatModel>>(
                stream: _busService.streamSeatsForBus(widget.bus.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final seats = snapshot.data ?? [];
                  return SeatGridWidget(
                    seats: seats,
                    selectedSeatNumber: _selectedSeatNumber,
                    onSeatSelected: (num) => setState(() => _selectedSeatNumber = num),
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
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2)),
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
                        const Text('Total: Rs. 150.00', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
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
