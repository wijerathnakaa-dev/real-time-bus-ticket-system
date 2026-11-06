import 'package:flutter/material.dart';
import '../../models/ticket_model.dart';
import '../../core/theme/app_theme.dart';
import 'my_tickets_screen.dart';

class TicketConfirmationScreen extends StatelessWidget {
  final TicketModel ticket;

  const TicketConfirmationScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmed'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 72),
            const SizedBox(height: 12),
            const Text(
              'Ticket Reserved Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
            ),
            const SizedBox(height: 24),

            // Printable / Viewable Ticket Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: const Color(0xFFFFFDE7), // Ticket parchment color
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      ticket.ticketId,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepOrange),
                    ),
                    const Divider(height: 24),
                    _buildRow('Bus Plate', ticket.busPlateNumber),
                    _buildRow('Route', 'Route ${ticket.routeNumber}'),
                    _buildRow('Allocated Seat', 'Seat #${ticket.seatNumber}'),
                    _buildRow('Passenger', ticket.passengerName),
                    _buildRow('Fare Paid', 'Rs. ${ticket.fare.toStringAsFixed(2)} (${ticket.paymentMethod})'),
                    _buildRow('Status', ticket.paymentStatus.toUpperCase()),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blueGrey.shade800, borderRadius: BorderRadius.circular(8)),
                      child: const Column(
                        children: [
                          Icon(Icons.qr_code_2, size: 80, color: Colors.white),
                          Text('SHOW THIS TO CONDUCTOR ON BOARD', style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => MyTicketsScreen(passengerId: ticket.passengerId)),
                );
              },
              child: const Text('VIEW ALL MY TICKETS'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('BACK TO HOME'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

