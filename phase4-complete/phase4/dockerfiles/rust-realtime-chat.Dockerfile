# dockerfiles/rust-realtime-chat.Dockerfile
# Same cargo-chef pattern as Phase 1 Rust Dockerfile
FROM lukemathwalker/cargo-chef:latest-rust-1.78 AS chef
WORKDIR /app

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json
COPY . .
RUN cargo test --release
RUN cargo build --release --bin realtime-chat

FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN useradd --uid 10001 --no-create-home appuser
USER appuser
COPY --from=builder /app/target/release/realtime-chat /usr/local/bin/realtime-chat
EXPOSE 7000
ENTRYPOINT ["realtime-chat"]
