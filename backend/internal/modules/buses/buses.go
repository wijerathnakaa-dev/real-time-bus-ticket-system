package buses

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
)

type BusResponse struct {
	ID             string  `json:"id"`
	PlateNumber    string  `json:"plate_number"`
	RouteNumber    string  `json:"route_number"`
	RouteName      string  `json:"route_name"`
	TotalSeats     int     `json:"total_seats"`
	AvailableSeats int     `json:"available_seats"`
	StandardFare   float64 `json:"standard_fare"`
	Status         string  `json:"status"`
}

func RegisterRoutes(rg *gin.RouterGroup, db *sql.DB) {
	rg.GET("", func(c *gin.Context) {
		// Mock fleet data matching seed dataset
		fleet := []BusResponse{
			{
				ID:             "bus_WP_ND_1024",
				PlateNumber:    "WP-ND-1024",
				RouteNumber:    "138",
				RouteName:      "Colombo Fort <-> Kottawa",
				TotalSeats:     40,
				AvailableSeats: 34,
				StandardFare:   150.00,
				Status:         "on_trip",
			},
			{
				ID:             "bus_WP_NA_9081",
				PlateNumber:    "WP-NA-9081",
				RouteNumber:    "120",
				RouteName:      "Pettah <-> Horana",
				TotalSeats:     40,
				AvailableSeats: 25,
				StandardFare:   220.00,
				Status:         "on_trip",
			},
		}
		c.JSON(http.StatusOK, fleet)
	})
}
