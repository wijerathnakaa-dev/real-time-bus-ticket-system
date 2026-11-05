import 'package:flutter/material.dart';
import '../../models/ticket_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/app_theme.dart';

class MyTicketsScreen extends StatelessWidget {
  final String passengerId;

  const MyTicketsScreen({super.key, required this.passengerId});

  @override
  Widget build(BuildContext context) {
    final ticketService = TicketService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Booked Tickets'),
      ),
      body: StreamBuilder<List<TicketModel>>(
        stream: ticketService.streamPassengerTickets(passengerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tickets = snapshot.data ?? [];
          if (tickets.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No tickets booked yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final tkt = tickets[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.confirmation_num_rounded),
                  ),
                  title: Text('${tkt.ticketId} • Seat #${tkt.seatNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${tkt.busPlateNumber} (Route ${tkt.routeNumber})\nFare: Rs. ${tkt.fare.toStringAsFixed(2)}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tkt.paymentStatus.toUpperCase(),
                      style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
