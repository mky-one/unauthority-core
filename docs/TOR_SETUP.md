# Tor Setup Guide

Configure Tor hidden services for LOS validator nodes. All network traffic routes through Tor — no public IP addresses are exposed.

**Version:** v1.0.6-testnet

---

## Overview

LOS validators run as Tor hidden services (`.onion` addresses). This provides:

- **No public IP** — validators are reachable only via .onion
- **Censorship resistance** — Tor circuits bypass network blocks
- **Privacy** — validator operators are anonymous
- **DDoS protection** — .onion addresses can't be targeted by IP

---

## Automated Setup

The fastest way to set up Tor for a 4-node testnet:

```bash
./setup_tor_testnet.sh
```

This script:
1. Installs Tor if not present (via `brew` on macOS, `apt` on Linux)
2. Generates dedicated `torrc` with 4 hidden service directories
3. Creates hidden service keys for each validator
4. Starts Tor and waits for `.onion` addresses
5. Outputs all addresses to `testnet-tor-info.json`

After running, your `.onion` addresses are in `testnet-tor-info.json`:

```json
{
  "validators": [
    {
      "id": 1,
      "onion": "abc123...xyz.onion",
      "rest_url": "http://abc123...xyz.onion",
      "p2p": "abc123...xyz.onion:4001"
    }
  ]
}
```

### Stop Tor

```bash
./stop_tor_testnet.sh
```

---

## Manual Setup

### 1. Install Tor

```bash
# macOS
brew install tor

# Ubuntu/Debian
sudo apt install tor

# Verify
tor --version
```

### 2. Create Hidden Service Directory

```bash
mkdir -p /var/lib/tor/los-validator-1
chmod 700 /var/lib/tor/los-validator-1
```

### 3. Configure torrc

Add to `/etc/tor/torrc` (or custom torrc):

```
# LOS Validator 1
HiddenServiceDir /var/lib/tor/los-validator-1
HiddenServicePort 80 127.0.0.1:3030    # REST API
HiddenServicePort 4001 127.0.0.1:4001  # P2P
```

For multiple validators:

```
# Validator 1
HiddenServiceDir /var/lib/tor/los-validator-1
HiddenServicePort 80 127.0.0.1:3030
HiddenServicePort 4001 127.0.0.1:4001

# Validator 2
HiddenServiceDir /var/lib/tor/los-validator-2
HiddenServicePort 80 127.0.0.1:3031
HiddenServicePort 4001 127.0.0.1:4002

# Validator 3
HiddenServiceDir /var/lib/tor/los-validator-3
HiddenServicePort 80 127.0.0.1:3032
HiddenServicePort 4001 127.0.0.1:4003

# Validator 4
HiddenServiceDir /var/lib/tor/los-validator-4
HiddenServicePort 80 127.0.0.1:3033
HiddenServicePort 4001 127.0.0.1:4004

# SOCKS5 proxy for outbound connections
SocksPort 9052
```

### 4. Start Tor

```bash
tor -f /path/to/torrc &
```

### 5. Get Your .onion Address

```bash
cat /var/lib/tor/los-validator-1/hostname
# abc123...xyz.onion
```

### 6. Start Node with Tor

```bash
./target/release/los-node \
  --dev \
  --port 3030 \
  --p2p-port 4001 \
  --tor-socks 127.0.0.1:9052 \
  --tor-onion abc123...xyz.onion
```

---

## Connecting to Tor Nodes

### From curl

```bash
# Requires Tor running with SOCKS5 proxy
curl --socks5-hostname 127.0.0.1:9052 \
  http://ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion/health
```

### From Tor Browser

Navigate directly to:
```
http://ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion/node-info
```

### From Flutter Wallet/Validator

The Flutter apps include **bundled Tor** — they handle .onion connectivity automatically:

- Bundled Tor port: 9250
- Tor Browser port: 9150
- Auto-detection sequence: detect existing → find system binary → check cache → install

No manual Tor configuration is needed for end users.

---

## Current Testnet Bootstrap Nodes

| Node | .onion Address | REST | P2P |
|------|---------------|------|-----|
| Validator 1 | `ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion` | `:80` | `:4001` |
| Validator 2 | `5yvqf4sdbif4pegxgrgfq5ksv3gqqpt27x2xzx5nvrmdqmsrk4mnkgad.onion` | `:80` | `:4001` |
| Validator 3 | `3e3vi6ealajwangzmiz2ec7b5gqahnysk3tjs7yol7rptmsrthrpjvad.onion` | `:80` | `:4001` |
| Validator 4 | `yapub6hgjr3eyxnxzvgd4yejt7rkhwlmaivdpy6757o3tr5iicckgjyd.onion` | `:80` | `:4001` |

These addresses are defined in `testnet-tor-info.json`.

---

## Security Best Practices

| Practice | Description |
|----------|-------------|
| Bind `127.0.0.1` | LOS node binds localhost by default — never expose to `0.0.0.0` in production |
| mDNS disabled | Auto-disabled when Tor is detected to prevent DNS leaks |
| Hidden service keys | Store in `chmod 700` directories — these ARE your node identity |
| Separate SOCKS ports | Use dedicated SOCKS port (9052) — don't share with browser (9150) |
| No DNS lookups | All peer resolution goes through Tor SOCKS5 (`--socks5-hostname`) |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Connection refused" on .onion | Ensure Tor is running and SOCKS5 port matches |
| Slow connections | Normal — Tor adds 2-5 seconds latency per hop |
| "Hostname not found" | Use `--socks5-hostname` (not `--socks5`) to resolve via Tor |
| Hidden service not generating | Check `torrc` syntax and directory permissions (must be `700`) |
| Flutter app can't connect | Check if another Tor instance is using port 9250 |

---

## Port Reference

| Port | Service | Protocol |
|------|---------|----------|
| 3030–3033 | REST API (local) | HTTP |
| 4001–4004 | P2P (local) | libp2p |
| 9052 | Tor SOCKS5 (setup_tor_testnet.sh) | SOCKS5 |
| 9050 | Tor SOCKS5 (system default) | SOCKS5 |
| 9150 | Tor Browser SOCKS5 | SOCKS5 |
| 9250 | Flutter bundled Tor | SOCKS5 |
| 80 | REST API (via .onion) | HTTP |
| 4001 | P2P (via .onion) | libp2p |
