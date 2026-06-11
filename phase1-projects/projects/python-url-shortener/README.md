# URL Shortener — FastAPI + Redis

## Local setup
```bash
pip install -r requirements.txt
# start Redis first
docker run -d -p 6379:6379 redis:7-alpine
make run
```

## Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | /shorten | Create a short URL |
| GET | /{code} | Redirect to original URL |
| GET | /health | Health check |
| GET | /metrics | Prometheus metrics |

## Environment variables
| Variable | Default | Description |
|----------|---------|-------------|
| REDIS_URL | redis://localhost:6379 | Redis connection string |

## Run with Docker
```bash
make up
```
