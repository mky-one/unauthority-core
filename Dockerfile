# Multi-stage build for minimal final image
FROM rust:1.75-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy manifests
COPY Cargo.toml Cargo.lock ./
COPY crates ./crates
COPY genesis ./genesis
COPY uat.proto ./

# Build release binaries
RUN cargo build --release --workspace

# Final minimal image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 uat && \
    mkdir -p /data /config && \
    chown -R uat:uat /data /config

WORKDIR /app

# Copy binaries from builder
COPY --from=builder /build/target/release/uat-node /usr/local/bin/
COPY --from=builder /build/target/release/uat-cli /usr/local/bin/
COPY --from=builder /build/target/release/genesis_generator /usr/local/bin/

# Copy configuration template
COPY validator.toml /config/validator.toml.template

# Copy genesis configuration files (required for node startup)
COPY genesis_config.json /opt/uat/genesis_config.json
COPY testnet-genesis/ /opt/uat/testnet-genesis/

USER uat

# Data directory for blockchain state
VOLUME ["/data", "/config"]

# Expose ports
# 8080-8082: REST API
# 50051-50053: gRPC
# 9000: P2P
# 9090: Prometheus metrics
EXPOSE 8080 8081 8082 50051 50052 50053 9000 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/uat-cli node-info || exit 1

ENTRYPOINT ["/usr/local/bin/uat-node"]
CMD ["--config", "/config/validator.toml", "--data-dir", "/data"]
