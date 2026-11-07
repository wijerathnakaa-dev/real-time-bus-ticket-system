import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../buses/bus_service.dart';
import '../tickets/ticket_service.dart';

/// Conductor issues a cash ticket in person. Fare is pro-rated by boarding/destination stop.
class IssueTicketModal extends StatefulWidget {
  final BusModel bus;
  final String seatNumber;
  final String? conductorId;
  final VoidCallback onTicketIssued;

  const IssueTicketModal({super.key, required this.bus, required this.seatNumber, this.conductorId, required this.onTicketIssued});

  @override
  State<IssueTicketModal> createState() => _IssueTicketModalState();
}

class _IssueTicketModalState extends State<IssueTicketModal> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ticketService = TicketService();
  RouteModel? _route;
  StopModel? _from;
  StopModel? _to;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.bus.routeId != null) {
      BusService().getRoute(widget.bus.routeId!).then((r) {
        if (!mounted) return;
        setState(() {
          _route = r;
          if (r.stops.length >= 2) {
            _from = r.stops.first;
            _to = r.stops.last;
          }
        });
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  double get _fare => _route?.fareBetween(_from, _to) ?? widget.bus.standardFare;

  Future<void> _issueTicket() async {
    setState(() => _isLoading = true);
    try {
      final t = await _ticketService.bookSeat(
        busId: widget.bus.id,
        seatNumber: widget.seatNumber,
        fromStopId: _from?.id,
        toStopId: _to?.id,
        passengerName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        passengerPhone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      );
      if (!mounted) return;
      widget.onTicketIssued();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Issued ${t.ticketId} - seat #${t.seatNumber} - collect ${AppConstants.money(t.fare)} cash'),
        backgroundColor: AppTheme.accentGreen,
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppTheme.occupiedRed));
      if (e.isConflict) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = _route?.stops ?? const <StopModel>[];
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Issuing ticket...',
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Issue ticket: seat #${widget.seatNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const Divider(),
            if (stops.length >= 2)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _from?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Boards at', isDense: true),
                      items: [for (final s in stops.sublist(0, stops.length - 1)) DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))],
                      onChanged: (id) => setState(() {
                        _from = stops.firstWhere((s) => s.id == id);
                        if (_to != null && _to!.sequence <= _from!.sequence) _to = stops.last;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_from?.id),
                      initialValue: _to?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Gets off at', isDense: true),
                      items: [
                        for (final s in stops.where((s) => s.sequence > (_from?.sequence ?? 0))) DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))
                      ],
                      onChanged: (id) => setState(() => _to = stops.firstWhere((s) => s.id == id)),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Passenger name (optional)', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Passenger phone (optional)', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _issueTicket,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
              child: Text('CASH RECEIVED - ${AppConstants.money(_fare)}'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
