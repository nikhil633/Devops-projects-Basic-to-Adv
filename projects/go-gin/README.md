# User API — Go Gin + PostgreSQL

## Stack
- **API**: Gin (Go 1.22)
- **DB**: PostgreSQL 16 via GORM
- **Container**: Multi-stage → scratch (tiny image, no shell)
- **Infra**: AKS + ACR via Terraform

## Local Dev
```bash
docker compose up --build
# API: http://localhost:8090
```

## Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | /health | Health check |
| GET | /users | List users (?page=1&limit=20) |
| POST | /users | Create user |
| GET | /users/:id | Get user |
| PUT | /users/:id | Update user |
| DELETE | /users/:id | Delete user |

## Pipeline Practice Goals
- [ ] Go build + test + race detection in CI
- [ ] Docker build (scratch image) & push to ACR (OIDC)
- [ ] Trivy + govulncheck + Snyk scan
- [ ] Terraform plan/apply
- [ ] kubectl deploy to AKS

## Key DevOps Notes
- Go scratch image → no OS, no shell, ultra-low CVE surface
- Static binary → fast startup, low memory (great HPA candidate)
- Use `CGO_ENABLED=0` in build to ensure scratch compatibility
