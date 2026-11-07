"""Quick smoke walk-through of the live API (backend running with demo data).

    python test/test_live_api.py            # http://127.0.0.1:5000
    API_URL=http://127.0.0.1:5055 python test/test_live_api.py
"""
import json
import os
import urllib.request

BASE = os.environ.get("API_URL", "http://127.0.0.1:5000").rstrip("/")


def call(method, path, body=None, token=None):
    req = urllib.request.Request(BASE + path, data=json.dumps(body).encode() if body is not None else None, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read() or b"null")


def main():
    print("=" * 60)
    print("REAL-TIME BUS SYSTEM - LIVE API WALK-THROUGH")
    print("=" * 60)
    h = call("GET", "/api/health")
    print(f"1. Health: {h['status'].upper()} - database {h['database']}")

    buses = call("GET", "/api/v1/buses")
    print(f"\n2. Fleet: {len(buses)} approved buses")
    for b in buses:
        print(f"   - {b['plate_number']} route {b['route_number']} {b['route_name']} | {b['available_seats']}/{b['total_seats']} free | {b['status']}")

    pax = call("POST", "/api/v1/auth/login", {"email": "passenger@citybus.lk", "password": "Passenger@123"})["token"]
    cond = call("POST", "/api/v1/auth/login", {"email": "conductor1@citybus.lk", "password": "Conductor@123"})["token"]
    seats = call("GET", "/api/v1/buses/bus_nb2451/seats")
    seat = next(s["seat_number"] for s in reversed(seats) if s["status"] == "available")
    t = call("POST", "/api/v1/tickets", {"bus_id": "bus_nb2451", "seat_number": seat, "from_stop_id": "route_ex01_s2", "to_stop_id": "route_ex01_s5"}, pax)
    print(f"\n3. Passenger booked seat #{t['seat_number']} on {t['bus_plate_number']}: {t['ticket_number']} Rs. {t['fare']} ({t['payment_status']})")
    mode = call("POST", "/api/v1/payments/start", {"ticket_id": t["id"]}, pax)["mode"]
    if mode == "simulated":
        t = call("POST", "/api/v1/payments/simulate", {"ticket_id": t["id"]}, pax)
        print(f"   Paid (simulated PayHere): {t['payment_status']}")
    else:
        print(f"   PayHere {mode} checkout ready - complete it in the app")

    eta = call("GET", "/api/v1/buses/bus_nb2451/eta")
    nxt = next((s for s in eta["stops"] if s["stop_id"] == eta.get("next_stop_id")), None)
    if nxt:
        print(f"\n4. Next stop {nxt['stop_name']} in {nxt.get('eta_minutes')} min")

    call("POST", "/api/v1/seats/release", {"bus_id": "bus_nb2451", "seat_number": seat}, cond)
    print(f"\n5. Conductor freed seat #{seat} when the passenger got off")
    print("\n" + "=" * 60)
    print("WALK-THROUGH COMPLETE")


if __name__ == "__main__":
    main()
