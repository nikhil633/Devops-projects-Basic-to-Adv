mod handler;
mod store;
mod metrics;

use axum::{Router, routing::{get, post}};
use std::sync::Arc;
use tokio::net::TcpListener;
use tracing_subscriber::fmt;

pub struct AppState {
    pub store: store::RedisStore,
}

#[tokio::main]
async fn main() {
    fmt::init();

    let redis_url = std::env::var("REDIS_URL").unwrap_or("redis://127.0.0.1:6379".into());
    let port = std::env::var("PORT").unwrap_or("9000".into());

    let store = store::RedisStore::new(&redis_url).await.expect("Redis connect failed");
    let state = Arc::new(AppState { store });

    metrics::register_metrics();

    let app = Router::new()
        .route("/health", get(handler::health))
        .route("/metrics", get(handler::metrics_handler))
        .route("/check", post(handler::check))
        .route("/stats/:key", get(handler::stats))
        .with_state(state);

    let addr = format!("0.0.0.0:{}", port);
    tracing::info!("Rate limiter listening on {}", addr);
    let listener = TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
