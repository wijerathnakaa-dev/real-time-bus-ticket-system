# System Architecture Overview & Supervisor Approval Checklist
**Jira Story:** RTBT-12  
**Target:** 4-Student Group Project  
**Sprint:** Sprint 1 Review  

---

## 1. Flutter Client Architecture

We implement a **Clean Layered Architecture with Provider / ChangeNotifier**, designed to be modular and easy for 4 students to divide without merge conflicts:

```text
lib/
├── main.dart                  # App entry point, Firebase init & route switcher
├── models/                    # Data transfer models (deserialized from Firestore)
│   ├── user_model.dart
│   ├── bus_model.dart
│   ├── route_model.dart
│   ├── seat_model.dart
│   └── ticket_model.dart
├── services/                  # Business logic & Firebase communications
│   ├── auth_service.dart      # Firebase Auth login, register, role lookup
│   ├── bus_service.dart       # Bus queries, seat listeners, number plate lookup
│   ├── ticket_service.dart    # Transactional booking & seat reservation
│   └── location_service.dart  # Geolocation & GPS telemetry
├── screens/                   # High-level screens organized by role
│   ├── auth/                  # Login, Register, Role Selection
│   ├── passenger/             # Find Bus, Seat Map, Checkout, My Tickets
│   ├── conductor/             # Shift Dashboard, Conductor Seat Map, Issue Ticket
│   └── common/                # Splash Screen, GPS Diagnostic Screen
├── widgets/                   # Reusable UI components
│   ├── seat_grid_widget.dart  # Interactive seat grid with color states
│   ├── bus_card_widget.dart   # Bus summary card
│   ├── loading_overlay.dart   # Consistent loading spinners
│   └── ticket_receipt.dart    # Printable / viewable ticket receipt
└── utils/                     # Constants, theme, and formatting
    ├── app_theme.dart         # Material 3 colors, typography, button styles
    ├── app_constants.dart     # Collections names, strings
    └── currency_helper.dart   # Standard price formatting
```

### Data Flow Diagram:
```text
[Flutter Screen (UI)]
        │  (Calls action e.g. bookSeat())
        ▼
[Service Layer (TicketService)]
        │  (Executes atomic Firestore Transaction)
        ▼
[Cloud Firestore / Auth API]
        │  (Streams update snapshots)
        ▼
[SeatGridWidget / Screens] (Rebuilds automatically)
```

---

## 2. Supervisor Approval Checklist

This checklist can be submitted to your university supervisor for formal Sprint 1 sign-off:

### A. Requirements & Scope Alignment
- [x] **Clear Persona Boundaries:** Passenger Mode and Conductor Mode have distinct, documented use cases.
- [x] **Anti-Scope Creep:** Advanced features (live map tracking, arrival times, push notifications) are strictly deferred to Sprints 4–6.
- [x] **Traceability:** Every requirement has a traceable Jira identifier (`RTBT-xx`).

### B. UI / UX Design & Accessibility
- [x] **Intuitive Navigation:** Wireframes created for both Passenger ([`docs/wireframes-passenger.md`](./wireframes-passenger.md)) and Conductor ([`docs/wireframes-conductor.md`](./wireframes-conductor.md)).
- [x] **Visual Clarity:** Clear color coding established for seat map (Available = Green, Taken = Red, Selected = Blue).
- [x] **Fail-Safe UI:** Mandatory loading indicators and friendly error handling designed for every screen.

### C. Database & Security Architecture
- [x] **Concurrency & Race Condition Safety:** Firestore atomic transaction (`runTransaction`) defined to prevent double-booking identical seats.
- [x] **Data Isolation:** `seats` modeled as a subcollection under `buses/{busId}` to prevent costly whole-fleet queries.
- [x] **Security by Design:** Role-based access documented; credentials and configuration files excluded via [`.gitignore`](../.gitignore).

### D. Team Collaboration & Scrum Governance
- [x] **Version Control:** Repository initialized with `main` and `develop` branches.
- [x] **Team Code Review:** Minimum 1 peer approval required per Pull Request as defined in [`CONTRIBUTING.md`](../CONTRIBUTING.md).
- [x] **Commit Convention:** Standardized `RTBT-xx: description` commit message format active.

---

### Supervisor Sign-Off:
- **Supervisor Name:** __________________________________
- **Signature:** ________________________________________
- **Date:** ___________________________________________
- **Status:** [ ] APPROVED FOR SPRINT 2    [ ] REVISIONS REQUIRED

