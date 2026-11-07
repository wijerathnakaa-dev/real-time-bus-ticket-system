import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ticket_model.dart';
import '../buses/bus_service.dart';
import 'bus_tracking_screen.dart';
import 'my_tickets_screen.dart';

/// Digital receipt with a QR code the conductor scans / types to verify boarding.
class TicketConfirmationScreen extends StatelessWidget {
  final TicketModel ticket;
  final bool fromHistory;

  const TicketConfirmationScreen({super.key, required this.ticket, this.fromHistory = false});

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final statusColor = t.isValidForBoarding ? AppTheme.accentGreen : (t.awaitingPayment ? Colors.orange : Colors.grey);
    return Scaffold(
      appBar: AppBar(title: Text(fromHistory ? 'E-ticket' : 'Booking confirmed'), automaticallyImplyLeading: fromHistory),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!fromHistory) ...[
              const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 64),
              const SizedBox(height: 8),
              const Text('Payment received - have a good trip!',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
              const SizedBox(height: 20),
            ],
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(t.ticketId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryDark)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        t.isActive ? (t.paymentStatus == 'paid' ? 'VALID - PAID' : 'AWAITING PAYMENT') : t.status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (t.isActive)
                      QrImageView(data: t.ticketId, size: 180, backgroundColor: Colors.white)
                    else
                      const Icon(Icons.qr_code_2, size: 120, color: Colors.black12),
                    const Text('Show this to the conductor when boarding', style: TextStyle(color: Colors.black54, fontSize: 11)),
                    const Divider(height: 28),
                    _row('Bus', t.busPlateNumber),
                    _row('Route', t.routeNumber),
                    if (t.fromStopName != null) _row('From', t.fromStopName!),
                    if (t.toStopName != null) _row('To', t.toStopName!),
                    _row('Seat', '#${t.seatNumber}'),
                    _row('Passenger', t.passengerName),
                    _row('Fare', '${AppConstants.money(t.fare)} (${t.paymentMethod == 'cash' ? 'cash' : 'PayHere'})'),
                    _row('Issued', DateFormat('d MMM yyyy, h:mm a').format(t.issuedAt)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (t.isActive)
              ElevatedButton.icon(
                icon: const Icon(Icons.location_on),
                label: const Text('TRACK MY BUS'),
                onPressed: () async {
                  final bus = await BusService().getBusById(t.busId);
                  if (bus != null && context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BusTrackingScreen(bus: bus)));
                  }
                },
              ),
            if (!fromHistory) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MyTicketsScreen(passengerId: t.passengerId))),
                child: const Text('VIEW ALL MY TICKETS'),
              ),
              TextButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('BACK TO HOME')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
            Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          ],
        ),
      );
}
