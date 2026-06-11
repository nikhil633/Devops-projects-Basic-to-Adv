// Package events defines all Kafka event types shared across saga steps.
// Every event carries a common header (EventID, CorrelationID, Timestamp)
// so any consumer can trace a single order through the entire saga.
package events

import "time"

// ── Kafka topic names ──────────────────────────────────────────────────────
// Forward-path topics (happy path)
const (
	TopicOrderCreated       = "order.created"
	TopicStockReserved      = "stock.reserved"
	TopicStockReserveFailed = "stock.reserve.failed"
	TopicPaymentProcessed   = "payment.processed"
	TopicPaymentFailed      = "payment.failed"
	TopicOrderFulfilled     = "order.fulfilled"
	TopicOrderCancelled     = "order.cancelled"

	// Compensating transaction topics (rollback path)
	TopicStockReleased   = "stock.released"
	TopicPaymentRefunded = "payment.refunded"
)

// OrderStatus is the saga state machine's current node
type OrderStatus string

const (
	StatusPending    OrderStatus = "PENDING"
	StatusReserving  OrderStatus = "RESERVING_STOCK"
	StatusPaying     OrderStatus = "PROCESSING_PAYMENT"
	StatusFulfilling OrderStatus = "FULFILLING"
	StatusCompleted  OrderStatus = "COMPLETED"
	StatusCancelled  OrderStatus = "CANCELLED"
)

// ── Event structs ──────────────────────────────────────────────────────────

// EventHeader is embedded in every event.
// CorrelationID == OrderID — it's the thread that connects all saga events.
type EventHeader struct {
	EventID       string    `json:"event_id"`
	CorrelationID string    `json:"correlation_id"`
	Timestamp     time.Time `json:"timestamp"`
}

// OrderCreated — published by the HTTP handler when a new order arrives
type OrderCreated struct {
	EventHeader
	OrderID    string      `json:"order_id"`
	CustomerID string      `json:"customer_id"`
	Items      []OrderItem `json:"items"`
	TotalPrice float64     `json:"total_price"`
}

type OrderItem struct {
	ProductID string  `json:"product_id"`
	Quantity  int     `json:"quantity"`
	UnitPrice float64 `json:"unit_price"`
}

// StockReserved — published by the (simulated) inventory worker
type StockReserved struct {
	EventHeader
	OrderID       string `json:"order_id"`
	ReservationID string `json:"reservation_id"`
}

// StockReserveFailed — insufficient stock or inventory service error
type StockReserveFailed struct {
	EventHeader
	OrderID string `json:"order_id"`
	Reason  string `json:"reason"`
}

// PaymentProcessed — published by the (simulated) payment worker
type PaymentProcessed struct {
	EventHeader
	OrderID       string  `json:"order_id"`
	TransactionID string  `json:"transaction_id"`
	Amount        float64 `json:"amount"`
}

// PaymentFailed — card declined or payment service error
type PaymentFailed struct {
	EventHeader
	OrderID string `json:"order_id"`
	Reason  string `json:"reason"`
}

// OrderFulfilled — order is packed and dispatched
type OrderFulfilled struct {
	EventHeader
	OrderID    string `json:"order_id"`
	TrackingID string `json:"tracking_id"`
}

// OrderCancelled — terminal failure state
type OrderCancelled struct {
	EventHeader
	OrderID string `json:"order_id"`
	Reason  string `json:"reason"`
}

// ── Compensating events (rollback) ────────────────────────────────────────

// StockReleased — undoes a reservation when payment fails
type StockReleased struct {
	EventHeader
	OrderID       string `json:"order_id"`
	ReservationID string `json:"reservation_id"`
}

// PaymentRefunded — undoes a charge (not needed here but shown for completeness)
type PaymentRefunded struct {
	EventHeader
	OrderID       string `json:"order_id"`
	TransactionID string `json:"transaction_id"`
}
