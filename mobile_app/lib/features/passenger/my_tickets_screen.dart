import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ticket_model.dart';
import '../tickets/ticket_service.dart';
import 'payment_screen.dart';
import 'ticket_confirmation_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  final String passengerId;
  const MyTicketsScreen({super.key, required this.passengerId});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final _service = TicketService();
  late final Stream<List<TicketModel>> _tickets = _service.streamPassengerTickets(widget.passengerId);

  Future<void> _cancel(TicketModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel ticket ${t.ticketId}?'),
        content: Text(t.paymentStatus == 'paid' ? 'Seat #${t.seatNumber} is released and the fare is marked for refund.' : 'Seat #${t.seatNumber} is released.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel ticket')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.cancel(t.id);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My tickets')),
      body: StreamBuilder<List<TicketModel>>(
        stream: _tickets,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(snapshot.error.toString())));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final tickets = snapshot.data!;
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
            itemBuilder: (context, i) {
              final t = tickets[i];
              final (label, color) = switch ((t.status, t.paymentStatus)) {
                ('active', 'paid') => ('VALID', AppTheme.accentGreen),
                ('active', _) => ('PAY NOW', Colors.orange),
                ('completed', _) => ('COMPLETED', Colors.blueGrey),
                (_, 'refunded') => ('REFUNDED', Colors.grey),
                _ => (t.status.toUpperCase(), Colors.grey),
              };
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.isActive ? AppTheme.primaryBlue : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    child: Text(t.seatNumber),
                  ),
                  title: Text('${t.busPlateNumber} - Seat #${t.seatNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${t.fromStopName ?? 'Route ${t.routeNumber}'}${t.toStopName != null ? ' to ${t.toStopName}' : ''}\n'
                    '${AppConstants.money(t.fare)} - ${DateFormat('d MMM, h:mm a').format(t.issuedAt)}',
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      if (t.isActive)
                        InkWell(
                          onTap: () => _cancel(t),
                          child: const Padding(padding: EdgeInsets.only(top: 6), child: Text('Cancel', style: TextStyle(fontSize: 12, color: AppTheme.occupiedRed))),
                        ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => t.awaitingPayment ? PaymentScreen(ticket: t) : TicketConfirmationScreen(ticket: t, fromHistory: true),
                  )),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
