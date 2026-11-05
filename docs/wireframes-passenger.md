# Wireframes & Navigation Flow — Passenger App
**Jira Story:** RTBT-9  
**Target:** Flutter Android Mobile App  

---

## 1. Passenger Navigation Flow Overview

```text
[Splash Screen]
      │
      ▼
[Login / Register Screen]
      │
      ▼
[Role Selection (if new registration)] ──► [Passenger Home / Find Bus]
                                                    │
             ┌──────────────────────────────────────┼──────────────────────────────────────┐
             ▼                                      ▼                                      ▼
     [Enter Bus Plate]                       [Scan Plate (OCR)]                     [My Tickets Tab]
             │                                      │                                      │
             └──────────────────┬───────────────────┘                                      │
                                ▼                                                          │
                      [Bus Details Screen]                                                 │
                                │                                                          │
                                ▼                                                          │
                        [Seat Map Screen]                                                  │
                                │ (Select seat)                                            │
                                ▼                                                          │
                     [Ticket Purchase Modal]                                               │
                                │ (Confirm & Pay)                                          │
                                ▼                                                          │
                   [Ticket Confirmation Screen] ───────────────────────────────────────────┘
```

---

## 2. Screen Specifications & ASCII Wireframes

### Screen 1: Splash & Authentication (Login / Register)
- **Purpose:** Identifies returning user session or prompts for authentication.
- **Components:** App Logo, Email TextField, Password TextField, Role Toggle (`Passenger` / `Conductor`), Primary Action Button (`Login` / `Register`), Error Banner area.

```text
+---------------------------------------+
|  09:30                           100% |
+---------------------------------------+
|                                       |
|               [LOGO]                  |
|            CityBus Go                 |
|   Real-Time Transit & Ticketing       |
|                                       |
|  +---------------------------------+  |
|  | [Tab: Login]   [Tab: Register]  |  |
|  +---------------------------------+  |
|                                       |
|  Email Address                        |
|  [ user@example.com                ]  |
|                                       |
|  Password                             |
|  [ ************                 (o)]  |
|                                       |
|  Role: (o) Passenger   ( ) Conductor  |
|                                       |
|  +---------------------------------+  |
|  |           CONTINUE              |  |
|  +---------------------------------+  |
|                                       |
|        Forgot Password?               |
+---------------------------------------+
```

---

### Screen 2: Passenger Home — Find Bus Screen
- **Purpose:** Search for an active bus via registration plate or OCR camera scan.
- **Components:** Search Bar (Input bus number), Scan Photo CTA Button, Quick Route List, Bottom Navigation Bar (`Find Bus`, `My Tickets`, `Profile`).

```text
+---------------------------------------+
| CityBus Go               [Profile (o)]|
+---------------------------------------+
|  Find Your Bus                        |
|  Enter vehicle plate or scan photo    |
|                                       |
|  +-----------------------------+ [Q] |
|  | e.g. NC-WP-4521             |     |
|  +-----------------------------+     |
|                                       |
|  [ [O] Scan Number Plate Photo ]      |
|                                       |
|  Active Routes Nearby:                |
|  +---------------------------------+  |
|  | Route 138: Colombo <-> Kottawa  |  |
|  | Bus: WP-ND-1024  •  12 Seats Free| |
|  +---------------------------------+  |
|  | Route 120: Pettah <-> Horana    |  |
|  | Bus: WP-NA-9081  •   4 Seats Free| |
|  +---------------------------------+  |
|                                       |
|---------------------------------------|
|  [(*) Find Bus]  [( ) My Tickets]     |
+---------------------------------------+
```

---

### Screen 3: Seat Availability Map Screen
- **Purpose:** Visual interactive seat grid showing real-time occupancy.
- **Components:** Bus header info (Plate, Route, Fare), Color Legend (Green: Free, Red: Taken, Blue: Selected), Seat Grid (2x2 layout with aisle), Bottom Sheet CTA (Seat #, Price, `Book Seat` button).

```text
+---------------------------------------+
| [<] Bus WP-ND-1024        Route 138   |
+---------------------------------------+
| Fare: Rs. 150.00 | Free: 18 | Taken: 22|
|                                       |
| Legend: [ ] Available  [X] Taken  [*] Selected
|                                       |
|             [ DRIVER ]                |
|                                       |
|   [ 01 ] [ 02 ]  [AISLE]  [ 03 ] [ 04 ]
|   [ 05 ] [ 06 ]  [AISLE]  [ 07 ] [ 08 ]
|   [ X  ] [ X  ]  [AISLE]  [ 11 ] [ 12 ]
|   [ 13 ] [ X  ]  [AISLE]  [ X  ] [ 16 ]
|   [ 17 ] [*18*]  [AISLE]  [ 19 ] [ 20 ]
|   [ X  ] [ X  ]  [AISLE]  [ X  ] [ X  ]
|                                       |
+---------------------------------------+
| Selected: Seat 18        Fare: Rs. 150 |
| [        PROCEED TO PURCHASE        ] |
+---------------------------------------+
```

---

### Screen 4: Ticket Confirmation & Digital Ticket ("My Tickets")
- **Purpose:** Proof of booking for the passenger and validation for conductor.
- **Components:** QR Code / Barcode, Ticket ID, Seat Number, Bus Plate, Route, Purchase Timestamp, Download / Back to Home CTA.

```text
+---------------------------------------+
| [<] Ticket Details            [Share] |
+---------------------------------------+
|                                       |
|  +---------------------------------+  |
|  |         TICKET ISSUED           |  |
|  |     Ticket ID: #TKT-89210       |  |
|  |                                 |  |
|  |       [  QR CODE / BARCODE  ]   |  |
|  |                                 |  |
|  | Route:      138 - Pettah/Kottawa|  |
|  | Bus Plate:  WP-ND-1024          |  |
|  | Seat:       18 (Window)         |  |
|  | Date/Time:  05 Nov 2026 10:15   |  |
|  | Passenger:  Alex Fernando       |  |
|  | Fare Paid:  Rs. 150.00 (Cash)   |  |
|  | Status:     CONFIRMED / ACTIVE  |  |
|  +---------------------------------+  |
|                                       |
|  [        VIEW ALL MY TICKETS       ] |
|  [           BACK TO HOME           ] |
+---------------------------------------+
```
