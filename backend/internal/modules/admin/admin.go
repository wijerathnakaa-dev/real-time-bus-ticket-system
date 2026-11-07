package admin

import (
	"database/sql"
	"net/http"
	"time"

	"real-time-bus-backend/internal/app"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(rg *gin.RouterGroup, d *app.Deps) {
	rg.Use(d.Auth(app.RoleAdmin))

	rg.GET("/stats", func(c *gin.Context) {
		var s struct {
			Buses, OnTrip, Pending, Routes, Passengers, Conductors, TicketsToday, ActiveTickets, SeatsTotal, SeatsTaken int
			RevenueToday                                                                                                float64
		}
		q := func(dst interface{}, query string, args ...interface{}) {
			_ = d.DB.QueryRow(query, args...).Scan(dst)
		}
		today := time.Now().Format("2006-01-02")
		q(&s.Buses, `SELECT COUNT(*) FROM buses`)
		q(&s.OnTrip, `SELECT COUNT(*) FROM buses WHERE status='on_trip'`)
		q(&s.Pending, `SELECT COUNT(*) FROM buses WHERE approved=FALSE`)
		q(&s.Routes, `SELECT COUNT(*) FROM routes`)
		q(&s.Passengers, `SELECT COUNT(*) FROM users WHERE role='passenger'`)
		q(&s.Conductors, `SELECT COUNT(*) FROM users WHERE role='conductor'`)
		q(&s.TicketsToday, `SELECT COUNT(*) FROM tickets WHERE issued_at >= ?`, today)
		q(&s.ActiveTickets, `SELECT COUNT(*) FROM tickets WHERE status='active'`)
		q(&s.RevenueToday, `SELECT COALESCE(SUM(fare),0) FROM tickets WHERE payment_status='paid' AND issued_at >= ?`, today)
		q(&s.SeatsTotal, `SELECT COUNT(*) FROM seats`)
		q(&s.SeatsTaken, `SELECT COUNT(*) FROM seats WHERE status='taken'`)
		c.JSON(http.StatusOK, gin.H{
			"buses": s.Buses, "buses_on_trip": s.OnTrip, "buses_pending_approval": s.Pending, "routes": s.Routes,
			"passengers": s.Passengers, "conductors": s.Conductors, "tickets_today": s.TicketsToday,
			"active_tickets": s.ActiveTickets, "revenue_today": s.RevenueToday, "seats_total": s.SeatsTotal, "seats_taken": s.SeatsTaken,
		})
	})

	rg.GET("/users", func(c *gin.Context) {
		where, args := "1=1", []interface{}{}
		if r := c.Query("role"); r != "" {
			where, args = "u.role = ?", append(args, r)
		}
		rows, err := d.DB.Query(`SELECT u.id, u.name, u.email, u.phone, u.role, u.assigned_bus_id, b.plate_number, u.created_at
			FROM users u LEFT JOIN buses b ON b.id = u.assigned_bus_id WHERE `+where+` ORDER BY u.role, u.name`, args...)
		if err != nil {
			app.DBError(c, err, "users")
			return
		}
		defer rows.Close()
		out := []gin.H{}
		for rows.Next() {
			var id, name, email, role string
			var phone, bus, plate sql.NullString
			var created time.Time
			if err := rows.Scan(&id, &name, &email, &phone, &role, &bus, &plate, &created); err != nil {
				app.DBError(c, err, "users")
				return
			}
			out = append(out, gin.H{"id": id, "name": name, "email": email, "phone": phone.String, "role": role,
				"assigned_bus_id": bus.String, "assigned_bus_plate": plate.String, "created_at": created})
		}
		c.JSON(http.StatusOK, out)
	})

	rg.GET("/payments", func(c *gin.Context) {
		rows, err := d.DB.Query(`SELECT p.id, p.ticket_id, t.ticket_number, t.passenger_name, p.provider, p.provider_ref, p.amount, p.currency, p.status, p.created_at
			FROM payments p JOIN tickets t ON t.id = p.ticket_id ORDER BY p.created_at DESC LIMIT 500`)
		if err != nil {
			app.DBError(c, err, "payments")
			return
		}
		defer rows.Close()
		out := []gin.H{}
		for rows.Next() {
			var id, tid, num, name, provider, cur, status string
			var ref sql.NullString
			var amt float64
			var at time.Time
			if err := rows.Scan(&id, &tid, &num, &name, &provider, &ref, &amt, &cur, &status, &at); err != nil {
				app.DBError(c, err, "payments")
				return
			}
			out = append(out, gin.H{"id": id, "ticket_id": tid, "ticket_number": num, "passenger_name": name, "provider": provider,
				"provider_ref": ref.String, "amount": amt, "currency": cur, "status": status, "created_at": at})
		}
		c.JSON(http.StatusOK, out)
	})
}
