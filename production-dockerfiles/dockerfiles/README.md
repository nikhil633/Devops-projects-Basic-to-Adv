# Production Dockerfiles — Complete Reference

## Quick reference

| Language / Stack | Dockerfile | Base Image | Final Image Size |
|---|---|---|---|
| Node.js + TypeScript | `nodejs-typescript/` | `node:20-alpine` | ~150MB |
| Node.js (JavaScript) | `nodejs-javascript/` | `node:20-alpine` | ~130MB |
| React (SPA) | `react/` | `nginx:1.27-alpine` | ~25MB |
| Angular (SPA) | `angular/` | `nginx:1.27-alpine` | ~25MB |
| Java + Maven | `java-maven/` | `eclipse-temurin:21-jre-alpine` | ~180MB |
| Java + Gradle | `java-gradle/` | `eclipse-temurin:21-jre-alpine` | ~180MB |
| Kotlin + Spring | `kotlin-spring/` | `eclipse-temurin:21-jre-alpine` | ~185MB |
| Go | `go/` | `gcr.io/distroless/static:nonroot` | ~15MB |
| Rust | `rust/` | `debian:bookworm-slim` | ~80MB |
| Python Flask | `python-flask/` | `python:3.12-slim` | ~200MB |
| Python FastAPI | `python-fastapi/` | `gcr.io/distroless/python3` | ~120MB |
| Python Django | `python-django/` | `python:3.12-slim` | ~220MB |
| .NET 8 ASP.NET Core | `dotnet/` | `mcr.microsoft.com/dotnet/aspnet:8.0-alpine` | ~120MB |
| Ruby on Rails | `ruby-rails/` | `ruby:3.3-slim` | ~300MB |
| PHP Laravel | `php-laravel/` | `php:8.3-fpm-alpine` | ~150MB |

---

## How to use each Dockerfile

### Node.js + TypeScript
```bash
# Project structure expected:
# ├── src/
# │   └── server.ts       (entry point)
# ├── tsconfig.json
# │   └── "outDir": "./dist"
# │   └── "rootDir": "./src"
# ├── package.json
# │   └── "build": "tsc"
# └── package-lock.json

docker build -t my-ts-app .
docker run -p 3000:3000 -e DATABASE_URL=... my-ts-app
```

### Node.js (JavaScript)
```bash
# Project structure expected:
# ├── src/
# │   └── server.js       (entry point)
# ├── package.json
# └── package-lock.json

docker build -t my-node-app .
docker run -p 3000:3000 my-node-app
```

### React
```bash
# Project structure: standard create-react-app or Vite

# Build with environment-specific API URL
docker build \
  --build-arg REACT_APP_API_URL=https://api.prod.com \
  -t my-react-app .

docker run -p 80:80 my-react-app
```

### Angular
```bash
# angular.json must have "outputPath": "dist/<project-name>"

docker build \
  --build-arg PROJECT_NAME=my-angular-app \
  -t my-angular-app .

docker run -p 80:80 my-angular-app
```

### Java + Maven
```bash
# Project structure: standard Maven layout
# pom.xml must have spring-boot-maven-plugin for layered JAR support

docker build -t my-java-app .
docker run -p 8080:8080 \
  -e DATABASE_URL=jdbc:postgresql://host:5432/mydb \
  -e DB_USER=user \
  -e DB_PASSWORD=secret \
  my-java-app
```

### Java + Gradle
```bash
# build.gradle.kts must have:
#   tasks.bootJar { layered { enabled.set(true) } }

docker build -t my-java-gradle-app .
docker run -p 8080:8080 my-java-gradle-app
```

### Go
```bash
# Change ./cmd/server to your actual main package path in the Dockerfile

docker build -t my-go-app .
docker run -p 8080:8080 my-go-app
# Note: no shell in distroless — use kubectl exec alternatives for debugging
```

### Rust
```bash
# Change 'my-rust-app' in Cargo.toml [[bin]] and in the Dockerfile CMD

docker build -t my-rust-app .
docker run -p 8080:8080 my-rust-app
```

### Python Flask
```bash
# Project structure expected:
# ├── app/
# │   └── __init__.py    (Flask app factory)
# ├── wsgi.py            (from app import create_app; app = create_app())
# └── requirements.txt

docker build -t my-flask-app .
docker run -p 8000:8000 \
  -e DATABASE_URL=postgresql://... \
  my-flask-app
```

### Python FastAPI
```bash
# Project structure expected:
# ├── app/
# │   └── main.py        (FastAPI app = FastAPI())
# ├── tests/
# └── requirements.txt

docker build -t my-fastapi-app .
docker run -p 8000:8000 my-fastapi-app
```

### Python Django
```bash
# Change 'myproject' to your Django project name in the Dockerfile

docker build -t my-django-app .
docker run -p 8000:8000 \
  -e DJANGO_SECRET_KEY=your-secret-key \
  -e DATABASE_URL=postgresql://user:pass@host:5432/db \
  -e ALLOWED_HOSTS=yourdomain.com \
  my-django-app
```

### .NET ASP.NET Core
```bash
# Change MyApp.dll to your project name in ENTRYPOINT

docker build -t my-dotnet-app .
docker run -p 8080:8080 \
  -e ConnectionStrings__DefaultConnection="Server=...;Database=..." \
  my-dotnet-app
```

### Ruby on Rails
```bash
# Change config/puma.rb to configure threads and workers

docker build -t my-rails-app .
docker run -p 3000:3000 \
  -e RAILS_MASTER_KEY=your-master-key \
  -e DATABASE_URL=postgresql://user:pass@host:5432/mydb \
  my-rails-app
```

### PHP Laravel
```bash
# Generate APP_KEY: php artisan key:generate --show

docker build -t my-laravel-app .
docker run -p 80:80 \
  -e APP_KEY=base64:your-key \
  -e DB_HOST=postgres \
  -e DB_DATABASE=mydb \
  -e DB_USERNAME=user \
  -e DB_PASSWORD=secret \
  my-laravel-app
```

---

## Production best practices (applied in ALL Dockerfiles)

### Multi-stage builds
Split the build into stages. Only the final stage ships:
- Stage 1: install all deps (including dev tools)
- Stage 2: compile / build / test
- Stage 3: runtime — copy only what's needed

### Non-root user
Every Dockerfile runs the final process as a non-root user.
Root in a container can escape to root on the host in certain configurations.

### Layer caching for dependencies
Copy dependency files (`package.json`, `go.mod`, `pom.xml`) BEFORE source code.
Docker caches the install layer and only re-runs it when dependencies change.
Source code changes don't trigger a full re-install.

### Minimal base images
| Choice | When to use |
|---|---|
| `distroless/static` | Go (statically linked) |
| `distroless/python3` | Python (minimal attack surface) |
| `alpine` | Node.js, Java, .NET (good balance) |
| `slim` | Python Flask/Django (needs system libs) |
| `debian:bookworm-slim` | Rust (needs glibc) |

### .dockerignore
Always use `.dockerignore`. Without it:
- `node_modules/` (500MB+) gets sent to build context
- `target/` (Rust, Java) gets sent to build context
- `.env` files with secrets get sent to build context
The universal `.dockerignore` in this folder covers all languages.

### HEALTHCHECK
Every production Dockerfile includes a HEALTHCHECK.
Docker and Kubernetes use this to:
- Detect crashed processes that haven't exited
- Delay traffic until the app is ready
- Restart unhealthy containers automatically

### Signal handling
- Go: binary handles signals directly
- Node.js: use tini or `node` directly (NOT `npm start` — npm eats SIGTERM)
- Java: JVM handles SIGTERM gracefully
- Python: Gunicorn handles signals
- Rust: binary handles signals directly

### Read-only root filesystem
For extra security, run with:
```bash
docker run --read-only --tmpfs /tmp my-app
```
Or in Kubernetes:
```yaml
securityContext:
  readOnlyRootFilesystem: true
```

---

## Multi-architecture builds (amd64 + arm64)

For CI/CD pipelines targeting both Intel servers and ARM (AWS Graviton, Apple Silicon):

```bash
# One-time setup
docker buildx create --use --name multiarch

# Build and push multi-arch image
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag myregistry/my-app:v1.0.0 \
  --push \
  .
```

All Dockerfiles in this collection are compatible with multi-arch builds.
Rust requires separate targets (`x86_64-unknown-linux-gnu` and `aarch64-unknown-linux-gnu`).
