import 'package:flutter/material.dart';
import '../../models/bus_model.dart';
import '../../services/ticket_service.dart';
import '../../widgets/loading_overlay.dart';
import '../../utils/app_theme.dart';

class IssueTicketModal extends StatefulWidget {
  final BusModel bus;
  final String seatNumber;
  final String conductorId;
  final VoidCallback onTicketIssued;

  const IssueTicketModal({
    super.key,
    required this.bus,
    required this.seatNumber,
    required this.conductorId,
    required this.onTicketIssued,
  });

  @override
  State<IssueTicketModal> createState() => _IssueTicketModalState();
}

class _IssueTicketModalState extends State<IssueTicketModal> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ticketService = TicketService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _issueTicket() async {
    setState(() => _isLoading = true);

    try {
      final passengerName = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Walk-in Passenger';
      final passengerPhone = _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null;

      await _ticketService.bookSeat(
        busId: widget.bus.id,
        busPlateNumber: widget.bus.plateNumber,
        routeNumber: widget.bus.routeNumber,
        seatNumber: widget.seatNumber,
        passengerId: 'walk_in',
        passengerName: passengerName,
        passengerPhone: passengerPhone,
        issuedByRole: 'conductor',
        conductorId: widget.conductorId,
        fare: 150.0,
        paymentMethod: 'cash',
      );

      if (!mounted) return;
      widget.onTicketIssued();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Issued Cash Ticket for Seat #${widget.seatNumber}'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to issue ticket: $e'),
          backgroundColor: AppTheme.occupiedRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Issuing cash ticket...',
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Issue Ticket: Seat #${widget.seatNumber}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Route ${widget.bus.routeNumber} (${widget.bus.plateNumber}) • Standard Fare: Rs. 150.00',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Passenger Name (Optional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Passenger Phone (Optional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _issueTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
              ),
              child: const Text('CONFIRM CASH PAYMENT (Rs. 150)'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
