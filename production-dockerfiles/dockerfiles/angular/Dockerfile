# ============================================================
# Angular — Production Dockerfile
# ============================================================
# Same pattern as React: build with Node, serve with Nginx.
# Angular CLI produces an optimised bundle in dist/<project-name>/
#
# Build:  docker build -t my-angular-app --build-arg PROJECT_NAME=my-app .
# Run:    docker run -p 80:80 my-angular-app
# ============================================================

# ── Stage 1: build ────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Install deps with frozen lockfile for reproducible builds
COPY package.json package-lock.json ./
RUN npm ci --frozen-lockfile

COPY . .

# Angular build args
# --configuration=production: enables tree-shaking, AOT compilation,
#   minification, dead code elimination
# --output-hashing=all: content-hashes all filenames for cache-busting
ARG PROJECT_NAME=my-app
ARG BASE_HREF=/

RUN npx ng build \
      --configuration=production \
      --output-hashing=all \
      --base-href=${BASE_HREF}
# Output: /app/dist/${PROJECT_NAME}/


# ── Stage 2: runtime (Nginx) ──────────────────────────────
FROM nginx:1.27-alpine AS runtime

# Remove default config
RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf

# Angular outputs to dist/<project-name>/ — copy everything inside
ARG PROJECT_NAME=my-app
COPY --from=builder /app/dist/${PROJECT_NAME}/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
