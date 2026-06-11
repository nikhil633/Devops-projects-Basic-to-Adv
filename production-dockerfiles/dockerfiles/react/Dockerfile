# ============================================================
# React — Production Dockerfile
# ============================================================
# Strategy:
#   Stage 1 (builder): Node.js runs `npm run build` → generates static files
#   Stage 2 (runtime): Nginx serves those static files
#
# Why Nginx and not `npm start`?
#   `npm start` (react-scripts start) is a dev server — single-threaded,
#   not optimised for production, includes hot-reload overhead.
#   Nginx serves static files with gzip, caching headers, and handles
#   React Router's client-side routing via `try_files`.
#
# Build:  docker build -t my-react-app .
# Run:    docker run -p 80:80 my-react-app
# ============================================================

# ── Stage 1: build ────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files and install ALL deps (devDeps needed for build)
COPY package.json package-lock.json ./
RUN npm ci --frozen-lockfile

# Copy source and build
COPY . .

# REACT_APP_* env vars are baked into the bundle at build time.
# Pass them as build args for different environments:
#   docker build --build-arg REACT_APP_API_URL=https://api.prod.com .
ARG REACT_APP_API_URL
ARG REACT_APP_ENV=production
ENV REACT_APP_API_URL=$REACT_APP_API_URL
ENV REACT_APP_ENV=$REACT_APP_ENV

RUN npm run build
# Output: /app/build/


# ── Stage 2: runtime (Nginx) ──────────────────────────────
FROM nginx:1.27-alpine AS runtime

# Remove default Nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom Nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built React app from builder
COPY --from=builder /app/build /usr/share/nginx/html

# Nginx runs on port 80 by default
EXPOSE 80

# Nginx handles its own signal handling — no need for tini here
CMD ["nginx", "-g", "daemon off;"]
