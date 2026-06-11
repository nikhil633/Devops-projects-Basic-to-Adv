# Inventory Service — Java Spring Boot + PostgreSQL

## Local setup
```bash
docker run -d -p 5432:5432 -e POSTGRES_DB=inventory -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres postgres:16-alpine
./mvnw spring-boot:run
```

## Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | /api/products | List all products |
| GET | /api/products/:id | Get product by ID |
| POST | /api/products | Create a product |
| PUT | /api/products/:id | Update a product |
| PATCH | /api/products/:id/stock | Adjust stock (delta) |
| DELETE | /api/products/:id | Delete a product |
| GET | /actuator/health | Health check |
| GET | /actuator/prometheus | Prometheus metrics |

## POST /api/products body
```json
{ "name": "Widget", "description": "A widget", "price": 9.99, "stock": 100 }
```

## Environment variables
| Variable | Default | Description |
|----------|---------|-------------|
| DATABASE_URL | jdbc:postgresql://localhost:5432/inventory | DB connection |
| DB_USER | postgres | DB username |
| DB_PASSWORD | postgres | DB password |
| PORT | 8080 | HTTP port |
