package config

import (
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	Port      string
	MySQLDSN  string
	JWTSecret string
}

func LoadConfig() *Config {
	_ = godotenv.Load()

	port := os.Getenv("PORT")
	if port == "" {
		port = "5000"
	}

	dsn := os.Getenv("MYSQL_DSN")
	if dsn == "" {
		// default: user:password@tcp(localhost:3306)/bus_transit_db
		dsn = "root:root@tcp(127.0.0.1:3306)/bus_transit_db?parseTime=true"
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "university_bus_transit_jwt_secret_key_2026"
	}

	return &Config{
		Port:      port,
		MySQLDSN:  dsn,
		JWTSecret: jwtSecret,
	}
}
