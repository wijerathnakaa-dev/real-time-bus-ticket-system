package tickets

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"log"
	"math"
	"net/http"
	"strings"
	"time"

	"real-time-bus-backend/internal/app"

	"github.com/gin-gonic/gin"
)

type Ticket struct {
	ID             string    `json:"id"`
	TicketNumber   string    `json:"ticket_number"`
	BusID          string    `json:"bus_id"`
	BusPlateNumber string    `json:"bus_plate_number"`
	RouteID        *string   `json:"route_id"`
	RouteNumber    *string   `json:"route_number"`
	SeatNumber     string    `json:"seat_number"`
	FromStopID     *string   `json:"from_stop_id"`
	FromStopName   *string   `json:"from_stop_name"`
	ToStopID       *string   `json:"to_stop_id"`
	ToStopName     *string   `json:"to_stop_name"`
	PassengerID    *string   `json:"passenger_id"`
	PassengerName  string    `json:"passenger_name"`
	PassengerPhone *string   `json:"passenger_phone"`
	IssuedByRole   string    `json:"issued_by_role"`
	ConductorID    *string   `json:"conductor_id"`
	Fare           float64   `json:"fare"`
	PaymentStatus  string    `json:"payment_status"`
	PaymentMethod  string    `json:"payment_method"`
	Status         string    `json:"status"`
	IssuedAt       time.Time `json:"issued_at"`
}

const selectTicket = `SELECT t.id, t.ticket_number, t.bus_id, b.plate_number, t.route_id, r.route_number, t.seat_number,
	t.from_stop_id, fs.stop_name, t.to_stop_id, ts.stop_name, t.passenger_id, t.passenger_name, t.passenger_phone,
	t.issued_by_role, t.conductor_id, t.fare, t.payment_status, t.payment_method, t.status, t.issued_at
	FROM tickets t
	JOIN buses b ON b.id = t.bus_id
	LEFT JOIN routes r ON r.id = t.route_id
	LEFT JOIN stops fs ON fs.id = t.from_stop_id
	LEFT JOIN stops ts ON ts.id = t.to_stop_id`

func scanTicket(s interface{ Scan(...interface{}) error }) (*Ticket, error) {
	var t Ticket
	err := s.Scan(&t.ID, &t.TicketNumber, &t.BusID, &t.BusPlateNumber, &t.RouteID, &t.RouteNumber, &t.SeatNumber,
		&t.FromStopID, &t.FromStopName, &t.ToStopID, &t.ToStopName, &t.PassengerID, &t.PassengerName, &t.PassengerPhone,
		&t.IssuedByRole, &t.ConductorID, &t.Fare, &t.PaymentStatus, &t.PaymentMethod, &t.Status, &t.IssuedAt)
	return &t, err
}

func Load(db *sql.DB, id string) (*Ticket, error) {
	return scanTicket(db.QueryRow(selectTicket+` WHERE t.id = ?`, id))
}

func queryTickets(db *sql.DB, where string, args ...interface{}) ([]*Ticket, error) {
	rows, err := db.Query(selectTicket+" WHERE "+where+" ORDER BY t.issued_at DESC LIMIT 500", args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []*Ticket{}
	for rows.Next() {
		t, err := scanTicket(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

type BookRequest struct {
	BusID          string `json:"bus_id" binding:"required"`
	SeatNumber     string `json:"seat_number" binding:"required"`
	FromStopID     string `json:"from_stop_id"`
	ToStopID       string `json:"to_stop_id"`
	PassengerName  string `json:"passenger_name"`
	PassengerPhone string `json:"passenger_phone"`
	PaymentMethod  string `json:"payment_method"` // payhere (passenger default) | cash (conductor default)
}

var ErrSeatTaken = errors.New("seat is already taken")

func ticketNumber() string {
	b := make([]byte, 3)
	_, _ = rand.Read(b)
	return "TKT-" + time.Now().Format("060102") + "-" + strings.ToUpper(hex.EncodeToString(b))
}

// Fare is the route's standard fare pro-rated by the number of stop-to-stop legs travelled.
func Fare(standard float64, fromSeq, toSeq, stopCount int) float64 {
	if stopCount < 2 || fromSeq <= 0 || toSeq <= fromSeq {
		return standard
	}
	f := standard * float64(toSeq-fromSeq) / float64(stopCount-1)
	return math.Max(math.Round(f/10)*10, math.Round(standard*0.2))
}

func RegisterRoutes(rg *gin.RouterGroup, d *app.Deps) {
	// Passenger buys a seat in-app, or conductor issues a ticket in person.
	rg.POST("", d.Auth(app.RolePassenger, app.RoleConductor, app.RoleAdmin), func(c *gin.Context) {
		var req BookRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		u := app.User(c)
		if u.Role == app.RoleConductor && !d.CanOperateBus(c, req.BusID) {
			app.Fail(c, http.StatusForbidden, "conductors can only issue tickets on their assigned bus")
			return
		}
		t, err := Book(d, u, req)
		switch {
		case errors.Is(err, ErrSeatTaken):
			app.Fail(c, http.StatusConflict, "seat "+req.SeatNumber+" was just taken - please choose another seat")
		case errors.Is(err, sql.ErrNoRows):
			app.Fail(c, http.StatusNotFound, "bus, seat or stop not found")
		case err != nil:
			app.Fail(c, http.StatusBadRequest, err.Error())
		default:
			c.JSON(http.StatusCreated, t)
		}
	})

	rg.GET("/mine", d.Auth(), func(c *gin.Context) {
		out, err := queryTickets(d.DB, "t.passenger_id = ?", app.User(c).UserID)
		if err != nil {
			app.DBError(c, err, "tickets")
			return
		}
		c.JSON(http.StatusOK, out)
	})

	// Admin: all tickets with filters. Conductor: tickets of their bus.
	rg.GET("", d.Auth(app.RoleAdmin, app.RoleConductor), func(c *gin.Context) {
		where, args := []string{"1=1"}, []interface{}{}
		u := app.User(c)
		busID := c.Query("bus_id")
		if u.Role == app.RoleConductor {
			if busID == "" || !d.CanOperateBus(c, busID) {
				app.Fail(c, http.StatusForbidden, "conductors must pass bus_id of their assigned bus")
				return
			}
		}
		for _, f := range [][2]string{{"bus_id", "t.bus_id"}, {"route_id", "t.route_id"}, {"status", "t.status"}, {"payment_status", "t.payment_status"}, {"payment_method", "t.payment_method"}} {
			if v := c.Query(f[0]); v != "" {
				where = append(where, f[1]+" = ?")
				args = append(args, v)
			}
		}
		if v := c.Query("from"); v != "" {
			where = append(where, "t.issued_at >= ?")
			args = append(args, v)
		}
		if v := c.Query("to"); v != "" {
			where = append(where, "t.issued_at < DATE_ADD(?, INTERVAL 1 DAY)")
			args = append(args, v)
		}
		if v := c.Query("q"); v != "" {
			where = append(where, "(t.ticket_number LIKE ? OR t.passenger_name LIKE ?)")
			args = append(args, "%"+v+"%", "%"+v+"%")
		}
		out, err := queryTickets(d.DB, strings.Join(where, " AND "), args...)
		if err != nil {
			app.DBError(c, err, "tickets")
			return
		}
		c.JSON(http.StatusOK, out)
	})

	rg.GET("/:id", d.Auth(), func(c *gin.Context) {
		t, err := Load(d.DB, c.Param("id"))
		if err != nil {
			app.DBError(c, err, "ticket")
			return
		}
		if !canSee(d, c, t) {
			app.Fail(c, http.StatusForbidden, "not your ticket")
			return
		}
		c.JSON(http.StatusOK, t)
	})

	// Verify a ticket by number (conductor scans the passenger's QR code).
	rg.GET("/verify/:number", d.Auth(app.RoleConductor, app.RoleAdmin), func(c *gin.Context) {
		t, err := scanTicket(d.DB.QueryRow(selectTicket+` WHERE t.ticket_number = ?`, c.Param("number")))
		if err != nil {
			app.DBError(c, err, "ticket")
			return
		}
		valid := t.Status == "active" && t.PaymentStatus == "paid" && d.CanOperateBus(c, t.BusID)
		c.JSON(http.StatusOK, gin.H{"valid": valid, "ticket": t})
	})

	rg.POST("/:id/cancel", d.Auth(), func(c *gin.Context) {
		t, err := Load(d.DB, c.Param("id"))
		if err != nil {
			app.DBError(c, err, "ticket")
			return
		}
		if !canSee(d, c, t) {
			app.Fail(c, http.StatusForbidden, "not your ticket")
			return
		}
		if t.Status != "active" {
			app.Fail(c, http.StatusConflict, "ticket is already "+t.Status)
			return
		}
		if err := Close(d, t.ID, "cancelled"); err != nil {
			app.DBError(c, err, "ticket")
			return
		}
		t, _ = Load(d.DB, t.ID)
		c.JSON(http.StatusOK, t)
	})
}

func canSee(d *app.Deps, c *gin.Context, t *Ticket) bool {
	u := app.User(c)
	return u.Role == app.RoleAdmin || (t.PassengerID != nil && *t.PassengerID == u.UserID) || d.CanOperateBus(c, t.BusID)
}

// Book atomically reserves a seat and creates its ticket.
func Book(d *app.Deps, u *app.Claims, req BookRequest) (*Ticket, error) {
	tx, err := d.DB.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	var routeID sql.NullString
	var approved bool
	var conductorID sql.NullString
	if err := tx.QueryRow(`SELECT route_id, approved, conductor_id FROM buses WHERE id = ?`, req.BusID).Scan(&routeID, &approved, &conductorID); err != nil {
		return nil, err
	}
	if !approved {
		return nil, errors.New("this bus is not approved for ticketing yet")
	}

	// Lock the seat row: concurrent bookings for the same seat serialise here.
	var status string
	if err := tx.QueryRow(`SELECT status FROM seats WHERE bus_id = ? AND seat_number = ? FOR UPDATE`, req.BusID, req.SeatNumber).Scan(&status); err != nil {
		return nil, err
	}
	if status != "available" {
		return nil, ErrSeatTaken
	}

	fare := 0.0
	var fromID, toID interface{}
	if routeID.Valid {
		var standard float64
		var stopCount int
		if err := tx.QueryRow(`SELECT standard_fare, (SELECT COUNT(*) FROM stops WHERE route_id = routes.id) FROM routes WHERE id = ?`, routeID.String).Scan(&standard, &stopCount); err != nil {
			return nil, err
		}
		fromSeq, toSeq := 0, 0
		if req.FromStopID != "" {
			if err := tx.QueryRow(`SELECT stop_sequence FROM stops WHERE id = ? AND route_id = ?`, req.FromStopID, routeID.String).Scan(&fromSeq); err != nil {
				return nil, err
			}
			fromID = req.FromStopID
		}
		if req.ToStopID != "" {
			if err := tx.QueryRow(`SELECT stop_sequence FROM stops WHERE id = ? AND route_id = ?`, req.ToStopID, routeID.String).Scan(&toSeq); err != nil {
				return nil, err
			}
			toID = req.ToStopID
		}
		if fromSeq > 0 && toSeq > 0 && toSeq <= fromSeq {
			return nil, errors.New("destination stop must come after the boarding stop")
		}
		fare = Fare(standard, fromSeq, toSeq, stopCount)
	}

	id := app.NewID("tkt")
	number := ticketNumber()
	var passengerID, conductor interface{}
	name, phone := strings.TrimSpace(req.PassengerName), req.PassengerPhone
	role, method, payStatus := app.RolePassenger, "payhere", "pending"
	if u.Role == app.RolePassenger {
		passengerID = u.UserID
		if name == "" {
			name = u.Name
		}
		if req.PaymentMethod == "cash" {
			return nil, errors.New("in-app tickets are paid with PayHere; cash is for conductor-issued tickets")
		}
	} else {
		role, method, payStatus = app.RoleConductor, "cash", "paid"
		conductor = u.UserID
		if name == "" {
			name = "Walk-in passenger"
		}
	}

	if _, err := tx.Exec(`INSERT INTO tickets (id, ticket_number, bus_id, route_id, seat_number, from_stop_id, to_stop_id, passenger_id,
		passenger_name, passenger_phone, issued_by_role, conductor_id, fare, payment_status, payment_method, status)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, ''), ?, ?, ?, ?, ?, 'active')`,
		id, number, req.BusID, nullStr(routeID), req.SeatNumber, fromID, toID, passengerID, name, phone, role, conductor, fare, payStatus, method); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(`UPDATE seats SET status='taken', booked_by=?, booked_at=NOW(), ticket_id=? WHERE bus_id=? AND seat_number=?`,
		passengerID, id, req.BusID, req.SeatNumber); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}

	d.PublishSeatChange("seat_booked", req.BusID, req.SeatNumber, "taken", gin.H{"ticket_id": id, "issued_by_role": role, "passenger_name": name})
	return Load(d.DB, id)
}

func nullStr(s sql.NullString) interface{} {
	if s.Valid {
		return s.String
	}
	return nil
}

// Close ends a ticket (completed = passenger alighted, cancelled, or expired) and frees its seat.
func Close(d *app.Deps, ticketID, newStatus string) error {
	tx, err := d.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var busID, seat, payStatus, status string
	if err := tx.QueryRow(`SELECT bus_id, seat_number, payment_status, status FROM tickets WHERE id=? FOR UPDATE`, ticketID).Scan(&busID, &seat, &payStatus, &status); err != nil {
		return err
	}
	if status != "active" {
		return nil
	}
	if newStatus == "cancelled" {
		switch payStatus {
		case "paid":
			payStatus = "refunded"
		case "pending":
			payStatus = "failed"
		}
	}
	if _, err := tx.Exec(`UPDATE tickets SET status=?, payment_status=? WHERE id=?`, newStatus, payStatus, ticketID); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE seats SET status='available', booked_by=NULL, booked_at=NULL, ticket_id=NULL WHERE bus_id=? AND seat_number=? AND ticket_id=?`, busID, seat, ticketID); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	d.PublishSeatChange("seat_released", busID, seat, "available", gin.H{"ticket_id": ticketID, "reason": newStatus})
	return nil
}

// ExpirePendingPayments frees seats held by in-app tickets whose payment never completed.
func ExpirePendingPayments(d *app.Deps, olderThan time.Duration) {
	for range time.Tick(time.Minute) {
		rows, err := d.DB.Query(`SELECT id FROM tickets WHERE status='active' AND payment_status='pending' AND issued_at < ?`, time.Now().Add(-olderThan))
		if err != nil {
			continue
		}
		var ids []string
		for rows.Next() {
			var id string
			if rows.Scan(&id) == nil {
				ids = append(ids, id)
			}
		}
		rows.Close()
		for _, id := range ids {
			if err := Close(d, id, "cancelled"); err != nil {
				log.Printf("[Tickets] expire %s: %v", id, err)
			} else {
				log.Printf("[Tickets] released unpaid hold %s", id)
			}
		}
	}
}
