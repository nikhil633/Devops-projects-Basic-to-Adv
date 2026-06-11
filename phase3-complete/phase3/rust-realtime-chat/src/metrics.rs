// metrics.rs
use prometheus::{IntCounter, IntGauge, Opts, Registry};
use std::sync::LazyLock;

pub static ACTIVE_CONNECTIONS: LazyLock<IntGauge> = LazyLock::new(|| {
    IntGauge::new("chat_active_connections", "Active WebSocket connections").unwrap()
});

pub static MESSAGES_SENT: LazyLock<IntCounter> = LazyLock::new(|| {
    IntCounter::new("chat_messages_sent_total", "Total chat messages sent").unwrap()
});

pub static ROOMS_CREATED: LazyLock<IntCounter> = LazyLock::new(|| {
    IntCounter::new("chat_rooms_created_total", "Total rooms created").unwrap()
});

pub fn register_metrics() {
    let r = prometheus::default_registry();
    r.register(Box::new(ACTIVE_CONNECTIONS.clone())).ok();
    r.register(Box::new(MESSAGES_SENT.clone())).ok();
    r.register(Box::new(ROOMS_CREATED.clone())).ok();
}
