package database

import (
	"database/sql"
	_ "embed"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/go-sql-driver/mysql"
)

// schema.sql is a copy of /database/schema.sql without the CREATE DATABASE / USE lines.
//
//go:embed schema.sql
var schemaSQL string

// ConnectMySQL opens the pool, creating the database itself if it does not exist yet.
func ConnectMySQL(dsn string) (*sql.DB, error) {
	cfg, err := mysql.ParseDSN(dsn)
	if err != nil {
		return nil, fmt.Errorf("invalid MYSQL_DSN: %w", err)
	}
	cfg.ParseTime = true
	cfg.MultiStatements = false
	if cfg.Params == nil {
		cfg.Params = map[string]string{}
	}
	cfg.Params["charset"] = "utf8mb4"
	// Store and read every timestamp in UTC: NOW() in the session and time.Time in Go agree,
	// so clients can convert to local time (Asia/Colombo) correctly.
	cfg.Params["time_zone"] = "'+00:00'"
	cfg.Loc = time.UTC

	db, err := open(cfg.FormatDSN())
	if err != nil {
		var myErr *mysql.MySQLError
		if errors.As(err, &myErr) && myErr.Number == 1049 && cfg.DBName != "" { // unknown database
			if cerr := createDatabase(*cfg); cerr != nil {
				return nil, cerr
			}
			return open(cfg.FormatDSN())
		}
		return nil, err
	}
	return db, nil
}

func open(dsn string) (*sql.DB, error) {
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(10)
	db.SetConnMaxLifetime(5 * time.Minute)
	if err := db.Ping(); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}

func createDatabase(cfg mysql.Config) error {
	name := cfg.DBName
	cfg.DBName = ""
	db, err := open(cfg.FormatDSN())
	if err != nil {
		return err
	}
	defer db.Close()
	_, err = db.Exec("CREATE DATABASE IF NOT EXISTS `" + strings.ReplaceAll(name, "`", "") + "` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
	return err
}

// Migrate applies the idempotent schema (CREATE TABLE IF NOT EXISTS ...).
func Migrate(db *sql.DB) error {
	for _, stmt := range splitStatements(schemaSQL) {
		if _, err := db.Exec(stmt); err != nil {
			return fmt.Errorf("migration failed: %w\n%s", err, stmt)
		}
	}
	return nil
}

func splitStatements(src string) []string {
	var out []string
	var b strings.Builder
	for _, line := range strings.Split(src, "\n") {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "--") {
			continue
		}
		b.WriteString(line)
		b.WriteString("\n")
		if strings.HasSuffix(trimmed, ";") {
			out = append(out, strings.TrimSuffix(strings.TrimSpace(b.String()), ";"))
			b.Reset()
		}
	}
	return out
}
