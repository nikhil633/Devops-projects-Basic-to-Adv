use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use prometheus::TextEncoder;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use crate::{AppState, metrics};

#[derive(Deserialize)]
pub struct CheckRequest {
    pub key: String,
    pub limit: u64,
    pub window_secs: u64,
}

#[derive(Serialize)]
pub struct CheckResponse {
    pub allowed: bool,
    pub current_count: u64,
    pub limit: u64,
    pub remaining: u64,
}

#[derive(Serialize)]
pub struct StatsResponse {
    pub key: String,
    pub current_count: u64,
}

pub async fn health() -> impl IntoResponse {
    Json(serde_json::json!({ "status": "ok" }))
}

pub async fn metrics_handler() -> impl IntoResponse {
    let encoder = TextEncoder::new();
    let families = prometheus::gather();
    let body = encoder.encode_to_string(&families).unwrap_or_default();
    (StatusCode::OK, body)
}

pub async fn check(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CheckRequest>,
) -> impl IntoResponse {
    let count = state
        .store
        .increment_and_expire(&req.key, req.window_secs)
        .await
        .unwrap_or(0);

    let allowed = count <= req.limit;
    metrics::RATE_CHECK_TOTAL
        .with_label_values(&[if allowed { "allowed" } else { "denied" }])
        .inc();

    let remaining = if allowed { req.limit - count } else { 0 };

    let status = if allowed { StatusCode::OK } else { StatusCode::TOO_MANY_REQUESTS };
    (status, Json(CheckResponse {
        allowed,
        current_count: count,
        limit: req.limit,
        remaining,
    }))
}

pub async fn stats(
    State(state): State<Arc<AppState>>,
    Path(key): Path<String>,
) -> impl IntoResponse {
    let count = state.store.get_count(&key).await.unwrap_or(0);
    Json(StatsResponse { key, current_count: count })
}
