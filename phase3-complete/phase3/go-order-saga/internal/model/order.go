// Package model defines the Order entity and its saga state machine.
package model

import (
	"time"

	"github.com/yourorg/order-saga/pkg/events"
)

// Order is the aggregate root — it owns the current saga state.
type Order struct {
	ID            string             `json:"id"`
	CustomerID    string             `json:"customer_id"`
	Items         []events.OrderItem `json:"items"`
	TotalPrice    float64            `json:"total_price"`
	Status        events.OrderStatus `json:"status"`
	ReservationID string             `json:"reservation_id,omitempty"`
	TransactionID string             `json:"transaction_id,omitempty"`
	TrackingID    string             `json:"tracking_id,omitempty"`
	FailureReason string             `json:"failure_reason,omitempty"`
	CreatedAt     time.Time          `json:"created_at"`
	UpdatedAt     time.Time          `json:"updated_at"`
}

// Transition moves the order to a new status and records the time.
// It returns false if the transition is not valid from the current status
// so callers can detect duplicate / out-of-order events.
func (o *Order) Transition(next events.OrderStatus) bool {
	allowed := allowedTransitions[o.Status]
	for _, a := range allowed {
		if a == next {
			o.Status = next
			o.UpdatedAt = time.Now()
			return true
		}
	}
	return false
}

// allowedTransitions is the saga state machine encoded as a map.
// Only edges listed here are valid; anything else is rejected.
var allowedTransitions = map[events.OrderStatus][]events.OrderStatus{
	events.StatusPending: {
		events.StatusReserving,
		events.StatusCancelled,
	},
	events.StatusReserving: {
		events.StatusPaying,
		events.StatusCancelled,
	},
	events.StatusPaying: {
		events.StatusFulfilling,
		events.StatusCancelled,
	},
	events.StatusFulfilling: {
		events.StatusCompleted,
		events.StatusCancelled,
	},
	// Terminal states — no further transitions
	events.StatusCompleted: {},
	events.StatusCancelled: {},
}
