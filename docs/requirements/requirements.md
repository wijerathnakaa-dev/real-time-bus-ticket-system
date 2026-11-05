# Software Requirements Specification (SRS)
## Project: Real-Time Bus Ticket Issuing and Seat Availability System
**Project Key:** RTBT  
**Sprint:** Sprint 1 — Design & Setup  
**Jira Issue:** [RTBT-7] Collect and document project requirements  
**Target Platform:** Android (Flutter)  
**Backend:** Firebase Authentication & Cloud Firestore  

---

## 1. Project Overview
The Real-Time Bus Ticket Issuing and Seat Availability System is a mobile application tailored for commuter transit. It provides two distinct modes:
1. **Passenger Mode:** Enables commuters to find a bus, inspect real-time seat availability, pick a vacant seat, and purchase an e-ticket.
2. **Conductor Mode:** Equips on-board bus conductors with a live seat grid to verify occupancy and issue manual tickets to walk-in passengers.

---

## 2. Functional Requirements (FR)

### 2.1 Shared & Authentication Features
- **FR-AUTH-01 (User Registration):** The system shall allow users to register with an email address, password, full name, phone number, and a selectable role (`passenger` or `conductor`).
- **FR-AUTH-02 (User Login & Session Persistence):** The system shall authenticate users with email and password, maintain their session across app restarts, and direct them to their respective role-based home screen.
- **FR-AUTH-03 (Role-Based Access Control):** The system shall enforce role separation so passengers cannot access conductor ticket-issuing screens and conductors are directed to fleet/bus management operations.
- **FR-AUTH-04 (User Logout):** The system shall provide an option to securely end the authenticated session and return to the login screen.

### 2.2 Passenger Features
- **FR-PASS-01 (Bus Identification):** The passenger shall be able to look up a bus by entering its registration number plate (e.g., `NC-WP-4521`).
- **FR-PASS-02 (Bus Identification via OCR - Future Enhancement):** The app shall allow taking a photo of a bus number plate to prefill the search field using on-device optical character recognition (OCR), with manual fallback.
- **FR-PASS-03 (View Bus Route & Information):** The system shall display the identified bus's route name, origin, destination, standard fare, and total capacity.
- **FR-PASS-04 (Visual Seat Availability Map):** The system shall display an intuitive interactive seat grid distinguishing between:
  - **Available:** Unoccupied seats available for selection.
  - **Taken / Occupied:** Seats already booked or issued.
  - **Selected:** The seat currently tapped by the passenger.
- **FR-PASS-05 (Seat Selection & Fare Calculation):** The passenger shall select an available seat and view a checkout summary showing bus number, route, seat number, and ticket price.
- **FR-PASS-06 (Ticket Purchase & Double-Booking Prevention):** The system shall execute ticket purchases using atomic database transactions to ensure two users cannot book the same seat at the same time.
- **FR-PASS-07 (Digital Ticket Confirmation):** Upon successful booking, the system shall display a digital ticket receipt containing a unique Ticket ID, bus plate, route, seat number, booking timestamp, and fare paid.
- **FR-PASS-08 (My Tickets History):** The passenger shall be able to view a list of all tickets previously booked under their account.

### 2.3 Conductor Features
- **FR-COND-01 (Bus Assignment / Selection):** The conductor shall select or be assigned to a specific bus for their shift.
- **FR-COND-02 (Conductor Seat Grid View):** The conductor shall view the real-time seat availability grid for their assigned bus.
- **FR-COND-03 (Issue On-Board Ticket):** The conductor shall be able to select an unoccupied seat, optionally input passenger contact details (name or phone), and issue a walk-in cash ticket.
- **FR-COND-04 (Atomic Seat Allocation):** When the conductor issues a ticket, the seat status shall instantly transition to `taken` via the same atomic transaction logic to prevent conflicts with mobile passenger bookings.
- **FR-COND-05 (Issued Tickets Manifest):** The conductor shall have access to a list of all tickets issued for the active bus journey.

---

## 3. Non-Functional Requirements (NFR)

- **NFR-01 (Usability & Simplicity):** The UI shall adhere to Material 3 design principles, using high-contrast colors (e.g., Green for Free, Red for Taken, Blue for Selected) and large touch targets suitable for moving buses and non-technical users.
- **NFR-02 (Performance & Responsiveness):** Screen transitions and seat map rendering shall complete in under 1.5 seconds on mid-range Android devices (Android 8.0 Oreo and above).
- **NFR-03 (Feedback & Loading States):** Every screen making network or database requests must display clear loading indicators (spinners or skeleton loaders) and user-friendly error banners. The app must never crash on network failure or permission denial.
- **NFR-04 (Security & Secrets Management):** No API keys, credentials, or private configuration values shall be hardcoded in source control. All sensitive keys must reside in environment configurations ignored by `.gitignore`.
- **NFR-05 (Data Integrity):** Cloud Firestore security rules shall restrict database modifications:
  - Passengers can only read bus/seat data and create tickets under their own `userId`.
  - Conductors can update seat availability and issue on-board tickets.
- **NFR-06 (Maintainability & Code Cleanliness):** Codebase must follow standard Flutter clean architecture (`screens`, `widgets`, `services`, `models`, `utils`) with comments explaining rationale for university student collaboration.

---

## 4. System Assumptions & Dependencies
1. **Device Environment:** Target devices run Android (API level 24 / Android 7.0 or higher) with an active internet connection (Wi-Fi or cellular data).
2. **Payment Processing:** For Sprints 1–3, payment is simulated/cash confirmation upon booking; external payment gateway integration (Stripe, PayHere, etc.) is reserved for later releases.
3. **Bus Fleet Model:** A bus follows a single scheduled trip/route per active session in Sprints 1–3.

---

## 5. Out of Scope (Deferred to Sprints 4–6)
To keep the initial sprints focused and achievable, the following features are explicitly **out of scope** for Sprints 1–3:
- Live GPS bus location tracking on an interactive Google Map.
- Estimated Time of Arrival (ETA) calculation and route-progress indicators.
- Push notifications for booking reminders or bus approach alerts.
- Third-party digital payment gateway integrations.
- Conductor shift reconciliation and multi-day financial auditing reports.
- Offline-first bidirectional sync (basic online connectivity is assumed).

