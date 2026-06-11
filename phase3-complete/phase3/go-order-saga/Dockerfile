# ── Stage 1: build ────────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Cache dependencies first (only re-downloads when go.mod/go.sum change)
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build a statically-linked binary
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s" \
    -o /order-saga \
    ./cmd/server

# ── Stage 2: run ──────────────────────────────────────────────────────────
# distroless/static has no shell — smallest possible attack surface
FROM gcr.io/distroless/static:nonroot

COPY --from=builder /order-saga /order-saga

EXPOSE 8080

ENTRYPOINT ["/order-saga"]
