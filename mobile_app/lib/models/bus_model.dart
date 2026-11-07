class BusModel {
  final String id;
  final String plateNumber;
  final String? routeId;
  final String routeNumber;
  final String routeName;
  final double standardFare;
  final String? conductorId;
  final String? conductorName;
  final int totalSeats;
  final int availableSeats;
  final String? photoUrl;
  final bool approved;
  final String status; // on_trip | idle | maintenance
  final double? latitude;
  final double? longitude;
  final double? speedKmh;

  BusModel({
    required this.id,
    required this.plateNumber,
    this.routeId,
    this.routeNumber = '',
    this.routeName = '',
    this.standardFare = 0,
    this.conductorId,
    this.conductorName,
    required this.totalSeats,
    required this.availableSeats,
    this.photoUrl,
    this.approved = true,
    required this.status,
    this.latitude,
    this.longitude,
    this.speedKmh,
  });

  bool get onTrip => status == 'on_trip';

  factory BusModel.fromJson(Map<String, dynamic> j) => BusModel(
        id: j['id'] ?? '',
        plateNumber: j['plate_number'] ?? '',
        routeId: j['route_id'],
        routeNumber: j['route_number'] ?? '',
        routeName: j['route_name'] ?? '',
        standardFare: (j['standard_fare'] as num?)?.toDouble() ?? 0,
        conductorId: j['conductor_id'],
        conductorName: j['conductor_name'],
        totalSeats: (j['total_seats'] as num?)?.toInt() ?? 40,
        availableSeats: (j['available_seats'] as num?)?.toInt() ?? 0,
        photoUrl: j['photo_url'],
        approved: j['approved'] ?? false,
        status: j['status'] ?? 'idle',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        speedKmh: (j['speed_kmh'] as num?)?.toDouble(),
      );
}
