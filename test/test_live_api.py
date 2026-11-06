import urllib.request
import json

BASE_URL = "http://127.0.0.1:5000"

def test_api():
    print("=" * 60)
    print("TESTING REAL-TIME BUS SYSTEM BACKEND API & LIFECYCLE")
    print("=" * 60)

    # 1. Health check
    req = urllib.request.Request(f"{BASE_URL}/api/health")
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
        print(f"1. Health Check: {data['status'].upper()} ({data['service']})")

    # 2. Get active fleet
    req = urllib.request.Request(f"{BASE_URL}/api/v1/buses")
    with urllib.request.urlopen(req) as resp:
        buses = json.loads(resp.read().decode())
        print(f"\n2. Fleet Lookup: Found {len(buses)} active buses")
        for b in buses:
            print(f"   - Bus {b['plate_number']} (Route {b['route_number']} {b['route_name']}) | Fare: Rs. {b['standard_fare']} | Seats Free: {b['available_seats']}/{b['total_seats']}")

    # 3. Passenger registers & books seat #18
    booking_payload = json.dumps({
        "bus_id": "bus_WP_ND_1024",
        "bus_plate_number": "WP-ND-1024",
        "route_number": "138",
        "seat_number": "18",
        "passenger_id": "pass_101",
        "passenger_name": "Alex Fernando",
        "fare": 150.0
    }).encode('utf-8')

    req = urllib.request.Request(
        f"{BASE_URL}/api/v1/tickets/book",
        data=booking_payload,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        tkt = json.loads(resp.read().decode())
        print(f"\n3. Transactional Ticket Booking: SUCCESS")
        print(f"   - Generated Ticket ID: {tkt['ticket_id']}")
        print(f"   - Seat Reserved: #{tkt['seat_number']} on {tkt['bus_plate_number']}")
        print(f"   - Passenger: {tkt['passenger_name']} | Fare: Rs. {tkt['fare']} | Status: {tkt['status']}")

    # 4. Conductor frees seat #18 when passenger disembarks
    release_payload = json.dumps({
        "bus_id": "bus_WP_ND_1024",
        "seat_number": "18"
    }).encode('utf-8')

    req = urllib.request.Request(
        f"{BASE_URL}/api/v1/seats/release",
        data=release_payload,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        rel = json.loads(resp.read().decode())
        print(f"\n4. Conductor Seat Freeing (Release): SUCCESS")
        print(f"   - Bus: {rel['bus_id']}")
        print(f"   - Seat #{rel['seat_number']} Status: {rel['status'].upper()}")

    print("\n" + "=" * 60)
    print("ALL API ENDPOINTS AND TRANSACTION LIFECYCLES PASSED")
    print("=" * 60)

if __name__ == "__main__":
    test_api()

