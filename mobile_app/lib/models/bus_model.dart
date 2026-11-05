import 'package:cloud_firestore/cloud_firestore.dart';

class BusModel {
  final String id;
  final String plateNumber;
  final String routeId;
  final String routeNumber;
  final String conductorId;
  final int totalSeats;
  final int availableSeats;
  final String status;
  final DateTime updatedAt;

  BusModel({
    required this.id,
    required this.plateNumber,
    required this.routeId,
    required this.routeNumber,
    required this.conductorId,
    required this.totalSeats,
    required this.availableSeats,
    required this.status,
    required this.updatedAt,
  });

  factory BusModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BusModel(
      id: doc.id,
      plateNumber: data['plateNumber'] ?? '',
      routeId: data['routeId'] ?? '',
      routeNumber: data['routeNumber'] ?? '',
      conductorId: data['conductorId'] ?? '',
      totalSeats: data['totalSeats'] ?? 40,
      availableSeats: data['availableSeats'] ?? 0,
      status: data['status'] ?? 'on_trip',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plateNumber': plateNumber,
      'routeId': routeId,
      'routeNumber': routeNumber,
      'conductorId': conductorId,
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'status': status,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

