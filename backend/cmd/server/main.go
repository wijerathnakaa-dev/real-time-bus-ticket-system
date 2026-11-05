package main

import (
	"log"
	"net/http"
	"os"

	"real-time-bus-backend/internal/config"
	"real-time-bus-backend/internal/database"
	"real-time-bus-backend/internal/modules/auth"
	"real-time-bus-backend/internal/modules/buses"
	"real-time-bus-backend/internal/modules/seats"
	"real-time-bus-backend/internal/modules/tickets"
	"real-time-bus-backend/internal/sockets"

	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.LoadConfig()

	// Initialize MySQL Connection
	db, err := database.ConnectMySQL(cfg.MySQLDSN)
	if err != nil {
		log.Printf("[Warning] MySQL connection not established (%v). Running in offline mock mode.\n", err)
	} else {
		defer db.Close()
		log.Println("[Database] Connected to MySQL successfully.")
	}

	router := gin.Default()

	// CORS Middleware
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	})

	// Health check
	router.GET("/api/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "Real-Time Bus System (Go Backend)",
			"engine":  "Golang + Gin + MySQL",
		})
	})

	// Hub for WebSocket real-time seat sync and GPS telemetry
	wsHub := sockets.NewHub()
	go wsHub.Run()

	// WebSocket endpoint
	router.GET("/ws", func(c *gin.Context) {
		sockets.ServeWs(wsHub, c.Writer, c.Request)
	})

	// Register API Modules
	api := router.Group("/api/v1")
	{
		auth.RegisterRoutes(api.Group("/auth"), db)
		buses.RegisterRoutes(api.Group("/buses"), db)
		seats.RegisterRoutes(api.Group("/seats"), db, wsHub)
		tickets.RegisterRoutes(api.Group("/tickets"), db, wsHub)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "5000"
	}

	log.Printf("[Server] Starting Go Backend on port %s...\n", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
