# Multi-stage build for Unauthority (LOS) validator node
FROM rust:1.75-slim AS builder

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY Cargo.toml Cargo.lock ./
COPY crates ./crates
COPY genesis ./genesis
COPY genesis_config.json ./
COPY los.proto ./
COPY pqcrypto-internals-seeded ./pqcrypto-internals-seeded

# Build release binaries
RUN cargo build --release -p los-node -p los-cli

# Strip private keys from genesis config for runtime image
RUN jq 'del(.bootstrap_nodes[].private_key, .bootstrap_nodes[].seed_phrase, .dev_accounts[].private_key, .dev_accounts[].seed_phrase)' \
    genesis_config.json > genesis_config_stripped.json

# Final minimal image
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 los && \
    mkdir -p /data /app && \
    chown -R los:los /data /app

WORKDIR /app

# Copy binaries
COPY --from=builder /build/target/release/los-node ./los-node
COPY --from=builder /build/target/release/los-cli ./los-cli

# Copy genesis config (stripped of secrets)
COPY --from=builder /build/genesis_config_stripped.json ./genesis_config.json
COPY testnet-genesis/ ./testnet-genesis/

USER los

VOLUME ["/data"]

# REST API (default 3030), gRPC (REST + 20000)
EXPOSE 3030 23030

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:3030/health || exit 1

ENTRYPOINT ["./los-node"]
CMD ["--port", "3030", "--data-dir", "/data"]
