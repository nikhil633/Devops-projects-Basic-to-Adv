# ============================================================
# Kotlin + Spring Boot — Production Dockerfile
# ============================================================
# Same pattern as Java + Maven: layered JAR extraction for
# optimal Docker layer caching. Kotlin compiles to JVM bytecode
# so the runtime is identical to Java.
#
# Build:  docker build -t my-kotlin-app .
# Run:    docker run -p 8080:8080 my-kotlin-app
# ============================================================

# ── Stage 1: dependency cache ─────────────────────────────
FROM gradle:8.7-jdk21-alpine AS deps

WORKDIR /app

COPY build.gradle.kts settings.gradle.kts gradlew ./
COPY gradle/                                       ./gradle/

# Kotlin plugin downloads Kotlin compiler — cache this separately
RUN ./gradlew dependencies --no-daemon -q


# ── Stage 2: build ────────────────────────────────────────
FROM deps AS builder

WORKDIR /app

COPY src/ ./src/

# bootJar = Spring Boot fat JAR with embedded Tomcat
# Kotlin compiler runs here (compiles .kt → JVM bytecode)
RUN ./gradlew bootJar --no-daemon


# ── Stage 3: layer extraction ─────────────────────────────
FROM eclipse-temurin:21-jre-alpine AS extractor

WORKDIR /extracted

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
