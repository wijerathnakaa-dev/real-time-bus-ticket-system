# Real-Time Bus Ticket Issuing and Seat Availability System

## Project Overview
A multi-mode mobile application built for Sri Lankan transit commuters and conductors:
- **Passenger Mode:** Find buses by number plate or OCR photo, view real-time seat occupancy grids, book tickets atomically, and view digital receipts.
- **Conductor Mode:** Live vehicle seat dashboard, walk-in ticket issuing, and real-time GPS telemetry broadcasting.

---

## Prerequisites
1. **Flutter SDK:** Flutter 3.16+ (Dart 3.0+)
2. **Android Studio / VS Code** with Flutter and Dart extensions
3. **Android Device or Emulator:** Android 7.0 (API Level 24) or higher
4. **Firebase Project:** Configured with Firebase Authentication (Email/Password) and Cloud Firestore.

---

## Step-by-Step Setup Guide

### 1. Clone & Install Dependencies
```bash
git clone <repo-url>
cd "SW-Bus Ticket"
flutter pub get
```

### 2. Configure Firebase
1. Open the [Firebase Console](https://console.firebase.google.com/) and create a new project: `citybus-go-rtbt`.
2. Add an **Android Application** with Package Name:
   ```text
   com.university.real_time_bus_ticket
   ```
3. Download `google-services.json` and place it in:
   ```text
   android/app/google-services.json
   ```
   *(Note: This file is excluded in `.gitignore` to protect credentials).*
4. Enable **Authentication** $\to$ Sign-in method $\to$ **Email/Password**.
5. Enable **Cloud Firestore** in test or production mode.
6. Deploy the security rules located in [`firestore.rules`](./firestore.rules):
   ```bash
   firebase deploy --only firestore:rules
   ```

### 3. Run the Application
Connect an Android device with USB debugging enabled or launch an Android emulator, then run:
```bash
flutter run
```

### 4. Running Unit Tests
Execute the local test suite:
```bash
flutter test
```

---

## Sprint 2 Verification Checklist
- [x] **RTBT-13:** Flutter clean architecture project setup with Passenger and Conductor modes.
- [x] **RTBT-14:** Firebase Auth registration, role selection (`passenger`/`conductor`), login & session persistence.
- [x] **RTBT-15:** Firestore security rules and seed data for routes, buses, and seats.
- [x] **RTBT-16:** GPS Diagnostics Screen with location streaming, accuracy check, and permission failure handling.

