"""
End-to-end API test for the Go backend (needs a running server + MySQL with demo seed data).

    python test/test_e2e_api.py                 # default http://127.0.0.1:5000
    API_URL=http://127.0.0.1:5055 python test/test_e2e_api.py

Covers: auth + roles, routes/stops, bus registration + admin approval, atomic seat
booking under a concurrent race, simulated payment, conductor issue/release, GPS +
per-stop ETA, stop events, trip end, admin stats/tickets.
"""
import json
import os
import threading
import time
import unittest
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone

BASE = os.environ.get("API_URL", "http://127.0.0.1:5000").rstrip("/") + "/api/v1"


def call(method, path, body=None, token=None, expect=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            status, raw = r.status, r.read()
    except urllib.error.HTTPError as e:
        status, raw = e.code, e.read()
    payload = json.loads(raw) if raw else None
    if expect is not None and status != expect:
        raise AssertionError(f"{method} {path} -> {status} (expected {expect}): {payload}")
    return status, payload


def free_seat(bus_id, skip=()):
    _, seats = call("GET", f"/buses/{bus_id}/seats", expect=200)
    return next(s["seat_number"] for s in reversed(seats) if s["status"] == "available" and s["seat_number"] not in skip)


def login(email, password):
    return call("POST", "/auth/login", {"email": email, "password": password}, expect=200)[1]["token"]


class E2E(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.admin = login("admin@citybus.lk", "Admin@123")
        cls.cond1 = login("conductor1@citybus.lk", "Conductor@123")
        cls.cond2 = login("conductor2@citybus.lk", "Conductor@123")
        email = f"e2e_{uuid.uuid4().hex[:8]}@test.lk"
        _, reg = call("POST", "/auth/register", {"name": "E2E Rider", "email": email, "password": "secret123"}, expect=201)
        cls.pax = reg["token"]
        _, reg2 = call("POST", "/auth/register", {"name": "Rival Rider", "email": "r" + email, "password": "secret123"}, expect=201)
        cls.pax2 = reg2["token"]

    def test_01_auth_and_roles(self):
        _, me = call("GET", "/auth/me", token=self.pax, expect=200)
        self.assertEqual(me["role"], "passenger")
        call("POST", "/auth/login", {"email": "admin@citybus.lk", "password": "wrong"}, expect=401)
        call("POST", "/auth/register", {"name": "x", "email": "x@x.lk", "password": "secret123", "role": "admin"}, expect=400)
        call("GET", "/admin/stats", token=self.pax, expect=403)
        call("GET", "/admin/stats", expect=401)

    def test_02_routes_and_buses(self):
        _, routes = call("GET", "/routes", expect=200)
        self.assertGreaterEqual(len(routes), 2)
        _, r = call("GET", "/routes/route_ex01", expect=200)
        self.assertEqual(len(r["stops"]), 8)
        _, found = call("GET", "/buses?plate=" + urllib.parse.quote("nb 2451"), expect=200)
        self.assertEqual(found[0]["plate_number"], "NB-2451")
        _, public = call("GET", "/buses", expect=200)
        self.assertNotIn("ND-1190", [b["plate_number"] for b in public], "unapproved bus must be hidden")

    def test_03_register_and_approve_bus(self):
        plate = "WP-" + uuid.uuid4().hex[:4].upper()
        _, bus = call("POST", "/buses", {"plate_number": plate, "total_seats": 30, "route_id": "route_ex03"}, token=self.admin, expect=201)
        self.assertTrue(bus["approved"])
        call("POST", f"/buses/{bus['id']}/approve", {"approved": False}, token=self.admin, expect=200)
        call("POST", f"/buses/{bus['id']}/approve", {"approved": True}, token=self.cond1, expect=403)
        _, seats = call("GET", f"/buses/{bus['id']}/seats", expect=200)
        self.assertEqual(len(seats), 30)

    def test_04_concurrent_booking_only_one_wins(self):
        seat = free_seat("bus_nb2451")
        results = []

        def book(tok):
            results.append(call("POST", "/tickets", {"bus_id": "bus_nb2451", "seat_number": seat,
                                                     "from_stop_id": "route_ex01_s2", "to_stop_id": "route_ex01_s8"}, token=tok)[0])

        threads = [threading.Thread(target=book, args=(t,)) for t in (self.pax, self.pax2, self.pax, self.pax2)]
        [t.start() for t in threads]
        [t.join() for t in threads]
        self.assertEqual(sorted(results), [201, 409, 409, 409], results)

    def test_05_passenger_buys_and_pays(self):
        _, t = call("POST", "/tickets", {"bus_id": "bus_nb2451", "seat_number": free_seat("bus_nb2451"), "from_stop_id": "route_ex01_s2",
                                         "to_stop_id": "route_ex01_s4"}, token=self.pax, expect=201)
        self.assertEqual(t["payment_status"], "pending")
        issued = datetime.fromisoformat(t["issued_at"].replace("Z", "+00:00"))
        self.assertLess(abs((datetime.now(timezone.utc) - issued).total_seconds()), 120, "timestamps must be true UTC")
        self.assertLess(t["fare"], 1000, "pro-rated fare for 2 of 7 legs")
        _, start = call("POST", "/payments/start", {"ticket_id": t["id"]}, token=self.pax, expect=200)
        self.assertEqual(start["mode"], "simulated")
        call("POST", "/payments/simulate", {"ticket_id": t["id"]}, token=self.pax2, expect=403)
        _, paid = call("POST", "/payments/simulate", {"ticket_id": t["id"]}, token=self.pax, expect=200)
        self.assertEqual(paid["payment_status"], "paid")
        _, mine = call("GET", "/tickets/mine", token=self.pax, expect=200)
        self.assertIn(t["id"], [x["id"] for x in mine])
        _, v = call("GET", f"/tickets/verify/{t['ticket_number']}", token=self.cond1, expect=200)
        self.assertTrue(v["valid"])
        _, v2 = call("GET", f"/tickets/verify/{t['ticket_number']}", token=self.cond2, expect=200)
        self.assertFalse(v2["valid"], "other bus's conductor must not validate it")
        _, c = call("POST", f"/tickets/{t['id']}/cancel", token=self.pax, expect=200)
        self.assertEqual((c["status"], c["payment_status"]), ("cancelled", "refunded"))

    def test_06_conductor_issue_and_release(self):
        seat = free_seat("bus_nb2451")
        call("POST", "/tickets", {"bus_id": "bus_nb2451", "seat_number": seat}, token=self.cond2, expect=403)
        _, t = call("POST", "/tickets", {"bus_id": "bus_nb2451", "seat_number": seat, "passenger_name": "Walk-in"}, token=self.cond1, expect=201)
        self.assertEqual((t["payment_method"], t["payment_status"]), ("cash", "paid"))
        call("POST", "/seats/release", {"bus_id": "bus_nb2451", "seat_number": seat}, token=self.pax, expect=403)
        call("POST", "/seats/release", {"bus_id": "bus_nb2451", "seat_number": seat}, token=self.cond1, expect=200)
        _, seats = call("GET", "/buses/bus_nb2451/seats", expect=200)
        self.assertEqual(next(s for s in seats if s["seat_number"] == seat)["status"], "available")
        seat2 = free_seat("bus_nb2451")
        call("POST", "/seats/override", {"bus_id": "bus_nb2451", "seat_number": seat2, "status": "taken"}, token=self.cond1, expect=200)
        call("POST", "/seats/override", {"bus_id": "bus_nb2451", "seat_number": seat2, "status": "available"}, token=self.admin, expect=200)

    def test_07_gps_eta_and_stop_events(self):
        call("POST", "/buses/bus_nb2451/location", {"latitude": 6.78, "longitude": 80.0}, token=self.cond2, expect=403)
        _, eta = call("POST", "/buses/bus_nb2451/location", {"latitude": 6.7836, "longitude": 80.0097, "speed_kmh": 80}, token=self.cond1, expect=200)
        kah = next(s for s in eta["stops"] if s["stop_id"] == "route_ex01_s2")
        self.assertIsNotNone(kah.get("actual_arrival"), "auto-arrival within 150 m")
        _, before = call("GET", "/buses/bus_nb2451/stop-events", expect=200)
        for _ in range(2):  # repeated tap must not duplicate history
            call("POST", "/buses/bus_nb2451/stop-events", {"stop_id": "route_ex01_s2", "event_type": "departure"}, token=self.cond1, expect=201)
        _, after = call("GET", "/buses/bus_nb2451/stop-events", expect=200)
        dep = lambda ev: sum(1 for e in ev if e["stop_id"] == "route_ex01_s2" and e["event_type"] == "departure")
        self.assertLessEqual(dep(after), max(dep(before), 1))
        _, eta = call("POST", "/buses/bus_nb2451/location", {"latitude": 6.75, "longitude": 80.03, "speed_kmh": 90}, token=self.cond1, expect=200)
        self.assertEqual(eta["next_stop_id"], "route_ex01_s3")
        upcoming = [s for s in eta["stops"] if s["state"] == "upcoming"]
        etas = [s["eta_minutes"] for s in upcoming]
        self.assertEqual(etas, sorted(etas), "ETAs increase along the route")
        self.assertTrue(all(e > 0 for e in etas))
        _, hist = call("GET", "/buses/bus_nb2451/stop-events", expect=200)
        self.assertGreaterEqual(len(hist), 3)

    def test_08_admin_overview_and_trip_end(self):
        _, stats = call("GET", "/admin/stats", token=self.admin, expect=200)
        self.assertGreaterEqual(stats["buses"], 3)
        _, tks = call("GET", "/tickets?bus_id=bus_nb2451", token=self.admin, expect=200)
        self.assertTrue(len(tks) > 0)
        _, conductors = call("GET", "/admin/users?role=conductor", token=self.admin, expect=200)
        self.assertGreaterEqual(len(conductors), 2)
        call("POST", "/buses/bus_nc7832/trip", {"action": "start"}, token=self.cond2, expect=200)
        call("POST", "/tickets", {"bus_id": "bus_nc7832", "seat_number": "3"}, token=self.cond2, expect=201)
        call("POST", "/buses/bus_nc7832/trip", {"action": "end"}, token=self.cond2, expect=200)
        _, seats = call("GET", "/buses/bus_nc7832/seats", expect=200)
        self.assertTrue(all(s["status"] == "available" for s in seats), "trip end frees every seat")


if __name__ == "__main__":
    print("Testing", BASE)
    unittest.main(verbosity=2)
