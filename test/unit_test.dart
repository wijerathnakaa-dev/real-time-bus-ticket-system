import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_bus_ticket/models/user_model.dart';
import 'package:real_time_bus_ticket/models/seat_model.dart';
import 'package:real_time_bus_ticket/models/location_model.dart';

void main() {
  group('Sprint 2 Unit Tests — Data Models & Role Logic', () {
    test('UserModel correctly parses and verifies Passenger role', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user_123',
        name: 'Test Passenger',
        email: 'passenger@example.com',
        role: 'passenger',
        assignedBusId: null,
        createdAt: now,
      );

      expect(user.isPassenger, isTrue);
      expect(user.isConductor, isFalse);
      expect(user.role, equals('passenger'));

      final map = user.toMap();
      expect(map['email'], equals('passenger@example.com'));
      expect(map['role'], equals('passenger'));
    });

    test('UserModel correctly parses and verifies Conductor role', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'conductor_456',
        name: 'Test Conductor',
        email: 'conductor@example.com',
        role: 'conductor',
        assignedBusId: 'bus_WP_ND_1024',
        createdAt: now,
      );

      expect(user.isConductor, isTrue);
      expect(user.isPassenger, isFalse);
      expect(user.assignedBusId, equals('bus_WP_ND_1024'));
    });

    test('SeatModel correctly tracks available and taken states', () {
      final availableSeat = SeatModel(
        seatNumber: '12',
        status: 'available',
      );

      expect(availableSeat.isAvailable, isTrue);
      expect(availableSeat.status, equals('available'));
      expect(availableSeat.bookedBy, isNull);

      final bookedSeat = SeatModel(
        seatNumber: '12',
        status: 'taken',
        bookedBy: 'user_123',
        bookedAt: DateTime.now(),
        ticketId: 'TKT-1001',
      );

      expect(bookedSeat.isAvailable, isFalse);
      expect(bookedSeat.status, equals('taken'));
      expect(bookedSeat.ticketId, equals('TKT-1001'));
    });

    test('LocationModel calculates accuracy and speed formatting', () {
      final loc = LocationModel(
        latitude: 6.927079,
        longitude: 79.861244,
        accuracy: 4.5,
        speed: 8.33, // ~30 km/h
        timestamp: DateTime(2026, 11, 5, 10, 0, 0),
      );

      expect(loc.latitude, closeTo(6.927, 0.001));
      expect(loc.longitude, closeTo(79.861, 0.001));
      expect(loc.accuracy, equals(4.5));
      expect(loc.speed * 3.6, closeTo(29.988, 0.01));
    });
  });
}

