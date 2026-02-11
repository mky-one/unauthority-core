# Docker Deployment

Run a 4-node UAT testnet with Prometheus and Grafana monitoring via Docker Compose.

**Version:** v1.0.6-testnet

---

## Prerequisites

- Docker 24+
- Docker Compose v2+

---

## Quick Start

```bash
# Build and start all services
docker compose up -d

# Check health
curl http://localhost:8080/health
curl http://localhost:8081/health
curl http://localhost:8082/health
curl http://localhost:8083/health
```

---

## Services

### Validators

| Service | REST | gRPC | P2P | Prometheus | IP |
|---------|------|------|-----|------------|----|
| validator-1 | 8080 | 50051 | 9000 | 9090 | 172.20.0.11 |
| validator-2 | 8081 | 50052 | 9001 | 9091 | 172.20.0.12 |
| validator-3 | 8082 | 50053 | 9002 | 9092 | 172.20.0.13 |
| validator-4 | 8083 | 50054 | 9003 | 9093 | 172.20.0.14 |

### Monitoring

| Service | Port | IP | Credentials |
|---------|------|----|-------------|
| Prometheus | 9094 | 172.20.0.20 | — |
| Grafana | 3000 | 172.20.0.21 | admin / `$GF_ADMIN_PASSWORD` |

---

## Docker Network

All services run on a bridge network `172.20.0.0/24`.

```
172.20.0.11  validator-1
172.20.0.12  validator-2
172.20.0.13  validator-3
172.20.0.14  validator-4
172.20.0.20  prometheus
172.20.0.21  grafana
```

---

## Dockerfile

Multi-stage build:

1. **Build stage**: `rust:1.75-slim` — compiles `uat-node` and `uat-cli`
2. **Runtime stage**: `debian:bookworm-slim` — minimal runtime

Security:
- Runs as non-root user (UID 1000)
- Private keys stripped from genesis config via `jq`
- Exposes ports: 8080 (REST), 50051 (gRPC), 9000 (P2P), 9090 (Prometheus)

---

## Environment Variables

Each validator container uses these environment variables:

| Variable | Description |
|----------|-------------|
| `UAT_NODE_ID` | Unique node identifier (1–4) |
| `UAT_VALIDATOR_ADDRESS` | Validator's UAT address |
| `UAT_PRIVKEY_PATH` | Path to encrypted private key |
| `UAT_STAKE_VOID` | Stake amount in VOID |
| `UAT_WALLET_PASSWORD` | Key encryption password |
| `UAT_BIND_ALL` | `1` to bind `0.0.0.0` (required in containers) |

---

## Health Checks

Docker Compose uses `uat-cli node-info` as the health check command. Validators start sequentially — each waits for the previous to be healthy via `depends_on` + `service_healthy`.

---

## Monitoring Setup

### Prometheus

Configuration at `docs/prometheus.yml`. Scrapes all 4 validators on their Prometheus ports (9090–9093).

Alert rules at `docs/prometheus-alerts.yml`.

### Grafana

Pre-built dashboard at `docs/grafana-dashboard.json`.

Import after starting:
1. Open `http://localhost:3000`
2. Login: admin / `$GF_ADMIN_PASSWORD`
3. Import dashboard from JSON

---

## Operations

```bash
# Start all
docker compose up -d

# View logs
docker compose logs -f validator-1
docker compose logs -f --tail 100

# Stop all
docker compose down

# Rebuild after code changes
docker compose build --no-cache
docker compose up -d

# Scale (not recommended — genesis is configured for 4 validators)
# Add new validators manually with appropriate genesis funding
```

---

## Volumes

| Volume | Mount | Purpose |
|--------|-------|---------|
| `validator-{n}-data` | `/app/node_data` | Ledger state + wallet |
| `prometheus-data` | `/prometheus` | Metrics history |
| `grafana-data` | `/var/lib/grafana` | Dashboard config |

To reset state:

```bash
docker compose down -v   # Removes all volumes
```

---

## Local Development Without Docker

For faster iteration during development, use the shell scripts:

```bash
./start.sh    # Launches 4 validators on ports 3030–3033
./stop.sh     # Graceful shutdown
```

Or run a single dev-mode node:

```bash
cargo run --release --bin uat-node -- --dev
```
