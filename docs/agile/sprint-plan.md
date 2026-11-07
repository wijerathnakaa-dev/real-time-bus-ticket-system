# Agile Delivery Plan — Real-Time Bus Ticket & Seat Availability System

The proposal's five-month waterfall plan (Oct 2026 – Feb 2027) is delivered as **6 Scrum sprints**
on the Jira board **RTBTS** (prabhathb1110.atlassian.net, board 2). Every sprint ends with a
**working, tested increment** that is demonstrated at the sprint review.

## Definition of Done (applies to every story)

1. Code merged into `develop` through a feature branch and reviewed by one teammate.
2. Automated tests for the story pass (`python test/run_sprint_tests.py <sprint>`).
3. The behaviour is demonstrable in the running system (mobile app, admin web or API).
4. No open `error`-level analyzer findings (`flutter analyze`, `go vet`).
5. Docs/README updated when setup or behaviour changes.

## Sprints and their working increments

| Sprint | Dates | Goal | Working increment shown at review | Proven by |
|---|---|---|---|---|
| 1 | Sep 21 – Oct 11 | Requirements & design | SRS, architecture, DB schema, wireframes, client sign-off | Document review |
| 2 | Oct 12 – Nov 1 | Project set-up | Repo/monorepo, Flutter skeleton with role navigation, Go server skeleton, GPS capture | `verify_sprint2.py`, `mobile_app/test/unit_test.dart` |
| 3 | Nov 2 – Nov 30 | **Core infrastructure** | Go API stores data in MySQL; register/login with JWT roles; routes & stops; conductor registers a bus, admin approves it; Flutter app logs in against the API; admin web login | `run_sprint_tests.py 3` (auth/roles, routes, bus approval, schema spec, Flutter unit tests) |
| 4 | Dec 1 – Dec 31 | **Alpha: core app features** | Passenger picks route → bus → stops → seat, pays (PayHere sandbox / simulated), gets QR e-ticket; conductor issues cash tickets and frees seats; no double booking; admin manages buses, routes, conductors, tickets, payments | `run_sprint_tests.py 4` (concurrent booking race, payment, issue/free, admin web tests + build) |
| 5 | Jan 1 – Jan 31 | **Beta: real-time features** | Live seat map on every device (WebSocket + Firebase RTDB mirror); conductor GPS broadcast; live map; per-stop ETA; auto-arrival + confirmed departures; "bus approaching" push; trip start/end; admin live monitoring | `run_sprint_tests.py 5` (GPS/ETA/stop events, trip end, live sync < 2 s) |
| 6 | Feb 1 – Feb 28 | **Testing & delivery** | Full regression, UAT with client, performance & security review, user manual, final demo | `run_sprint_tests.py all` |

## How each increment is demonstrated

* **Sprint 3** – start backend (`go run ./cmd/server`), register a conductor in the app, set up a bus,
  approve it in the admin web, log in as a passenger and find it by plate.
* **Sprint 4** – passenger books seat → pays → shows QR; conductor's seat map turns the seat red;
  conductor issues a walk-in ticket and frees a seat; admin sees tickets and payments.
* **Sprint 5** – conductor starts trip + GPS; passenger's tracking screen shows next stop and ETAs
  updating live; admin overview shows the bus moving and an activity feed of seat events.
* **Sprint 6** – end-to-end on the demo routes (Makumbura → Galle, Colombo Fort → Katunayake).

## Test suites

| Suite | Command | Covers |
|---|---|---|
| API end-to-end | `python test/test_e2e_api.py` | roles, routes, buses, atomic booking race, payments, release, GPS/ETA, trips, admin |
| Live sync | `node test/test_websocket.mjs` | seat events reach subscribed clients < 2 s, per-bus isolation |
| Backend spec | `python test/verify_backend.py` | endpoints, seat lock, schema/migration in sync |
| Flutter unit | `cd mobile_app && flutter test` | models, fare pro-rating, live merge, API client errors |
| Admin web unit | `cd admin_web && npm test` | event feed text, revenue summary, map projection |
