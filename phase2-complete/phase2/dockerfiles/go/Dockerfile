# ─── Stage 1: build ───────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Download modules before copying source (better layer caching)
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy source and run tests
COPY . .
RUN go test ./... -v -race

# Build a statically-linked binary
# CGO_ENABLED=0  — no C runtime dependency, binary works in distroless/scratch
# -w -s          — strip debug info and symbol table (smaller binary)
# -trimpath      — remove local file paths from binary (reproducible builds)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -trimpath \
    -o /app/server \
    ./cmd/server

# ─── Stage 2: runtime ─────────────────────────────────────────────────────
# distroless/static: no shell, no libc, no package manager
# The Go binary is fully static so it needs nothing from the OS
FROM gcr.io/distroless/static:nonroot

# Copy the binary from builder
COPY --from=builder /app/server /server

EXPOSE 8080

# nonroot = UID 65532 (defined by distroless)
USER nonroot:nonroot

ENTRYPOINT ["/server"]
