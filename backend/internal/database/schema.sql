-- Real-Time Bus Ticket Issuing and Seat Availability System
-- Persistent relational schema (MySQL 8.0+, InnoDB, utf8mb4)
-- Live seat/position fan-out lives in Firebase Realtime Database; this is the system of record.


-- 1. Users (passenger | conductor | admin)
CREATE TABLE IF NOT EXISTS users (
    id              VARCHAR(64)  NOT NULL PRIMARY KEY,
    name            VARCHAR(120) NOT NULL,
    email           VARCHAR(120) NOT NULL UNIQUE,
    phone           VARCHAR(20),
    password_hash   VARCHAR(100) NOT NULL,
    role            ENUM('passenger','conductor','admin') NOT NULL DEFAULT 'passenger',
    assigned_bus_id VARCHAR(64),
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Routes (long-distance expressway routes with fixed stops)
CREATE TABLE IF NOT EXISTS routes (
    id                      VARCHAR(64)   NOT NULL PRIMARY KEY,
    route_number            VARCHAR(20)   NOT NULL,
    origin                  VARCHAR(100)  NOT NULL,
    destination             VARCHAR(100)  NOT NULL,
    standard_fare           DECIMAL(10,2) NOT NULL DEFAULT 150.00,
    estimated_duration_mins INT           NOT NULL DEFAULT 45,
    created_by              VARCHAR(64),
    created_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 3. Stops (ordered along a route)
CREATE TABLE IF NOT EXISTS stops (
    id            VARCHAR(64)   NOT NULL PRIMARY KEY,
    route_id      VARCHAR(64)   NOT NULL,
    stop_name     VARCHAR(100)  NOT NULL,
    stop_sequence INT           NOT NULL,
    latitude      DECIMAL(10,6) NOT NULL,
    longitude     DECIMAL(10,6) NOT NULL,
    UNIQUE KEY uq_route_seq (route_id, stop_sequence),
    CONSTRAINT fk_stops_route FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 4. Buses (registered by conductor, approved by admin)
CREATE TABLE IF NOT EXISTS buses (
    id           VARCHAR(64) NOT NULL PRIMARY KEY,
    plate_number VARCHAR(30) NOT NULL UNIQUE,
    route_id     VARCHAR(64),
    conductor_id VARCHAR(64),
    total_seats  INT         NOT NULL DEFAULT 40,
    photo_url    VARCHAR(500),
    approved     BOOLEAN     NOT NULL DEFAULT FALSE,
    status       ENUM('on_trip','idle','maintenance') NOT NULL DEFAULT 'idle',
    trip_started_at TIMESTAMP NULL,
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_buses_route     FOREIGN KEY (route_id)     REFERENCES routes(id) ON DELETE SET NULL,
    CONSTRAINT fk_buses_conductor FOREIGN KEY (conductor_id) REFERENCES users(id)  ON DELETE SET NULL
) ENGINE=InnoDB;

-- 5. Seats (one row per physical seat; updated atomically with SELECT ... FOR UPDATE)
CREATE TABLE IF NOT EXISTS seats (
    id          BIGINT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
    bus_id      VARCHAR(64) NOT NULL,
    seat_number VARCHAR(10) NOT NULL,
    status      ENUM('available','taken') NOT NULL DEFAULT 'available',
    booked_by   VARCHAR(64),
    booked_at   TIMESTAMP NULL,
    ticket_id   VARCHAR(64),
    UNIQUE KEY uq_bus_seat (bus_id, seat_number),
    CONSTRAINT fk_seats_bus FOREIGN KEY (bus_id) REFERENCES buses(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 6. Tickets (in-app purchase or conductor-issued)
CREATE TABLE IF NOT EXISTS tickets (
    id              VARCHAR(64)   NOT NULL PRIMARY KEY,
    ticket_number   VARCHAR(30)   NOT NULL UNIQUE,
    bus_id          VARCHAR(64)   NOT NULL,
    route_id        VARCHAR(64),
    seat_number     VARCHAR(10)   NOT NULL,
    from_stop_id    VARCHAR(64),
    to_stop_id      VARCHAR(64),
    passenger_id    VARCHAR(64),
    passenger_name  VARCHAR(120)  NOT NULL,
    passenger_phone VARCHAR(20),
    issued_by_role  ENUM('passenger','conductor') NOT NULL,
    conductor_id    VARCHAR(64),
    fare            DECIMAL(10,2) NOT NULL,
    payment_status  ENUM('pending','paid','refunded','failed') NOT NULL DEFAULT 'pending',
    payment_method  ENUM('cash','payhere') NOT NULL DEFAULT 'cash',
    status          ENUM('active','completed','cancelled') NOT NULL DEFAULT 'active',
    issued_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_tickets_passenger (passenger_id, issued_at),
    KEY idx_tickets_bus (bus_id, issued_at),
    CONSTRAINT fk_tickets_bus   FOREIGN KEY (bus_id)   REFERENCES buses(id),
    CONSTRAINT fk_tickets_route FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 7. Payments (PayHere sandbox / live)
CREATE TABLE IF NOT EXISTS payments (
    id            VARCHAR(64)   NOT NULL PRIMARY KEY,
    ticket_id     VARCHAR(64)   NOT NULL,
    provider      VARCHAR(20)   NOT NULL DEFAULT 'payhere',
    provider_ref  VARCHAR(100),
    amount        DECIMAL(10,2) NOT NULL,
    currency      CHAR(3)       NOT NULL DEFAULT 'LKR',
    status        ENUM('pending','success','failed','refunded') NOT NULL DEFAULT 'pending',
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payments_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 8. Latest GPS position per bus
CREATE TABLE IF NOT EXISTS bus_locations (
    bus_id     VARCHAR(64)   NOT NULL PRIMARY KEY,
    latitude   DECIMAL(10,6) NOT NULL,
    longitude  DECIMAL(10,6) NOT NULL,
    accuracy   DECIMAL(6,2),
    speed_kmh  DECIMAL(6,2),
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_locations_bus FOREIGN KEY (bus_id) REFERENCES buses(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 9. Per-stop arrival/departure history (ETA engine + conductor "confirm departure")
CREATE TABLE IF NOT EXISTS stop_events (
    id           BIGINT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
    bus_id       VARCHAR(64) NOT NULL,
    stop_id      VARCHAR(64) NOT NULL,
    event_type   ENUM('arrival','departure') NOT NULL,
    confirmed_by VARCHAR(64),
    occurred_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_stop_events_bus (bus_id, occurred_at),
    CONSTRAINT fk_stop_events_bus  FOREIGN KEY (bus_id)  REFERENCES buses(id) ON DELETE CASCADE,
    CONSTRAINT fk_stop_events_stop FOREIGN KEY (stop_id) REFERENCES stops(id) ON DELETE CASCADE
) ENGINE=InnoDB;
