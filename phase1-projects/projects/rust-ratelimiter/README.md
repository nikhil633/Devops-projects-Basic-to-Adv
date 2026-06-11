# Rate Limiter — Rust + Axum + Redis

## Local setup
```bash
docker run -d -p 6379:6379 redis:7-alpine
make run
```

## Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | /check | Check if request is allowed |
| GET | /stats/:key | Get current count for a key |
| GET | /health | Health check |
| GET | /metrics | Prometheus metrics |

## POST /check body
```json
{ "key": "user:123", "limit": 10, "window_secs": 60 }
```
Returns 200 (allowed) or 429 (rate limited).

## Environment variables
| Variable | Default | Description |
|----------|---------|-------------|
| REDIS_URL | redis://127.0.0.1:6379 | Redis connection |
| PORT | 9000 | HTTP port |
