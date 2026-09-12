package main

import (
	"log"
	"os"

	"github.com/example/user-api/internal/handler"
	"github.com/example/user-api/internal/middleware"
	"github.com/example/user-api/internal/repository"
	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	dsn := getEnv("DATABASE_URL", "host=db user=user password=password dbname=usersdb port=5432 sslmode=disable")

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	repo := repository.NewUserRepository(db)
	h := handler.NewUserHandler(repo)

	if os.Getenv("GIN_MODE") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())
	r.Use(middleware.RequestID())

	r.GET("/health", h.Health)

	users := r.Group("/users")
	{
		users.GET("", h.List)
		users.POST("", h.Create)
		users.GET("/:id", h.GetByID)
		users.PUT("/:id", h.Update)
		users.DELETE("/:id", h.Delete)
	}

	port := getEnv("PORT", "8090")
	log.Printf("User API starting on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
