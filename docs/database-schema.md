# Cloud Firestore Database Schema Specification
**Jira Story:** RTBT-11  
**Target:** Google Cloud Firestore (NoSQL Document Store)  

---

## 1. Schema Architecture Overview

```text
Firestore Root
  ├── users/                  (collection: passenger and conductor accounts)
  ├── routes/                 (collection: predefined bus routes and standard fares)
  ├── buses/                  (collection: active fleet vehicles)
  │     └── [busId]/seats/    (subcollection: individual seat availability per bus)
  ├── tickets/                (collection: issued and booked tickets)
  └── bus_locations/          (collection: real-time telemetry prepared for future sprints)
```

---

## 2. Collections & Document Specifications

### 2.1 Collection: `users`
- **Document ID:** Firebase Auth UID (`auth.uid`)
- **Purpose:** Stores user profile and application authorization role (`passenger` or `conductor`).

| Field | Type | Description |
| :--- | :--- | :--- |
| `uid` | `string` | Matches Firebase Authentication UID |
| `name` | `string` | User's full display name |
| `email` | `string` | User's email address |
| `phone` | `string` | Optional phone contact |
| `role` | `string` | `'passenger'` or `'conductor'` |
| `assignedBusId` | `string \| null` | For conductors: the busId currently assigned, or null |
| `createdAt` | `timestamp` | Account creation timestamp |

#### Example Document (`users/usr_pass_789`):
```json
{
  "uid": "usr_pass_789",
  "name": "Kamal Perera",
  "email": "kamal@gmail.com",
  "phone": "+94771234567",
  "role": "passenger",
  "assignedBusId": null,
  "createdAt": "2026-11-05T08:30:00Z"
}
```

---

### 2.2 Collection: `routes`
- **Document ID:** Route ID (e.g., `route_138`)
- **Purpose:** Route metadata, origins, destinations, and standard ticket price.

| Field | Type | Description |
| :--- | :--- | :--- |
| `routeNumber` | `string` | Official transit route number (e.g., `"138"`) |
| `origin` | `string` | Starting city/terminal (e.g., `"Colombo Fort"`) |
| `destination` | `string` | Ending terminal (e.g., `"Kottawa"`) |
| `standardFare` | `number` | Default ticket price (e.g., `150.00`) |
| `estimatedDurationMins` | `number` | Approximate travel time in minutes |

#### Example Document (`routes/route_138`):
```json
{
  "routeNumber": "138",
  "origin": "Colombo Fort",
  "destination": "Kottawa",
  "standardFare": 150.0,
  "estimatedDurationMins": 45
}
```

---

### 2.3 Collection: `buses`
- **Document ID:** Auto-ID or normalized plate number (e.g., `bus_WP_ND_1024`)
- **Purpose:** Fleet vehicles currently active on routes.

| Field | Type | Description |
| :--- | :--- | :--- |
| `plateNumber` | `string` | Registration number (e.g., `"WP-ND-1024"`) |
| `routeId` | `string` | Foreign key referencing `routes/{routeId}` |
| `routeNumber` | `string` | Denormalized route string for rapid UI search display |
| `conductorId` | `string` | Reference to `users/{uid}` for current conductor |
| `totalSeats` | `number` | Total vehicle seating capacity (e.g., `40`) |
| `availableSeats` | `number` | Real-time counter of unbooked seats |
| `status` | `string` | Vehicle status: `'on_trip'`, `'idle'`, `'maintenance'` |
| `updatedAt` | `timestamp` | Last update time |

#### Example Document (`buses/bus_WP_ND_1024`):
```json
{
  "plateNumber": "WP-ND-1024",
  "routeId": "route_138",
  "routeNumber": "138",
  "conductorId": "usr_cond_101",
  "totalSeats": 40,
  "availableSeats": 18,
  "status": "on_trip",
  "updatedAt": "2026-11-05T09:40:00Z"
}
```

---

### 2.4 Subcollection: `buses/{busId}/seats`
- **Document ID:** Seat number string padded (e.g., `"01"`, `"02"`, `"18"`)
- **Purpose:** Tracks the individual booking status of every seat. Placing this as a subcollection isolates real-time listeners so passengers only subscribe to the seat updates of their specific selected bus.

| Field | Type | Description |
| :--- | :--- | :--- |
| `seatNumber` | `string` | Seat identifier (`"01"`, `"18"`, etc.) |
| `status` | `string` | `'available'` or `'taken'` |
| `bookedBy` | `string \| null` | `userId` of passenger or conductor who reserved it |
| `bookedAt` | `timestamp \| null` | Time of booking |
| `ticketId` | `string \| null` | Reference to generated `tickets/{ticketId}` |

#### Example Document (`buses/bus_WP_ND_1024/seats/18`):
```json
{
  "seatNumber": "18",
  "status": "available",
  "bookedBy": null,
  "bookedAt": null,
  "ticketId": null
}
```

---

### 2.5 Collection: `tickets`
- **Document ID:** Auto-generated unique Ticket ID (e.g., `tkt_9821038472`)
- **Purpose:** Non-repudiable transaction record of a purchased ticket.

| Field | Type | Description |
| :--- | :--- | :--- |
| `ticketId` | `string` | Human-friendly ticket number |
| `busId` | `string` | Reference to `buses/{busId}` |
| `busPlateNumber` | `string` | Denormalized plate number for offline display |
| `routeNumber` | `string` | Denormalized route name |
| `seatNumber` | `string` | Seat allocated |
| `passengerId` | `string` | Reference to `users/{uid}` (or `"walk_in"` if cash) |
| `passengerName` | `string` | Name of passenger |
| `issuedByRole` | `string` | `'passenger'` (app self-checkout) or `'conductor'` (walk-in) |
| `conductorId` | `string \| null` | Conductor UID if issued manually |
| `fare` | `number` | Fare amount paid (e.g., `150.00`) |
| `paymentStatus` | `string` | `'paid'` or `'pending'` |
| `paymentMethod` | `string` | `'cash'` or `'in_app'` |
| `issuedAt` | `timestamp` | Exact purchase timestamp |

#### Example Document (`tickets/tkt_9821038472`):
```json
{
  "ticketId": "TKT-89210",
  "busId": "bus_WP_ND_1024",
  "busPlateNumber": "WP-ND-1024",
  "routeNumber": "138",
  "seatNumber": "18",
  "passengerId": "usr_pass_789",
  "passengerName": "Kamal Perera",
  "issuedByRole": "passenger",
  "conductorId": null,
  "fare": 150.0,
  "paymentStatus": "paid",
  "paymentMethod": "cash",
  "issuedAt": "2026-11-05T10:15:00Z"
}
```

---

### 2.6 Collection: `bus_locations` (Prepared for Sprints 4–6)
- **Document ID:** `busId`
- **Purpose:** Live GPS telemetry stream recorded by conductor device.

| Field | Type | Description |
| :--- | :--- | :--- |
| `busId` | `string` | Bus reference |
| `latitude` | `number` | GPS Latitude in decimal degrees |
| `longitude` | `number` | GPS Longitude in decimal degrees |
| `accuracy` | `number` | Accuracy in meters |
| `speed` | `number` | Speed in km/h |
| `timestamp` | `timestamp` | GPS ping timestamp |

---

## 3. Database Indexes

1. **`tickets` collection:**
   - Single-field index on `passengerId` (ASC) + `issuedAt` (DESC) — enables fast retrieval of "My Tickets" for a passenger.
   - Single-field index on `busId` (ASC) + `issuedAt` (DESC) — enables conductors to retrieve their trip manifest quickly.
2. **`buses` collection:**
   - Single-field index on `plateNumber` (ASC) — allows instant exact search by number plate.

---

## 4. Concurrency & Anti-Double-Booking Strategy

To satisfy **FR-PASS-06** and **RTBT-19**:
Seat allocation MUST be performed inside a **Firestore Transaction** (`runTransaction`):
1. **Read phase:** Transaction reads `buses/{busId}/seats/{seatNumber}`.
2. **Validation phase:** If `seat.status != 'available'`, throw `SeatAlreadyBookedException` and abort.
3. **Write phase:**
   - Update `buses/{busId}/seats/{seatNumber}` $\to$ `status = 'taken'`, `ticketId = newTicketRef.id`.
   - Decrement `buses/{busId}.availableSeats` by 1 (`FieldValue.increment(-1)`).
   - Create new document in `tickets/{newTicketId}`.
