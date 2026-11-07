class TicketModel {
  final String id;
  final String ticketId; // human-readable ticket number, also encoded in the QR code
  final String busId;
  final String busPlateNumber;
  final String routeNumber;
  final String seatNumber;
  final String? fromStopName;
  final String? toStopName;
  final String passengerId;
  final String passengerName;
  final String? passengerPhone;
  final String issuedByRole; // 'passenger' or 'conductor'
  final String? conductorId;
  final double fare;
  final String paymentStatus; // pending | paid | refunded | failed
  final String paymentMethod; // payhere | cash
  final String status; // active | completed | cancelled
  final DateTime issuedAt;

  TicketModel({
    required this.id,
    required this.ticketId,
    required this.busId,
    required this.busPlateNumber,
    required this.routeNumber,
    required this.seatNumber,
    this.fromStopName,
    this.toStopName,
    required this.passengerId,
    required this.passengerName,
    this.passengerPhone,
    required this.issuedByRole,
    this.conductorId,
    required this.fare,
    required this.paymentStatus,
    required this.paymentMethod,
    this.status = 'active',
    required this.issuedAt,
  });

  bool get isActive => status == 'active';
  bool get awaitingPayment => isActive && paymentStatus == 'pending';
  bool get isValidForBoarding => isActive && paymentStatus == 'paid';

  factory TicketModel.fromJson(Map<String, dynamic> j) => TicketModel(
        id: j['id'] ?? '',
        ticketId: j['ticket_number'] ?? '',
        busId: j['bus_id'] ?? '',
        busPlateNumber: j['bus_plate_number'] ?? '',
        routeNumber: j['route_number'] ?? '',
        seatNumber: j['seat_number']?.toString() ?? '',
        fromStopName: j['from_stop_name'],
        toStopName: j['to_stop_name'],
        passengerId: j['passenger_id'] ?? '',
        passengerName: j['passenger_name'] ?? '',
        passengerPhone: j['passenger_phone'],
        issuedByRole: j['issued_by_role'] ?? 'passenger',
        conductorId: j['conductor_id'],
        fare: (j['fare'] as num?)?.toDouble() ?? 0,
        paymentStatus: j['payment_status'] ?? 'pending',
        paymentMethod: j['payment_method'] ?? 'payhere',
        status: j['status'] ?? 'active',
        issuedAt: DateTime.tryParse(j['issued_at'] ?? '')?.toLocal() ?? DateTime.now(),
      );
}
