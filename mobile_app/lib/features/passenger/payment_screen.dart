import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/notifications/push_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ticket_model.dart';
import '../tickets/ticket_service.dart';
import 'ticket_confirmation_screen.dart';

/// PayHere payment for a reserved (pending) ticket. The seat stays held for 15 minutes.
class PaymentScreen extends StatefulWidget {
  final TicketModel ticket;
  const PaymentScreen({super.key, required this.ticket});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _service = TicketService();
  PaymentStart? _start;
  String? _error;
  bool _busy = false;
  StreamSubscription<TicketModel>? _watch;

  @override
  void initState() {
    super.initState();
    _service.startPayment(widget.ticket.id).then((s) {
      if (mounted) setState(() => _start = s);
    }).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
    _watch = _service.watchTicket(widget.ticket).listen((t) {
      if (!mounted) return;
      if (t.paymentStatus == 'paid') _done(t);
      if (t.status == 'cancelled') setState(() => _error = 'Payment failed or the seat hold expired. Please book again.');
    });
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  void _done(TicketModel t) {
    _watch?.cancel();
    PushService.followBus(t.busId); // "bus approaching" pushes for this trip
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TicketConfirmationScreen(ticket: t)));
  }

  Future<void> _pay() async {
    final s = _start;
    if (s == null) return;
    setState(() => _busy = true);
    try {
      if (s.isSimulated) {
        _done(await _service.simulatePayment(widget.ticket.id));
      } else if (!await _service.openCheckout(s.checkoutUrl!)) {
        setState(() => _error = 'Could not open the PayHere checkout page.');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    try {
      await _service.cancel(widget.ticket.id);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final s = _start;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.lock_clock, size: 56, color: AppTheme.primaryBlue),
          const SizedBox(height: 8),
          Text('Seat #${t.seatNumber} on ${t.busPlateNumber} is held for you',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const Text('Complete payment within 15 minutes.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('Ticket', t.ticketId),
                  if (t.fromStopName != null) _row('From', t.fromStopName!),
                  if (t.toStopName != null) _row('To', t.toStopName!),
                  _row('Passenger', t.passengerName),
                  const Divider(),
                  _row('Total', AppConstants.money(t.fare), bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: AppTheme.occupiedRed), textAlign: TextAlign.center),
            ),
          if (s == null && _error == null) const Center(child: CircularProgressIndicator()),
          if (s != null) ...[
            if (s.isSimulated)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  'Demo mode: PayHere merchant keys are not configured on the server, so this is a simulated payment. No money is charged.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _busy ? null : _pay,
              icon: const Icon(Icons.payment),
              label: Text(s.isSimulated ? 'PAY ${AppConstants.money(t.fare)} (SIMULATED)' : 'PAY WITH PAYHERE${s.mode == 'sandbox' ? ' (SANDBOX)' : ''}'),
            ),
            if (!s.isSimulated)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('After paying in the browser, come back here - this screen updates automatically.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
          ],
          const SizedBox(height: 8),
          TextButton(onPressed: _cancel, child: const Text('Cancel and release seat')),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Colors.black54)),
            Flexible(child: Text(v, textAlign: TextAlign.right, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: bold ? 17 : 14))),
          ],
        ),
      );
}
