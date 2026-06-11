# ============================================================
# .NET 8 (ASP.NET Core) — Production Dockerfile
# ============================================================
# Uses the official dotnet SDK for build and the smaller
# ASP.NET Core runtime image for production.
# Runtime-only image is ~200MB vs ~700MB for the full SDK.
#
# Build:  docker build -t my-dotnet-app .
# Run:    docker run -p 8080:8080 my-dotnet-app
# ============================================================

# ── Stage 1: restore (dependency cache) ───────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS restore

WORKDIR /src

# Copy project file first — only re-runs restore when .csproj changes
COPY *.csproj .
RUN dotnet restore \
      --runtime linux-musl-x64 \
      --locked-mode
#   --locked-mode: fail if packages.lock.json is out of sync (reproducible)


# ── Stage 2: build ────────────────────────────────────────
FROM restore AS builder

WORKDIR /src

COPY . .

# Publish a self-contained, trimmed, ready-to-run binary
# --configuration Release     : enables optimisations, disables debug
# --runtime linux-musl-x64    : statically linked musl binary (Alpine compat)
# --self-contained false       : rely on runtime in the base image (smaller)
# --no-restore                : use deps from previous stage
# /p:PublishTrimmed=true       : remove unused assemblies (smaller image)
# /p:PublishReadyToRun=true    : AOT-compile hotpaths (faster startup)
RUN dotnet publish \
      --configuration Release \
      --no-restore \
      --output /app/publish \
      /p:PublishTrimmed=false \
      /p:PublishReadyToRun=true


# ── Stage 3: runtime ──────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime

# Non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

WORKDIR /app

COPY --chown=appuser:appgroup --from=builder /app/publish .

EXPOSE 8080

# ASP.NET Core reads these env vars:
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "MyApp.dll"]
#                       ↑ Replace with your project name
