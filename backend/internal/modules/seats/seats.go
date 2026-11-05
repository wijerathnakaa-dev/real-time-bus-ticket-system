package seats

import (
	"database/sql"
	"net/http"

	"real-time-bus-backend/internal/sockets"

	"github.com/gin-gonic/gin"
)

type ReleaseSeatRequest struct {
	BusID      string `json:"bus_id" binding:"required"`
	SeatNumber string `json:"seat_number" binding:"required"`
}

func RegisterRoutes(rg *gin.RouterGroup, db *sql.DB, hub *sockets.Hub) {
	rg.POST("/release", func(c *gin.Context) {
		var req ReleaseSeatRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Broadcast seat release to connected passengers via WebSocket
		hub.BroadcastJSON(gin.H{
			"type":        "seat_released",
			"bus_id":      req.BusID,
			"seat_number": req.SeatNumber,
			"status":      "available",
		})

		c.JSON(http.StatusOK, gin.H{
			"message":     "Seat freed successfully",
			"bus_id":      req.BusID,
			"seat_number": req.SeatNumber,
			"status":      "available",
		})
	})
}
