import 'dart:async';

import '../../core/api/api_client.dart';
import '../../core/api/live_socket.dart';
import '../../models/bus_model.dart';
import '../../models/eta_model.dart';
import '../../models/route_model.dart';
import '../../models/seat_model.dart';

/// Buses, routes, live seat maps and ETAs from the Go API + WebSocket.
class BusService {
  final ApiClient _api = ApiClient.instance;

  Future<BusModel?> getBusById(String busId) async {
    try {
      return BusModel.fromJson(await _api.get('/buses/$busId') as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Plate search ignores spaces/dashes: "nb 2451" finds "NB-2451".
  Future<BusModel?> findBusByPlate(String plateNumber) async {
    final list = await listBuses(plate: plateNumber);
    return list.isEmpty ? null : list.first;
  }

  Future<List<BusModel>> listBuses({String? plate, String? routeId, bool includeUnapproved = false}) async {
    final res = await _api.get('/buses', query: {
      if (plate != null) 'plate': plate,
      if (routeId != null) 'route_id': routeId,
      if (includeUnapproved) 'all': '1',
    }) as List;
    return res.map((b) => BusModel.fromJson(b as Map<String, dynamic>)).toList();
  }

  /// Fleet list that refreshes when any bus changes (used by passenger browse).
  Stream<List<BusModel>> streamActiveBuses() => _liveList(() => listBuses(), null);

  Future<List<RouteModel>> listRoutes() async {
    final res = await _api.get('/routes') as List;
    return res.map((r) => RouteModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<RouteModel> getRoute(String id) async => RouteModel.fromJson(await _api.get('/routes/$id') as Map<String, dynamic>);

  Future<List<SeatModel>> getSeats(String busId) async {
    final res = await _api.get('/buses/$busId/seats') as List;
    return res.map((s) => SeatModel.fromJson(s as Map<String, dynamic>)).toList();
  }

  /// Live seat map: initial fetch, then seat_booked / seat_released events applied
  /// in place; a full re-fetch after every (re)connect keeps it consistent.
  Stream<List<SeatModel>> streamSeatsForBus(String busId) {
    late StreamController<List<SeatModel>> ctrl;
    LiveSocket? socket;
    StreamSubscription? sub;
    var seats = <SeatModel>[];

    Future<void> reload() async {
      try {
        seats = await getSeats(busId);
        if (!ctrl.isClosed) ctrl.add(seats);
      } catch (e) {
        if (!ctrl.isClosed) ctrl.addError(e);
      }
    }

    ctrl = StreamController<List<SeatModel>>(
      onListen: () {
        reload();
        socket = LiveSocket(busId: busId);
        sub = socket!.events.listen((e) {
          final type = e['type'];
          if (type == 'resync' || type == 'trip_end' || type == 'bus_updated') {
            reload();
          } else if ((type == 'seat_booked' || type == 'seat_released') && e['bus_id'] == busId) {
            final n = e['seat_number']?.toString();
            seats = [
              for (final s in seats) s.seatNumber == n ? s.withStatus(e['status'] as String, ticketId: e['ticket_id'] as String?) : s
            ];
            if (!ctrl.isClosed) ctrl.add(seats);
          }
        });
      },
      onCancel: () {
        sub?.cancel();
        socket?.close();
      },
    );
    return ctrl.stream;
  }

  Future<BusEta> getEta(String busId) async => BusEta.fromJson(await _api.get('/buses/$busId/eta') as Map<String, dynamic>);

  /// Live position + per-stop ETA timeline, plus "bus approaching" alerts via [onEvent].
  Stream<BusEta> streamEta(String busId, {void Function(Map<String, dynamic> event)? onEvent}) {
    late StreamController<BusEta> ctrl;
    LiveSocket? socket;
    StreamSubscription? sub;
    BusEta? current;

    Future<void> reload() async {
      try {
        current = await getEta(busId);
        if (!ctrl.isClosed) ctrl.add(current!);
      } catch (e) {
        if (!ctrl.isClosed) ctrl.addError(e);
      }
    }

    ctrl = StreamController<BusEta>(
      onListen: () {
        reload();
        socket = LiveSocket(busId: busId);
        sub = socket!.events.listen((e) {
          final type = e['type'] as String?;
          onEvent?.call(e);
          if (type == 'resync' || type == 'trip_start' || type == 'trip_end' || type == 'route_updated') {
            reload();
          } else if (current != null && (type == 'bus_location' || type == 'stop_departure' || type == 'stop_arrival')) {
            if (e['stops'] is List) {
              current = current!.merge(e);
              if (!ctrl.isClosed) ctrl.add(current!);
            } else {
              reload();
            }
          }
        });
      },
      onCancel: () {
        sub?.cancel();
        socket?.close();
      },
    );
    return ctrl.stream;
  }

  // ----- Conductor -----

  Future<BusModel?> getMyBus() async {
    try {
      return BusModel.fromJson(await _api.get('/buses/mine') as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<BusModel> registerBus({required String plateNumber, required int totalSeats, String? routeId, String? photoUrl}) async =>
      BusModel.fromJson(await _api.post('/buses', {
        'plate_number': plateNumber,
        'total_seats': totalSeats,
        if (routeId != null) 'route_id': routeId,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photo_url': photoUrl,
      }) as Map<String, dynamic>);

  Future<BusModel> updateBus(String busId, {String? routeId, int? totalSeats, String? photoUrl}) async =>
      BusModel.fromJson(await _api.put('/buses/$busId', {
        if (routeId != null) 'route_id': routeId,
        if (totalSeats != null) 'total_seats': totalSeats,
        if (photoUrl != null) 'photo_url': photoUrl,
      }) as Map<String, dynamic>);

  Future<RouteModel> createRoute({required String routeNumber, required String origin, required String destination, required double fare, required int durationMins, required List<StopModel> stops}) async =>
      RouteModel.fromJson(await _api.post('/routes', {
        'route_number': routeNumber,
        'origin': origin,
        'destination': destination,
        'standard_fare': fare,
        'estimated_duration_mins': durationMins,
        'stops': stops.map((s) => s.toJson()).toList(),
      }) as Map<String, dynamic>);

  Future<RouteModel> updateRouteStops(RouteModel r, List<StopModel> stops) async => RouteModel.fromJson(await _api.put('/routes/${r.id}', {
        'route_number': r.routeNumber,
        'origin': r.origin,
        'destination': r.destination,
        'standard_fare': r.standardFare,
        'estimated_duration_mins': r.estimatedDurationMins,
        'stops': stops.map((s) => s.toJson()).toList(),
      }) as Map<String, dynamic>);

  Future<BusEta> setTrip(String busId, {required bool start}) async =>
      BusEta.fromJson(await _api.post('/buses/$busId/trip', {'action': start ? 'start' : 'end'}) as Map<String, dynamic>);

  Future<BusEta> confirmStop(String busId, String stopId, {required bool departure}) async =>
      BusEta.fromJson(await _api.post('/buses/$busId/stop-events', {'stop_id': stopId, 'event_type': departure ? 'departure' : 'arrival'}) as Map<String, dynamic>);

  Future<void> sendLocation(String busId, {required double lat, required double lng, double accuracy = 0, double speedKmh = 0}) =>
      _api.post('/buses/$busId/location', {'latitude': lat, 'longitude': lng, 'accuracy': accuracy, 'speed_kmh': speedKmh});

  // ----- Admin (in-app overview) -----

  Future<BusModel> approveBus(String busId, bool approved) async =>
      BusModel.fromJson(await _api.post('/buses/$busId/approve', {'approved': approved}) as Map<String, dynamic>);

  Stream<List<T>> _liveList<T>(Future<List<T>> Function() load, String? busId) {
    late StreamController<List<T>> ctrl;
    LiveSocket? socket;
    StreamSubscription? sub;
    Timer? debounce;
    Future<void> reload() async {
      try {
        final v = await load();
        if (!ctrl.isClosed) ctrl.add(v);
      } catch (e) {
        if (!ctrl.isClosed) ctrl.addError(e);
      }
    }

    ctrl = StreamController<List<T>>(
      onListen: () {
        reload();
        socket = LiveSocket(busId: busId);
        sub = socket!.events.listen((e) {
          if (e['type'] == 'bus_location' || e['type'] == 'disconnected') return;
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 400), reload);
        });
      },
      onCancel: () {
        debounce?.cancel();
        sub?.cancel();
        socket?.close();
      },
    );
    return ctrl.stream;
  }
}
