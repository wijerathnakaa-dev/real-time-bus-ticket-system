package buses

import (
	"database/sql"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"real-time-bus-backend/internal/app"

	"github.com/gin-gonic/gin"
	"github.com/go-sql-driver/mysql"
)

type Bus struct {
	ID             string     `json:"id"`
	PlateNumber    string     `json:"plate_number"`
	RouteID        *string    `json:"route_id"`
	RouteNumber    *string    `json:"route_number"`
	RouteName      *string    `json:"route_name"`
	StandardFare   *float64   `json:"standard_fare"`
	ConductorID    *string    `json:"conductor_id"`
	ConductorName  *string    `json:"conductor_name"`
	TotalSeats     int        `json:"total_seats"`
	AvailableSeats int        `json:"available_seats"`
	PhotoURL       *string    `json:"photo_url"`
	Approved       bool       `json:"approved"`
	Status         string     `json:"status"`
	Latitude       *float64   `json:"latitude"`
	Longitude      *float64   `json:"longitude"`
	SpeedKmh       *float64   `json:"speed_kmh"`
	LocationAt     *time.Time `json:"location_updated_at"`
}

const selectBus = `SELECT b.id, b.plate_number, b.route_id, r.route_number, CONCAT(r.origin, ' - ', r.destination), r.standard_fare,
	b.conductor_id, u.name, b.total_seats,
	(SELECT COUNT(*) FROM seats s WHERE s.bus_id = b.id AND s.status = 'available'),
	b.photo_url, b.approved, b.status, l.latitude, l.longitude, l.speed_kmh, l.updated_at
	FROM buses b
	LEFT JOIN routes r ON r.id = b.route_id
	LEFT JOIN users u ON u.id = b.conductor_id
	LEFT JOIN bus_locations l ON l.bus_id = b.id`

func scanBus(s interface{ Scan(...interface{}) error }) (*Bus, error) {
	var b Bus
	err := s.Scan(&b.ID, &b.PlateNumber, &b.RouteID, &b.RouteNumber, &b.RouteName, &b.StandardFare, &b.ConductorID, &b.ConductorName,
		&b.TotalSeats, &b.AvailableSeats, &b.PhotoURL, &b.Approved, &b.Status, &b.Latitude, &b.Longitude, &b.SpeedKmh, &b.LocationAt)
	return &b, err
}

func Load(db *sql.DB, id string) (*Bus, error) {
	return scanBus(db.QueryRow(selectBus+` WHERE b.id = ?`, id))
}

type BusRequest struct {
	PlateNumber string  `json:"plate_number"`
	RouteID     *string `json:"route_id"`
	TotalSeats  int     `json:"total_seats"`
	PhotoURL    *string `json:"photo_url"`
	Status      string  `json:"status"`
}

func NormalizePlate(p string) string {
	p = strings.ToUpper(strings.TrimSpace(p))
	p = strings.NewReplacer(" ", "-", "--", "-").Replace(p)
	return p
}

func RegisterRoutes(rg *gin.RouterGroup, d *app.Deps) {
	// Public list: approved buses only. ?route_id=, ?plate= (partial), ?all=1 (admin: include unapproved).
	rg.GET("", func(c *gin.Context) {
		where, args := []string{"1=1"}, []interface{}{}
		if c.Query("all") != "1" {
			where = append(where, "b.approved = TRUE")
		}
		if v := c.Query("route_id"); v != "" {
			where = append(where, "b.route_id = ?")
			args = append(args, v)
		}
		if v := c.Query("plate"); v != "" {
			where = append(where, "REPLACE(b.plate_number, '-', '') LIKE ?")
			args = append(args, "%"+strings.ReplaceAll(NormalizePlate(v), "-", "")+"%")
		}
		if v := c.Query("status"); v != "" {
			where = append(where, "b.status = ?")
			args = append(args, v)
		}
		rows, err := d.DB.Query(selectBus+" WHERE "+strings.Join(where, " AND ")+" ORDER BY b.plate_number", args...)
		if err != nil {
			app.DBError(c, err, "buses")
			return
		}
		defer rows.Close()
		out := []*Bus{}
		for rows.Next() {
			b, err := scanBus(rows)
			if err != nil {
				app.DBError(c, err, "buses")
				return
			}
			out = append(out, b)
		}
		c.JSON(http.StatusOK, out)
	})

	// The conductor's assigned bus.
	rg.GET("/mine", d.Auth(app.RoleConductor), func(c *gin.Context) {
		b, err := scanBus(d.DB.QueryRow(selectBus+` WHERE b.conductor_id = ? ORDER BY b.updated_at DESC LIMIT 1`, app.User(c).UserID))
		if err != nil {
			app.DBError(c, err, "assigned bus")
			return
		}
		c.JSON(http.StatusOK, b)
	})

	rg.GET("/:id", func(c *gin.Context) {
		b, err := Load(d.DB, c.Param("id"))
		if err != nil {
			app.DBError(c, err, "bus")
			return
		}
		c.JSON(http.StatusOK, b)
	})

	rg.GET("/:id/seats", func(c *gin.Context) {
		seats, err := d.SeatMap(d.DB, c.Param("id"))
		if err != nil {
			app.DBError(c, err, "seats")
			return
		}
		c.JSON(http.StatusOK, seats)
	})

	// Conductor sets up their bus profile (pending admin approval); admin may register any bus.
	rg.POST("", d.Auth(app.RoleConductor, app.RoleAdmin), func(c *gin.Context) {
		var req BusRequest
		if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.PlateNumber) == "" {
			app.Fail(c, http.StatusBadRequest, "plate_number is required")
			return
		}
		if req.TotalSeats <= 0 || req.TotalSeats > 80 {
			req.TotalSeats = 40
		}
		u := app.User(c)
		id := app.NewID("bus")
		var conductor interface{}
		approved := u.Role == app.RoleAdmin
		if u.Role == app.RoleConductor {
			conductor = u.UserID
		}
		tx, err := d.DB.Begin()
		if err != nil {
			app.DBError(c, err, "bus")
			return
		}
		defer tx.Rollback()
		_, err = tx.Exec(`INSERT INTO buses (id, plate_number, route_id, conductor_id, total_seats, photo_url, approved, status) VALUES (?, ?, ?, ?, ?, ?, ?, 'idle')`,
			id, NormalizePlate(req.PlateNumber), req.RouteID, conductor, req.TotalSeats, req.PhotoURL, approved)
		if err != nil {
			if me, ok := err.(*mysql.MySQLError); ok && me.Number == 1062 {
				app.Fail(c, http.StatusConflict, "a bus with this number plate is already registered")
				return
			}
			app.DBError(c, err, "bus")
			return
		}
		if err := SyncSeats(tx, id, req.TotalSeats); err != nil {
			app.DBError(c, err, "seats")
			return
		}
		if conductor != nil {
			if _, err := tx.Exec(`UPDATE users SET assigned_bus_id=? WHERE id=?`, id, conductor); err != nil {
				app.DBError(c, err, "user")
				return
			}
		}
		if err := tx.Commit(); err != nil {
			app.DBError(c, err, "bus")
			return
		}
		b, _ := Load(d.DB, id)
		d.Hub.BroadcastJSON(gin.H{"type": "bus_registered", "bus_id": id})
		c.JSON(http.StatusCreated, b)
	})

	rg.PUT("/:id", d.Auth(app.RoleConductor, app.RoleAdmin), func(c *gin.Context) {
		id := c.Param("id")
		if !d.CanOperateBus(c, id) {
			app.Fail(c, http.StatusForbidden, "only the assigned conductor or an admin can edit this bus")
			return
		}
		var req BusRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		cur, err := Load(d.DB, id)
		if err != nil {
			app.DBError(c, err, "bus")
			return
		}
		if req.PlateNumber == "" {
			req.PlateNumber = cur.PlateNumber
		}
		if req.TotalSeats <= 0 {
			req.TotalSeats = cur.TotalSeats
		}
		if req.RouteID == nil {
			req.RouteID = cur.RouteID
		}
		if req.PhotoURL == nil {
			req.PhotoURL = cur.PhotoURL
		}
		if req.Status == "" {
			req.Status = cur.Status
		}
		tx, err := d.DB.Begin()
		if err != nil {
			app.DBError(c, err, "bus")
			return
		}
		defer tx.Rollback()
		if _, err := tx.Exec(`UPDATE buses SET plate_number=?, route_id=?, total_seats=?, photo_url=?, status=? WHERE id=?`,
			NormalizePlate(req.PlateNumber), req.RouteID, req.TotalSeats, req.PhotoURL, req.Status, id); err != nil {
			app.DBError(c, err, "bus")
			return
		}
		if err := SyncSeats(tx, id, req.TotalSeats); err != nil {
			app.Fail(c, http.StatusConflict, err.Error())
			return
		}
		if err := tx.Commit(); err != nil {
			app.DBError(c, err, "bus")
			return
		}
		b, _ := Load(d.DB, id)
		d.Hub.BroadcastBus(id, gin.H{"type": "bus_updated", "bus_id": id})
		c.JSON(http.StatusOK, b)
	})

	// Bus photo upload (stored locally under ./uploads; Firebase Storage URLs can also be set via PUT photo_url).
	rg.POST("/:id/photo", d.Auth(app.RoleConductor, app.RoleAdmin), func(c *gin.Context) {
		id := c.Param("id")
		if !d.CanOperateBus(c, id) {
			app.Fail(c, http.StatusForbidden, "not your bus")
			return
		}
		file, err := c.FormFile("photo")
		if err != nil {
			app.Fail(c, http.StatusBadRequest, "multipart field 'photo' is required")
			return
		}
		ext := strings.ToLower(filepath.Ext(file.Filename))
		if ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".webp" {
			app.Fail(c, http.StatusBadRequest, "photo must be jpg, png or webp")
			return
		}
		_ = os.MkdirAll("uploads", 0o755)
		name := fmt.Sprintf("%s_%d%s", id, time.Now().Unix(), ext)
		if err := c.SaveUploadedFile(file, filepath.Join("uploads", name)); err != nil {
			app.Fail(c, http.StatusInternalServerError, err.Error())
			return
		}
		url := d.Cfg.PublicBaseURL + "/uploads/" + name
		if _, err := d.DB.Exec(`UPDATE buses SET photo_url=? WHERE id=?`, url, id); err != nil {
			app.DBError(c, err, "bus")
			return
		}
		c.JSON(http.StatusOK, gin.H{"photo_url": url})
	})

	rg.POST("/:id/approve", d.Auth(app.RoleAdmin), func(c *gin.Context) {
		var req struct {
			Approved bool `json:"approved"`
		}
		_ = c.ShouldBindJSON(&req)
		res, err := d.DB.Exec(`UPDATE buses SET approved=? WHERE id=?`, req.Approved, c.Param("id"))
		if err != nil {
			app.DBError(c, err, "bus")
			return
		}
		if n, _ := res.RowsAffected(); n == 0 {
			if _, err := Load(d.DB, c.Param("id")); err != nil {
				app.DBError(c, err, "bus")
				return
			}
		}
		b, _ := Load(d.DB, c.Param("id"))
		d.Hub.BroadcastJSON(gin.H{"type": "bus_updated", "bus_id": c.Param("id")})
		c.JSON(http.StatusOK, b)
	})

	// Admin assigns (or reassigns) conductor and/or route.
	rg.POST("/:id/assign", d.Auth(app.RoleAdmin), func(c *gin.Context) {
		var req struct {
			ConductorID *string `json:"conductor_id"`
			RouteID     *string `json:"route_id"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		id := c.Param("id")
		tx, err := d.DB.Begin()
		if err != nil {
			app.DBError(c, err, "bus")
			return
		}
		defer tx.Rollback()
		if req.ConductorID != nil {
			var role string
			if err := tx.QueryRow(`SELECT role FROM users WHERE id=?`, *req.ConductorID).Scan(&role); err != nil {
				app.DBError(c, err, "conductor")
				return
			}
			if role != app.RoleConductor {
				app.Fail(c, http.StatusBadRequest, "user is not a conductor")
				return
			}
			if _, err := tx.Exec(`UPDATE users SET assigned_bus_id=NULL WHERE assigned_bus_id=?`, id); err != nil {
				app.DBError(c, err, "user")
				return
			}
			if _, err := tx.Exec(`UPDATE buses SET conductor_id=NULL WHERE conductor_id=? AND id<>?`, *req.ConductorID, id); err != nil {
				app.DBError(c, err, "bus")
				return
			}
			if _, err := tx.Exec(`UPDATE buses SET conductor_id=? WHERE id=?`, *req.ConductorID, id); err != nil {
				app.DBError(c, err, "bus")
				return
			}
			if _, err := tx.Exec(`UPDATE users SET assigned_bus_id=? WHERE id=?`, id, *req.ConductorID); err != nil {
				app.DBError(c, err, "user")
				return
			}
		}
		if req.RouteID != nil {
			if _, err := tx.Exec(`UPDATE buses SET route_id=? WHERE id=?`, *req.RouteID, id); err != nil {
				app.DBError(c, err, "bus")
				return
			}
		}
		if err := tx.Commit(); err != nil {
			app.DBError(c, err, "bus")
			return
		}
		b, err := Load(d.DB, id)
		if err != nil {
			app.DBError(c, err, "bus")
			return
		}
		d.Hub.BroadcastBus(id, gin.H{"type": "bus_updated", "bus_id": id})
		c.JSON(http.StatusOK, b)
	})
}

// SyncSeats makes seats 1..total exist for the bus; it refuses to remove booked seats.
func SyncSeats(tx *sql.Tx, busID string, total int) error {
	for i := 1; i <= total; i++ {
		if _, err := tx.Exec(`INSERT IGNORE INTO seats (bus_id, seat_number) VALUES (?, ?)`, busID, fmt.Sprintf("%d", i)); err != nil {
			return err
		}
	}
	var taken int
	_ = tx.QueryRow(`SELECT COUNT(*) FROM seats WHERE bus_id=? AND CAST(seat_number AS UNSIGNED) > ? AND status='taken'`, busID, total).Scan(&taken)
	if taken > 0 {
		return fmt.Errorf("cannot reduce seats below %d: %d higher-numbered seats are booked", total, taken)
	}
	_, err := tx.Exec(`DELETE FROM seats WHERE bus_id=? AND CAST(seat_number AS UNSIGNED) > ?`, busID, total)
	return err
}
