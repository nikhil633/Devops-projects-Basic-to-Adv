# ─── Stage 1: build ───────────────────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-21-alpine AS builder

WORKDIR /app

# Download dependencies first (cache layer — only re-runs when pom.xml changes)
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Copy source, run tests, package
COPY src/ ./src/
RUN mvn clean package -q

# ─── Stage 2: extract layers ──────────────────────────────────────────────
# Spring Boot 3 supports layered JARs — splits the fat JAR into:
#   dependencies/    — third-party libs (rarely change)
#   snapshot-dependencies/ — snapshot libs
#   spring-boot-loader/    — Spring Boot loader classes
#   application/           — YOUR code (changes every build)
# This means only the application/ layer rebuilds on most deployments
FROM eclipse-temurin:21-jre-alpine AS extractor

WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

# ─── Stage 3: runtime ─────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine AS runtime

# Security hardening
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

WORKDIR /app

# Copy layers in order of change frequency (least → most)
# Docker caches each COPY as a separate layer
COPY --from=extractor /app/dependencies/ ./
COPY --from=extractor /app/spring-boot-loader/ ./
COPY --from=extractor /app/snapshot-dependencies/ ./
COPY --from=extractor /app/application/ ./

EXPOSE 8080

# JVM tuning for containers:
# -XX:+UseContainerSupport     — respects container memory limits (not host RAM)
# -XX:MaxRAMPercentage=75.0    — use 75% of container memory limit for heap
# -XX:+ExitOnOutOfMemoryError  — crash fast instead of degrading silently
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-XX:+ExitOnOutOfMemoryError", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "org.springframework.boot.loader.launch.JarLauncher"]
