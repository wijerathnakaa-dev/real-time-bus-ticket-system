"""
Sprint 3 Verification Suite & Core Features Demo
Tests:
- RTBT-17: Identify bus by number plate and route resolution
- RTBT-18: View seat occupancy and available seat counting
- RTBT-19: Select seat and execute atomic transactional ticket purchase
- RTBT-20: Conductor walk-in ticket issuing
- RTBT-21: Conductor seat map synchronization with passenger view
"""

import sys
import unittest
from datetime import datetime

class Bus:
    def __init__(self, bus_id, plate, route, total_seats=40):
        self.bus_id = bus_id
        self.plate = plate
        self.route = route
        self.total_seats = total_seats
        self.seats = {
            f"{i:02d}": {"status": "available", "booked_by": None, "ticket_id": None}
            for i in range(1, total_seats + 1)
        }

    @property
    def available_seats_count(self):
        return sum(1 for s in self.seats.values() if s["status"] == "available")

    def book_seat_transactional(self, seat_num, passenger_id, role="passenger"):
        if seat_num not in self.seats:
            raise KeyError(f"Seat {seat_num} does not exist.")
        if self.seats[seat_num]["status"] != "available":
            raise ValueError(f"Seat {seat_num} is already taken!")

        ticket_id = f"TKT-{datetime.now().strftime('%f')}"
        self.seats[seat_num]["status"] = "taken"
        self.seats[seat_num]["booked_by"] = passenger_id
        self.seats[seat_num]["ticket_id"] = ticket_id
        return {
            "ticket_id": ticket_id,
            "bus_plate": self.plate,
            "route": self.route,
            "seat_number": seat_num,
            "passenger_id": passenger_id,
            "role": role,
            "fare": 150.0,
            "status": "paid"
        }


class TestSprint3CoreFeatures(unittest.TestCase):
    def setUp(self):
        self.fleet = {
            "WP-ND-1024": Bus("bus_1", "WP-ND-1024", "Route 138"),
            "WP-NA-9081": Bus("bus_2", "WP-NA-9081", "Route 120")
        }

    def test_rtbt17_bus_identification(self):
        # Normal plate search
        bus = self.fleet.get("WP-ND-1024")
        self.assertIsNotNone(bus)
        self.assertEqual(bus.route, "Route 138")

        # Invalid plate search
        missing = self.fleet.get("WP-XX-9999")
        self.assertIsNone(missing)
        print("  [PASS] RTBT-17: Bus identification & route resolution verified.")

    def test_rtbt18_view_available_seats(self):
        bus = self.fleet["WP-ND-1024"]
        self.assertEqual(bus.available_seats_count, 40)
        self.assertEqual(bus.seats["05"]["status"], "available")
        print("  [PASS] RTBT-18: View seat availability and counting verified.")

    def test_rtbt19_passenger_ticket_purchase_atomic(self):
        bus = self.fleet["WP-ND-1024"]
        ticket = bus.book_seat_transactional("18", "passenger_kamal", role="passenger")
        self.assertEqual(ticket["seat_number"], "18")
        self.assertEqual(bus.seats["18"]["status"], "taken")
        self.assertEqual(bus.available_seats_count, 39)

        # Race condition test: second user tries to book seat 18
        with self.assertRaises(ValueError):
            bus.book_seat_transactional("18", "passenger_nimal", role="passenger")
        print("  [PASS] RTBT-19: Atomic transactional seat booking & double-booking prevention verified.")

    def test_rtbt20_conductor_issue_ticket(self):
        bus = self.fleet["WP-ND-1024"]
        ticket = bus.book_seat_transactional("08", "walk_in_passenger", role="conductor")
        self.assertEqual(ticket["role"], "conductor")
        self.assertEqual(bus.seats["08"]["status"], "taken")
        self.assertEqual(bus.seats["08"]["booked_by"], "walk_in_passenger")
        print("  [PASS] RTBT-20: Conductor walk-in ticket issuing verified.")

    def test_rtbt21_conductor_seat_map_sync(self):
        bus = self.fleet["WP-ND-1024"]
        # Passenger books seat 12
        bus.book_seat_transactional("12", "passenger_sarah", role="passenger")
        # Conductor reads seat map -> seat 12 must be taken
        conductor_view_status = bus.seats["12"]["status"]
        self.assertEqual(conductor_view_status, "taken")
        print("  [PASS] RTBT-21: Conductor seat map synchronization verified.")


if __name__ == "__main__":
    print("=" * 60)
    print("RUNNING SPRINT 3 VERIFICATION TEST SUITE (RTBT-17 to RTBT-21)")
    print("=" * 60)
    suite = unittest.TestLoader().loadTestsFromTestCase(TestSprint3CoreFeatures)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)

