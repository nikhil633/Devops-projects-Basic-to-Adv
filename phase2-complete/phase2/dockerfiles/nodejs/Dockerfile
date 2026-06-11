# ─── Stage 1: deps ────────────────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

# Copy package files first — Docker cache layer only rebuilds when these change
COPY package.json package-lock.json ./
# Install ALL deps (including devDeps needed for tests)
RUN npm ci --frozen-lockfile

# ─── Stage 2: test ────────────────────────────────────────────────────────
FROM deps AS test

COPY . .
RUN npm test

# ─── Stage 3: prod-deps ───────────────────────────────────────────────────
# Install only production dependencies (no jest, nodemon, etc.)
FROM node:20-alpine AS prod-deps

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --frozen-lockfile --omit=dev

# ─── Stage 4: runtime ─────────────────────────────────────────────────────
# node:20-alpine is small (~60MB) and has no package manager at runtime
FROM node:20-alpine AS runtime

# Security: run as non-root node user (UID 1000, pre-created in node image)
USER node
WORKDIR /app

# Copy production deps and app source
COPY --chown=node:node --from=prod-deps /app/node_modules ./node_modules
COPY --chown=node:node src/ ./src/
COPY --chown=node:node package.json ./

EXPOSE 3000

# Use tini as PID 1 — properly forwards signals to Node and reaps zombies
# Alpine includes it via --init in docker run; for k8s set it explicitly
CMD ["node", "src/server.js"]
