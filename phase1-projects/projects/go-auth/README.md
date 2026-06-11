# Auth Service — Go + Gin + JWT + Redis

## Local setup
```bash
go mod tidy
docker run -d -p 6379:6379 redis:7-alpine
make run
```

## Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | /auth/login | Get access + refresh token |
| POST | /auth/refresh | Refresh access token |
| POST | /auth/validate | Validate an access token |
| POST | /auth/logout | Revoke refresh token |
| GET | /health | Health check |
| GET | /metrics | Prometheus metrics |

## Demo credentials
username: `admin` / password: `password`

## Environment variables
| Variable | Default | Description |
|----------|---------|-------------|
| REDIS_URL | redis://localhost:6379 | Redis connection |
| JWT_SECRET | supersecretkey | JWT signing secret |
| PORT | 8080 | HTTP port |
