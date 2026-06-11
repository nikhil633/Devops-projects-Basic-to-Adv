# Notification Service — Node.js + Express + Redis

## Local setup
```bash
npm install
docker run -d -p 6379:6379 redis:7-alpine
npm start
```

## Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | /notify | Enqueue a notification |
| GET | /status/:id | Get notification status |
| GET | /health | Health check |
| GET | /metrics | Prometheus metrics |

## Request body for POST /notify
```json
{ "type": "email", "recipient": "user@example.com", "message": "Hello!" }
```

## Environment variables
| Variable | Default | Description |
|----------|---------|-------------|
| REDIS_URL | redis://localhost:6379 | Redis connection string |
| PORT | 3000 | HTTP port |
| LOG_LEVEL | info | Pino log level |
