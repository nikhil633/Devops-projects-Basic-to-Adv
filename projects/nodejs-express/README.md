# Order API — Node.js Express + MongoDB

## Stack
- **API**: Express.js (Node 20)
- **DB**: MongoDB 7.0
- **Container**: Multi-stage Docker build
- **Infra**: AKS + ACR via Terraform

## Local Dev
```bash
docker compose up --build
# API: http://localhost:3000
```

## Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | /health | Health check |
| GET | /orders | List orders (filter: customerId, status) |
| POST | /orders | Create order |
| GET | /orders/:id | Get order |
| PATCH | /orders/:id/status | Update order status |
| DELETE | /orders/:id | Delete order |

## Pipeline Practice Goals
- [ ] Docker build & push to ACR (OIDC auth)
- [ ] Trivy + npm audit + Snyk scan
- [ ] Terraform plan/apply
- [ ] kubectl deploy to AKS
