import 'package:flutter/material.dart';
import '../../models/bus_model.dart';
import '../../models/seat_model.dart';
import '../../services/bus_service.dart';
import '../../widgets/seat_grid_widget.dart';
import '../../utils/app_theme.dart';
import 'issue_ticket_modal.dart';

class ConductorSeatMapScreen extends StatefulWidget {
  final BusModel bus;
  final String conductorId;

  const ConductorSeatMapScreen({
    super.key,
    required this.bus,
    required this.conductorId,
  });

  @override
  State<ConductorSeatMapScreen> createState() => _ConductorSeatMapScreenState();
}

class _ConductorSeatMapScreenState extends State<ConductorSeatMapScreen> {
  final BusService _busService = BusService();
  String? _selectedSeatNumber;

  void _onSeatTapped(String seatNumber, List<SeatModel> seats) {
    final seat = seats.firstWhere((s) => s.seatNumber == seatNumber);
    if (!seat.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seat #$seatNumber is already taken.'),
          backgroundColor: AppTheme.occupiedRed,
        ),
      );
      return;
    }

    setState(() => _selectedSeatNumber = seatNumber);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => IssueTicketModal(
        bus: widget.bus,
        seatNumber: seatNumber,
        conductorId: widget.conductorId,
        onTicketIssued: () => setState(() => _selectedSeatNumber = null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.bus.plateNumber} Seat Control'),
        backgroundColor: AppTheme.primaryDark,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Route ${widget.bus.routeNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Bus: ${widget.bus.plateNumber}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('TAP SEAT TO ISSUE', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Available (Tap)', AppTheme.accentGreen),
                _buildLegendItem('Occupied', AppTheme.occupiedRed),
                _buildLegendItem('Selected', AppTheme.selectedSeat),
              ],
            ),
          ),

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
                  isConductorView: true,
                  onSeatSelected: (num) => _onSeatTapped(num, seats),
                );
              },
            ),
          ),
        ],
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
