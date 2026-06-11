# Real-time Chat — Rust + Axum + WebSocket + Redis

## Architecture

```
Client A ──WebSocket──► Pod 1 ──► Hub (broadcast channel)
                                      │
                               Redis pub/sub ──► Pod 2 ──► Hub ──WebSocket──► Client B
                                      │
                               Redis stream (history)
```

Every message is:
1. Persisted to a Redis Stream (last 500 messages per room, survives restarts)
2. Published to Redis pub/sub (reaches users on other pods)
3. Broadcast to local hub (reaches users on the same pod instantly)

New joiners automatically receive the last 50 messages as history.

## Run locally

```bash
# Start 2 app instances + Redis
make up

# Create a room
curl -X POST http://localhost:7000/rooms \
  -H "Content-Type: application/json" \
  -d '{"name":"general","description":"General chat"}'
# → {"id":"abc-123",...}

# Connect client 1 (on pod 1)
websocat ws://localhost:7000/rooms/abc-123/ws

# Connect client 2 (on pod 2 — different instance!)
websocat ws://localhost:7001/rooms/abc-123/ws

# Send a message from client 1 — client 2 receives it via Redis pub/sub
{"user_id":"u1","username":"Alice","content":"Hello from pod 1!"}
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /rooms | Create a room |
| GET | /rooms | List all rooms |
| GET | /rooms/:id/ws | WebSocket connection |
| GET | /rooms/:id/history | Last 50 messages |
| GET | /health | Health check |
| GET | /metrics | Prometheus metrics |

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| REDIS_URL | redis://127.0.0.1:6379 | Redis connection |
| PORT | 7000 | HTTP/WS port |
| RUST_LOG | info | Log level |

## Key concepts

**Why broadcast channels?**
`tokio::sync::broadcast` delivers every message to ALL receivers.
One send, N receives — perfect for chat rooms.

**Why Redis Streams over lists?**
Streams support consumer groups, range queries, and auto-trimming (MAXLEN).
`XREVRANGE + - COUNT 50` fetches the last 50 messages in one command.

**Why two Redis connections?**
pub/sub connections can only subscribe — they cannot issue regular commands.
We use a separate connection pool for GET/SET and a dedicated pub/sub connection.
