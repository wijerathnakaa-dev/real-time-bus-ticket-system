# Go backend

Gin REST API + WebSocket hub on MySQL 8. Configure with `.env` (see `.env.example`), then `go run ./cmd/server`.
On start it creates the database if missing, applies `internal/database/schema.sql` (a copy of
`/database/schema.sql`), and seeds demo data into an empty database.

## API (`/api/v1`)

| Area | Endpoints | Who |
|---|---|---|
| Auth | `POST /auth/register` (passenger/conductor), `POST /auth/login`, `GET /auth/me` | anyone / signed in |
| Routes | `GET /routes`, `GET /routes/:id` (with stops), `POST /routes`, `PUT /routes/:id`, `DELETE /routes/:id` | public / admin or route's conductor / admin |
| Buses | `GET /buses?plate=&route_id=&all=1`, `GET /buses/mine`, `GET /buses/:id`, `GET /buses/:id/seats`, `POST /buses`, `PUT /buses/:id`, `POST /buses/:id/photo`, `POST /buses/:id/approve`, `POST /buses/:id/assign` | public / conductor / admin |
| Tracking | `POST /buses/:id/location`, `GET /buses/:id/eta`, `POST|GET /buses/:id/stop-events`, `POST /buses/:id/trip` | assigned conductor or admin / public |
| Tickets | `POST /tickets` (atomic seat lock), `GET /tickets/mine`, `GET /tickets?bus_id=…`, `GET /tickets/:id`, `GET /tickets/verify/:number`, `POST /tickets/:id/cancel` | passenger / conductor / admin |
| Seats | `POST /seats/release` (passenger alighted), `POST /seats/override` | assigned conductor or admin |
| Payments | `GET /payments/config`, `POST /payments/start`, `GET /payments/payhere/checkout/:ticket`, `POST /payments/payhere/notify`, `POST /payments/simulate` (demo mode only) | passenger / PayHere |
| Admin | `GET /admin/stats`, `GET /admin/users?role=`, `GET /admin/payments` | admin |

WebSocket: `/ws?bus_id=<id>` (one bus) or `/ws` (all events). Events: `seat_booked`, `seat_released`,
`ticket_paid`, `bus_location` (with per-stop ETA), `stop_arrival`, `stop_departure`, `trip_start`,
`trip_end`, `bus_approaching`, `bus_updated`, `route_updated`.

## Key rules
* A seat is booked inside a transaction with `SELECT … FOR UPDATE`; a second booking gets **409**.
* In-app tickets hold the seat as `pending` until PayHere confirms; unpaid holds are released after 15 minutes.
* Fare is pro-rated by stop legs between boarding and destination (min 20% of the full fare).
* ETA = distance along the remaining stops ÷ current speed (route average when stationary); arrival is
  recorded automatically within 150 m of a stop; departures are confirmed by the conductor.
* All timestamps are stored and returned in UTC.
