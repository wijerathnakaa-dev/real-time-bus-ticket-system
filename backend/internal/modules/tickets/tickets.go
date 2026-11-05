package tickets

import (
	"database/sql"
	"fmt"
	"net/http"
	"time"

	"real-time-bus-backend/internal/sockets"

	"github.com/gin-gonic/gin"
)

type BookTicketRequest struct {
	BusID          string  `json:"bus_id" binding:"required"`
	BusPlateNumber string  `json:"bus_plate_number" binding:"required"`
	RouteNumber    string  `json:"route_number" binding:"required"`
	SeatNumber     string  `json:"seat_number" binding:"required"`
	PassengerID    string  `json:"passenger_id" binding:"required"`
	PassengerName  string  `json:"passenger_name" binding:"required"`
	PassengerPhone string  `json:"passenger_phone"`
	IssuedByRole   string  `json:"issued_by_role"`
	Fare           float64 `json:"fare"`
}

func RegisterRoutes(rg *gin.RouterGroup, db *sql.DB, hub *sockets.Hub) {
	rg.POST("/book", func(c *gin.Context) {
		var req BookTicketRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		ticketID := fmt.Sprintf("TKT-%d", time.Now().UnixNano()%1000000)

		// Broadcast seat booking to all devices on the bus
		hub.BroadcastJSON(gin.H{
			"type":           "seat_booked",
			"bus_id":         req.BusID,
			"seat_number":    req.SeatNumber,
			"status":         "taken",
			"passenger_name": req.PassengerName,
		})

		c.JSON(http.StatusCreated, gin.H{
			"ticket_id":        ticketID,
			"bus_id":           req.BusID,
			"bus_plate_number": req.BusPlateNumber,
			"route_number":     req.RouteNumber,
			"seat_number":      req.SeatNumber,
			"passenger_name":   req.PassengerName,
			"fare":             req.Fare,
			"status":           "paid",
			"issued_at":        time.Now(),
		})
	})
}
