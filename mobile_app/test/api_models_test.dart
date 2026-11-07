import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:real_time_bus_ticket/core/api/api_client.dart';
import 'package:real_time_bus_ticket/models/bus_model.dart';
import 'package:real_time_bus_ticket/models/eta_model.dart';
import 'package:real_time_bus_ticket/models/route_model.dart';
import 'package:real_time_bus_ticket/models/seat_model.dart';
import 'package:real_time_bus_ticket/models/ticket_model.dart';

RouteModel _route() => RouteModel.fromJson({
      'id': 'route_ex01',
      'route_number': 'EX1-17',
      'origin': 'Makumbura',
      'destination': 'Galle',
      'standard_fare': 1000,
      'estimated_duration_mins': 90,
      'stops': [
        for (var i = 1; i <= 8; i++) {'id': 's$i', 'stop_name': 'Stop $i', 'stop_sequence': i, 'latitude': 6.8 - i * 0.1, 'longitude': 80.0}
      ],
    });

void main() {
  group('Sprint 3-5: API models and client logic', () {
    test('fare is pro-rated by stops exactly like the Go server', () {
      final r = _route();
      expect(r.stops.length, 8);
      expect(r.fareBetween(r.stops[0], r.stops[7]), 1000); // full route
      expect(r.fareBetween(r.stops[1], r.stops[3]), 290); // 2 of 7 legs = 285.7 -> 290
      expect(r.fareBetween(r.stops[6], r.stops[7]), 200); // floor at 20% of the full fare
      expect(r.fareBetween(null, null), 1000);
    });

    test('live seat events update a seat and clear ownership when freed', () {
      final s = SeatModel.fromJson({'seat_number': 7, 'status': 'available'});
      final taken = s.withStatus('taken', ticketId: 'tkt_1');
      expect(taken.isAvailable, isFalse);
      expect(taken.ticketId, 'tkt_1');
      final freed = taken.withStatus('available');
      expect(freed.isAvailable, isTrue);
      expect(freed.ticketId, isNull);
    });

    test('bus and ticket JSON from the API parse correctly', () {
      final b = BusModel.fromJson({'id': 'bus_1', 'plate_number': 'NB-2451', 'total_seats': 40, 'available_seats': 34, 'status': 'on_trip', 'approved': true});
      expect(b.onTrip, isTrue);
      final t = TicketModel.fromJson({
        'id': 'tkt_1',
        'ticket_number': 'TKT-261106-ABC123',
        'bus_id': 'bus_1',
        'seat_number': '18',
        'passenger_name': 'Alex',
        'issued_by_role': 'passenger',
        'fare': 290,
        'payment_status': 'pending',
        'payment_method': 'payhere',
        'status': 'active',
        'issued_at': '2026-11-06T10:00:00Z',
      });
      expect(t.awaitingPayment, isTrue);
      expect(t.isValidForBoarding, isFalse);
    });

    test('a bus_location event merges into the ETA timeline', () {
      final eta = BusEta.fromJson({'bus_id': 'bus_1', 'status': 'on_trip', 'stops': []});
      final merged = eta.merge({
        'type': 'bus_location',
        'latitude': 6.75,
        'longitude': 80.03,
        'speed_kmh': 90,
        'next_stop_id': 's3',
        'stops': [
          {'stop_id': 's3', 'stop_name': 'Gelanigama', 'stop_sequence': 3, 'state': 'upcoming', 'eta_minutes': 4.2, 'distance_km': 6.3}
        ],
      });
      expect(merged.latitude, 6.75);
      expect(merged.nextStop?.stopName, 'Gelanigama');
      expect(merged.nextStop?.etaMinutes, 4.2);
    });

    test('ApiClient sends the bearer token and surfaces server errors (409 seat conflict)', () async {
      String? auth;
      ApiClient.instance.httpClient = MockClient((req) async {
        auth = req.headers['Authorization'];
        return http.Response(jsonEncode({'error': 'seat 18 was just taken - please choose another seat'}), 409);
      });
      ApiClient.instance.token = 'abc';
      try {
        await ApiClient.instance.post('/tickets', {'bus_id': 'bus_1', 'seat_number': '18'});
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.isConflict, isTrue);
        expect(e.message, contains('just taken'));
      }
      expect(auth, 'Bearer abc');
    });
  });
}
