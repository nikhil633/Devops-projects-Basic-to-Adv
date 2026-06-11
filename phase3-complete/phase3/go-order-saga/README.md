# Order Processing Saga — Go + Gin + Kafka + Redis

## What this service does

This implements the **Saga orchestration pattern** for distributed order processing.

A saga is a sequence of local transactions, each publishing an event to trigger
the next step. If any step fails, **compensating transactions** undo the
previous steps — like a distributed rollback without a 2-phase commit.

---

## Saga state machine

```
                        ┌─────────────┐
                        │   PENDING   │  ← order.created published
                        └──────┬──────┘
                               │
                    [inventory worker]
                               │
             ┌─────────────────┴──────────────────┐
             │ stock.reserved                      │ stock.reserve.failed
             ▼                                     ▼
    ┌──────────────────┐                  ┌──────────────┐
    │ RESERVING_STOCK  │                  │  CANCELLED   │
    └────────┬─────────┘                  └──────────────┘
             │
     [payment worker]
             │
    ┌────────┴────────────────────────────┐
    │ payment.processed                   │ payment.failed
    ▼                                     ▼
┌──────────────────────┐        ┌──────────────────────────────────┐
│ PROCESSING_PAYMENT   │        │  Compensating tx:                │
└──────────┬───────────┘        │  publish stock.released          │
           │                    │  → CANCELLED                     │
  [fulfillment worker]          └──────────────────────────────────┘
           │
           ▼
    ┌─────────────┐
    │  FULFILLING │
    └──────┬──────┘
           │ order.fulfilled
           ▼
    ┌─────────────┐
    │  COMPLETED  │  ← saga done ✓
    └─────────────┘
```

---

## Project structure

```
go-order-saga/
├── cmd/server/
│   └── main.go                  # entrypoint — wires HTTP + orchestrator
├── internal/
│   ├── handler/
│   │   └── handler.go           # REST API (POST /orders, GET /orders/:id)
│   ├── saga/
│   │   ├── orchestrator.go      # saga brain — reacts to Kafka events
│   │   └── orchestrator_test.go # state machine + serialisation tests
│   ├── kafka/
│   │   └── client.go            # Kafka producer + consumer wrappers
│   ├── store/
│   │   └── order_store.go       # Redis persistence
│   └── model/
│       └── order.go             # Order aggregate + state machine
├── pkg/
│   ├── events/
│   │   └── events.go            # all Kafka event structs + topic constants
│   └── logger/
│       └── logger.go            # zap structured logger
├── Dockerfile                   # multi-stage distroless build
├── docker-compose.yml           # app + Kafka (KRaft) + Redis + Kafka UI
├── Makefile
└── go.mod
```

---

## How to run

### Full stack with Docker Compose
```bash
make up
# wait ~20 seconds for Kafka to be ready
```

Open **Kafka UI** at http://localhost:8090 to watch events flow in real time.

### Test the three scenarios

```bash
# 1. Happy path — order total $100, should COMPLETE
make test-order-success

# 2. Payment failure — order total $750 (> $500 limit), stock gets released
make test-order-payment-fail

# 3. Stock failure — order total $1500 (> $1000 limit), cancelled immediately
make test-order-stock-fail
```

After placing an order, grab the `order_id` from the response and poll:
```bash
curl http://localhost:8080/orders/<order_id> | jq .status
```

### Run tests
```bash
make test
```

---

## API reference

| Method | Path | Description |
|--------|------|-------------|
| POST | /orders | Place a new order |
| GET | /orders | List all orders |
| GET | /orders/:id | Get order + current saga status |
| GET | /health | Liveness probe |
| GET | /metrics | Prometheus metrics |

### POST /orders body
```json
{
  "customer_id": "cust-001",
  "items": [
    { "product_id": "prod-A", "quantity": 2, "unit_price": 49.99 }
  ]
}
```

### Response
```json
{
  "order_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "PENDING",
  "total_price": 99.98,
  "message": "order accepted — processing asynchronously"
}
```

---

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| REDIS_URL | redis://localhost:6379 | Redis connection string |
| KAFKA_BROKERS | localhost:9092 | Comma-separated broker list |
| PORT | 8080 | HTTP port |
| LOG_LEVEL | info | `info` or `debug` |

---

## Key concepts demonstrated

**Saga orchestration** — one central orchestrator (this service) drives all
steps vs. choreography where services react to each other's events.

**Compensating transactions** — when payment fails after stock was reserved,
the orchestrator publishes `stock.released` to undo the reservation.
This is the distributed equivalent of a rollback.

**Idempotency** — the state machine's `Transition()` method rejects invalid
or duplicate state changes, so replaying a Kafka message is safe.

**Partition key = OrderID** — all events for the same order land on the same
Kafka partition, guaranteeing message ordering per order.

**Manual offset commit** — the Kafka consumer only commits an offset after the
handler returns nil. If the handler errors, the message is redelivered.
