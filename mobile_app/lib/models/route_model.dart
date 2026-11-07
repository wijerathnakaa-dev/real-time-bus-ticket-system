class StopModel {
  final String id;
  final String name;
  final int sequence;
  final double latitude;
  final double longitude;

  StopModel({required this.id, required this.name, required this.sequence, required this.latitude, required this.longitude});

  factory StopModel.fromJson(Map<String, dynamic> j) => StopModel(
        id: j['id'] ?? j['stop_id'] ?? '',
        name: j['stop_name'] ?? '',
        sequence: (j['stop_sequence'] as num?)?.toInt() ?? 0,
        latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'stop_name': name, 'latitude': latitude, 'longitude': longitude};
}

class RouteModel {
  final String id;
  final String routeNumber;
  final String origin;
  final String destination;
  final double standardFare;
  final int estimatedDurationMins;
  final List<StopModel> stops;
  final int stopCount;

  RouteModel({
    required this.id,
    required this.routeNumber,
    required this.origin,
    required this.destination,
    required this.standardFare,
    required this.estimatedDurationMins,
    this.stops = const [],
    this.stopCount = 0,
  });

  String get name => '$origin - $destination';

  factory RouteModel.fromJson(Map<String, dynamic> j) {
    final stops = ((j['stops'] as List?) ?? []).map((s) => StopModel.fromJson(s as Map<String, dynamic>)).toList();
    return RouteModel(
      id: j['id'] ?? '',
      routeNumber: j['route_number'] ?? '',
      origin: j['origin'] ?? '',
      destination: j['destination'] ?? '',
      standardFare: (j['standard_fare'] as num?)?.toDouble() ?? 0,
      estimatedDurationMins: (j['estimated_duration_mins'] as num?)?.toInt() ?? 0,
      stops: stops,
      stopCount: (j['stop_count'] as num?)?.toInt() ?? stops.length,
    );
  }

  /// Mirrors the server's pro-rated fare so the passenger sees the price before booking.
  double fareBetween(StopModel? from, StopModel? to) {
    if (from == null || to == null || stops.length < 2 || to.sequence <= from.sequence) return standardFare;
    final f = standardFare * (to.sequence - from.sequence) / (stops.length - 1);
    final rounded = (f / 10).round() * 10.0;
    final floor = (standardFare * 0.2).roundToDouble();
    return rounded > floor ? rounded : floor;
  }
}
