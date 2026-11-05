# Database Configuration & Seed Instructions

This directory contains the database migration scripts, relational schema (`schema.sql`), and seed data for the Real-Time Bus System.

## Dual Database Architecture
1. **Cloud Firestore (Primary Real-Time Engine):**
   - Direct real-time client subscriptions for low-latency (<2-5s) seat map updates.
   - Atomic seat reservations via Firestore transactions.
   - Seeded via `scripts/seed.js` using `seed_data.json`.

2. **PostgreSQL Relational Schema (`database/schema.sql`):**
   - For historical auditing, trip reconciliation, and complex multi-stop transit reporting.

## Setup Instructions (PostgreSQL)
```bash
# Connect to PostgreSQL and create database
psql -U postgres
CREATE DATABASE bus_transit_db;

# Run schema
psql -U postgres -d bus_transit_db -f database/schema.sql
```

