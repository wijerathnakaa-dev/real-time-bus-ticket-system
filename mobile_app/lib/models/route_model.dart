import 'package:cloud_firestore/cloud_firestore.dart';

class RouteModel {
  final String id;
  final String routeNumber;
  final String origin;
  final String destination;
  final double standardFare;
  final int estimatedDurationMins;

  RouteModel({
    required this.id,
    required this.routeNumber,
    required this.origin,
    required this.destination,
    required this.standardFare,
    required this.estimatedDurationMins,
  });

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RouteModel(
      id: doc.id,
      routeNumber: data['routeNumber'] ?? '',
      origin: data['origin'] ?? '',
      destination: data['destination'] ?? '',
      standardFare: (data['standardFare'] as num?)?.toDouble() ?? 150.0,
      estimatedDurationMins: (data['estimatedDurationMins'] as num?)?.toInt() ?? 45,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'routeNumber': routeNumber,
      'origin': origin,
      'destination': destination,
      'standardFare': standardFare,
      'estimatedDurationMins': estimatedDurationMins,
    };
  }
}

