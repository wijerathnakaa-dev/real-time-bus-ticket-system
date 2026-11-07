package routes

import (
	"database/sql"
	"net/http"
	"strings"

	"real-time-bus-backend/internal/app"

	"github.com/gin-gonic/gin"
)

type Stop struct {
	ID        string  `json:"id"`
	RouteID   string  `json:"route_id"`
	Name      string  `json:"stop_name" binding:"required"`
	Sequence  int     `json:"stop_sequence"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type Route struct {
	ID                    string  `json:"id"`
	RouteNumber           string  `json:"route_number" binding:"required"`
	Origin                string  `json:"origin" binding:"required"`
	Destination           string  `json:"destination" binding:"required"`
	StandardFare          float64 `json:"standard_fare"`
	EstimatedDurationMins int     `json:"estimated_duration_mins"`
	Stops                 []Stop  `json:"stops,omitempty"`
	StopCount             int     `json:"stop_count"`
}

func RegisterRoutes(rg *gin.RouterGroup, d *app.Deps) {
	rg.GET("", func(c *gin.Context) {
		rows, err := d.DB.Query(`SELECT r.id, r.route_number, r.origin, r.destination, r.standard_fare, r.estimated_duration_mins,
			(SELECT COUNT(*) FROM stops s WHERE s.route_id = r.id) FROM routes r ORDER BY r.route_number`)
		if err != nil {
			app.DBError(c, err, "routes")
			return
		}
		defer rows.Close()
		out := []Route{}
		for rows.Next() {
			var r Route
			if err := rows.Scan(&r.ID, &r.RouteNumber, &r.Origin, &r.Destination, &r.StandardFare, &r.EstimatedDurationMins, &r.StopCount); err != nil {
				app.DBError(c, err, "routes")
				return
			}
			out = append(out, r)
		}
		c.JSON(http.StatusOK, out)
	})

	rg.GET("/:id", func(c *gin.Context) {
		r, err := Load(d.DB, c.Param("id"))
		if err != nil {
			app.DBError(c, err, "route")
			return
		}
		c.JSON(http.StatusOK, r)
	})

	// Admins create any route; conductors may define their own route (deck: "define at sign-up").
	rg.POST("", d.Auth(app.RoleAdmin, app.RoleConductor), func(c *gin.Context) {
		var r Route
		if err := c.ShouldBindJSON(&r); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		r.ID = app.NewID("route")
		if r.StandardFare <= 0 {
			r.StandardFare = 150
		}
		if r.EstimatedDurationMins <= 0 {
			r.EstimatedDurationMins = 60
		}
		tx, err := d.DB.Begin()
		if err != nil {
			app.DBError(c, err, "route")
			return
		}
		defer tx.Rollback()
		if _, err := tx.Exec(`INSERT INTO routes (id, route_number, origin, destination, standard_fare, estimated_duration_mins, created_by)
			VALUES (?, ?, ?, ?, ?, ?, ?)`, r.ID, strings.TrimSpace(r.RouteNumber), r.Origin, r.Destination, r.StandardFare, r.EstimatedDurationMins, app.User(c).UserID); err != nil {
			app.DBError(c, err, "route")
			return
		}
		if err := replaceStops(tx, r.ID, r.Stops); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		if err := tx.Commit(); err != nil {
			app.DBError(c, err, "route")
			return
		}
		full, _ := Load(d.DB, r.ID)
		c.JSON(http.StatusCreated, full)
	})

	rg.PUT("/:id", d.Auth(app.RoleAdmin, app.RoleConductor), func(c *gin.Context) {
		id := c.Param("id")
		if !canEditRoute(d, c, id) {
			app.Fail(c, http.StatusForbidden, "only an admin or the conductor assigned to a bus on this route can edit it")
			return
		}
		var r Route
		if err := c.ShouldBindJSON(&r); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		tx, err := d.DB.Begin()
		if err != nil {
			app.DBError(c, err, "route")
			return
		}
		defer tx.Rollback()
		res, err := tx.Exec(`UPDATE routes SET route_number=?, origin=?, destination=?, standard_fare=?, estimated_duration_mins=? WHERE id=?`,
			r.RouteNumber, r.Origin, r.Destination, r.StandardFare, r.EstimatedDurationMins, id)
		if err != nil {
			app.DBError(c, err, "route")
			return
		}
		if n, _ := res.RowsAffected(); n == 0 {
			var exists int
			if tx.QueryRow(`SELECT COUNT(*) FROM routes WHERE id=?`, id).Scan(&exists); exists == 0 {
				app.Fail(c, http.StatusNotFound, "route not found")
				return
			}
		}
		if r.Stops != nil {
			if err := replaceStops(tx, id, r.Stops); err != nil {
				app.Fail(c, http.StatusBadRequest, err.Error())
				return
			}
		}
		if err := tx.Commit(); err != nil {
			app.DBError(c, err, "route")
			return
		}
		full, _ := Load(d.DB, id)
		d.Hub.BroadcastJSON(gin.H{"type": "route_updated", "route_id": id})
		c.JSON(http.StatusOK, full)
	})

	rg.DELETE("/:id", d.Auth(app.RoleAdmin), func(c *gin.Context) {
		res, err := d.DB.Exec(`DELETE FROM routes WHERE id=?`, c.Param("id"))
		if err != nil {
			app.DBError(c, err, "route")
			return
		}
		if n, _ := res.RowsAffected(); n == 0 {
			app.Fail(c, http.StatusNotFound, "route not found")
			return
		}
		c.Status(http.StatusNoContent)
	})
}

func canEditRoute(d *app.Deps, c *gin.Context, routeID string) bool {
	u := app.User(c)
	if u.Role == app.RoleAdmin {
		return true
	}
	var n int
	_ = d.DB.QueryRow(`SELECT COUNT(*) FROM buses WHERE route_id=? AND conductor_id=?`, routeID, u.UserID).Scan(&n)
	if n > 0 {
		return true
	}
	var createdBy sql.NullString
	_ = d.DB.QueryRow(`SELECT created_by FROM routes WHERE id=?`, routeID).Scan(&createdBy)
	return createdBy.Valid && createdBy.String == u.UserID
}

func replaceStops(tx *sql.Tx, routeID string, stops []Stop) error {
	if _, err := tx.Exec(`DELETE FROM stops WHERE route_id=?`, routeID); err != nil {
		return err
	}
	for i, s := range stops {
		if strings.TrimSpace(s.Name) == "" {
			return errBadStop
		}
		if _, err := tx.Exec(`INSERT INTO stops (id, route_id, stop_name, stop_sequence, latitude, longitude) VALUES (?, ?, ?, ?, ?, ?)`,
			app.NewID("stop"), routeID, s.Name, i+1, s.Latitude, s.Longitude); err != nil {
			return err
		}
	}
	return nil
}

var errBadStop = &stopError{"every stop needs a stop_name"}

type stopError struct{ s string }

func (e *stopError) Error() string { return e.s }

// Load returns a route with its ordered stops.
func Load(db *sql.DB, id string) (*Route, error) {
	var r Route
	if err := db.QueryRow(`SELECT id, route_number, origin, destination, standard_fare, estimated_duration_mins FROM routes WHERE id=?`, id).
		Scan(&r.ID, &r.RouteNumber, &r.Origin, &r.Destination, &r.StandardFare, &r.EstimatedDurationMins); err != nil {
		return nil, err
	}
	stops, err := LoadStops(db, id)
	if err != nil {
		return nil, err
	}
	r.Stops, r.StopCount = stops, len(stops)
	return &r, nil
}

func LoadStops(db *sql.DB, routeID string) ([]Stop, error) {
	rows, err := db.Query(`SELECT id, route_id, stop_name, stop_sequence, latitude, longitude FROM stops WHERE route_id=? ORDER BY stop_sequence`, routeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Stop{}
	for rows.Next() {
		var s Stop
		if err := rows.Scan(&s.ID, &s.RouteID, &s.Name, &s.Sequence, &s.Latitude, &s.Longitude); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}
