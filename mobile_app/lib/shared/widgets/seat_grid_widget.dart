import 'package:flutter/material.dart';
import '../../models/seat_model.dart';
import '../../core/theme/app_theme.dart';

typedef OnSeatSelectedCallback = void Function(String seatNumber);

class SeatGridWidget extends StatelessWidget {
  final List<SeatModel> seats;
  final String? selectedSeatNumber;
  final OnSeatSelectedCallback onSeatSelected;
  final bool isConductorView;

  const SeatGridWidget({
    super.key,
    required this.seats,
    required this.selectedSeatNumber,
    required this.onSeatSelected,
    this.isConductorView = false,
  });

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) {
      return const Center(child: Text('Loading bus seating layout...'));
    }

    return Column(
      children: [
        // Front / Driver Indicator
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('FRONT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
              Row(
                children: [
                  Icon(Icons.airline_seat_recline_extra, size: 18, color: Colors.blueGrey),
                  SizedBox(width: 4),
                  Text('DRIVER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                ],
              ),
            ],
          ),
        ),

        // Seat Grid (2 x Aisle x 2 Layout)
        Expanded(
          child: ListView.builder(
            itemCount: (seats.length / 4).ceil(),
            itemBuilder: (context, rowIndex) {
              final startIndex = rowIndex * 4;
              final seat1 = startIndex < seats.length ? seats[startIndex] : null;
              final seat2 = startIndex + 1 < seats.length ? seats[startIndex + 1] : null;
              final seat3 = startIndex + 2 < seats.length ? seats[startIndex + 2] : null;
              final seat4 = startIndex + 3 < seats.length ? seats[startIndex + 3] : null;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (seat1 != null) _buildSeatBox(seat1),
                    const SizedBox(width: 8),
                    if (seat2 != null) _buildSeatBox(seat2),
                    const SizedBox(width: 28), // Aisle
                    if (seat3 != null) _buildSeatBox(seat3),
                    const SizedBox(width: 8),
                    if (seat4 != null) _buildSeatBox(seat4),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSeatBox(SeatModel seat) {
    final isSelected = selectedSeatNumber == seat.seatNumber;
    final isTaken = !seat.isAvailable;

    Color bgColor;
    if (isTaken) {
      bgColor = AppTheme.occupiedRed;
    } else if (isSelected) {
      bgColor = AppTheme.selectedSeat;
    } else {
      bgColor = AppTheme.accentGreen;
    }

    return GestureDetector(
      onTap: () {
        if (!isTaken) {
          onSeatSelected(seat.seatNumber);
        }
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.selectedSeat.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isTaken ? Icons.close : (isSelected ? Icons.check : Icons.airline_seat_recline_normal),
                color: Colors.white,
                size: 20,
              ),
              Text(
                seat.seatNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

