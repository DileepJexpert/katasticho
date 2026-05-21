# ──────────────────────────────────────────────────────────────
# Katasticho ERP — Multi-stage Docker build
# Stage 1: Maven build   (full JDK + Maven)
# Stage 2: Runtime image  (slim JRE only)
# ──────────────────────────────────────────────────────────────

# ── Stage 1: Build ────────────────────────────────────────────
FROM maven:3.9.9-eclipse-temurin-21-alpine AS builder

WORKDIR /build

# Download dependencies first (cached layer)
COPY .mvn/ .mvn/
COPY pom.xml ./
RUN mvn dependency:go-offline -B

# Copy source and build
COPY src/ src/
RUN mvn package -DskipTests -B && \
    mv target/katasticho-erp-*.jar target/app.jar

# ── Stage 2: Runtime ─────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine

RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY --from=builder /build/target/app.jar app.jar

# Flyway migrations run on startup automatically
# JVM tuning: container-aware memory defaults
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:InitialRAMPercentage=50.0 \
               -Djava.security.egd=file:/dev/./urandom"

EXPOSE 8080

USER app

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
