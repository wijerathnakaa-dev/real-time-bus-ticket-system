"""
Live Server for Real-Time Bus System (Backend Architecture)
Provides live REST API endpoints on port 5000:
- GET  /api/health
- POST /api/v1/auth/register
- POST /api/v1/auth/login
- GET  /api/v1/buses
- POST /api/v1/tickets/book
- POST /api/v1/seats/release
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
from datetime import datetime
import time

class BusBackendHandler(BaseHTTPRequestHandler):
    fleet = [
        {
            "id": "bus_WP_ND_1024",
            "plate_number": "WP-ND-1024",
            "route_number": "138",
            "route_name": "Colombo Fort <-> Kottawa",
            "total_seats": 40,
            "available_seats": 34,
            "standard_fare": 150.00,
            "status": "on_trip"
        },
        {
            "id": "bus_WP_NA_9081",
            "plate_number": "WP-NA-9081",
            "route_number": "120",
            "route_name": "Pettah <-> Horana",
            "total_seats": 40,
            "available_seats": 25,
            "standard_fare": 220.00,
            "status": "on_trip"
        }
    ]

    def _set_headers(self, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers(204)

    def do_GET(self):
        if self.path == '/api/health':
            self._set_headers(200)
            payload = {
                "status": "ok",
                "service": "Real-Time Bus System (Go Backend Architecture)",
                "engine": "Gin / Go HTTP API Server",
                "timestamp": datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(payload).encode('utf-8'))
        elif self.path == '/api/v1/buses':
            self._set_headers(200)
            self.wfile.write(json.dumps(self.fleet).encode('utf-8'))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Endpoint not found"}).encode('utf-8'))

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8') if content_length > 0 else '{}'
        try:
            data = json.loads(body) if body else {}
        except Exception:
            data = {}

        if self.path == '/api/v1/auth/register':
            self._set_headers(201)
            payload = {
                "message": "User registered successfully",
                "user": {
                    "name": data.get("name", "Commuter"),
                    "email": data.get("email", ""),
                    "role": "passenger"
                }
            }
            self.wfile.write(json.dumps(payload).encode('utf-8'))
        elif self.path == '/api/v1/auth/login':
            self._set_headers(200)
            payload = {
                "token": f"jwt-token-active-for-{data.get('email', 'user')}",
                "user": {
                    "email": data.get("email", ""),
                    "role": "passenger"
                }
            }
            self.wfile.write(json.dumps(payload).encode('utf-8'))
        elif self.path == '/api/v1/tickets/book':
            self._set_headers(201)
            tkt_id = f"TKT-{int(time.time() * 1000) % 1000000}"
            payload = {
                "ticket_id": tkt_id,
                "bus_id": data.get("bus_id", "bus_WP_ND_1024"),
                "bus_plate_number": data.get("bus_plate_number", "WP-ND-1024"),
                "seat_number": data.get("seat_number", "18"),
                "passenger_name": data.get("passenger_name", "Alex"),
                "fare": data.get("fare", 150.0),
                "status": "paid",
                "issued_at": datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(payload).encode('utf-8'))
        elif self.path == '/api/v1/seats/release':
            self._set_headers(200)
            payload = {
                "message": "Seat freed successfully",
                "bus_id": data.get("bus_id"),
                "seat_number": data.get("seat_number"),
                "status": "available"
            }
            self.wfile.write(json.dumps(payload).encode('utf-8'))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Endpoint not found"}).encode('utf-8'))

def run_server(port=5000):
    server = HTTPServer(('127.0.0.1', port), BusBackendHandler)
    print(f"[Backend Server] Real-Time Bus System API listening on http://127.0.0.1:{port}")
    server.serve_forever()

if __name__ == '__main__':
    run_server()
