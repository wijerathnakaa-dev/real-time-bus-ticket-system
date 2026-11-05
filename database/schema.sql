-- Real-Time Bus Ticket Issuing and Seat Availability System
-- Relational Schema Definition (PostgreSQL / Cloud SQL)

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY, -- Firebase UID or UUID
    name VARCHAR(120) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    phone VARCHAR(20),
    role VARCHAR(20) NOT NULL CHECK (role IN ('passenger', 'conductor', 'admin')),
    assigned_bus_id VARCHAR(64),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Routes Table
CREATE TABLE IF NOT EXISTS routes (
    id VARCHAR(64) PRIMARY KEY,
    route_number VARCHAR(20) NOT NULL,
    origin VARCHAR(100) NOT NULL,
    destination VARCHAR(100) NOT NULL,
    standard_fare NUMERIC(10, 2) NOT NULL DEFAULT 150.00,
    estimated_duration_mins INT DEFAULT 45,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Stops Table (Per-stop occupancy support)
CREATE TABLE IF NOT EXISTS stops (
    id VARCHAR(64) PRIMARY KEY,
    route_id VARCHAR(64) REFERENCES routes(id) ON DELETE CASCADE,
    stop_name VARCHAR(100) NOT NULL,
    stop_sequence INT NOT NULL,
    latitude NUMERIC(10, 6) NOT NULL,
    longitude NUMERIC(10, 6) NOT NULL
);

-- 4. Buses Table
CREATE TABLE IF NOT EXISTS buses (
    id VARCHAR(64) PRIMARY KEY,
    plate_number VARCHAR(30) UNIQUE NOT NULL,
    route_id VARCHAR(64) REFERENCES routes(id),
    conductor_id VARCHAR(64) REFERENCES users(id),
    total_seats INT NOT NULL DEFAULT 40,
    status VARCHAR(20) NOT NULL DEFAULT 'on_trip' CHECK (status IN ('on_trip', 'idle', 'maintenance')),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Seats Table
CREATE TABLE IF NOT EXISTS seats (
    id SERIAL PRIMARY KEY,
    bus_id VARCHAR(64) REFERENCES buses(id) ON DELETE CASCADE,
    seat_number VARCHAR(10) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'taken')),
    booked_by VARCHAR(64) REFERENCES users(id),
    booked_at TIMESTAMP WITH TIME ZONE,
    ticket_id VARCHAR(64),
    UNIQUE (bus_id, seat_number)
);

-- 6. Tickets Table
CREATE TABLE IF NOT EXISTS tickets (
    id VARCHAR(64) PRIMARY KEY,
    ticket_number VARCHAR(30) UNIQUE NOT NULL,
    bus_id VARCHAR(64) REFERENCES buses(id),
    route_id VARCHAR(64) REFERENCES routes(id),
    seat_number VARCHAR(10) NOT NULL,
    passenger_id VARCHAR(64),
    passenger_name VARCHAR(120) NOT NULL,
    passenger_phone VARCHAR(20),
    issued_by_role VARCHAR(20) NOT NULL CHECK (issued_by_role IN ('passenger', 'conductor')),
    conductor_id VARCHAR(64) REFERENCES users(id),
    fare NUMERIC(10, 2) NOT NULL,
    payment_status VARCHAR(20) NOT NULL DEFAULT 'paid',
    payment_method VARCHAR(20) NOT NULL DEFAULT 'cash',
    issued_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. GPS Locations Telemetry Table
CREATE TABLE IF NOT EXISTS bus_locations (
    bus_id VARCHAR(64) PRIMARY KEY REFERENCES buses(id) ON DELETE CASCADE,
    latitude NUMERIC(10, 6) NOT NULL,
    longitude NUMERIC(10, 6) NOT NULL,
    accuracy NUMERIC(6, 2),
    speed NUMERIC(6, 2),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_tickets_passenger ON tickets(passenger_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_tickets_bus ON tickets(bus_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_buses_plate ON buses(plate_number);

