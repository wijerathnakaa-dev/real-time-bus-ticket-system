// Package app holds what every API module shares: dependencies, JWT auth and
// role middleware, error helpers, and the live seat-map publisher.
package app

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"net/http"
	"strings"
	"time"

	"real-time-bus-backend/internal/config"
	"real-time-bus-backend/internal/realtime"
	"real-time-bus-backend/internal/sockets"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

const (
	RolePassenger = "passenger"
	RoleConductor = "conductor"
	RoleAdmin     = "admin"
)

type Deps struct {
	DB  *sql.DB
	Hub *sockets.Hub
	Cfg *config.Config
	RT  *realtime.Firebase // nil when Firebase is not configured
}

// ---------- IDs and responses ----------

func NewID(prefix string) string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return prefix + "_" + hex.EncodeToString(b)
}

func Fail(c *gin.Context, status int, msg string) {
	c.AbortWithStatusJSON(status, gin.H{"error": msg})
}

// DBError maps sql.ErrNoRows to 404 and everything else to 500.
func DBError(c *gin.Context, err error, what string) {
	if errors.Is(err, sql.ErrNoRows) {
		Fail(c, http.StatusNotFound, what+" not found")
		return
	}
	Fail(c, http.StatusInternalServerError, err.Error())
}

// ---------- JWT ----------

type Claims struct {
	UserID string `json:"uid"`
	Name   string `json:"name"`
	Role   string `json:"role"`
	jwt.RegisteredClaims
}

func (d *Deps) IssueToken(id, name, role string) (string, error) {
	claims := Claims{
		UserID: id, Name: name, Role: role,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   id,
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(7 * 24 * time.Hour)),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(d.Cfg.JWTSecret))
}

func (d *Deps) parseToken(raw string) (*Claims, error) {
	claims := &Claims{}
	_, err := jwt.ParseWithClaims(raw, claims, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return []byte(d.Cfg.JWTSecret), nil
	})
	return claims, err
}

// Auth requires a valid bearer token; with roles given, the user must hold one of them.
func (d *Deps) Auth(roles ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		raw := strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer ")
		if raw == "" {
			Fail(c, http.StatusUnauthorized, "missing bearer token")
			return
		}
		claims, err := d.parseToken(raw)
		if err != nil {
			Fail(c, http.StatusUnauthorized, "invalid or expired token")
			return
		}
		if len(roles) > 0 {
			ok := false
			for _, r := range roles {
				ok = ok || r == claims.Role
			}
			if !ok {
				Fail(c, http.StatusForbidden, "requires role: "+strings.Join(roles, " or "))
				return
			}
		}
		c.Set("user", claims)
		c.Next()
	}
}

func User(c *gin.Context) *Claims {
	if v, ok := c.Get("user"); ok {
		return v.(*Claims)
	}
	return &Claims{}
}

// CanOperateBus: admins always; conductors only for the bus assigned to them.
func (d *Deps) CanOperateBus(c *gin.Context, busID string) bool {
	u := User(c)
	if u.Role == RoleAdmin {
		return true
	}
	if u.Role != RoleConductor {
		return false
	}
	var conductor sql.NullString
	if err := d.DB.QueryRow(`SELECT conductor_id FROM buses WHERE id = ?`, busID).Scan(&conductor); err != nil {
		return false
	}
	return conductor.Valid && conductor.String == u.UserID
}

// ---------- Live seat map ----------

type Seat struct {
	SeatNumber string     `json:"seat_number"`
	Status     string     `json:"status"`
	BookedBy   *string    `json:"booked_by,omitempty"`
	TicketID   *string    `json:"ticket_id,omitempty"`
	BookedAt   *time.Time `json:"booked_at,omitempty"`
}

func (d *Deps) SeatMap(q interface {
	Query(string, ...interface{}) (*sql.Rows, error)
}, busID string) ([]Seat, error) {
	rows, err := q.Query(`SELECT seat_number, status, booked_by, ticket_id, booked_at FROM seats
		WHERE bus_id = ? ORDER BY CAST(seat_number AS UNSIGNED), seat_number`, busID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	seats := []Seat{}
	for rows.Next() {
		var s Seat
		var by, tid sql.NullString
		var at sql.NullTime
		if err := rows.Scan(&s.SeatNumber, &s.Status, &by, &tid, &at); err != nil {
			return nil, err
		}
		if by.Valid {
			s.BookedBy = &by.String
		}
		if tid.Valid {
			s.TicketID = &tid.String
		}
		if at.Valid {
			s.BookedAt = &at.Time
		}
		seats = append(seats, s)
	}
	return seats, rows.Err()
}

// PublishSeatChange pushes one seat change over WebSocket and mirrors the bus's
// whole seat map to Firebase RTDB. Call it only after the DB transaction commits.
func (d *Deps) PublishSeatChange(event, busID, seatNumber, status string, extra gin.H) {
	msg := gin.H{"type": event, "bus_id": busID, "seat_number": seatNumber, "status": status, "at": time.Now()}
	for k, v := range extra {
		msg[k] = v
	}
	d.Hub.BroadcastBus(busID, msg)

	if d.RT != nil {
		if seats, err := d.SeatMap(d.DB, busID); err == nil {
			free := 0
			m := map[string]string{}
			for _, s := range seats {
				m[s.SeatNumber] = s.Status
				if s.Status == "available" {
					free++
				}
			}
			d.RT.Set("buses/"+busID+"/seats", m)
			d.RT.Set("buses/"+busID+"/available_seats", free)
		}
	}
}
