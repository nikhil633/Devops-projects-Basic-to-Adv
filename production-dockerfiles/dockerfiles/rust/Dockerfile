# ============================================================
# Rust — Production Dockerfile
# ============================================================
# Uses cargo-chef for dependency caching.
# Without cargo-chef: every source change recompiles ALL crates (5–15 min).
# With cargo-chef:    only YOUR code recompiles on source changes (~30 sec).
#
# How cargo-chef works:
#   1. planner:  analyse Cargo.toml + Cargo.lock → generate recipe.json
#   2. builder:  cook recipe.json (compile dependencies only)
#   3. builder:  compile your code on top of cached deps
#   4. runtime:  copy just the binary into a minimal image
#
# Build:  docker build -t my-rust-app .
# Run:    docker run -p 8080:8080 my-rust-app
# ============================================================

# ── Stage 1: planner ──────────────────────────────────────
# cargo-chef analyses your workspace and produces a dependency recipe
FROM lukemathwalker/cargo-chef:latest-rust-1.78 AS planner

WORKDIR /app

# Only copy Cargo files — no source needed for planning
COPY Cargo.toml Cargo.lock ./
# For workspaces with multiple crates:
# COPY crate-a/Cargo.toml crate-a/
# COPY crate-b/Cargo.toml crate-b/

# Analyse the dependency graph
RUN cargo chef prepare --recipe-path recipe.json


# ── Stage 2: dependency build (cached layer) ───────────────
FROM lukemathwalker/cargo-chef:latest-rust-1.78 AS chef

WORKDIR /app

COPY --from=planner /app/recipe.json recipe.json

# Compile ALL dependencies in release mode.
# This layer is only re-run when Cargo.toml or Cargo.lock changes.
# On every other build (source change only), this is a cache hit.
RUN cargo chef cook --release --recipe-path recipe.json


# ── Stage 3: build ────────────────────────────────────────
FROM chef AS builder

WORKDIR /app

# Copy source code (dependencies are already compiled above)
COPY . .

# Run tests before building the release binary
RUN cargo test --release

# Build the release binary
# --release: enable all optimisations (important for production performance)
RUN cargo build --release --bin my-rust-app
#                                  ↑ Change to your binary name (from [[bin]] in Cargo.toml)


# ── Stage 4: runtime ──────────────────────────────────────
# debian:bookworm-slim is used instead of scratch/distroless
# because Rust's default target uses glibc.
# For a scratch-compatible binary, use the musl target:
#   RUN rustup target add x86_64-unknown-linux-musl
#   RUN cargo build --release --target x86_64-unknown-linux-musl
#   Then use FROM scratch and copy the musl binary.
FROM debian:bookworm-slim AS runtime

# Install only what's needed at runtime
# ca-certificates: TLS certificate verification
# libssl3: OpenSSL (if your app uses TLS/HTTPS)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      libssl3 \
 && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd --uid 10001 --no-create-home --shell /bin/false appuser
USER appuser

COPY --from=builder /app/target/release/my-rust-app /usr/local/bin/server
#                                            ↑ Match your binary name

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["server"]
