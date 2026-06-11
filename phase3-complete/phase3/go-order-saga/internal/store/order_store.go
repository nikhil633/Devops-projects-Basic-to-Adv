// Package store persists order state in Redis.
//
// Why Redis and not a SQL DB?
// Each saga step is a separate Kafka consumer. Redis gives us sub-millisecond
// reads so each consumer can load the order, check its state, update it, and
// save — all within the Kafka consumer's poll loop without blocking.
package store

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/yourorg/order-saga/internal/model"
)

const orderTTL = 7 * 24 * time.Hour // orders expire after 7 days

// OrderStore wraps Redis with typed methods for Order CRUD.
type OrderStore struct {
	client *redis.Client
}

func NewOrderStore(redisURL string) (*OrderStore, error) {
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("parse redis url: %w", err)
	}
	c := redis.NewClient(opts)
	if err := c.Ping(context.Background()).Err(); err != nil {
		return nil, fmt.Errorf("redis ping: %w", err)
	}
	return &OrderStore{client: c}, nil
}

func key(orderID string) string {
	return "order:" + orderID
}

// Save serialises the order as JSON and writes it to Redis with a TTL.
func (s *OrderStore) Save(ctx context.Context, order *model.Order) error {
	b, err := json.Marshal(order)
	if err != nil {
		return fmt.Errorf("marshal order: %w", err)
	}
	return s.client.Set(ctx, key(order.ID), b, orderTTL).Err()
}

// Get loads an order by ID. Returns (nil, nil) when not found.
func (s *OrderStore) Get(ctx context.Context, orderID string) (*model.Order, error) {
	b, err := s.client.Get(ctx, key(orderID)).Bytes()
	if err == redis.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("redis get: %w", err)
	}
	var o model.Order
	if err := json.Unmarshal(b, &o); err != nil {
		return nil, fmt.Errorf("unmarshal order: %w", err)
	}
	return &o, nil
}

// List returns all orders (uses SCAN — safe for large key spaces).
func (s *OrderStore) List(ctx context.Context) ([]*model.Order, error) {
	var orders []*model.Order
	iter := s.client.Scan(ctx, 0, "order:*", 100).Iterator()
	for iter.Next(ctx) {
		b, err := s.client.Get(ctx, iter.Val()).Bytes()
		if err != nil {
			continue
		}
		var o model.Order
		if err := json.Unmarshal(b, &o); err != nil {
			continue
		}
		orders = append(orders, &o)
	}
	return orders, iter.Err()
}
