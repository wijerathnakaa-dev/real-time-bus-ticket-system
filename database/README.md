# Database

The system of record is **MySQL 8**. `schema.sql` here is the reference copy of the schema; the
backend embeds `backend/internal/database/schema.sql` and applies it automatically on start
(it also creates the `bus_transit_db` database if it is missing).

## Run MySQL locally with Docker
Set `MYSQL_ROOT_PASSWORD` and `MYSQL_HOST_PORT` (e.g. 3308) in `deployment/docker/.env`, then:
```bash
cd deployment/docker && docker compose up -d mysql
```
Point `MYSQL_DSN` in `backend/.env` at `127.0.0.1:<MYSQL_HOST_PORT>` and start the backend
(`go run ./cmd/server`). With `SEED_DEMO_DATA=true` an empty database gets the demo users,
routes and buses listed in the main README.
