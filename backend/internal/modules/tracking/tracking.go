// Package tracking handles GPS telemetry, the per-stop ETA engine, stop
// arrival/departure events, trip start/end, and "bus approaching" notifications.
package tracking

import (
	"database/sql"
	"fmt"
	"math"
	"net/http"
	"sync"
	"time"

	"real-time-bus-backend/internal/app"
	"real-time-bus-backend/internal/modules/routes"
	"real-time-bus-backend/internal/modules/tickets"

	"github.com/gin-gonic/gin"
)

const (
	arrivalRadiusKm   = 0.15 // within 150 m of a stop counts as arrived
	notifyWithinMins  = 5.0  // push "approaching" when ETA drops to 5 minutes
	defaultSpeedKmh   = 45.0 // expressway average when the bus is stationary
	minMovingSpeedKmh = 5.0
)

type LocationRequest struct {
	Latitude  float64 `json:"latitude" binding:"required"`
	Longitude float64 `json:"longitude" binding:"required"`
	Accuracy  float64 `json:"accuracy"`
	SpeedKmh  float64 `json:"speed_kmh"`
}

type StopETA struct {
	StopID          string     `json:"stop_id"`
	StopName        string     `json:"stop_name"`
	Sequence        int        `json:"stop_sequence"`
	Latitude        float64    `json:"latitude"`
	Longitude       float64    `json:"longitude"`
	State           string     `json:"state"` // departed | arrived | upcoming
	DistanceKm      *float64   `json:"distance_km,omitempty"`
	ETAMinutes      *float64   `json:"eta_minutes,omitempty"`
	ETAAt           *time.Time `json:"eta_at,omitempty"`
	ActualArrival   *time.Time `json:"actual_arrival,omitempty"`
	ActualDeparture *time.Time `json:"actual_departure,omitempty"`
}

type ETAResponse struct {
	BusID       string     `json:"bus_id"`
	Status      string     `json:"status"`
	TripStarted *time.Time `json:"trip_started_at"`
	Latitude    *float64   `json:"latitude"`
	Longitude   *float64   `json:"longitude"`
	SpeedKmh    float64    `json:"speed_kmh"`
	UpdatedAt   *time.Time `json:"location_updated_at"`
	NextStopID  *string    `json:"next_stop_id"`
	Stops       []StopETA  `json:"stops"`
}

var (
	notifiedMu sync.Mutex
	notified   = map[string]bool{} // busID|tripStart|stopID
)

func RegisterRoutes(buses *gin.RouterGroup, d *app.Deps) {
	buses.POST("/:id/location", d.Auth(app.RoleConductor, app.RoleAdmin), func(c *gin.Context) {
		busID := c.Param("id")
		if !d.CanOperateBus(c, busID) {
			app.Fail(c, http.StatusForbidden, "only the assigned conductor can broadcast this bus's GPS")
			return
		}
		var req LocationRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		if math.Abs(req.Latitude) > 90 || math.Abs(req.Longitude) > 180 {
			app.Fail(c, http.StatusBadRequest, "invalid coordinates")
			return
		}
		if _, err := d.DB.Exec(`INSERT INTO bus_locations (bus_id, latitude, longitude, accuracy, speed_kmh) VALUES (?, ?, ?, ?, ?)
			ON DUPLICATE KEY UPDATE latitude=VALUES(latitude), longitude=VALUES(longitude), accuracy=VALUES(accuracy), speed_kmh=VALUES(speed_kmh), updated_at=NOW()`,
			busID, req.Latitude, req.Longitude, req.Accuracy, req.SpeedKmh); err != nil {
			app.DBError(c, err, "location")
			return
		}
		eta, err := ComputeETA(d.DB, busID)
		if err != nil {
			app.DBError(c, err, "bus")
			return
		}
		autoArrive(d, eta)
		eta, _ = ComputeETA(d.DB, busID)
		msg := gin.H{"type": "bus_location", "bus_id": busID, "latitude": req.Latitude, "longitude": req.Longitude,
			"speed_kmh": req.SpeedKmh, "next_stop_id": eta.NextStopID, "stops": eta.Stops, "at": time.Now()}
		d.Hub.BroadcastBus(busID, msg)
		if d.RT != nil {
			d.RT.Set("buses/"+busID+"/location", gin.H{"latitude": req.Latitude, "longitude": req.Longitude, "speed_kmh": req.SpeedKmh, "updated_at": time.Now().Unix()})
			d.RT.Set("buses/"+busID+"/eta", eta.Stops)
		}
		notifyApproaching(d, eta)
		c.JSON(http.StatusOK, eta)
	})

	buses.GET("/:id/eta", func(c *gin.Context) {
		eta, err := ComputeETA(d.DB, c.Param("id"))
		if err != nil {
			app.DBError(c, err, "bus")
			return
		}
		c.JSON(http.StatusOK, eta)
	})

	// Conductor confirms actual arrival/departure at a stop.
	buses.POST("/:id/stop-events", d.Auth(app.RoleConductor, app.RoleAdmin), func(c *gin.Context) {
		busID := c.Param("id")
		if !d.CanOperateBus(c, busID) {
			app.Fail(c, http.StatusForbidden, "not your bus")
			return
		}
		var req struct {
			StopID    string `json:"stop_id" binding:"required"`
			EventType string `json:"event_type" binding:"required,oneof=arrival departure"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		// Idempotent per trip: a repeated tap (or retry after network loss) does not duplicate history.
		var dup int
		_ = d.DB.QueryRow(`SELECT COUNT(*) FROM stop_events e JOIN buses b ON b.id = e.bus_id
			WHERE e.bus_id=? AND e.stop_id=? AND e.event_type=? AND e.occurred_at >= COALESCE(b.trip_started_at, NOW() - INTERVAL 12 HOUR)`,
			busID, req.StopID, req.EventType).Scan(&dup)
		if dup == 0 {
			if _, err := d.DB.Exec(`INSERT INTO stop_events (bus_id, stop_id, event_type, confirmed_by) VALUES (?, ?, ?, ?)`,
				busID, req.StopID, req.EventType, app.User(c).UserID); err != nil {
				app.DBError(c, err, "stop event")
				return
			}
		}
		eta, _ := ComputeETA(d.DB, busID)
		d.Hub.BroadcastBus(busID, gin.H{"type": "stop_" + req.EventType, "bus_id": busID, "stop_id": req.StopID, "stops": eta.Stops, "at": time.Now()})
		if d.RT != nil {
			d.RT.Set("buses/"+busID+"/eta", eta.Stops)
		}
		c.JSON(http.StatusCreated, eta)
	})

	buses.GET("/:id/stop-events", func(c *gin.Context) {
		rows, err := d.DB.Query(`SELECT e.id, e.stop_id, s.stop_name, e.event_type, e.confirmed_by, u.name, e.occurred_at
			FROM stop_events e JOIN stops s ON s.id = e.stop_id LEFT JOIN users u ON u.id = e.confirmed_by
			WHERE e.bus_id = ? ORDER BY e.occurred_at DESC, e.id DESC LIMIT 200`, c.Param("id"))
		if err != nil {
			app.DBError(c, err, "stop events")
			return
		}
		defer rows.Close()
		out := []gin.H{}
		for rows.Next() {
			var id int64
			var stopID, stopName, typ string
			var by, byName sql.NullString
			var at time.Time
			if err := rows.Scan(&id, &stopID, &stopName, &typ, &by, &byName, &at); err != nil {
				app.DBError(c, err, "stop events")
				return
			}
			out = append(out, gin.H{"id": id, "stop_id": stopID, "stop_name": stopName, "event_type": typ,
				"confirmed_by": by.String, "confirmed_by_name": byName.String, "automatic": !by.Valid, "occurred_at": at})
		}
		c.JSON(http.StatusOK, out)
	})

	// Trip start/end. Ending a trip completes every active ticket and frees all seats.
	buses.POST("/:id/trip", d.Auth(app.RoleConductor, app.RoleAdmin), func(c *gin.Context) {
		busID := c.Param("id")
		if !d.CanOperateBus(c, busID) {
			app.Fail(c, http.StatusForbidden, "not your bus")
			return
		}
		var req struct {
			Action string `json:"action" binding:"required,oneof=start end"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		if req.Action == "start" {
			if _, err := d.DB.Exec(`UPDATE buses SET status='on_trip', trip_started_at=NOW() WHERE id=?`, busID); err != nil {
				app.DBError(c, err, "bus")
				return
			}
		} else {
			rows, err := d.DB.Query(`SELECT id, payment_status FROM tickets WHERE bus_id=? AND status='active'`, busID)
			if err != nil {
				app.DBError(c, err, "tickets")
				return
			}
			type open struct{ id, pay string }
			var list []open
			for rows.Next() {
				var o open
				if rows.Scan(&o.id, &o.pay) == nil {
					list = append(list, o)
				}
			}
			rows.Close()
			for _, o := range list {
				status := "completed"
				if o.pay == "pending" {
					status = "cancelled"
				}
				if err := tickets.Close(d, o.id, status); err != nil {
					app.DBError(c, err, "ticket")
					return
				}
			}
			if _, err := d.DB.Exec(`UPDATE buses SET status='idle', trip_started_at=NULL WHERE id=?`, busID); err != nil {
				app.DBError(c, err, "bus")
				return
			}
			if _, err := d.DB.Exec(`UPDATE seats SET status='available', booked_by=NULL, booked_at=NULL, ticket_id=NULL WHERE bus_id=?`, busID); err != nil {
				app.DBError(c, err, "seats")
				return
			}
		}
		eta, _ := ComputeETA(d.DB, busID)
		d.Hub.BroadcastBus(busID, gin.H{"type": "trip_" + req.Action, "bus_id": busID, "at": time.Now()})
		c.JSON(http.StatusOK, eta)
	})
}

// ComputeETA builds the per-stop timeline for a bus from its latest GPS fix and this trip's stop events.
func ComputeETA(db *sql.DB, busID string) (*ETAResponse, error) {
	resp := &ETAResponse{BusID: busID, Stops: []StopETA{}}
	var routeID sql.NullString
	var started sql.NullTime
	var est int
	if err := db.QueryRow(`SELECT b.route_id, b.status, b.trip_started_at, COALESCE(r.estimated_duration_mins, 60)
		FROM buses b LEFT JOIN routes r ON r.id = b.route_id WHERE b.id = ?`, busID).Scan(&routeID, &resp.Status, &started, &est); err != nil {
		return nil, err
	}
	if started.Valid {
		resp.TripStarted = &started.Time
	}
	var lat, lng, speed sql.NullFloat64
	var at sql.NullTime
	_ = db.QueryRow(`SELECT latitude, longitude, speed_kmh, updated_at FROM bus_locations WHERE bus_id=?`, busID).Scan(&lat, &lng, &speed, &at)
	if lat.Valid {
		resp.Latitude, resp.Longitude = &lat.Float64, &lng.Float64
	}
	if at.Valid {
		resp.UpdatedAt = &at.Time
	}
	resp.SpeedKmh = speed.Float64
	if !routeID.Valid {
		return resp, nil
	}
	stops, err := routes.LoadStops(db, routeID.String)
	if err != nil || len(stops) == 0 {
		return resp, err
	}

	// This trip's actual arrivals/departures.
	since := time.Now().Add(-12 * time.Hour)
	if started.Valid {
		since = started.Time
	}
	arrivals, departures := map[string]time.Time{}, map[string]time.Time{}
	rows, err := db.Query(`SELECT stop_id, event_type, occurred_at FROM stop_events WHERE bus_id=? AND occurred_at >= ? ORDER BY occurred_at`, busID, since)
	if err == nil {
		for rows.Next() {
			var sid, typ string
			var t time.Time
			if rows.Scan(&sid, &typ, &t) == nil {
				if typ == "arrival" {
					arrivals[sid] = t
				} else {
					departures[sid] = t
				}
			}
		}
		rows.Close()
	}

	// Next stop: the first stop after the furthest one we've departed from.
	lastDeparted := -1
	for i, s := range stops {
		if _, ok := departures[s.ID]; ok {
			lastDeparted = i
		}
	}
	next := lastDeparted + 1
	if lastDeparted < 0 && lat.Valid {
		// No departures yet this trip: start from the closest stop.
		best := math.MaxFloat64
		for i, s := range stops {
			if dkm := Haversine(lat.Float64, lng.Float64, s.Latitude, s.Longitude); dkm < best {
				best, next = dkm, i
			}
		}
	}

	speedKmh := speed.Float64
	if speedKmh < minMovingSpeedKmh {
		speedKmh = routeSpeed(stops, est)
	}

	cum := 0.0
	for i, s := range stops {
		e := StopETA{StopID: s.ID, StopName: s.Name, Sequence: s.Sequence, Latitude: s.Latitude, Longitude: s.Longitude, State: "upcoming"}
		if t, ok := arrivals[s.ID]; ok {
			t := t
			e.ActualArrival = &t
		}
		if t, ok := departures[s.ID]; ok {
			t := t
			e.ActualDeparture = &t
		}
		switch {
		case i <= lastDeparted || (i < next):
			e.State = "departed"
		case e.ActualArrival != nil:
			e.State = "arrived"
		}
		if i >= next && lat.Valid && resp.Status == "on_trip" {
			if i == next {
				cum = Haversine(lat.Float64, lng.Float64, s.Latitude, s.Longitude)
			} else {
				p := stops[i-1]
				cum += Haversine(p.Latitude, p.Longitude, s.Latitude, s.Longitude)
			}
			dist := round1(cum)
			mins := round1(cum / speedKmh * 60)
			when := time.Now().Add(time.Duration(mins * float64(time.Minute)))
			e.DistanceKm, e.ETAMinutes, e.ETAAt = &dist, &mins, &when
			if i == next {
				id := s.ID
				resp.NextStopID = &id
			}
		}
		resp.Stops = append(resp.Stops, e)
	}
	return resp, nil
}

func routeSpeed(stops []routes.Stop, estMins int) float64 {
	total := 0.0
	for i := 1; i < len(stops); i++ {
		total += Haversine(stops[i-1].Latitude, stops[i-1].Longitude, stops[i].Latitude, stops[i].Longitude)
	}
	if estMins <= 0 || total <= 0 {
		return defaultSpeedKmh
	}
	return math.Max(total/(float64(estMins)/60), 15)
}

func autoArrive(d *app.Deps, eta *ETAResponse) {
	if eta.NextStopID == nil || eta.Status != "on_trip" {
		return
	}
	for _, s := range eta.Stops {
		if s.StopID == *eta.NextStopID && s.ActualArrival == nil && s.DistanceKm != nil && *s.DistanceKm <= arrivalRadiusKm {
			if _, err := d.DB.Exec(`INSERT INTO stop_events (bus_id, stop_id, event_type) VALUES (?, ?, 'arrival')`, eta.BusID, s.StopID); err == nil {
				d.Hub.BroadcastBus(eta.BusID, gin.H{"type": "stop_arrival", "bus_id": eta.BusID, "stop_id": s.StopID, "automatic": true, "at": time.Now()})
			}
		}
	}
}

func notifyApproaching(d *app.Deps, eta *ETAResponse) {
	if eta.TripStarted == nil {
		return
	}
	var plate string
	_ = d.DB.QueryRow(`SELECT plate_number FROM buses WHERE id=?`, eta.BusID).Scan(&plate)
	for _, s := range eta.Stops {
		if s.ETAMinutes == nil || s.State != "upcoming" || *s.ETAMinutes > notifyWithinMins {
			continue
		}
		key := fmt.Sprintf("%s|%d|%s", eta.BusID, eta.TripStarted.Unix(), s.StopID)
		notifiedMu.Lock()
		done := notified[key]
		notified[key] = true
		notifiedMu.Unlock()
		if done {
			continue
		}
		title := fmt.Sprintf("Bus %s is almost at %s", plate, s.StopName)
		body := fmt.Sprintf("Arriving in about %.0f min", math.Max(1, *s.ETAMinutes))
		d.Hub.BroadcastBus(eta.BusID, gin.H{"type": "bus_approaching", "bus_id": eta.BusID, "stop_id": s.StopID, "stop_name": s.StopName, "eta_minutes": s.ETAMinutes, "title": title, "body": body})
		if d.RT != nil {
			d.RT.NotifyTopic("bus_"+eta.BusID, title, body, map[string]string{"bus_id": eta.BusID, "stop_id": s.StopID})
		}
	}
}

// Haversine returns the great-circle distance in km.
func Haversine(lat1, lon1, lat2, lon2 float64) float64 {
	const r = 6371.0
	dLat := (lat2 - lat1) * math.Pi / 180
	dLon := (lon2 - lon1) * math.Pi / 180
	a := math.Sin(dLat/2)*math.Sin(dLat/2) + math.Cos(lat1*math.Pi/180)*math.Cos(lat2*math.Pi/180)*math.Sin(dLon/2)*math.Sin(dLon/2)
	return 2 * r * math.Asin(math.Sqrt(a))
}

func round1(f float64) float64 { return math.Round(f*10) / 10 }
