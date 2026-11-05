import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory SeatModel.fromMap(Map<String, dynamic> map, String id) {
    return SeatModel(
      seatNumber: id,
      status: map['status'] ?? 'available',
      bookedBy: map['bookedBy'],
      bookedAt: (map['bookedAt'] as Timestamp?)?.toDate(),
      ticketId: map['ticketId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'seatNumber': seatNumber,
      'status': status,
      'bookedBy': bookedBy,
      'bookedAt': bookedAt != null ? Timestamp.fromDate(bookedAt!) : null,
      'ticketId': ticketId,
    };
  }
}

