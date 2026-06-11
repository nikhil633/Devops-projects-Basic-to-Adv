.PHONY: run test build up down logs tidy topics

# ── Local development ──────────────────────────────────────────────────────

run:
	go run ./cmd/server

test:
	go test ./... -v -race

tidy:
	go mod tidy

build:
	CGO_ENABLED=0 go build -ldflags="-w -s" -o bin/order-saga ./cmd/server

# ── Docker Compose ─────────────────────────────────────────────────────────

up:
	docker-compose up --build

down:
	docker-compose down -v

logs:
	docker-compose logs -f app

# ── Kafka helpers ──────────────────────────────────────────────────────────

# List all topics (run after `make up`)
topics:
	docker-compose exec kafka kafka-topics.sh \
		--bootstrap-server localhost:9092 \
		--list

# Watch all saga events flowing through Kafka in real time
watch-events:
	docker-compose exec kafka kafka-console-consumer.sh \
		--bootstrap-server localhost:9092 \
		--topic order.created \
		--from-beginning

# ── Manual test commands (run after `make up`) ─────────────────────────────

# Place a small order (< $500) — should COMPLETE
test-order-success:
	curl -s -X POST http://localhost:8080/orders \
		-H "Content-Type: application/json" \
		-d '{"customer_id":"cust-001","items":[{"product_id":"prod-A","quantity":2,"unit_price":50.00}]}' \
		| jq .

# Place an order between $500–$1000 — payment FAILS, stock compensation runs
test-order-payment-fail:
	curl -s -X POST http://localhost:8080/orders \
		-H "Content-Type: application/json" \
		-d '{"customer_id":"cust-002","items":[{"product_id":"prod-B","quantity":1,"unit_price":750.00}]}' \
		| jq .

# Place an order > $1000 — stock reservation FAILS immediately
test-order-stock-fail:
	curl -s -X POST http://localhost:8080/orders \
		-H "Content-Type: application/json" \
		-d '{"customer_id":"cust-003","items":[{"product_id":"prod-C","quantity":1,"unit_price":1500.00}]}' \
		| jq .

# List all orders
list-orders:
	curl -s http://localhost:8080/orders | jq .
