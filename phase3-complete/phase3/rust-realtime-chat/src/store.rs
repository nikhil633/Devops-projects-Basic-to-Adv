// store.rs — Redis-backed persistence and pub/sub
//
// Two Redis features used here:
//
// 1. Pub/Sub  ("chat:room:<id>")
//    When pod A receives a message, it publishes to Redis.
//    Pod B (which has its own subscribers) gets the message via Redis
//    and forwards it to its local Hub. This is the cross-pod fan-out.
//
// 2. Streams  ("stream:room:<id>")
//    Every message is XADD'd to a stream with a capped length (MAXLEN 500).
//    When a new user joins, XRANGE fetches the last N messages as history.
//    Streams are persistent — survive Redis restarts (with AOF/RDB).

use redis::{AsyncCommands, Client, RedisError};
use serde_json;
use tracing::{error, info};

use crate::{hub::Hub, model::{ChatMessage, Room}};

const HISTORY_MAX_LEN: usize = 500;
const HISTORY_FETCH:   usize = 50;

#[derive(Clone)]
pub struct RedisStore {
    client: Client,
}

impl RedisStore {
    pub async fn new(url: &str) -> Result<Self, RedisError> {
        let client = Client::open(url)?;
        // Test connection
        let mut conn = client.get_multiplexed_async_connection().await?;
        redis::cmd("PING").query_async::<String>(&mut conn).await?;
        info!("Connected to Redis at {}", url);
        Ok(Self { client })
    }

    // ── Rooms ──────────────────────────────────────────────────────────────

    pub async fn save_room(&self, room: &Room) -> redis::RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let json = serde_json::to_string(room).unwrap();
        conn.hset("rooms", &room.id, json).await?;
        Ok(())
    }

    pub async fn list_rooms(&self) -> redis::RedisResult<Vec<Room>> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let map: std::collections::HashMap<String, String> =
            conn.hgetall("rooms").await?;
        let rooms = map
            .values()
            .filter_map(|v| serde_json::from_str(v).ok())
            .collect();
        Ok(rooms)
    }

    pub async fn get_room(&self, room_id: &str) -> redis::RedisResult<Option<Room>> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let raw: Option<String> = conn.hget("rooms", room_id).await?;
        Ok(raw.and_then(|v| serde_json::from_str(&v).ok()))
    }

    // ── Message history (Redis Streams) ────────────────────────────────────

    /// Append a message to the room's stream, capped at HISTORY_MAX_LEN
    pub async fn append_message(&self, msg: &ChatMessage) -> redis::RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = format!("stream:room:{}", msg.room_id);
        let json = serde_json::to_string(msg).unwrap();

        // XADD stream:room:<id> MAXLEN ~ 500 * content <json>
        redis::cmd("XADD")
            .arg(&key)
            .arg("MAXLEN")
            .arg("~")
            .arg(HISTORY_MAX_LEN)
            .arg("*")            // auto-generate stream ID
            .arg("content")
            .arg(&json)
            .query_async::<String>(&mut conn)
            .await?;

        Ok(())
    }

    /// Fetch the last N messages from the room's stream
    pub async fn get_history(&self, room_id: &str, count: usize)
        -> redis::RedisResult<Vec<ChatMessage>>
    {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = format!("stream:room:{}", room_id);
        let n = count.min(HISTORY_MAX_LEN);

        // XREVRANGE key + - COUNT n  → most recent N, newest-first
        let entries: Vec<(String, Vec<(String, String)>)> = redis::cmd("XREVRANGE")
            .arg(&key)
            .arg("+")
            .arg("-")
            .arg("COUNT")
            .arg(n)
            .query_async(&mut conn)
            .await
            .unwrap_or_default();

        let mut msgs: Vec<ChatMessage> = entries
            .iter()
            .filter_map(|(_, fields)| {
                fields.iter()
                    .find(|(k, _)| k == "content")
                    .and_then(|(_, v)| serde_json::from_str(v).ok())
            })
            .collect();

        // Return in chronological order (oldest first)
        msgs.reverse();
        Ok(msgs)
    }

    // ── Pub/Sub cross-instance fan-out ─────────────────────────────────────

    /// Publish a message to Redis so other pods pick it up
    pub async fn publish_message(&self, msg: &ChatMessage) -> redis::RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let channel = format!("chat:room:{}", msg.room_id);
        let json = serde_json::to_string(msg).unwrap();
        conn.publish::<_, _, i64>(&channel, &json).await?;
        Ok(())
    }

    /// Subscribe to ALL room channels and forward messages into the local Hub.
    /// Runs forever — intended to be spawned as a background task.
    pub async fn subscribe_and_forward(&self, hub: Hub) {
        let mut pubsub_conn = match self.client.get_async_pubsub().await {
            Ok(c) => c,
            Err(e) => {
                error!("Failed to get pubsub connection: {}", e);
                return;
            }
        };

        // Subscribe to pattern "chat:room:*" — catches all rooms
        if let Err(e) = pubsub_conn.psubscribe("chat:room:*").await {
            error!("psubscribe failed: {}", e);
            return;
        }

        info!("Redis pub/sub listener started (pattern: chat:room:*)");

        use futures_util::StreamExt;
        let mut stream = pubsub_conn.into_on_message();

        while let Some(redis_msg) = stream.next().await {
            let payload: String = match redis_msg.get_payload() {
                Ok(p) => p,
                Err(_) => continue,
            };

            let msg: ChatMessage = match serde_json::from_str(&payload) {
                Ok(m) => m,
                Err(e) => {
                    error!("Failed to deserialise pub/sub message: {}", e);
                    continue;
                }
            };

            // Forward into local hub (reaches all WebSocket connections on this pod)
            hub.publish(&msg.room_id.clone(), msg);
        }
    }

    /// Fetch history (convenience wrapper used by the HTTP handler)
    pub async fn room_history(&self, room_id: &str) -> Vec<ChatMessage> {
        self.get_history(room_id, HISTORY_FETCH)
            .await
            .unwrap_or_default()
    }
}
