class StopEta {
  final String stopId;
  final String stopName;
  final int sequence;
  final double latitude;
  final double longitude;
  final String state; // departed | arrived | upcoming
  final double? distanceKm;
  final double? etaMinutes;
  final DateTime? etaAt;
  final DateTime? actualArrival;
  final DateTime? actualDeparture;

  StopEta({
    required this.stopId,
    required this.stopName,
    required this.sequence,
    required this.latitude,
    required this.longitude,
    required this.state,
    this.distanceKm,
    this.etaMinutes,
    this.etaAt,
    this.actualArrival,
    this.actualDeparture,
  });

  factory StopEta.fromJson(Map<String, dynamic> j) => StopEta(
        stopId: j['stop_id'] ?? '',
        stopName: j['stop_name'] ?? '',
        sequence: (j['stop_sequence'] as num?)?.toInt() ?? 0,
        latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
        state: j['state'] ?? 'upcoming',
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        etaMinutes: (j['eta_minutes'] as num?)?.toDouble(),
        etaAt: DateTime.tryParse(j['eta_at'] ?? '')?.toLocal(),
        actualArrival: DateTime.tryParse(j['actual_arrival'] ?? '')?.toLocal(),
        actualDeparture: DateTime.tryParse(j['actual_departure'] ?? '')?.toLocal(),
      );
}

class BusEta {
  final String busId;
  final String status;
  final double? latitude;
  final double? longitude;
  final double speedKmh;
  final DateTime? updatedAt;
  final String? nextStopId;
  final List<StopEta> stops;

  BusEta({
    required this.busId,
    required this.status,
    this.latitude,
    this.longitude,
    this.speedKmh = 0,
    this.updatedAt,
    this.nextStopId,
    this.stops = const [],
  });

  bool get onTrip => status == 'on_trip';

  StopEta? get nextStop {
    for (final s in stops) {
      if (s.stopId == nextStopId) return s;
    }
    return null;
  }

  factory BusEta.fromJson(Map<String, dynamic> j) => BusEta(
        busId: j['bus_id'] ?? '',
        status: j['status'] ?? 'idle',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        speedKmh: (j['speed_kmh'] as num?)?.toDouble() ?? 0,
        updatedAt: DateTime.tryParse(j['location_updated_at'] ?? '')?.toLocal(),
        nextStopId: j['next_stop_id'],
        stops: ((j['stops'] as List?) ?? []).map((s) => StopEta.fromJson(s as Map<String, dynamic>)).toList(),
      );

  /// Applies a live bus_location / stop_* WebSocket event on top of the current timeline.
  BusEta merge(Map<String, dynamic> e) => BusEta(
        busId: busId,
        status: status,
        latitude: (e['latitude'] as num?)?.toDouble() ?? latitude,
        longitude: (e['longitude'] as num?)?.toDouble() ?? longitude,
        speedKmh: (e['speed_kmh'] as num?)?.toDouble() ?? speedKmh,
        updatedAt: e['type'] == 'bus_location' ? DateTime.now() : updatedAt,
        nextStopId: e.containsKey('next_stop_id') ? e['next_stop_id'] as String? : nextStopId,
        stops: e['stops'] is List ? (e['stops'] as List).map((s) => StopEta.fromJson(s as Map<String, dynamic>)).toList() : stops,
      );
}
