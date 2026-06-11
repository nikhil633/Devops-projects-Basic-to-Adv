// Package kafka wraps the franz-go Kafka client with typed Publish / Subscribe helpers.
//
// Why franz-go?
// It is a pure-Go Kafka client with excellent context support, no CGo, and
// built-in idempotent producer semantics — important for exactly-once delivery.
package kafka

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/twmb/franz-go/pkg/kgo"
	"go.uber.org/zap"

	"github.com/yourorg/order-saga/pkg/logger"
)

// Client wraps a franz-go kgo.Client for both producing and consuming.
type Client struct {
	kgo *kgo.Client
}

// NewClient creates a Kafka client connected to the given brokers.
// groupID is optional — pass "" for producer-only clients.
func NewClient(brokers []string, groupID string, topics ...string) (*Client, error) {
	opts := []kgo.Opt{
		kgo.SeedBrokers(brokers...),
		kgo.ProducerBatchCompression(kgo.SnappyCompression()),
		// Idempotent producer: Kafka will deduplicate retried sends
		kgo.RequiredAcks(kgo.AllISRAcks()),
	}

	if groupID != "" {
		opts = append(opts,
			kgo.ConsumerGroup(groupID),
			kgo.ConsumeTopics(topics...),
			kgo.DisableAutoCommit(), // we commit manually after processing
		)
	}

	c, err := kgo.NewClient(opts...)
	if err != nil {
		return nil, fmt.Errorf("kafka new client: %w", err)
	}
	return &Client{kgo: c}, nil
}

// Publish serialises payload as JSON and sends it to topic.
// The orderID is used as the partition key so all events for one order
// land on the same partition — preserving order.
func (c *Client) Publish(ctx context.Context, topic, orderID string, payload any) error {
	b, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal event: %w", err)
	}

	record := &kgo.Record{
		Topic: topic,
		Key:   []byte(orderID), // partition key = orderID
		Value: b,
	}

	// ProduceSync blocks until the broker acknowledges the write.
	if err := c.kgo.ProduceSync(ctx, record).FirstErr(); err != nil {
		return fmt.Errorf("kafka produce to %s: %w", topic, err)
	}

	logger.L.Debug("published event", zap.String("topic", topic), zap.String("order_id", orderID))
	return nil
}

// MessageHandler is the callback signature for Subscribe.
// Returning an error prevents the offset from being committed (message redelivered).
type MessageHandler func(ctx context.Context, topic string, value []byte) error

// Subscribe polls Kafka and calls handler for each message.
// It runs until ctx is cancelled. On handler success it commits the offset.
// On handler error it logs the failure but continues so other messages aren't blocked.
func (c *Client) Subscribe(ctx context.Context, handler MessageHandler) error {
	for {
		// PollFetches blocks until records are available or ctx is done
		fetches := c.kgo.PollFetches(ctx)
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if errs := fetches.Errors(); len(errs) > 0 {
			for _, e := range errs {
				logger.L.Error("kafka fetch error",
					zap.String("topic", e.Topic),
					zap.Int32("partition", e.Partition),
					zap.Error(e.Err),
				)
			}
		}

		fetches.EachRecord(func(r *kgo.Record) {
			if err := handler(ctx, r.Topic, r.Value); err != nil {
				logger.L.Error("handler error — message will NOT be committed",
					zap.String("topic", r.Topic),
					zap.String("key", string(r.Key)),
					zap.Error(err),
				)
				return // offset not committed → message redelivered
			}
			// Commit this specific offset
			if err := c.kgo.CommitRecords(ctx, r); err != nil {
				logger.L.Error("commit failed", zap.Error(err))
			}
		})
	}
}

func (c *Client) Close() {
	c.kgo.Close()
}
