# syntax=docker/dockerfile:1.9
FROM node:22-alpine AS base
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY package*.json ./

FROM base AS dev-deps
RUN --mount=type=cache,target=/root/.npm \
    npm ci

FROM base AS prod-deps
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

FROM dev-deps AS build
COPY . .
RUN npm run build

FROM base AS production
COPY --from=prod-deps --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=build      --chown=appuser:appgroup /app/dist         ./dist
ENV NODE_ENV=production PORT=3000
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/server.js"]

explain it every line


Alpine + Non-root + cache

# syntax=docker/dockerfile:1.9

FROM node:22-alpine AS base

RUN addgroup -S nodeapp && adduser -S nodeuser -G nodeapp

WORKDIR /app

COPY package*.json ./

FROM base AS dev-deps

RUN --mount=type=cache,target=/root/.npm \
    npm ci


FROM base AS build
COPY . .
RUN npm run build

FROM base AS prod-deps

RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

FROM base AS runtime

COPY --from=prod-deps --chown=nodeuser:nodeapp /app/node_modules ./node_modules

COPY --from=build --chown=nodeuser:nodeapp /app/dist ./dist

ENV NODE_ENV=production

USER nodeuser

EXPOSE 3000

CMD ["node", "dist/server.js"]


Distroless (Maximum security)

# syntax=docker/dockerfile:1.9

FROM node:22-alpine AS build

WORKDIR /app

COPY package*.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm ci

COPY . .

RUN npm run build


FROM node:22-alpine AS prod-deps

WORKDIR /app

COPY package*.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev


FROM gcr.io/distroless/nodejs22-debian12

WORKDIR /app

COPY --from=build /app/dist ./dist

COPY --from=prod-deps /app/node_modules ./node_modules

USER nonroot

EXPOSE 3000

CMD ["dist/server.js"]

Node Official Image with built-in user

# syntax=docker/dockerfile:1.9

FROM node:22-alpine AS build

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run build


FROM node:22-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev


COPY --from=build /app/dist ./dist


USER node


ENV NODE_ENV=production


EXPOSE 3000


CMD ["node","dist/server.js"]


Next.js production DOckerfile

# syntax=docker/dockerfile:1.9

FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run build


FROM node:22-alpine AS runtime

WORKDIR /app

ENV NODE_ENV=production


COPY --from=builder /app/.next ./.next

COPY --from=builder /app/public ./public

COPY --from=builder /app/package.json ./


RUN npm ci --omit=dev


USER node


EXPOSE 3000


CMD ["npm","start"]


production with Healthcheck and init process

FROM node:22-alpine

RUN apk add --no-cache dumb-init

WORKDIR /app

COPY . .

RUN npm ci --omit=dev

ENTRYPOINT ["dumb-init","--"]

CMD ["node","server.js"]


| Pattern              | Usage                      |
| -------------------- | -------------------------- |
| Multi-stage + Alpine | ⭐⭐⭐⭐⭐ Most common          |
| Distroless           | ⭐⭐⭐⭐⭐ High security        |
| Node built-in user   | ⭐⭐⭐⭐ Common                |
| npm prune            | ⭐⭐⭐ Legacy projects        |
| Next.js optimized    | ⭐⭐⭐⭐⭐ Web apps             |
| dumb-init            | ⭐⭐⭐⭐ Long-running services |




# Pull
docker pull nginx:alpine
docker pull --platform linux/arm64 nginx:alpine
docker pull --all-tags nginx    # pull every tag

# List
docker image ls
docker image ls --format \
  "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
docker image ls --filter dangling=true
docker image ls --filter reference='nginx:*'
docker image ls -q             # IDs only

# Inspect
docker image inspect nginx
docker image inspect nginx \
  --format '{{.Os}}/{{.Architecture}}'
docker image inspect nginx \
  --format '{{json .RootFS.Layers}}'
docker image history nginx
docker image history --no-trunc nginx

# Tag & Push
docker image tag nginx:alpine myrepo/nginx:1.27
docker push myrepo/nginx:1.27
docker push --all-tags myrepo/nginx

explain all commands


# Remove
docker image rm nginx:alpine
docker image rm -f nginx        # force
docker rmi $(docker images -q)  # remove all
docker image prune              # dangling only
docker image prune -a           # all unused
docker image prune -a \
  --filter "until=24h"          # older than 24h

# Save / Load / Export
docker image save -o nginx.tar nginx:alpine
docker image save nginx:alpine | gzip > nginx.tar.gz
docker image load -i nginx.tar
docker image load < nginx.tar.gz

# Import from tarball
docker import rootfs.tar.gz myimage:v1
docker import --change \
  "CMD /bin/bash" rootfs.tar myimage

# Manifest (multi-platform inspection)
docker manifest inspect nginx:alpine
docker buildx imagetools inspect nginx:alpine

explain all


Golang

FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" \
    -o /app/server ./cmd/server

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt \
     /etc/ssl/certs/
COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]

can you explain it each and every line and word