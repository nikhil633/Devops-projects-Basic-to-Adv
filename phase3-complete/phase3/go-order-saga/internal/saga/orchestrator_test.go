package saga_test

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/order-saga/internal/model"
	"github.com/yourorg/order-saga/pkg/events"
)

// ── State machine tests ────────────────────────────────────────────────────
// These test the Order.Transition() method in isolation — no Kafka, no Redis.

func TestOrderTransition_HappyPath(t *testing.T) {
	order := newTestOrder()

	steps := []events.OrderStatus{
		events.StatusReserving,
		events.StatusPaying,
		events.StatusFulfilling,
		events.StatusCompleted,
	}

	for _, next := range steps {
		ok := order.Transition(next)
		assert.True(t, ok, "transition to %s should be allowed", next)
		assert.Equal(t, next, order.Status)
	}
}

func TestOrderTransition_FailurePath(t *testing.T) {
	order := newTestOrder()

	// Move to RESERVING first
	order.Transition(events.StatusReserving)

	// Cancel from RESERVING is valid
	ok := order.Transition(events.StatusCancelled)
	assert.True(t, ok)
	assert.Equal(t, events.StatusCancelled, order.Status)
}

func TestOrderTransition_InvalidTransition(t *testing.T) {
	order := newTestOrder()

	// Cannot jump from PENDING straight to COMPLETED
	ok := order.Transition(events.StatusCompleted)
	assert.False(t, ok, "PENDING → COMPLETED should be rejected")
	assert.Equal(t, events.StatusPending, order.Status, "status should be unchanged")
}

func TestOrderTransition_TerminalStateIsImmutable(t *testing.T) {
	order := newTestOrder()
	order.Transition(events.StatusReserving)
	order.Transition(events.StatusCancelled)

	// Once CANCELLED, no further transitions should be allowed
	ok := order.Transition(events.StatusPaying)
	assert.False(t, ok)
	assert.Equal(t, events.StatusCancelled, order.Status)
}

func TestOrderTransition_DuplicateEventIdempotency(t *testing.T) {
	order := newTestOrder()
	order.Transition(events.StatusReserving)

	// First time: valid
	ok1 := order.Transition(events.StatusPaying)
	assert.True(t, ok1)

	// Second time (duplicate event): should be rejected gracefully
	ok2 := order.Transition(events.StatusPaying)
	assert.False(t, ok2, "duplicate transition should be rejected")
}

// ── Event serialisation tests ──────────────────────────────────────────────
// Verify all event structs round-trip through JSON correctly.
// This matters because Kafka messages are raw JSON bytes.

func TestOrderCreatedEvent_Serialisation(t *testing.T) {
	original := events.OrderCreated{
		EventHeader: events.EventHeader{
			EventID:       uuid.New().String(),
			CorrelationID: uuid.New().String(),
			Timestamp:     time.Now().UTC().Truncate(time.Second),
		},
		OrderID:    "order-123",
		CustomerID: "cust-456",
		Items: []events.OrderItem{
			{ProductID: "prod-1", Quantity: 2, UnitPrice: 9.99},
			{ProductID: "prod-2", Quantity: 1, UnitPrice: 49.99},
		},
		TotalPrice: 69.97,
	}

	b, err := json.Marshal(original)
	require.NoError(t, err)

	var decoded events.OrderCreated
	err = json.Unmarshal(b, &decoded)
	require.NoError(t, err)

	assert.Equal(t, original.OrderID, decoded.OrderID)
	assert.Equal(t, original.CustomerID, decoded.CustomerID)
	assert.Equal(t, original.TotalPrice, decoded.TotalPrice)
	assert.Len(t, decoded.Items, 2)
	assert.Equal(t, original.Items[0].ProductID, decoded.Items[0].ProductID)
}

func TestPaymentFailedEvent_Serialisation(t *testing.T) {
	original := events.PaymentFailed{
		EventHeader: events.EventHeader{
			EventID:       uuid.New().String(),
			CorrelationID: "order-789",
			Timestamp:     time.Now().UTC().Truncate(time.Second),
		},
		OrderID: "order-789",
		Reason:  "card declined",
	}

	b, err := json.Marshal(original)
	require.NoError(t, err)

	var decoded events.PaymentFailed
	err = json.Unmarshal(b, &decoded)
	require.NoError(t, err)

	assert.Equal(t, original.OrderID, decoded.OrderID)
	assert.Equal(t, original.Reason, decoded.Reason)
	assert.Equal(t, original.CorrelationID, decoded.CorrelationID)
}

// ── Order total calculation tests ──────────────────────────────────────────

func TestOrderTotalCalculation(t *testing.T) {
	items := []events.OrderItem{
		{ProductID: "p1", Quantity: 3, UnitPrice: 10.00}, // 30.00
		{ProductID: "p2", Quantity: 2, UnitPrice: 5.50},  // 11.00
		{ProductID: "p3", Quantity: 1, UnitPrice: 99.99}, // 99.99
	}

	var total float64
	for _, item := range items {
		total += item.UnitPrice * float64(item.Quantity)
	}

	assert.InDelta(t, 140.99, total, 0.001)
}

// ── Compensation logic tests ───────────────────────────────────────────────
// Test that compensation events carry the right fields.

func TestStockReleasedEvent_HasReservationID(t *testing.T) {
	reservationID := "RES-abc123"

	e := events.StockReleased{
		EventHeader: events.EventHeader{
			EventID:       uuid.New().String(),
			CorrelationID: "order-001",
			Timestamp:     time.Now(),
		},
		OrderID:       "order-001",
		ReservationID: reservationID,
	}

	b, err := json.Marshal(e)
	require.NoError(t, err)

	var decoded events.StockReleased
	err = json.Unmarshal(b, &decoded)
	require.NoError(t, err)

	assert.Equal(t, reservationID, decoded.ReservationID,
		"reservation ID must survive serialisation so inventory can release the right hold")
}

// ── Helpers ────────────────────────────────────────────────────────────────

func newTestOrder() *model.Order {
	return &model.Order{
		ID:         uuid.New().String(),
		CustomerID: "cust-test",
		Items: []events.OrderItem{
			{ProductID: "prod-1", Quantity: 1, UnitPrice: 10.00},
		},
		TotalPrice: 10.00,
		Status:     events.StatusPending,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}
}

// ── Integration-style test using a mock store ──────────────────────────────

// MockStore lets us test saga logic without a real Redis
type MockStore struct {
	orders map[string]*model.Order
}

func NewMockStore() *MockStore {
	return &MockStore{orders: make(map[string]*model.Order)}
}

func (m *MockStore) Save(_ context.Context, o *model.Order) error {
	m.orders[o.ID] = o
	return nil
}

func (m *MockStore) Get(_ context.Context, id string) (*model.Order, error) {
	return m.orders[id], nil
}

func TestMockStore_SaveAndGet(t *testing.T) {
	s := NewMockStore()
	ctx := context.Background()

	order := newTestOrder()
	err := s.Save(ctx, order)
	require.NoError(t, err)

	loaded, err := s.Get(ctx, order.ID)
	require.NoError(t, err)
	require.NotNil(t, loaded)

	assert.Equal(t, order.ID, loaded.ID)
	assert.Equal(t, order.Status, loaded.Status)
}

func TestMockStore_GetNonExistent(t *testing.T) {
	s := NewMockStore()
	ctx := context.Background()

	loaded, err := s.Get(ctx, "does-not-exist")
	require.NoError(t, err)
	assert.Nil(t, loaded, "should return nil for unknown order IDs")
}
