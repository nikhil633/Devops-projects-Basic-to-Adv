# ============================================================
# Java + Gradle — Production Dockerfile
# ============================================================
# Build:  docker build -t my-java-gradle-app .
# Run:    docker run -p 8080:8080 my-java-gradle-app
# ============================================================

# ── Stage 1: dependency cache ─────────────────────────────
FROM gradle:8.7-jdk21-alpine AS deps

WORKDIR /app

# Copy only the Gradle wrapper and build files first.
# Gradle's dependency cache lives in ~/.gradle.
# This layer only re-runs when build.gradle.kts or settings.gradle.kts changes.
COPY build.gradle.kts settings.gradle.kts gradlew ./
COPY gradle/                                      ./gradle/

# Download dependencies without building
# --no-daemon: don't start a long-lived Gradle daemon (wastes memory in Docker)
RUN ./gradlew dependencies --no-daemon -q


# ── Stage 2: build ────────────────────────────────────────
FROM deps AS builder

WORKDIR /app

COPY src/ ./src/

# Build the bootJar (Spring Boot fat JAR)
RUN ./gradlew bootJar --no-daemon -x test
# Add -x test to skip tests in CI (tests run separately in the pipeline)
# Remove -x test if you want tests inside the build


# ── Stage 3: layer extraction (same as Maven) ─────────────
FROM eclipse-temurin:21-jre-alpine AS extractor

WORKDIR /extracted

# Gradle outputs to build/libs/
COPY --from=builder /app/build/libs/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract --destination /extracted


# ── Stage 4: runtime ──────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine AS runtime

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

WORKDIR /app

COPY --chown=appuser:appgroup --from=extractor /extracted/dependencies/          ./
COPY --chown=appuser:appgroup --from=extractor /extracted/spring-boot-loader/    ./
COPY --chown=appuser:appgroup --from=extractor /extracted/snapshot-dependencies/ ./
COPY --chown=appuser:appgroup --from=extractor /extracted/application/           ./

EXPOSE 8080

ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:+ExitOnOutOfMemoryError \
               -Djava.security.egd=file:/dev/./urandom"

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
