# Product API — Python FastAPI + PostgreSQL

## Stack
- **API**: FastAPI (Python 3.12)
- **DB**: PostgreSQL 16
- **Container**: Multi-stage Docker build
- **Infra**: AKS + ACR via Terraform

## Local Dev
```bash
docker compose up --build
# API: http://localhost:8000
# Docs: http://localhost:8000/docs
```

## Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | /health | Health check |
| GET | /products | List products |
| POST | /products | Create product |
| GET | /products/{id} | Get product |
| PUT | /products/{id} | Update product |
| DELETE | /products/{id} | Delete product |

## Pipeline Practice Goals
- [ ] Docker build & push to ACR (OIDC auth)
- [ ] Trivy image scan
- [ ] Snyk dependency scan
- [ ] Terraform plan/apply
- [ ] kubectl deploy to AKS
