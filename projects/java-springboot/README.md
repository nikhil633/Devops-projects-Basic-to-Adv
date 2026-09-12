# Inventory API — Java Spring Boot 3 + PostgreSQL

## Stack
- **API**: Spring Boot 3.3 (Java 21)
- **DB**: PostgreSQL 16
- **Container**: 3-stage Docker build with Spring Boot layers
- **Infra**: AKS + ACR via Terraform

## Local Dev
```bash
docker compose up --build
# API: http://localhost:8080
# Actuator: http://localhost:8080/actuator/health
```

## Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | /health | Health check |
| GET | /items | List items (filter: ?category=) |
| POST | /items | Create item |
| GET | /items/{id} | Get item |
| PUT | /items/{id} | Update item |
| DELETE | /items/{id} | Delete item |
| GET | /items/low-stock | Items below threshold (?threshold=10) |
| GET | /actuator/health | Spring Actuator health |

## Pipeline Practice Goals
- [ ] Maven build + test in CI
- [ ] Docker build (layered JAR) & push to ACR (OIDC)
- [ ] Trivy + OWASP dependency scan
- [ ] Snyk scan
- [ ] Terraform plan/apply
- [ ] kubectl deploy to AKS
