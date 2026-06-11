# ============================================================
# Node.js (JavaScript) — Production Dockerfile
# ============================================================
# Build:  docker build -t my-node-app .
# Run:    docker run -p 3000:3000 my-node-app
# ============================================================

# ── Stage 1: install production deps only ─────────────────
FROM node:20-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./

# --omit=dev: skip devDependencies (jest, eslint, nodemon, etc.)
# Result: smaller node_modules, faster install
RUN npm ci --frozen-lockfile --omit=dev


# ── Stage 2: runtime ──────────────────────────────────────
# No compilation needed for plain JS — just copy app + deps
FROM node:20-alpine AS runtime

# Install tini: lightweight init system
# Solves two problems:
#   1. Proper SIGTERM forwarding (npm wraps node in a shell that eats signals)
#   2. Zombie process reaping (important for long-running services)
RUN apk add --no-cache tini

USER node
WORKDIR /app

COPY --chown=node:node --from=deps /app/node_modules ./node_modules
COPY --chown=node:node src/ ./src/
COPY --chown=node:node package.json ./

EXPOSE 3000

ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# tini as PID 1 → forwards signals correctly → graceful shutdown works
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "src/server.js"]
