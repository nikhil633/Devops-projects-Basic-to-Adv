// main.rs — Real-time chat service
//
// Architecture:
//   HTTP layer (Axum)
//     ├── POST /rooms          create a chat room
//     ├── GET  /rooms          list rooms
//     ├── GET  /rooms/:id/ws   WebSocket upgrade — client connects here
//     └── GET  /health, /metrics
//
//   Hub (in-memory broker per instance)
//     └── Each room has a broadcast channel
//         When a message arrives on any WebSocket, it is:
//           1. Written to Redis pub/sub (fan-out to other instances)
//           2. Written to Redis stream (persistent message history)
//           3. Broadcast to all local WebSocket connections for that room
//
//   Redis
//     ├── pub/sub channel  "chat:room:<id>"  — cross-instance fan-out
//     └── stream           "stream:room:<id>" — message history (XADD/XRANGE)
//
// Why this design?
//   A single Axum instance can hold thousands of WebSocket connections in
//   async tasks — no threads per connection.
//   Redis pub/sub ensures messages reach users connected to OTHER pods.
//   The Redis stream gives new joiners the last N messages immediately.

mod handler;
mod hub;
mod model;
mod store;
mod metrics;

use std::sync::Arc;
use axum::{Router, routing::{get, post}};
use tokio::net::TcpListener;
use tracing_subscriber::fmt;

pub struct AppState {
    pub hub:   hub::Hub,
    pub store: store::RedisStore,
}

#[tokio::main]
async fn main() {
    fmt::init();

    let redis_url = std::env::var("REDIS_URL")
        .unwrap_or_else(|_| "redis://127.0.0.1:6379".into());
    let port = std::env::var("PORT").unwrap_or_else(|_| "7000".into());

    let store = store::RedisStore::new(&redis_url)
        .await
        .expect("Redis connection failed");

    let hub = hub::Hub::new();

    // Spawn a task that subscribes to Redis pub/sub and forwards
    // messages arriving from other instances into the local hub
    {
        let hub_clone   = hub.clone();
        let store_clone = store.clone();
        tokio::spawn(async move {
            store_clone.subscribe_and_forward(hub_clone).await;
        });
    }

    metrics::register_metrics();

    let state = Arc::new(AppState { hub, store });

    let app = Router::new()
        .route("/health",              get(handler::health))
        .route("/metrics",             get(handler::metrics_handler))
        .route("/rooms",               post(handler::create_room))
        .route("/rooms",               get(handler::list_rooms))
        .route("/rooms/:room_id/ws",   get(handler::ws_handler))
        .route("/rooms/:room_id/history", get(handler::room_history))
        .with_state(state);

    let addr = format!("0.0.0.0:{}", port);
    tracing::info!("Chat service listening on {}", addr);
    let listener = TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
