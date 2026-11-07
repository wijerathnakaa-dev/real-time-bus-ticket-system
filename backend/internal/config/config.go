package config

import (
	"os"
	"strings"

	"github.com/joho/godotenv"
)

type Config struct {
	Port      string
	MySQLDSN  string
	JWTSecret string

	// SeedDemoData loads sample routes, buses and accounts into an empty database.
	SeedDemoData bool

	// Firebase (optional): when the service-account file exists, live seat maps and
	// bus positions are mirrored to Realtime Database and FCM pushes are sent.
	FirebaseCredentialsFile string
	FirebaseDatabaseURL     string

	// PayHere (optional): without a merchant ID the API runs a clearly-labelled
	// simulated payment so the flow can be demonstrated end to end.
	PayHereMerchantID     string
	PayHereMerchantSecret string
	PayHereSandbox        bool
	PublicBaseURL         string
}

func LoadConfig() *Config {
	_ = godotenv.Load()

	return &Config{
		Port:                    env("PORT", "5000"),
		MySQLDSN:                env("MYSQL_DSN", "root:root@tcp(127.0.0.1:3306)/bus_transit_db?parseTime=true"),
		JWTSecret:               env("JWT_SECRET", "dev_only_change_me_bus_transit_secret"),
		SeedDemoData:            envBool("SEED_DEMO_DATA", true),
		FirebaseCredentialsFile: env("FIREBASE_CREDENTIALS_FILE", "firebase-service-account.json"),
		FirebaseDatabaseURL:     env("FIREBASE_DATABASE_URL", ""),
		PayHereMerchantID:       env("PAYHERE_MERCHANT_ID", ""),
		PayHereMerchantSecret:   env("PAYHERE_MERCHANT_SECRET", ""),
		PayHereSandbox:          envBool("PAYHERE_SANDBOX", true),
		PublicBaseURL:           strings.TrimRight(env("PUBLIC_BASE_URL", "http://localhost:5000"), "/"),
	}
}

func (c *Config) PayHereEnabled() bool {
	return c.PayHereMerchantID != "" && c.PayHereMerchantSecret != ""
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envBool(key string, def bool) bool {
	switch strings.ToLower(os.Getenv(key)) {
	case "1", "true", "yes":
		return true
	case "0", "false", "no":
		return false
	}
	return def
}
