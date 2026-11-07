package seats

import (
	"database/sql"
	"net/http"

	"real-time-bus-backend/internal/app"
	"real-time-bus-backend/internal/modules/tickets"

	"github.com/gin-gonic/gin"
)

type SeatRequest struct {
	BusID      string `json:"bus_id" binding:"required"`
	SeatNumber string `json:"seat_number" binding:"required"`
	Status     string `json:"status"` // override only: available | taken
}

func RegisterRoutes(rg *gin.RouterGroup, d *app.Deps) {
	// Conductor frees the seat when its passenger alights: the ticket becomes "completed".
	rg.POST("/release", d.Auth(app.RoleConductor, app.RoleAdmin), func(c *gin.Context) {
		var req SeatRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		if !d.CanOperateBus(c, req.BusID) {
			app.Fail(c, http.StatusForbidden, "only the assigned conductor or an admin can free seats on this bus")
			return
		}
		var ticketID sql.NullString
		var status string
		if err := d.DB.QueryRow(`SELECT status, ticket_id FROM seats WHERE bus_id=? AND seat_number=?`, req.BusID, req.SeatNumber).Scan(&status, &ticketID); err != nil {
			app.DBError(c, err, "seat")
			return
		}
		if status == "available" {
			c.JSON(http.StatusOK, gin.H{"bus_id": req.BusID, "seat_number": req.SeatNumber, "status": "available", "message": "Seat was already free"})
			return
		}
		if ticketID.Valid {
			if err := tickets.Close(d, ticketID.String, "completed"); err != nil {
				app.DBError(c, err, "ticket")
				return
			}
		} else if err := setSeat(d, req.BusID, req.SeatNumber, "available"); err != nil {
			app.DBError(c, err, "seat")
			return
		}
		c.JSON(http.StatusOK, gin.H{"message": "Seat freed successfully", "bus_id": req.BusID, "seat_number": req.SeatNumber, "status": "available"})
	})

	// Manual override (conductor on board, or admin correcting a wrong state).
	rg.POST("/override", d.Auth(app.RoleConductor, app.RoleAdmin), func(c *gin.Context) {
		var req SeatRequest
		if err := c.ShouldBindJSON(&req); err != nil || (req.Status != "available" && req.Status != "taken") {
			app.Fail(c, http.StatusBadRequest, "bus_id, seat_number and status (available|taken) are required")
			return
		}
		if !d.CanOperateBus(c, req.BusID) {
			app.Fail(c, http.StatusForbidden, "only the assigned conductor or an admin can change seats on this bus")
			return
		}
		var ticketID sql.NullString
		if err := d.DB.QueryRow(`SELECT ticket_id FROM seats WHERE bus_id=? AND seat_number=?`, req.BusID, req.SeatNumber).Scan(&ticketID); err != nil {
			app.DBError(c, err, "seat")
			return
		}
		if req.Status == "available" && ticketID.Valid {
			if err := tickets.Close(d, ticketID.String, "completed"); err != nil {
				app.DBError(c, err, "ticket")
				return
			}
		} else if err := setSeat(d, req.BusID, req.SeatNumber, req.Status); err != nil {
			app.DBError(c, err, "seat")
			return
		}
		c.JSON(http.StatusOK, gin.H{"bus_id": req.BusID, "seat_number": req.SeatNumber, "status": req.Status})
	})
}

func setSeat(d *app.Deps, busID, seat, status string) error {
	q := `UPDATE seats SET status='available', booked_by=NULL, booked_at=NULL, ticket_id=NULL WHERE bus_id=? AND seat_number=?`
	if status == "taken" {
		q = `UPDATE seats SET status='taken', booked_at=NOW() WHERE bus_id=? AND seat_number=?`
	}
	if _, err := d.DB.Exec(q, busID, seat); err != nil {
		return err
	}
	event := "seat_released"
	if status == "taken" {
		event = "seat_booked"
	}
	d.PublishSeatChange(event, busID, seat, status, gin.H{"reason": "manual_override"})
	return nil
}
