package auth

import (
	"database/sql"
	"net/http"
	"strings"

	"real-time-bus-backend/internal/app"

	"github.com/gin-gonic/gin"
	"github.com/go-sql-driver/mysql"
	"golang.org/x/crypto/bcrypt"
)

type RegisterRequest struct {
	Name     string `json:"name" binding:"required"`
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
	Phone    string `json:"phone"`
	// Role may be "passenger" (default) or "conductor". Admin accounts are never self-registered.
	Role string `json:"role"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type UserDTO struct {
	ID            string  `json:"id"`
	Name          string  `json:"name"`
	Email         string  `json:"email"`
	Phone         *string `json:"phone"`
	Role          string  `json:"role"`
	AssignedBusID *string `json:"assigned_bus_id"`
}

func RegisterRoutes(rg *gin.RouterGroup, d *app.Deps) {
	rg.POST("/register", func(c *gin.Context) {
		var req RegisterRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		role := strings.ToLower(req.Role)
		if role == "" {
			role = app.RolePassenger
		}
		if role != app.RolePassenger && role != app.RoleConductor {
			app.Fail(c, http.StatusBadRequest, "role must be passenger or conductor")
			return
		}
		hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			app.Fail(c, http.StatusInternalServerError, "failed to hash password")
			return
		}
		id := app.NewID("usr")
		email := strings.ToLower(strings.TrimSpace(req.Email))
		_, err = d.DB.Exec(`INSERT INTO users (id, name, email, phone, password_hash, role) VALUES (?, ?, ?, NULLIF(?, ''), ?, ?)`,
			id, strings.TrimSpace(req.Name), email, req.Phone, string(hash), role)
		if err != nil {
			if me, ok := err.(*mysql.MySQLError); ok && me.Number == 1062 {
				app.Fail(c, http.StatusConflict, "an account with this email already exists")
				return
			}
			app.Fail(c, http.StatusInternalServerError, err.Error())
			return
		}
		token, _ := d.IssueToken(id, req.Name, role)
		c.JSON(http.StatusCreated, gin.H{"token": token, "user": UserDTO{ID: id, Name: req.Name, Email: email, Role: role}})
	})

	rg.POST("/login", func(c *gin.Context) {
		var req LoginRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		var u UserDTO
		var hash string
		err := d.DB.QueryRow(`SELECT id, name, email, phone, role, assigned_bus_id, password_hash FROM users WHERE email = ?`,
			strings.ToLower(strings.TrimSpace(req.Email))).Scan(&u.ID, &u.Name, &u.Email, &u.Phone, &u.Role, &u.AssignedBusID, &hash)
		if err == sql.ErrNoRows || (err == nil && bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)) != nil) {
			app.Fail(c, http.StatusUnauthorized, "incorrect email or password")
			return
		}
		if err != nil {
			app.Fail(c, http.StatusInternalServerError, err.Error())
			return
		}
		token, err := d.IssueToken(u.ID, u.Name, u.Role)
		if err != nil {
			app.Fail(c, http.StatusInternalServerError, "failed to issue token")
			return
		}
		c.JSON(http.StatusOK, gin.H{"token": token, "user": u})
	})

	rg.GET("/me", d.Auth(), func(c *gin.Context) {
		u, err := LoadUser(d.DB, app.User(c).UserID)
		if err != nil {
			app.DBError(c, err, "user")
			return
		}
		c.JSON(http.StatusOK, u)
	})
}

func LoadUser(db *sql.DB, id string) (*UserDTO, error) {
	var u UserDTO
	err := db.QueryRow(`SELECT id, name, email, phone, role, assigned_bus_id FROM users WHERE id = ?`, id).
		Scan(&u.ID, &u.Name, &u.Email, &u.Phone, &u.Role, &u.AssignedBusID)
	return &u, err
}
