# ============================================================
# Go — Production Dockerfile
# ============================================================
# Final image: distroless/static — no shell, no libc, no OS tools.
# The Go binary is fully statically linked so it needs nothing.
# Image size: ~10–20MB (vs 200MB+ for Ubuntu-based images).
# Attack surface: near zero (nothing to exploit except your binary).
#
# Build:  docker build -t my-go-app .
# Run:    docker run -p 8080:8080 my-go-app
# ============================================================

# ── Stage 1: build ────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Download modules before copying source.
# go.mod + go.sum define exact dependency versions.
# This layer only re-runs when go.mod or go.sum changes.
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy source and build
COPY . .

# Run tests inside the build — broken code never ships
RUN go test ./... -v -race -timeout 60s

# Build a statically linked binary
# CGO_ENABLED=0  : disable C bindings — produces a static binary
# GOOS=linux     : target OS (even if building on macOS)
# GOARCH=amd64   : target architecture (change to arm64 for ARM)
# -ldflags       : linker flags
#   -w            : omit DWARF debug symbols (smaller binary)
#   -s            : omit symbol table (smaller binary)
# -trimpath      : remove local file paths from binary (reproducible builds)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
      -ldflags="-w -s" \
      -trimpath \
      -o /app/server \
      ./cmd/server
#   ↑ Change ./cmd/server to your actual main package path


# ── Stage 2: runtime ──────────────────────────────────────
# distroless/static:nonroot
#   - No shell (/bin/sh doesn't exist) — no exec attacks
#   - No package manager — nothing to install malware with
#   - Runs as UID 65532 (nonroot) by default
#   - Only contains: CA certificates, /etc/passwd, /etc/os-release
FROM gcr.io/distroless/static:nonroot AS runtime

# Copy the statically linked binary
COPY --from=builder /app/server /server

EXPOSE 8080

USER nonroot:nonroot

# No HEALTHCHECK here — distroless has no wget/curl.
# Use Kubernetes liveness/readiness probes instead (HTTP probes don't need
# a shell — kubelet makes the HTTP request directly).

ENTRYPOINT ["/server"]
