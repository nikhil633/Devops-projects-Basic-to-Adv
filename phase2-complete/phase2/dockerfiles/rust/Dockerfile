# ─── Stage 1: chef (dependency caching) ──────────────────────────────────
# cargo-chef caches Rust dependencies across builds — without it every
# source change re-downloads and re-compiles all crates (can take 5+ min)
FROM lukemathwalker/cargo-chef:latest-rust-1.78 AS chef
WORKDIR /app

# ─── Stage 2: planner ─────────────────────────────────────────────────────
FROM chef AS planner
COPY . .
# Generates a recipe.json that describes which crates to compile
RUN cargo chef prepare --recipe-path recipe.json

# ─── Stage 3: builder ─────────────────────────────────────────────────────
FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json

# Build dependencies first — this layer is only re-run when Cargo.toml changes
RUN cargo chef cook --release --recipe-path recipe.json

# Now copy source and build the real binary
COPY . .
RUN cargo test --release
RUN cargo build --release --bin rate-limiter

# ─── Stage 4: runtime ─────────────────────────────────────────────────────
# scratch is literally an empty image — nothing but the binary
# Works because the Rust binary is statically linked (musl target not needed
# here since we use the default glibc and copy it in)
FROM debian:bookworm-slim AS runtime

# Install only CA certs (needed for TLS to Redis) and nothing else
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd --uid 10001 --no-create-home appuser
USER appuser

COPY --from=builder /app/target/release/rate-limiter /usr/local/bin/rate-limiter

EXPOSE 9000

ENTRYPOINT ["rate-limiter"]
