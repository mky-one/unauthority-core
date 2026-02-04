# Unauthority Validator Dashboard

Professional monitoring and management interface for Unauthority blockchain validator operators.

## Features

- **Real-time Monitoring**: Live network statistics and validator performance
- **Validator Management**: View stake, uptime, and rewards for all validators
- **Block Explorer**: Recent blocks and transaction history
- **Network Health**: Connection status and peer information
- **Desktop Application**: Standalone Electron app for Mac, Windows, and Linux

## Quick Start

### Development Mode

```bash
# Install dependencies
npm install

# Run web version
npm run dev

# Run Electron app
npm run electron:dev
```

### Build Desktop App

```bash
# Build for current platform
npm run electron:build

# Build for specific platform
npm run electron:build:mac
npm run electron:build:win
npm run electron:build:linux
```

## Configuration

The dashboard connects to your validator node REST API (default: `http://localhost:3030`).

Update the API endpoint in Settings if your node runs on a different port.

## Requirements

- Node.js 18+
- Running Unauthority validator node with REST API enabled

## Architecture

- **Frontend**: React + TypeScript + Vite
- **Styling**: TailwindCSS
- **State**: Zustand
- **Charts**: Recharts
- **Desktop**: Electron

## Deployment Options

1. **Electron Desktop App** (Recommended)
   - Download from GitHub Releases
   - Install `.dmg` (Mac), `.exe` (Windows), or `.AppImage` (Linux)

2. **Web Version**
   - Build: `npm run build`
   - Serve `dist/` folder with any HTTP server

3. **IPFS Decentralized Hosting**
   - Upload `dist/` to IPFS via Pinata or Nft.storage
   - Access via IPFS gateway

## License

MIT - Unauthority Core Team
