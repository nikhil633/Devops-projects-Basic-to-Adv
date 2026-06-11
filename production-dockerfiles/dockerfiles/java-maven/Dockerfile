# ============================================================
# Java + Maven — Production Dockerfile
# ============================================================
# Uses Spring Boot layered JAR extraction for optimal layer caching.
# Only the "application" layer (your code) rebuilds on source changes.
# The "dependencies" layer (100MB+ of jars) is cached unless pom.xml changes.
#
# Build:  docker build -t my-java-app .
# Run:    docker run -p 8080:8080 my-java-app
# ============================================================

# ── Stage 1: dependency cache ─────────────────────────────
# Download dependencies BEFORE copying source.
# This layer only re-runs when pom.xml changes — not on every code change.
FROM maven:3.9-eclipse-temurin-21-alpine AS deps

WORKDIR /app

COPY pom.xml .
# go-offline downloads all dependencies into ~/.m2 cache
# -B = batch mode (no interactive prompts, cleaner CI output)
RUN mvn dependency:go-offline -B -q


# ── Stage 2: build + test ─────────────────────────────────
FROM deps AS builder

WORKDIR /app

# Copy source (after deps — so source changes don't bust the dep cache)
COPY src/ ./src/

# Build the fat JAR and run tests
# -T 4: use 4 threads for parallel test execution
RUN mvn clean package -B -T 4

# ── Spring Boot layer extraction ──────────────────────────
# Spring Boot 3 splits the fat JAR into 4 ordered layers:
#   1. dependencies          (3rd-party libs — rarely change)
#   2. spring-boot-loader    (Spring Boot loader classes)
#   3. snapshot-dependencies (SNAPSHOT jars — change more often)
#   4. application           (YOUR code — changes every build)
# Docker caches each COPY as a separate layer.
# Result: only layer 4 uploads on most deploys (10KB vs 100MB).
FROM eclipse-temurin:21-jre-alpine AS extractor

WORKDIR /extracted

COPY --from=builder /app/target/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract --destination /extracted


# ── Stage 3: runtime ──────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine AS runtime

# Non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

WORKDIR /app

# Copy layers in order: least-changed → most-changed
# Docker can cache each layer independently
COPY --chown=appuser:appgroup --from=extractor /extracted/dependencies/          ./
COPY --chown=appuser:appgroup --from=extractor /extracted/spring-boot-loader/    ./
COPY --chown=appuser:appgroup --from=extractor /extracted/snapshot-dependencies/ ./
COPY --chown=appuser:appgroup --from=extractor /extracted/application/           ./

EXPOSE 8080

# ── JVM tuning for containers ─────────────────────────────
# -XX:+UseContainerSupport   : respects Docker memory limits (not host RAM)
# -XX:MaxRAMPercentage=75.0  : heap = 75% of container memory limit
# -XX:+ExitOnOutOfMemoryError: crash fast on OOM instead of degrading
# -Djava.security.egd        : faster SecureRandom (important for web apps)
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:+ExitOnOutOfMemoryError \
               -Djava.security.egd=file:/dev/./urandom"

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
