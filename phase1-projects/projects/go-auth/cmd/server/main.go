package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/yourorg/auth-service/internal/handler"
	"github.com/yourorg/auth-service/internal/store"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	redisURL := getEnv("REDIS_URL", "redis://localhost:6379")
	jwtSecret := getEnv("JWT_SECRET", "supersecretkey")
	port := getEnv("PORT", "8080")

	redisStore, err := store.NewRedisStore(redisURL)
	if err != nil {
		log.Fatalf("failed to connect to redis: %v", err)
	}

	h := handler.New(redisStore, jwtSecret)

	r := gin.Default()

	r.GET("/health", h.Health)
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	auth := r.Group("/auth")
	{
		auth.POST("/login", h.Login)
		auth.POST("/refresh", h.Refresh)
		auth.POST("/validate", h.Validate)
		auth.POST("/logout", h.Logout)
	}

	log.Printf("Auth service listening on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}


//  If u run in VM use below code 

// package main

// import (
// 	"log"
// 	"os"

// 	"github.com/gin-gonic/gin"
// 	"github.com/prometheus/client_golang/prometheus/promhttp"
// 	"github.com/yourorg/auth-service/internal/handler"
// 	"github.com/yourorg/auth-service/internal/store"
// )

// func main() {
// 	redisURL := getEnv("REDIS_URL", "redis://localhost:6379")
// 	jwtSecret := getEnv("JWT_SECRET", "supersecretkey")
// 	port := getEnv("PORT", "8080")

// 	redisStore, err := store.NewRedisStore(redisURL)
// 	if err != nil {
// 		log.Fatalf("failed to connect to redis: %v", err)
// 	}

// 	h := handler.New(redisStore, jwtSecret)

// 	r := gin.Default()

// 	// Security: don't trust all proxies
// 	r.SetTrustedProxies(nil)

// 	// Root endpoint
// 	r.GET("/", func(c *gin.Context) {
// 		c.JSON(200, gin.H{
// 			"service": "auth-service",
// 			"status":  "running",
// 		})
// 	})

// 	r.GET("/health", h.Health)
// 	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

// 	auth := r.Group("/auth")
// 	{
// 		auth.POST("/login", h.Login)
// 		auth.POST("/refresh", h.Refresh)
// 		auth.POST("/validate", h.Validate)
// 		auth.POST("/logout", h.Logout)
// 	}

// 	log.Printf("Auth service listening on :%s", port)

// 	if err := r.Run(":" + port); err != nil {
// 		log.Fatalf("server error: %v", err)
// 	}
// }

// func getEnv(key, fallback string) string {
// 	if v := os.Getenv(key); v != "" {
// 		return v
// 	}
// 	return fallback
// }