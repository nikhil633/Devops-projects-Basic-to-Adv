// Package saga contains the orchestrator — the brain of the order saga.
//
// ── How the Saga pattern works ────────────────────────────────────────────
//
// A distributed transaction across multiple services is broken into steps.
// Each step publishes a Kafka event. Downstream workers react to that event,
// do their work, and publish the result event (success or failure).
// The orchestrator listens to ALL result events and decides what to do next.
//
// Happy path:
//   order.created → [inventory worker] → stock.reserved
//   stock.reserved → [payment worker] → payment.processed
//   payment.processed → [fulfillment worker] → order.fulfilled
//   order.fulfilled → saga complete ✓
//
// Failure path (e.g. payment fails):
//   payment.failed → orchestrator publishes stock.released (compensating tx)
//   stock.released → orchestrator marks order CANCELLED
//
// The orchestrator owns the state machine. Workers are dumb — they just do
// one thing and report back.
package saga

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"go.uber.org/zap"

	"github.com/yourorg/order-saga/internal/kafka"
	"github.com/yourorg/order-saga/internal/model"
	"github.com/yourorg/order-saga/internal/store"
	"github.com/yourorg/order-saga/pkg/events"
	"github.com/yourorg/order-saga/pkg/logger"
)

// Orchestrator listens on all result topics and drives the saga forward.
type Orchestrator struct {
	store    *store.OrderStore
	producer *kafka.Client  // separate producer client (no consumer group)
	consumer *kafka.Client  // consumer group client
}

func NewOrchestrator(s *store.OrderStore, producer, consumer *kafka.Client) *Orchestrator {
	return &Orchestrator{store: s, producer: producer, consumer: consumer}
}

// Run starts consuming result events. Blocks until ctx is cancelled.
func (o *Orchestrator) Run(ctx context.Context) error {
	logger.L.Info("saga orchestrator starting")
	return o.consumer.Subscribe(ctx, o.dispatch)
}

// dispatch routes each incoming Kafka message to the right handler.
func (o *Orchestrator) dispatch(ctx context.Context, topic string, value []byte) error {
	logger.L.Debug("received event", zap.String("topic", topic))

	switch topic {
	case events.TopicOrderCreated:
		return o.onOrderCreated(ctx, value)
	case events.TopicStockReserved:
		return o.onStockReserved(ctx, value)
	case events.TopicStockReserveFailed:
		return o.onStockReserveFailed(ctx, value)
	case events.TopicPaymentProcessed:
		return o.onPaymentProcessed(ctx, value)
	case events.TopicPaymentFailed:
		return o.onPaymentFailed(ctx, value)
	case events.TopicOrderFulfilled:
		return o.onOrderFulfilled(ctx, value)
	default:
		logger.L.Warn("unknown topic — skipping", zap.String("topic", topic))
		return nil
	}
}

// ── Step handlers ──────────────────────────────────────────────────────────

// onOrderCreated: order just arrived — kick off stock reservation
func (o *Orchestrator) onOrderCreated(ctx context.Context, raw []byte) error {
	var e events.OrderCreated
	if err := json.Unmarshal(raw, &e); err != nil {
		return fmt.Errorf("unmarshal OrderCreated: %w", err)
	}

	order := &model.Order{
		ID:         e.OrderID,
		CustomerID: e.CustomerID,
		Items:      e.Items,
		TotalPrice: e.TotalPrice,
		Status:     events.StatusPending,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}
	order.Transition(events.StatusReserving)

	if err := o.store.Save(ctx, order); err != nil {
		return fmt.Errorf("save order: %w", err)
	}

	logger.L.Info("order created → reserving stock",
		zap.String("order_id", order.ID),
		zap.Float64("total", order.TotalPrice),
	)

	// Tell the inventory worker to reserve stock
	// In production the inventory service consumes this topic itself.
	// Here we simulate it inline by publishing stock.reserved immediately.
	return o.simulateStockReservation(ctx, order)
}

// onStockReserved: inventory confirmed → start payment
func (o *Orchestrator) onStockReserved(ctx context.Context, raw []byte) error {
	var e events.StockReserved
	if err := json.Unmarshal(raw, &e); err != nil {
		return fmt.Errorf("unmarshal StockReserved: %w", err)
	}

	order, err := o.loadOrder(ctx, e.OrderID)
	if err != nil {
		return err
	}

	order.ReservationID = e.ReservationID
	if !order.Transition(events.StatusPaying) {
		logger.L.Warn("invalid transition to PAYING — duplicate event?",
			zap.String("order_id", order.ID),
			zap.String("current_status", string(order.Status)),
		)
		return nil // not an error — just skip duplicate
	}

	if err := o.store.Save(ctx, order); err != nil {
		return fmt.Errorf("save order: %w", err)
	}

	logger.L.Info("stock reserved → processing payment",
		zap.String("order_id", order.ID),
		zap.String("reservation_id", e.ReservationID),
	)

	return o.simulatePayment(ctx, order)
}

// onStockReserveFailed: no stock → cancel immediately (no compensation needed yet)
func (o *Orchestrator) onStockReserveFailed(ctx context.Context, raw []byte) error {
	var e events.StockReserveFailed
	if err := json.Unmarshal(raw, &e); err != nil {
		return fmt.Errorf("unmarshal StockReserveFailed: %w", err)
	}

	order, err := o.loadOrder(ctx, e.OrderID)
	if err != nil {
		return err
	}

	order.FailureReason = e.Reason
	order.Transition(events.StatusCancelled)

	if err := o.store.Save(ctx, order); err != nil {
		return fmt.Errorf("save order: %w", err)
	}

	logger.L.Warn("stock reservation failed — order cancelled",
		zap.String("order_id", order.ID),
		zap.String("reason", e.Reason),
	)

	return o.producer.Publish(ctx, events.TopicOrderCancelled, order.ID, events.OrderCancelled{
		EventHeader:   newHeader(order.ID),
		OrderID:       order.ID,
		Reason:        e.Reason,
	})
}

// onPaymentProcessed: payment succeeded → fulfil
func (o *Orchestrator) onPaymentProcessed(ctx context.Context, raw []byte) error {
	var e events.PaymentProcessed
	if err := json.Unmarshal(raw, &e); err != nil {
		return fmt.Errorf("unmarshal PaymentProcessed: %w", err)
	}

	order, err := o.loadOrder(ctx, e.OrderID)
	if err != nil {
		return err
	}

	order.TransactionID = e.TransactionID
	if !order.Transition(events.StatusFulfilling) {
		return nil // duplicate
	}

	if err := o.store.Save(ctx, order); err != nil {
		return fmt.Errorf("save order: %w", err)
	}

	logger.L.Info("payment processed → fulfilling order",
		zap.String("order_id", order.ID),
		zap.String("transaction_id", e.TransactionID),
	)

	return o.simulateFulfillment(ctx, order)
}

// onPaymentFailed: charge declined → compensate by releasing stock, then cancel
func (o *Orchestrator) onPaymentFailed(ctx context.Context, raw []byte) error {
	var e events.PaymentFailed
	if err := json.Unmarshal(raw, &e); err != nil {
		return fmt.Errorf("unmarshal PaymentFailed: %w", err)
	}

	order, err := o.loadOrder(ctx, e.OrderID)
	if err != nil {
		return err
	}

	logger.L.Warn("payment failed — releasing stock (compensating transaction)",
		zap.String("order_id", order.ID),
		zap.String("reason", e.Reason),
	)

	// ── Compensating transaction ─────────────────────────────────────────
	// Payment charged nothing yet, but stock IS reserved.
	// We must release it so other customers can buy the item.
	if order.ReservationID != "" {
		if err := o.producer.Publish(ctx, events.TopicStockReleased, order.ID, events.StockReleased{
			EventHeader:   newHeader(order.ID),
			OrderID:       order.ID,
			ReservationID: order.ReservationID,
		}); err != nil {
			return fmt.Errorf("publish StockReleased: %w", err)
		}
	}

	order.FailureReason = e.Reason
	order.Transition(events.StatusCancelled)

	if err := o.store.Save(ctx, order); err != nil {
		return fmt.Errorf("save order: %w", err)
	}

	return o.producer.Publish(ctx, events.TopicOrderCancelled, order.ID, events.OrderCancelled{
		EventHeader: newHeader(order.ID),
		OrderID:     order.ID,
		Reason:      e.Reason,
	})
}

// onOrderFulfilled: saga complete 🎉
func (o *Orchestrator) onOrderFulfilled(ctx context.Context, raw []byte) error {
	var e events.OrderFulfilled
	if err := json.Unmarshal(raw, &e); err != nil {
		return fmt.Errorf("unmarshal OrderFulfilled: %w", err)
	}

	order, err := o.loadOrder(ctx, e.OrderID)
	if err != nil {
		return err
	}

	order.TrackingID = e.TrackingID
	order.Transition(events.StatusCompleted)

	if err := o.store.Save(ctx, order); err != nil {
		return fmt.Errorf("save order: %w", err)
	}

	logger.L.Info("order saga COMPLETED",
		zap.String("order_id", order.ID),
		zap.String("tracking_id", e.TrackingID),
	)
	return nil
}

// ── Simulation helpers ─────────────────────────────────────────────────────
// In production these would be separate microservices consuming these topics.
// Here we inline them so the whole saga is demonstrable with a single service.

func (o *Orchestrator) simulateStockReservation(ctx context.Context, order *model.Order) error {
	// Simulate: orders over $1000 are "out of stock" for demo purposes
	if order.TotalPrice > 1000 {
		return o.producer.Publish(ctx, events.TopicStockReserveFailed, order.ID, events.StockReserveFailed{
			EventHeader: newHeader(order.ID),
			OrderID:     order.ID,
			Reason:      "insufficient stock",
		})
	}
	return o.producer.Publish(ctx, events.TopicStockReserved, order.ID, events.StockReserved{
		EventHeader:   newHeader(order.ID),
		OrderID:       order.ID,
		ReservationID: "RES-" + uuid.New().String()[:8],
	})
}

func (o *Orchestrator) simulatePayment(ctx context.Context, order *model.Order) error {
	// Simulate: orders over $500 fail payment for demo purposes
	if order.TotalPrice > 500 {
		return o.producer.Publish(ctx, events.TopicPaymentFailed, order.ID, events.PaymentFailed{
			EventHeader: newHeader(order.ID),
			OrderID:     order.ID,
			Reason:      "card declined",
		})
	}
	return o.producer.Publish(ctx, events.TopicPaymentProcessed, order.ID, events.PaymentProcessed{
		EventHeader:   newHeader(order.ID),
		OrderID:       order.ID,
		TransactionID: "TXN-" + uuid.New().String()[:8],
		Amount:        order.TotalPrice,
	})
}

func (o *Orchestrator) simulateFulfillment(ctx context.Context, order *model.Order) error {
	return o.producer.Publish(ctx, events.TopicOrderFulfilled, order.ID, events.OrderFulfilled{
		EventHeader: newHeader(order.ID),
		OrderID:     order.ID,
		TrackingID:  "TRK-" + uuid.New().String()[:8],
	})
}

// ── Helpers ────────────────────────────────────────────────────────────────

func (o *Orchestrator) loadOrder(ctx context.Context, orderID string) (*model.Order, error) {
	order, err := o.store.Get(ctx, orderID)
	if err != nil {
		return nil, fmt.Errorf("load order %s: %w", orderID, err)
	}
	if order == nil {
		return nil, fmt.Errorf("order %s not found in store", orderID)
	}
	return order, nil
}

func newHeader(correlationID string) events.EventHeader {
	return events.EventHeader{
		EventID:       uuid.New().String(),
		CorrelationID: correlationID,
		Timestamp:     time.Now(),
	}
}
