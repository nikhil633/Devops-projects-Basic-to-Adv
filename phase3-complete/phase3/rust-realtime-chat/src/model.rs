// model.rs — shared data types

use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub id:        String,
    pub room_id:   String,
    pub user_id:   String,
    pub username:  String,
    pub content:   String,
    pub timestamp: u64,
    /// "message" | "join" | "leave" | "system"
    pub kind:      String,
}

impl ChatMessage {
    pub fn new(room_id: &str, user_id: &str, username: &str, content: &str, kind: &str) -> Self {
        Self {
            id:        uuid::Uuid::new_v4().to_string(),
            room_id:   room_id.to_string(),
            user_id:   user_id.to_string(),
            username:  username.to_string(),
            content:   content.to_string(),
            timestamp: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            kind: kind.to_string(),
        }
    }

    pub fn system(room_id: &str, content: &str) -> Self {
        Self::new(room_id, "system", "System", content, "system")
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Room {
    pub id:          String,
    pub name:        String,
    pub description: String,
    pub created_at:  u64,
}

impl Room {
    pub fn new(name: &str, description: &str) -> Self {
        Self {
            id:          uuid::Uuid::new_v4().to_string(),
            name:        name.to_string(),
            description: description.to_string(),
            created_at:  SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs(),
        }
    }
}

/// Message sent from the client over WebSocket
#[derive(Debug, Deserialize)]
pub struct ClientMessage {
    pub content:  String,
    pub username: String,
    pub user_id:  String,
}
