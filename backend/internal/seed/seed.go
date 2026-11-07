// Package seed loads demo data into an empty database (SEED_DEMO_DATA=true).
// Demo accounts are listed in backend/README.md - change or disable them before production.
package seed

import (
	"database/sql"
	"fmt"
	"log"

	"real-time-bus-backend/internal/modules/buses"

	"golang.org/x/crypto/bcrypt"
)

type stop struct {
	name     string
	lat, lng float64
}

type route struct {
	id, number, origin, dest string
	fare                     float64
	mins                     int
	stops                    []stop
}

var demoRoutes = []route{
	{"route_ex01", "EX1-17", "Makumbura (Kottawa)", "Galle", 1000, 90, []stop{
		{"Makumbura Multimodal Centre", 6.840713, 79.976854},
		{"Kahathuduwa Interchange", 6.783611, 80.009722},
		{"Gelanigama Interchange", 6.714906, 80.056929},
		{"Dodangoda Interchange", 6.570520, 80.088660},
		{"Welipenna Interchange", 6.468610, 80.101800},
		{"Kurundugahahethekma Interchange", 6.265500, 80.138600},
		{"Baddegama Interchange", 6.179700, 80.179300},
		{"Pinnaduwa (Galle) Interchange", 6.067300, 80.240000},
	}},
	{"route_ex03", "EX3-187", "Colombo Fort", "Katunayake Airport", 400, 45, []stop{
		{"Colombo Fort Bus Stand", 6.934400, 79.850000},
		{"Peliyagoda Interchange", 6.960800, 79.883500},
		{"Ja-Ela Interchange", 7.074400, 79.891900},
		{"Katunayake (BIA)", 7.169700, 79.884000},
	}},
}

func Run(db *sql.DB) error {
	var users int
	if err := db.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&users); err != nil {
		return err
	}
	if users > 0 {
		return nil
	}
	log.Println("[Seed] empty database - loading demo routes, buses and accounts")

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	accounts := []struct{ id, name, email, phone, role, password string }{
		{"usr_admin", "System Admin", "admin@citybus.lk", "0110000000", "admin", "Admin@123"},
		{"usr_conductor1", "Nimal Perera", "conductor1@citybus.lk", "0771111111", "conductor", "Conductor@123"},
		{"usr_conductor2", "Kamal Silva", "conductor2@citybus.lk", "0772222222", "conductor", "Conductor@123"},
		{"usr_passenger1", "Alex Fernando", "passenger@citybus.lk", "0773333333", "passenger", "Passenger@123"},
	}
	for _, a := range accounts {
		hash, err := bcrypt.GenerateFromPassword([]byte(a.password), bcrypt.DefaultCost)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(`INSERT INTO users (id, name, email, phone, password_hash, role) VALUES (?, ?, ?, ?, ?, ?)`,
			a.id, a.name, a.email, a.phone, string(hash), a.role); err != nil {
			return err
		}
	}

	for _, r := range demoRoutes {
		if _, err := tx.Exec(`INSERT INTO routes (id, route_number, origin, destination, standard_fare, estimated_duration_mins, created_by) VALUES (?, ?, ?, ?, ?, ?, 'usr_admin')`,
			r.id, r.number, r.origin, r.dest, r.fare, r.mins); err != nil {
			return err
		}
		for i, s := range r.stops {
			if _, err := tx.Exec(`INSERT INTO stops (id, route_id, stop_name, stop_sequence, latitude, longitude) VALUES (?, ?, ?, ?, ?, ?)`,
				fmt.Sprintf("%s_s%d", r.id, i+1), r.id, s.name, i+1, s.lat, s.lng); err != nil {
				return err
			}
		}
	}

	demoBuses := []struct {
		id, plate, route string
		conductor        interface{}
		seats            int
		approved         bool
		status           string
	}{
		{"bus_nb2451", "NB-2451", "route_ex01", "usr_conductor1", 40, true, "on_trip"},
		{"bus_nc7832", "NC-7832", "route_ex03", "usr_conductor2", 36, true, "idle"},
		{"bus_nd1190", "ND-1190", "route_ex01", nil, 40, false, "idle"},
	}
	for _, b := range demoBuses {
		if _, err := tx.Exec(`INSERT INTO buses (id, plate_number, route_id, conductor_id, total_seats, approved, status, trip_started_at)
			VALUES (?, ?, ?, ?, ?, ?, ?, IF(? = 'on_trip', NOW(), NULL))`, b.id, b.plate, b.route, b.conductor, b.seats, b.approved, b.status, b.status); err != nil {
			return err
		}
		if err := buses.SyncSeats(tx, b.id, b.seats); err != nil {
			return err
		}
		if b.conductor != nil {
			if _, err := tx.Exec(`UPDATE users SET assigned_bus_id=? WHERE id=?`, b.id, b.conductor); err != nil {
				return err
			}
		}
	}

	// NB-2451 is mid-trip near Kahathuduwa with a few walk-in passengers on board.
	if _, err := tx.Exec(`INSERT INTO bus_locations (bus_id, latitude, longitude, accuracy, speed_kmh) VALUES ('bus_nb2451', 6.805000, 79.995000, 8, 72)`); err != nil {
		return err
	}
	if _, err := tx.Exec(`INSERT INTO stop_events (bus_id, stop_id, event_type, confirmed_by) VALUES
		('bus_nb2451', 'route_ex01_s1', 'arrival', 'usr_conductor1'), ('bus_nb2451', 'route_ex01_s1', 'departure', 'usr_conductor1')`); err != nil {
		return err
	}
	for i, seat := range []string{"1", "2", "5", "6", "9", "14"} {
		id := fmt.Sprintf("tkt_seed%d", i+1)
		if _, err := tx.Exec(`INSERT INTO tickets (id, ticket_number, bus_id, route_id, seat_number, from_stop_id, to_stop_id, passenger_name,
			issued_by_role, conductor_id, fare, payment_status, payment_method, status)
			VALUES (?, ?, 'bus_nb2451', 'route_ex01', ?, 'route_ex01_s1', 'route_ex01_s8', 'Walk-in passenger', 'conductor', 'usr_conductor1', 1000, 'paid', 'cash', 'active')`,
			id, fmt.Sprintf("TKT-SEED-%03d", i+1), seat); err != nil {
			return err
		}
		if _, err := tx.Exec(`UPDATE seats SET status='taken', booked_at=NOW(), ticket_id=? WHERE bus_id='bus_nb2451' AND seat_number=?`, id, seat); err != nil {
			return err
		}
	}
	return tx.Commit()
}
