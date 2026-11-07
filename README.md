# Real-Time Bus Ticket Issuing and Seat Availability System (CityBus Go)

EC5406 Software Project. One Flutter app with **Passenger**, **Conductor** and **Admin** modes, an
**Admin Web Dashboard**, and a **Go** backend on **MySQL** with live updates over **WebSocket** and a
**Firebase Realtime Database** mirror — for long-distance expressway routes with fixed stops.

```
Flutter app (passenger / conductor / admin)  ─┐            ┌─ MySQL 8 (system of record)
Admin web dashboard (React)                   ─┼─ Go API ───┼─ Firebase RTDB mirror + FCM push (optional)
Conductor phone GPS                           ─┘  REST + WS └─ PayHere (sandbox / live, optional)
```

| Folder | What it is |
|---|---|
| `backend/` | Go (Gin) REST API + WebSocket hub, ETA engine, PayHere, Firebase mirror |
| `mobile_app/` | Flutter app (Android; also builds for web) |
| `admin_web/` | Admin Web Dashboard (React + Vite) |
| `database/schema.sql` | MySQL schema (applied automatically by the backend) |
| `test/` | API end-to-end, live-sync and per-sprint test runner |
| `docs/agile/sprint-plan.md` | Agile sprints, Definition of Done, increment per sprint |

## Quick start (local)

Prerequisites: **Go 1.22+**, **MySQL 8**, **Flutter 3.24+** with Android Studio/SDK, **Node 18+**.

### 1. Backend
No local MySQL? Run one in Docker (set `MYSQL_ROOT_PASSWORD` and `MYSQL_HOST_PORT`, e.g. 3308, in `deployment/docker/.env`):
```bash
cd deployment/docker && docker compose up -d mysql
```
Then point `MYSQL_DSN` at `127.0.0.1:<MYSQL_HOST_PORT>`.
```bash
cd backend
cp .env.example .env        # set MYSQL_DSN to your MySQL user/password
go run ./cmd/server         # creates the DB, applies the schema, seeds demo data, listens on :5000
```
Check: `http://localhost:5000/api/health`

### 2. Admin web dashboard
```bash
cd admin_web
npm install
npm run dev                 # http://localhost:5173  (API URL in admin_web/.env, see .env.example)
```

### 3. Mobile app
```bash
cd mobile_app
flutter pub get
flutter run                 # Android emulator reaches the PC's backend at 10.0.2.2:5000
flutter run --dart-define=API_URL=http://192.168.1.20:5000   # real phone on the same Wi-Fi
flutter build apk --release
```

### Demo accounts (created only in an empty database when `SEED_DEMO_DATA=true`)
| Role | Email | Password |
|---|---|---|
| Admin | admin@citybus.lk | Admin@123 |
| Conductor (bus NB-2451, Makumbura → Galle) | conductor1@citybus.lk | Conductor@123 |
| Conductor (bus NC-7832, Colombo Fort → Katunayake) | conductor2@citybus.lk | Conductor@123 |
| Passenger | passenger@citybus.lk | Passenger@123 |

Change these or set `SEED_DEMO_DATA=false` before any real deployment.

## Optional integrations

| Integration | How to turn it on | Without it |
|---|---|---|
| Firebase RTDB + FCM push | Put the service-account JSON at `backend/firebase-service-account.json`, set `FIREBASE_DATABASE_URL`; put `google-services.json` in `mobile_app/android/app/` | Live data still flows over WebSocket; no push notifications |
| PayHere | Set `PAYHERE_MERCHANT_ID`, `PAYHERE_MERCHANT_SECRET` (and `PAYHERE_SANDBOX=true`) in `backend/.env`; `PUBLIC_BASE_URL` must be reachable by PayHere for the notify callback | Clearly-labelled simulated payment |
| Google Maps (app) | `MAPS_API_KEY=...` in `mobile_app/android/local.properties`, run with `--dart-define=MAPS_ENABLED=true` | Stop-timeline progress view |
| Google Maps (admin web) | `VITE_GOOGLE_MAPS_KEY=...` in `admin_web/.env` | Schematic live map |

## Tests
```bash
python test/run_sprint_tests.py all     # needs the backend running with demo data
```
See `docs/agile/sprint-plan.md` for what each sprint's suite proves.
