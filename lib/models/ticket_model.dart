import 'package:cloud_firestore/cloud_firestore.dart';

class TicketModel {
  final String id;
  final String ticketId;
  final String busId;
  final String busPlateNumber;
  final String routeNumber;
  final String seatNumber;
  final String passengerId;
  final String passengerName;
  final String? passengerPhone;
  final String issuedByRole; // 'passenger' or 'conductor'
  final String? conductorId;
  final double fare;
  final String paymentStatus;
  final String paymentMethod;
  final DateTime issuedAt;

  TicketModel({
    required this.id,
    required this.ticketId,
    required this.busId,
    required this.busPlateNumber,
    required this.routeNumber,
    required this.seatNumber,
    required this.passengerId,
    required this.passengerName,
    this.passengerPhone,
    required this.issuedByRole,
    this.conductorId,
    required this.fare,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.issuedAt,
  });

  factory TicketModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TicketModel(
      id: doc.id,
      ticketId: data['ticketId'] ?? doc.id,
      busId: data['busId'] ?? '',
      busPlateNumber: data['busPlateNumber'] ?? '',
      routeNumber: data['routeNumber'] ?? '',
      seatNumber: data['seatNumber'] ?? '',
      passengerId: data['passengerId'] ?? '',
      passengerName: data['passengerName'] ?? '',
      passengerPhone: data['passengerPhone'],
      issuedByRole: data['issuedByRole'] ?? 'passenger',
      conductorId: data['conductorId'],
      fare: (data['fare'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: data['paymentStatus'] ?? 'paid',
      paymentMethod: data['paymentMethod'] ?? 'cash',
      issuedAt: (data['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticketId': ticketId,
      'busId': busId,
      'busPlateNumber': busPlateNumber,
      'routeNumber': routeNumber,
      'seatNumber': seatNumber,
      'passengerId': passengerId,
      'passengerName': passengerName,
      if (passengerPhone != null) 'passengerPhone': passengerPhone,
      'issuedByRole': issuedByRole,
      if (conductorId != null) 'conductorId': conductorId,
      'fare': fare,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'issuedAt': Timestamp.fromDate(issuedAt),
    };
  }
}
