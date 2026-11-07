class SeatModel {
  final String seatNumber;
  final String status; // 'available' or 'taken'
  final String? bookedBy;
  final DateTime? bookedAt;
  final String? ticketId;

  SeatModel({
    required this.seatNumber,
    required this.status,
    this.bookedBy,
    this.bookedAt,
    this.ticketId,
  });

  bool get isAvailable => status == 'available';

  factory SeatModel.fromJson(Map<String, dynamic> j) => SeatModel(
        seatNumber: j['seat_number'].toString(),
        status: j['status'] ?? 'available',
        bookedBy: j['booked_by'],
        bookedAt: DateTime.tryParse(j['booked_at'] ?? ''),
        ticketId: j['ticket_id'],
      );

  /// Applies a live seat_booked / seat_released event.
  SeatModel withStatus(String newStatus, {String? ticketId}) => SeatModel(
        seatNumber: seatNumber,
        status: newStatus,
        bookedBy: newStatus == 'available' ? null : bookedBy,
        bookedAt: newStatus == 'available' ? null : (bookedAt ?? DateTime.now()),
        ticketId: newStatus == 'available' ? null : (ticketId ?? this.ticketId),
      );
}
