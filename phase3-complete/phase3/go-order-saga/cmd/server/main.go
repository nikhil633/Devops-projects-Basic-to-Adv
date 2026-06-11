// main.go wires together all components and starts:
//   1. The HTTP server (order placement + status query)
//   2. The saga orchestrator (Kafka consumer loop)
//
// Both run concurrently. If either exits, the whole process exits via errgroup.
package main

import (
	"context"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"golang.org/x/sync/errgroup"

	"github.com/yourorg/order-saga/internal/handler"
	"github.com/yourorg/order-saga/internal/kafka"
	"github.com/yourorg/order-saga/internal/saga"
	"github.com/yourorg/order-saga/internal/store"
	"github.com/yourorg/order-saga/pkg/events"
	"github.com/yourorg/order-saga/pkg/logger"
)

func main() {
	// ── Config from environment ──────────────────────────────────────────
	redisURL := getEnv("REDIS_URL", "redis://localhost:6379")
	kafkaBrokers := strings.Split(getEnv("KAFKA_BROKERS", "localhost:9092"), ",")
	port := getEnv("PORT", "8080")

	// ── Dependencies ─────────────────────────────────────────────────────
	orderStore, err := store.NewOrderStore(redisURL)
	if err != nil {
		logger.L.Fatal("redis connect failed", zap.Error(err))
	}
	logger.L.Info("connected to Redis", zap.String("url", redisURL))

	// Producer client — no consumer group, used by HTTP handler + orchestrator
	// to publish events
	producer, err := kafka.NewClient(kafkaBrokers, "")
	if err != nil {
		logger.L.Fatal("kafka producer connect failed", zap.Error(err))
	}
	defer producer.Close()

	// Consumer client — subscribes to ALL result topics the orchestrator needs
	consumer, err := kafka.NewClient(
		kafkaBrokers,
		"order-saga-orchestrator", // consumer group ID
		// Topics the orchestrator reacts to:
		events.TopicOrderCreated,
		events.TopicStockReserved,
		events.TopicStockReserveFailed,
		events.TopicPaymentProcessed,
		events.TopicPaymentFailed,
		events.TopicOrderFulfilled,
	)
	if err != nil {
		logger.L.Fatal("kafka consumer connect failed", zap.Error(err))
	}
	defer consumer.Close()

	logger.L.Info("connected to Kafka", zap.Strings("brokers", kafkaBrokers))

	// ── HTTP server ───────────────────────────────────────────────────────
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	router.Use(gin.Recovery())

	h := handler.New(orderStore, producer)
	h.RegisterRoutes(router)

	// ── Orchestrator ──────────────────────────────────────────────────────
	orchestrator := saga.NewOrchestrator(orderStore, producer, consumer)

	// ── Graceful shutdown ─────────────────────────────────────────────────
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// errgroup runs both goroutines; if one fails both are cancelled
	g, gCtx := errgroup.WithContext(ctx)

	// Goroutine 1: HTTP server
	g.Go(func() error {
		logger.L.Info("HTTP server starting", zap.String("port", port))
		return router.Run(":" + port)
	})

	// Goroutine 2: Saga orchestrator consumer loop
	g.Go(func() error {
		return orchestrator.Run(gCtx)
	})

	// Wait for SIGTERM or one of the goroutines to return an error
	if err := g.Wait(); err != nil && err != context.Canceled {
		logger.L.Error("service exited with error", zap.Error(err))
		os.Exit(1)
	}

	logger.L.Info("service shut down cleanly")
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
