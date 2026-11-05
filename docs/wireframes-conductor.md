# Wireframes & Navigation Flow — Conductor App
**Jira Story:** RTBT-10  
**Target:** Flutter Android Mobile App  

---

## 1. Conductor Navigation Flow Overview

```text
[Conductor Login]
       │
       ▼
[Assigned Bus Dashboard] ─── (Tap "Manage Seats") ───► [Live Seat Map Grid]
       │                                                      │
       ├─► [Issue Walk-in Ticket Form] ◄──────────────────────┤ (Tap vacant seat)
       │         │                                            │
       │         ▼                                            ▼
       │   [Confirm & Print / Show Ticket]          [Seat Details Dialog]
       │
       └─► [Trip Manifest / Issued Tickets List]
```

---

## 2. Screen Specifications & ASCII Wireframes

### Screen 1: Conductor Dashboard ("My Bus")
- **Purpose:** Shift overview, select/verify the assigned vehicle, view passenger counts and total revenue collected for current trip.
- **Components:** Assigned Bus Banner (Plate #, Route), Shift Status Toggle, Summary Metrics (Seats Free, Seats Occupied, Total Cash Collected), Primary Action Buttons (`Open Live Seat Map`, `Quick Issue Ticket`, `Trip Manifest`).

```text
+---------------------------------------+
| CityBus Conductor        [Logout [->] |
+---------------------------------------+
|  BUS: WP-ND-1024       SHIFT: ACTIVE  |
|  Route 138 (Colombo - Kottawa)        |
+---------------------------------------+
|                                       |
|  TODAY'S TRIP SUMMARY                 |
|  +---------------------------------+  |
|  |  AVAILABLE  |  OCCUPIED |  TOTAL|  |
|  |     14      |     26    |   40  |  |
|  +---------------------------------+  |
|  |  CASH COLLECTED:   Rs. 3,900.00 |  |
|  +---------------------------------+  |
|                                       |
|  QUICK ACTIONS                        |
|  +---------------------------------+  |
|  |  [#] LIVE SEAT MAP              |  |
|  +---------------------------------+  |
|  |  [+] ISSUE WALK-IN TICKET       |  |
|  +---------------------------------+  |
|  |  [=] VIEW ISSUED TICKETS (26)   |  |
|  +---------------------------------+  |
|                                       |
+---------------------------------------+
```

---

### Screen 2: Conductor Live Seat Map
- **Purpose:** Real-time visual monitoring of seating capacity and one-tap seat assignment for physical boarding passengers.
- **Components:** Top counter (Seats Taken vs Seats Available), Interactive Seat Grid with high-contrast buttons, Tap on Available $\to$ Opens Issue Ticket Modal; Tap on Taken $\to$ Displays Passenger Details & Ticket ID.

```text
+---------------------------------------+
| [<] Live Seat Map        [Refresh (R)]|
+---------------------------------------+
|  Occupancy: 26 / 40   (65% Full)      |
|  [ ] Available (Tap to Issue)  [X] Taken
|                                       |
|             [ FRONT / DRIVER ]        |
|                                       |
|   [ 01 ] [ 02 ]   [AISLE]  [ X  ] [ X  ]
|   [ X  ] [ X  ]   [AISLE]  [ 07 ] [ 08 ]
|   [ X  ] [ X  ]   [AISLE]  [ X  ] [ X  ]
|   [ 13 ] [ X  ]   [AISLE]  [ 15 ] [ 16 ]
|   [ X  ] [ X  ]   [AISLE]  [ X  ] [ 20 ]
|                                       |
+---------------------------------------+
| Tip: Tap any green seat to issue a    |
| walk-in cash ticket on the spot.      |
+---------------------------------------+
```

---

### Screen 3: Issue On-Board Walk-in Ticket
- **Purpose:** Conductor creates a ticket on the spot for passengers who pay cash inside the bus.
- **Components:** Selected Seat Display, Fare Amount (Fixed or Stage-based), Optional Passenger Name / Phone Number, Payment Mode (`Cash`), `Confirm & Issue Ticket` Button.

```text
+---------------------------------------+
| [<] Issue On-Board Ticket             |
+---------------------------------------+
|                                       |
|  Assigned Seat:   [ SEAT #08 ]        |
|  Route:           138 (Colombo-Kottawa|
|  Standard Fare:   Rs. 150.00          |
|                                       |
|  Passenger Name (Optional)            |
|  [ e.g. John Doe                    ] |
|                                       |
|  Passenger Phone (Optional)           |
|  [ 077 123 4567                     ] |
|                                       |
|  Payment Method:                      |
|  (*) Cash Collected   ( ) Mobile QR   |
|                                       |
|  +---------------------------------+  |
|  |    CONFIRM & ISSUE TICKET       |  |
|  +---------------------------------+  |
+---------------------------------------+
```

---

### Screen 4: Trip Manifest / Ticket List
- **Purpose:** Conductor reviews every passenger ticket issued on this bus for inspection and auditing.
- **Components:** Search/Filter by Seat Number or Ticket ID, List items with Seat #, Ticket ID, Booking Method (`Online App` vs `Conductor Cash`), and Timestamp.

```text
+---------------------------------------+
| [<] Issued Tickets (26)     [Filter Q]|
+---------------------------------------+
|                                       |
|  Seat 01 • #TKT-89011 • Rs. 150       |
|  Online (Alex F.) • 09:45 AM          |
|  -----------------------------------  |
|  Seat 02 • #TKT-89012 • Rs. 150       |
|  Online (Sarah M.) • 09:50 AM         |
|  -----------------------------------  |
|  Seat 03 • #TKT-89015 • Rs. 150       |
|  Walk-in (Cash) • 10:05 AM            |
|  -----------------------------------  |
|  Seat 04 • #TKT-89018 • Rs. 150       |
|  Walk-in (Cash) • 10:12 AM            |
|                                       |
+---------------------------------------+
```
