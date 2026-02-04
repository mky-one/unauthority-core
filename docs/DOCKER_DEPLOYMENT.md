# Docker Deployment Guide

This guide explains how to deploy the Unauthority blockchain network using Docker and Docker Compose.

## Prerequisites

- Docker Engine 24.0+
- Docker Compose V2
- At least 4GB RAM
- 20GB free disk space

Install Docker:
```bash
# macOS (via Homebrew)
brew install docker docker-compose

# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Verify installation
docker --version
docker compose version
```

---

## Quick Start

### 1. Build Images
```bash
# Build all containers
docker compose build

# Build specific service
docker compose build validator-1
```

### 2. Initialize Genesis
```bash
# Generate genesis configuration (if not exists)
docker run --rm -v $(pwd)/genesis:/genesis \
  unauthority-core_validator-1 \
  /usr/local/bin/genesis_generator --output /genesis/genesis_config.json
```

### 3. Start Network
```bash
# Start all services
docker compose up -d

# Start specific validators
docker compose up -d validator-1 validator-2

# View logs
docker compose logs -f validator-1
```

### 4. Verify Health
```bash
# Check all containers
docker compose ps

# Test API endpoints
curl http://localhost:8080/node-info
curl http://localhost:8081/node-info
curl http://localhost:8082/node-info

# Check consensus
curl http://localhost:8080/validators
```

---

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    Docker Network (172.20.0.0/16)              │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Validator 1  │  │ Validator 2  │  │ Validator 3  │         │
│  │ 172.20.0.11  │  │ 172.20.0.12  │  │ 172.20.0.13  │         │
│  │              │  │              │  │              │         │
│  │ REST: 8080   │  │ REST: 8081   │  │ REST: 8082   │         │
│  │ gRPC: 50051  │  │ gRPC: 50052  │  │ gRPC: 50053  │         │
│  │ P2P:  9000   │  │ P2P:  9001   │  │ P2P:  9002   │         │
│  │ Prom: 9090   │  │ Prom: 9091   │  │ Prom: 9092   │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                 │                 │                 │
│         └─────────────────┼─────────────────┘                 │
│                           │                                   │
│              ┌────────────┴──────────┐                        │
│              │                       │                        │
│    ┌─────────▼────────┐    ┌────────▼────────┐               │
│    │   Prometheus     │    │    Grafana      │               │
│    │   172.20.0.20    │    │   172.20.0.21   │               │
│    │   Port: 9093     │───►│   Port: 3000    │               │
│    └──────────────────┘    └─────────────────┘               │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## Configuration

### Environment Variables

Edit `docker-compose.yml` to customize:

```yaml
environment:
  - RUST_LOG=info              # Logging level (debug/info/warn/error)
  - UAT_NODE_NAME=validator-1  # Node identifier
  - UAT_VALIDATOR_MODE=true    # Enable validator mode
  - UAT_MIN_STAKE=1000         # Minimum stake requirement
```

### Volume Mounts

Data persistence:
- `./node_data/validator-X:/data` - Blockchain state
- `./validator.toml:/config/validator.toml` - Configuration file

### Port Mapping

| Service      | Internal Port | External Port | Purpose           |
|--------------|---------------|---------------|-------------------|
| Validator 1  | 8080          | 8080          | REST API          |
| Validator 1  | 50051         | 50051         | gRPC              |
| Validator 1  | 9000          | 9000          | P2P Network       |
| Validator 1  | 9090          | 9090          | Prometheus        |
| Validator 2  | 8080          | 8081          | REST API          |
| Validator 3  | 8080          | 8082          | REST API          |
| Prometheus   | 9090          | 9093          | Metrics UI        |
| Grafana      | 3000          | 3000          | Dashboard         |

---

## Management Commands

### Start/Stop Services
```bash
# Start all
docker compose up -d

# Stop all
docker compose down

# Restart specific service
docker compose restart validator-1

# Stop without removing volumes
docker compose stop
```

### Logs & Debugging
```bash
# View logs
docker compose logs -f

# Logs for specific service
docker compose logs -f validator-1

# Last 100 lines
docker compose logs --tail=100 validator-1

# Export logs
docker compose logs > uat-network.log
```

### Resource Monitoring
```bash
# Resource usage
docker stats

# Container details
docker compose ps

# Inspect container
docker inspect uat-validator-1
```

### Execute Commands Inside Container
```bash
# Open shell
docker compose exec validator-1 bash

# Run CLI command
docker compose exec validator-1 uat-cli balance UAT123...

# Check sync status
docker compose exec validator-1 uat-cli node-info
```

---

## Scaling

### Add More Validators

1. Copy validator configuration:
```bash
cp -r node_data/validator-1 node_data/validator-4
```

2. Add service to `docker-compose.yml`:
```yaml
validator-4:
  build:
    context: .
    dockerfile: Dockerfile
  container_name: uat-validator-4
  networks:
    uat-network:
      ipv4_address: 172.20.0.14
  ports:
    - "8083:8080"
    - "50054:50051"
  volumes:
    - ./node_data/validator-4:/data
  environment:
    - UAT_NODE_NAME=validator-4
    - UAT_BOOTSTRAP_PEER=172.20.0.11:9000
  depends_on:
    - validator-1
```

3. Start new validator:
```bash
docker compose up -d validator-4
```

---

## Monitoring

### Prometheus
Access metrics at: http://localhost:9093

Available metrics:
- `uat_block_height` - Current block number
- `uat_transactions_total` - Total transactions processed
- `uat_validator_stake` - Stake amount per validator
- `uat_consensus_round` - Current consensus round

### Grafana
Access dashboard at: http://localhost:3000
- Username: `admin`
- Password: `unauthority`

Pre-configured dashboards:
- Network Overview
- Validator Performance
- Transaction Throughput
- Resource Usage

---

## Backup & Restore

### Backup Blockchain State
```bash
# Stop validators
docker compose stop validator-1 validator-2 validator-3

# Create backup
tar -czf uat-backup-$(date +%Y%m%d).tar.gz node_data/

# Restart validators
docker compose start validator-1 validator-2 validator-3
```

### Restore from Backup
```bash
# Stop network
docker compose down

# Restore data
tar -xzf uat-backup-20260205.tar.gz

# Start network
docker compose up -d
```

---

## Troubleshooting

### Validators Not Syncing
```bash
# Check P2P connectivity
docker compose exec validator-1 netstat -an | grep 9000

# Verify bootstrap peers
docker compose logs validator-2 | grep "bootstrap"

# Check network
docker network inspect unauthority-core_uat-network
```

### High CPU/Memory Usage
```bash
# Check resources
docker stats

# Limit resources in docker-compose.yml:
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
```

### Cannot Access REST API
```bash
# Check if port is open
curl -v http://localhost:8080/node-info

# Check firewall
sudo ufw allow 8080/tcp

# Check container logs
docker compose logs validator-1
```

### Genesis Configuration Issues
```bash
# Regenerate genesis
docker compose down -v
rm -rf node_data/*
docker run --rm -v $(pwd)/genesis:/genesis \
  unauthority-core_validator-1 genesis_generator
docker compose up -d
```

---

## Production Considerations

### Security
- Change default Grafana password
- Use TLS/SSL for external APIs
- Restrict port access with firewall
- Enable Docker security features:
  ```yaml
  security_opt:
    - no-new-privileges:true
  read_only: true
  ```

### Performance
- Use SSD storage for data volumes
- Enable swap for memory management
- Set appropriate ulimits:
  ```yaml
  ulimits:
    nofile:
      soft: 65536
      hard: 65536
  ```

### High Availability
- Use Docker Swarm or Kubernetes for orchestration
- Implement load balancer for REST APIs
- Set up automatic failover
- Configure health checks properly

---

## Clean Up

### Remove All Data
```bash
# Stop and remove containers
docker compose down

# Remove volumes
docker compose down -v

# Remove images
docker rmi $(docker images -q unauthority*)

# Clean up data directories
rm -rf node_data/*
```

---

## Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [UAT Node Configuration](../validator.toml)
- [Monitoring Setup](./PROMETHEUS_MONITORING_REPORT.md)
