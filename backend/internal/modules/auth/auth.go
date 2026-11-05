package auth

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type RegisterRequest struct {
	Name     string `json:"name" binding:"required"`
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
	Phone    string `json:"phone"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

func RegisterRoutes(rg *gin.RouterGroup, db *sql.DB) {
	rg.POST("/register", func(c *gin.Context) {
		var req RegisterRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to encrypt password"})
			return
		}

		// Public registration enforces role = 'passenger'
		c.JSON(http.StatusCreated, gin.H{
			"message": "User registered successfully",
			"user": gin.H{
				"name":  req.Name,
				"email": req.Email,
				"role":  "passenger",
			},
		})
		_ = hashedPassword
	})

	rg.POST("/login", func(c *gin.Context) {
		var req LoginRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"token": "mock-jwt-token-for-" + req.Email,
			"user": gin.H{
				"email": req.Email,
				"role":  "passenger",
			},
		})
	})
}
