// hub.rs — in-memory message broker
//
// The Hub holds one tokio broadcast channel per room.
// When a WebSocket connection joins a room it calls hub.subscribe(room_id)
// to get a Receiver. When it wants to send a message it calls hub.publish().
//
// broadcast::channel is perfect here:
//   - Multiple receivers (all users in a room) get every message
//   - Sender::send() is O(1) regardless of subscriber count
//   - Lagged receivers get an error and can reconnect — no memory buildup

use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
};
use tokio::sync::broadcast;
use crate::model::ChatMessage;

const CHANNEL_CAPACITY: usize = 256;

#[derive(Clone)]
pub struct Hub {
    // room_id → broadcast sender
    rooms: Arc<Mutex<HashMap<String, broadcast::Sender<ChatMessage>>>>,
}

impl Hub {
    pub fn new() -> Self {
        Self {
            rooms: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Returns a Receiver for the given room, creating the channel if needed.
    pub fn subscribe(&self, room_id: &str) -> broadcast::Receiver<ChatMessage> {
        let mut rooms = self.rooms.lock().unwrap();
        rooms
            .entry(room_id.to_string())
            .or_insert_with(|| broadcast::channel(CHANNEL_CAPACITY).0)
            .subscribe()
    }

    /// Broadcast a message to all local subscribers of a room.
    /// Returns the number of receivers that got the message.
    pub fn publish(&self, room_id: &str, msg: ChatMessage) -> usize {
        let rooms = self.rooms.lock().unwrap();
        if let Some(tx) = rooms.get(room_id) {
            tx.send(msg).unwrap_or(0)
        } else {
            0
        }
    }

    /// List all room IDs that have at least one active subscriber.
    pub fn active_rooms(&self) -> Vec<String> {
        let rooms = self.rooms.lock().unwrap();
        rooms
            .iter()
            .filter(|(_, tx)| tx.receiver_count() > 0)
            .map(|(id, _)| id.clone())
            .collect()
    }

    /// Total active WebSocket connections across all rooms.
    pub fn connection_count(&self) -> usize {
        let rooms = self.rooms.lock().unwrap();
        rooms.values().map(|tx| tx.receiver_count()).sum()
    }
}
