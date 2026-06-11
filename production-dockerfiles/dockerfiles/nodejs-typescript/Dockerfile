# ============================================================
# Node.js + TypeScript — Production Dockerfile
# ============================================================
# Build:  docker build -t my-ts-app .
# Run:    docker run -p 3000:3000 my-ts-app
# ============================================================

# ── Stage 1: deps ─────────────────────────────────────────
# Install ALL dependencies (including devDeps needed to compile TypeScript)
FROM node:20-alpine AS deps

WORKDIR /app

# Copy package files first — Docker caches this layer.
# The heavy npm install only re-runs when package.json changes,
# not on every source file change.
COPY package.json package-lock.json ./

# ci = reproducible install from lockfile (never upgrades)
# frozen-lockfile = fail if lockfile is out of sync
RUN npm ci --frozen-lockfile


# ── Stage 2: build ────────────────────────────────────────
# Compile TypeScript → JavaScript
FROM deps AS builder

WORKDIR /app

COPY tsconfig.json ./
COPY src/ ./src/

# tsc compiles to dist/ (set in tsconfig.json: "outDir": "./dist")
RUN npm run build

# Remove devDependencies — only production deps needed at runtime
RUN npm prune --omit=dev


# ── Stage 3: runtime ──────────────────────────────────────
# Final image: only the compiled JS + production node_modules
FROM node:20-alpine AS runtime

# Security: run as the built-in non-root 'node' user (UID 1000)
USER node

WORKDIR /app

# Copy compiled output and production deps from builder
COPY --chown=node:node --from=builder /app/dist        ./dist
COPY --chown=node:node --from=builder /app/node_modules ./node_modules
COPY --chown=node:node --from=builder /app/package.json ./

# Expose the port your Express/Fastify app listens on
EXPOSE 3000

# NODE_ENV=production:
#   - Disables development error pages
#   - Enables Express production optimisations
#   - Reduces logging verbosity in many frameworks
ENV NODE_ENV=production

# Healthcheck — Docker / Kubernetes liveness probe
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Run the compiled entry point
# Use node directly — NOT npm start — so signals (SIGTERM) reach your process
CMD ["node", "dist/server.js"]
