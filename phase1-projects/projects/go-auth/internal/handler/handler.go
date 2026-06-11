package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/yourorg/auth-service/internal/store"
	"github.com/yourorg/auth-service/pkg/token"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	loginTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "auth_login_total",
		Help: "Total login attempts",
	}, []string{"status"})

	tokenValidations = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "auth_token_validations_total",
		Help: "Token validation results",
	}, []string{"result"})
)

// Handler holds service dependencies
type Handler struct {
	store     store.Store
	jwtSecret string
}

func New(s store.Store, secret string) *Handler {
	return &Handler{store: s, jwtSecret: secret}
}

func (h *Handler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok", "timestamp": time.Now().Unix()})
}

// Login accepts username+password, returns access + refresh tokens
// In production replace the hardcoded credential check with a real user DB
func (h *Handler) Login(c *gin.Context) {
	var req struct {
		Username string `json:"username" binding:"required"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		loginTotal.WithLabelValues("invalid_input").Inc()
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Demo credential — replace with DB lookup
	if req.Username != "admin" || req.Password != "password" {
		loginTotal.WithLabelValues("unauthorized").Inc()
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	access, refresh, err := token.GeneratePair(req.Username, h.jwtSecret)
	if err != nil {
		loginTotal.WithLabelValues("error").Inc()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "could not generate tokens"})
		return
	}

	_ = h.store.StoreRefresh(c.Request.Context(), req.Username, refresh)

	loginTotal.WithLabelValues("success").Inc()
	c.JSON(http.StatusOK, gin.H{
		"access_token":  access,
		"refresh_token": refresh,
		"token_type":    "Bearer",
	})
}

// Refresh issues a new access token from a valid refresh token
func (h *Handler) Refresh(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	claims, err := token.Validate(req.RefreshToken, h.jwtSecret)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid refresh token"})
		return
	}

	stored, err := h.store.GetRefresh(c.Request.Context(), claims.Subject)
	if err != nil || stored != req.RefreshToken {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "refresh token revoked or not found"})
		return
	}

	access, newRefresh, err := token.GeneratePair(claims.Subject, h.jwtSecret)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "could not generate tokens"})
		return
	}

	_ = h.store.StoreRefresh(c.Request.Context(), claims.Subject, newRefresh)
	c.JSON(http.StatusOK, gin.H{"access_token": access, "refresh_token": newRefresh})
}

// Validate checks whether an access token is valid
func (h *Handler) Validate(c *gin.Context) {
	var req struct {
		Token string `json:"token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	claims, err := token.Validate(req.Token, h.jwtSecret)
	if err != nil {
		tokenValidations.WithLabelValues("invalid").Inc()
		c.JSON(http.StatusUnauthorized, gin.H{"valid": false, "error": err.Error()})
		return
	}

	tokenValidations.WithLabelValues("valid").Inc()
	c.JSON(http.StatusOK, gin.H{"valid": true, "subject": claims.Subject})
}

// Logout revokes the refresh token for a user
func (h *Handler) Logout(c *gin.Context) {
	var req struct {
		Username string `json:"username" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	_ = h.store.DeleteRefresh(c.Request.Context(), req.Username)
	c.JSON(http.StatusOK, gin.H{"message": "logged out"})
}
