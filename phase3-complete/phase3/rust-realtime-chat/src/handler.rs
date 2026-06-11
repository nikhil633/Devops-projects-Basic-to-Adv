// handler.rs — HTTP routes + WebSocket upgrade
//
// WebSocket flow per connection:
//   1. Client GET /rooms/:id/ws   → Axum upgrades to WebSocket
//   2. Handler subscribes to hub (gets a broadcast::Receiver)
//   3. Two concurrent tasks spin up:
//        read_task:  reads frames from the client → publishes to Redis + hub
//        write_task: reads from hub Receiver       → sends frames to client
//   4. When either task finishes (client disconnects / error), both are cancelled
//
// This gives us full-duplex messaging without blocking.

use axum::{
    extract::{Path, State, WebSocketUpgrade, ws::{WebSocket, Message}},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use futures_util::{SinkExt, StreamExt};
use prometheus::TextEncoder;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::select;
use tracing::{error, info, warn};

use crate::{
    AppState,
    metrics,
    model::{ChatMessage, ClientMessage, Room},
};

// ── REST handlers ──────────────────────────────────────────────────────────

pub async fn health() -> impl IntoResponse {
    Json(serde_json::json!({
        "status": "ok",
        "connections": 0  // real value injected below via state
    }))
}

pub async fn metrics_handler() -> impl IntoResponse {
    let encoder = TextEncoder::new();
    let body = encoder.encode_to_string(&prometheus::gather()).unwrap_or_default();
    (StatusCode::OK, body)
}

#[derive(Deserialize)]
pub struct CreateRoomRequest {
    pub name:        String,
    pub description: String,
}

pub async fn create_room(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CreateRoomRequest>,
) -> impl IntoResponse {
    if req.name.trim().is_empty() {
        return (StatusCode::BAD_REQUEST,
            Json(serde_json::json!({"error": "name is required"}))).into_response();
    }

    let room = Room::new(&req.name, &req.description);
    if let Err(e) = state.store.save_room(&room).await {
        error!("Failed to save room: {}", e);
        return (StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": "could not create room"}))).into_response();
    }

    metrics::ROOMS_CREATED.inc();
    info!("Room created: {} ({})", room.name, room.id);
    (StatusCode::CREATED, Json(room)).into_response()
}

pub async fn list_rooms(State(state): State<Arc<AppState>>) -> impl IntoResponse {
    match state.store.list_rooms().await {
        Ok(rooms) => Json(rooms).into_response(),
        Err(e) => {
            error!("list_rooms error: {}", e);
            StatusCode::INTERNAL_SERVER_ERROR.into_response()
        }
    }
}

pub async fn room_history(
    State(state): State<Arc<AppState>>,
    Path(room_id): Path<String>,
) -> impl IntoResponse {
    let history = state.store.room_history(&room_id).await;
    Json(history)
}

// ── WebSocket handler ──────────────────────────────────────────────────────

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    Path(room_id): Path<String>,
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    // Verify room exists before upgrading
    match state.store.get_room(&room_id).await {
        Ok(Some(_)) => {}
        Ok(None) => return StatusCode::NOT_FOUND.into_response(),
        Err(e) => {
            error!("get_room error: {}", e);
            return StatusCode::INTERNAL_SERVER_ERROR.into_response();
        }
    }

    ws.on_upgrade(move |socket| handle_socket(socket, room_id, state))
}

async fn handle_socket(socket: WebSocket, room_id: String, state: Arc<AppState>) {
    metrics::ACTIVE_CONNECTIONS.inc();
    info!("WebSocket connected to room {}", room_id);

    // Send message history to the new joiner
    let history = state.store.room_history(&room_id).await;
    let (mut sender, mut receiver) = socket.split();

    for msg in &history {
        if let Ok(json) = serde_json::to_string(msg) {
            let _ = sender.send(Message::Text(json.into())).await;
        }
    }

    // Subscribe to hub AFTER sending history so we don't miss live messages
    let mut hub_rx = state.hub.subscribe(&room_id);

    // ── write task: hub → WebSocket ──────────────────────────────────────
    let room_id_write = room_id.clone();
    let mut write_task = tokio::spawn(async move {
        loop {
            match hub_rx.recv().await {
                Ok(msg) => {
                    if let Ok(json) = serde_json::to_string(&msg) {
                        if sender.send(Message::Text(json.into())).await.is_err() {
                            break; // client disconnected
                        }
                    }
                }
                Err(tokio::sync::broadcast::error::RecvError::Lagged(n)) => {
                    warn!("Room {} receiver lagged by {} messages", room_id_write, n);
                }
                Err(_) => break,
            }
        }
    });

    // ── read task: WebSocket → hub + Redis ───────────────────────────────
    let state_read = state.clone();
    let room_id_read = room_id.clone();
    let mut read_task = tokio::spawn(async move {
        while let Some(Ok(frame)) = receiver.next().await {
            match frame {
                Message::Text(text) => {
                    let client_msg: ClientMessage = match serde_json::from_str(&text) {
                        Ok(m) => m,
                        Err(_) => {
                            warn!("Invalid message from client: {}", text);
                            continue;
                        }
                    };

                    let chat_msg = ChatMessage::new(
                        &room_id_read,
                        &client_msg.user_id,
                        &client_msg.username,
                        &client_msg.content,
                        "message",
                    );

                    // 1. Persist to Redis stream
                    let _ = state_read.store.append_message(&chat_msg).await;

                    // 2. Fan-out to other pods via Redis pub/sub
                    let _ = state_read.store.publish_message(&chat_msg).await;

                    // 3. Broadcast to local hub (reaches connections on THIS pod)
                    state_read.hub.publish(&room_id_read, chat_msg);

                    metrics::MESSAGES_SENT.inc();
                }
                Message::Close(_) => break,
                Message::Ping(p) => {
                    // Axum handles pong automatically, but we can log
                    let _ = p; // suppress unused warning
                }
                _ => {}
            }
        }
    });

    // Wait for either task to finish (disconnect or error)
    select! {
        _ = &mut write_task => read_task.abort(),
        _ = &mut read_task  => write_task.abort(),
    }

    metrics::ACTIVE_CONNECTIONS.dec();
    info!("WebSocket disconnected from room {}", room_id);
}
