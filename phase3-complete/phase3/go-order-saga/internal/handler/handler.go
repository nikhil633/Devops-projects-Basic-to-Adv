// Package handler exposes the REST API for placing orders and querying their status.
//
// POST /orders        — place a new order (publishes order.created to Kafka)
// GET  /orders/:id    — get current saga status for one order
// GET  /orders        — list all orders
// GET  /health        — liveness probe
// GET  /metrics       — Prometheus metrics
package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.uber.org/zap"

	"github.com/yourorg/order-saga/internal/kafka"
	"github.com/yourorg/order-saga/internal/store"
	"github.com/yourorg/order-saga/pkg/events"
	"github.com/yourorg/order-saga/pkg/logger"
)

// ── Prometheus metrics ─────────────────────────────────────────────────────

var (
	ordersCreated = promauto.NewCounter(prometheus.CounterOpts{
		Name: "orders_created_total",
		Help: "Total orders placed via the API",
	})

	ordersByStatus = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "orders_by_status_total",
		Help: "Orders counted by terminal status",
	}, []string{"status"})

	requestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "HTTP request latency",
		Buckets: prometheus.DefBuckets,
	}, []string{"method", "path", "status"})
)

// Handler holds the HTTP handler dependencies.
type Handler struct {
	store    *store.OrderStore
	producer *kafka.Client
}

func New(s *store.OrderStore, producer *kafka.Client) *Handler {
	return &Handler{store: s, producer: producer}
}

// RegisterRoutes wires all routes onto the given Gin engine.
func (h *Handler) RegisterRoutes(r *gin.Engine) {
	r.Use(metricsMiddleware())

	r.GET("/health", h.health)
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	orders := r.Group("/orders")
	{
		orders.POST("", h.createOrder)
		orders.GET("", h.listOrders)
		orders.GET("/:id", h.getOrder)
	}
}

// ── Route handlers ─────────────────────────────────────────────────────────

func (h *Handler) health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok", "timestamp": time.Now().Unix()})
}

// createOrder validates the request, assigns an order ID, saves initial state,
// and publishes order.created to Kafka to kick off the saga.
func (h *Handler) createOrder(c *gin.Context) {
	var req struct {
		CustomerID string             `json:"customer_id" binding:"required"`
		Items      []events.OrderItem `json:"items" binding:"required,min=1"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Calculate total server-side (never trust client-supplied totals)
	var total float64
	for _, item := range req.Items {
		total += item.UnitPrice * float64(item.Quantity)
	}

	orderID := uuid.New().String()

	event := events.OrderCreated{
		EventHeader: events.EventHeader{
			EventID:       uuid.New().String(),
			CorrelationID: orderID,
			Timestamp:     time.Now(),
		},
		OrderID:    orderID,
		CustomerID: req.CustomerID,
		Items:      req.Items,
		TotalPrice: total,
	}

	if err := h.producer.Publish(c.Request.Context(), events.TopicOrderCreated, orderID, event); err != nil {
		logger.L.Error("failed to publish order.created", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "could not place order"})
		return
	}

	ordersCreated.Inc()
	logger.L.Info("order placed", zap.String("order_id", orderID), zap.Float64("total", total))

	c.JSON(http.StatusAccepted, gin.H{
		"order_id":    orderID,
		"status":      "PENDING",
		"total_price": total,
		"message":     "order accepted — processing asynchronously",
	})
}

func (h *Handler) getOrder(c *gin.Context) {
	order, err := h.store.Get(c.Request.Context(), c.Param("id"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if order == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "order not found"})
		return
	}
	c.JSON(http.StatusOK, order)
}

func (h *Handler) listOrders(c *gin.Context) {
	orders, err := h.store.List(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, orders)
}

// ── Middleware ─────────────────────────────────────────────────────────────

// metricsMiddleware records request duration with method/path/status labels.
func metricsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		duration := time.Since(start).Seconds()
		requestDuration.WithLabelValues(
			c.Request.Method,
			c.FullPath(),
			http.StatusText(c.Writer.Status()),
		).Observe(duration)
	}
}
