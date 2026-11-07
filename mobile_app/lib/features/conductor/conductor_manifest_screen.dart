import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bus_model.dart';
import '../../models/ticket_model.dart';
import '../tickets/ticket_service.dart';
import 'qr_scan_screen.dart';

/// Trip manifest: who is booked (in-app advance bookings and walk-ins), by seat,
/// plus ticket verification by the number shown under the passenger's QR code.
class ConductorManifestScreen extends StatefulWidget {
  final BusModel bus;
  const ConductorManifestScreen({super.key, required this.bus});

  @override
  State<ConductorManifestScreen> createState() => _ConductorManifestScreenState();
}

class _ConductorManifestScreenState extends State<ConductorManifestScreen> {
  final _service = TicketService();
  late final Stream<List<TicketModel>> _tickets = _service.streamBusTickets(widget.bus.id);
  final _number = TextEditingController();

  Future<void> _scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (code == null || !mounted) return;
    _number.text = code;
    await _verify();
  }

  Future<void> _verify() async {
    final n = _number.text.trim();
    if (n.isEmpty) return;
    try {
      final (valid, t) = await _service.verify(n);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(valid ? Icons.verified : Icons.block, color: valid ? AppTheme.accentGreen : AppTheme.occupiedRed, size: 48),
          title: Text(valid ? 'Valid ticket' : 'Not valid on this bus'),
          content: Text('${t.ticketId}\n${t.passengerName} - seat #${t.seatNumber}\n${t.busPlateNumber} - ${t.status} / ${t.paymentStatus}'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppTheme.occupiedRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passengers'), backgroundColor: AppTheme.primaryDark),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _number,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Ticket number', hintText: 'TKT-...', isDense: true),
                    onSubmitted: (_) => _verify(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: 'Scan QR', onPressed: _scan),
                ElevatedButton(onPressed: _verify, child: const Text('VERIFY')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TicketModel>>(
              stream: _tickets,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text(snap.error.toString()));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final list = [...snap.data!]..sort((a, b) => int.tryParse(a.seatNumber)?.compareTo(int.tryParse(b.seatNumber) ?? 0) ?? 0);
                if (list.isEmpty) return const Center(child: Text('No active tickets on this trip yet.'));
                final advance = list.where((t) => t.issuedByRole == 'passenger').length;
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('${list.length} on board / booked - $advance booked in the app', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    for (final t in list)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: t.issuedByRole == 'passenger' ? Colors.deepPurple : AppTheme.primaryDark,
                          foregroundColor: Colors.white,
                          child: Text(t.seatNumber),
                        ),
                        title: Text(t.passengerName),
                        subtitle: Text('${t.fromStopName ?? '-'} to ${t.toStopName ?? '-'}\n${t.ticketId}'),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(AppConstants.money(t.fare), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(t.issuedByRole == 'passenger' ? (t.paymentStatus == 'paid' ? 'App - paid' : 'App - unpaid') : 'Cash',
                                style: TextStyle(fontSize: 11, color: t.paymentStatus == 'paid' ? AppTheme.accentGreen : Colors.orange)),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
