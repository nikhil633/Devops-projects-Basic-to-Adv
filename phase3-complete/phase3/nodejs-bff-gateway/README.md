# BFF API Gateway — Node.js + GraphQL + Apollo Server

## What it does

Instead of the frontend calling 5 microservices directly, it calls ONE endpoint.
The gateway fans out to the relevant services, caches results in Redis,
and returns exactly what the frontend needs.

```
Frontend ──► GraphQL Query ──► BFF Gateway
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
               go-auth       java-inventory   nodejs-notification
                                    │
                            python-url-shortener
                            rust-ratelimiter (middleware)
```

## Run locally

```bash
npm install
# Start upstream services first (Phase 1), then:
npm start
# GraphQL Playground: http://localhost:4000
```

## Example queries

### Login
```graphql
mutation {
  login(username: "admin", password: "password") {
    accessToken
    refreshToken
  }
}
```

### Get all products (hits inventory service, cached 30s)
```graphql
query {
  products {
    id name price stock
  }
}
```

### Dashboard (fans out to inventory + notification in parallel)
```graphql
query {
  dashboard {
    totalProducts
    lowStockItems { id name stock }
    recentNotifications { id status }
  }
}
```

### Full workflow in one query
```graphql
query {
  products { id name price stock }
  dashboard { totalProducts lowStockItems { name stock } }
}
```

## Caching strategy

| Data | TTL | Invalidated on |
|------|-----|----------------|
| Product list | 30s | createProduct, updateStock, deleteProduct |
| Single product | 30s | updateStock, deleteProduct |
| Valid auth tokens | 60s | Never (tokens expire server-side) |
| Notification status | 5m | Never (immutable once sent) |

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| AUTH_SERVICE_URL | http://localhost:8080 | Go auth service |
| INVENTORY_SERVICE_URL | http://localhost:8080 | Java inventory service |
| NOTIFICATION_SERVICE_URL | http://localhost:3000 | Node.js notification service |
| URL_SERVICE_URL | http://localhost:8000 | Python URL shortener |
| RATE_LIMITER_URL | http://localhost:9000 | Rust rate limiter |
| REDIS_URL | redis://localhost:6379 | Redis for caching |
| RATE_LIMIT_PER_MINUTE | 60 | Requests per IP per minute |
| PORT | 4000 | GraphQL port |
