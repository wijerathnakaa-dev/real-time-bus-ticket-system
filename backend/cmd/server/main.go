package main

import (
	"log"
	"net/http"
	"time"

	"real-time-bus-backend/internal/app"
	"real-time-bus-backend/internal/config"
	"real-time-bus-backend/internal/database"
	"real-time-bus-backend/internal/modules/admin"
	"real-time-bus-backend/internal/modules/auth"
	"real-time-bus-backend/internal/modules/buses"
	"real-time-bus-backend/internal/modules/payments"
	"real-time-bus-backend/internal/modules/routes"
	"real-time-bus-backend/internal/modules/seats"
	"real-time-bus-backend/internal/modules/tickets"
	"real-time-bus-backend/internal/modules/tracking"
	"real-time-bus-backend/internal/realtime"
	"real-time-bus-backend/internal/seed"
	"real-time-bus-backend/internal/sockets"

	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.LoadConfig()

	db, err := database.ConnectMySQL(cfg.MySQLDSN)
	if err != nil {
		log.Fatalf("[Database] cannot connect to MySQL: %v\nSet MYSQL_DSN in backend/.env (see .env.example).", err)
	}
	defer db.Close()
	if err := database.Migrate(db); err != nil {
		log.Fatalf("[Database] %v", err)
	}
	log.Println("[Database] connected to MySQL, schema up to date")
	if cfg.SeedDemoData {
		if err := seed.Run(db); err != nil {
			log.Fatalf("[Seed] %v", err)
		}
	}

	hub := sockets.NewHub()
	go hub.Run()

	d := &app.Deps{DB: db, Hub: hub, Cfg: cfg, RT: realtime.New(cfg.FirebaseCredentialsFile, cfg.FirebaseDatabaseURL)}
	go tickets.ExpirePendingPayments(d, 15*time.Minute)

	router := gin.Default()
	router.MaxMultipartMemory = 8 << 20
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization")
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	})

	router.GET("/api/health", func(c *gin.Context) {
		dbStatus := "ok"
		if err := db.Ping(); err != nil {
			dbStatus = err.Error()
		}
		c.JSON(http.StatusOK, gin.H{
			"status":   "ok",
			"service":  "Real-Time Bus System (Go Backend)",
			"engine":   "Golang + Gin + MySQL",
			"database": dbStatus,
			"firebase": d.RT != nil,
			"payhere":  cfg.PayHereEnabled(),
		})
	})

	// WebSocket: /ws?bus_id=<id> for one bus, or /ws for every event (admin dashboard).
	router.GET("/ws", func(c *gin.Context) { sockets.ServeWs(hub, c.Writer, c.Request) })
	router.Static("/uploads", "./uploads")

	api := router.Group("/api/v1")
	{
		auth.RegisterRoutes(api.Group("/auth"), d)
		routes.RegisterRoutes(api.Group("/routes"), d)
		busGroup := api.Group("/buses")
		buses.RegisterRoutes(busGroup, d)
		tracking.RegisterRoutes(busGroup, d)
		seats.RegisterRoutes(api.Group("/seats"), d)
		tickets.RegisterRoutes(api.Group("/tickets"), d)
		payments.RegisterRoutes(api.Group("/payments"), d)
		admin.RegisterRoutes(api.Group("/admin"), d)
	}

	log.Printf("[Server] Go backend listening on :%s\n", cfg.Port)
	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
