# Frontend Installer Build Guide

Panduan lengkap untuk membuild desktop installer (Electron app) untuk Wallet dan Validator Dashboard.

## Prerequisites

1. **Node.js 18+** dan npm
2. **Rust 1.75+** (untuk backend)
3. **Platform-specific requirements:**
   - **macOS:** Xcode Command Line Tools
   - **Windows:** Visual Studio Build Tools
   - **Linux:** `fuse`, `libfuse2` untuk AppImage

## Quick Build (Automated)

Gunakan script otomatis:

```bash
cd unauthority-core
chmod +x scripts/build_installers.sh
./scripts/build_installers.sh
```

Menu akan muncul:
```
1) Public Wallet Installer
2) Validator Dashboard Installer  
3) Both
```

## Manual Build

### Build Wallet Installer

```bash
cd frontend-wallet

# Install dependencies
npm install

# Build for current platform
npm run electron:build

# Or build for specific platform:
npm run build:mac      # macOS (.dmg)
npm run build:win      # Windows (.exe)
npm run build:linux    # Linux (.AppImage, .deb)

# Build for all platforms (requires all SDKs installed)
npm run build:all
```

**Output:** `frontend-wallet/dist/`

### Build Validator Dashboard Installer

```bash
cd frontend-validator

# Install dependencies
npm install

# Build for current platform
npm run electron:build

# Or build for specific platform:
npm run build:mac      # macOS (.dmg)
npm run build:win      # Windows (.exe)
npm run build:linux    # Linux (.AppImage, .deb)

# Build for all platforms
npm run build:all
```

**Output:** `frontend-validator/dist/`

---

## Platform-Specific Instructions

### macOS (.dmg)

**Requirements:**
- macOS 10.13+ (host machine)
- Xcode Command Line Tools: `xcode-select --install`

**Build:**
```bash
npm run build:mac
```

**Output files:**
- `Unauthority-Wallet-0.1.0.dmg` (wallet)
- `Unauthority-Validator-Dashboard-0.1.0.dmg` (validator)

**Code Signing (optional for distribution):**
```bash
# Get Developer ID certificate from Apple Developer
# Sign the app
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  --options runtime \
  "dist/mac/Unauthority Wallet.app"

# Notarize (required for Catalina+)
xcrun notarytool submit dist/Unauthority-Wallet-0.1.0.dmg \
  --apple-id your@email.com \
  --password app-specific-password \
  --team-id TEAMID
```

---

### Windows (.exe)

**Requirements:**
- Windows 10+ (host machine) OR
- Linux/macOS with `wine` installed for cross-compilation

**Build:**
```bash
npm run build:win
```

**Output files:**
- `Unauthority-Wallet-Setup-0.1.0.exe` (NSIS installer)
- `Unauthority-Wallet-0.1.0-portable.exe` (portable)

**Code Signing (optional):**
```bash
# Get Code Signing Certificate
# Sign with signtool.exe (Windows SDK)
signtool sign /f certificate.pfx /p password \
  /t http://timestamp.digicert.com \
  dist/Unauthority-Wallet-Setup-0.1.0.exe
```

---

### Linux (.AppImage, .deb)

**Requirements:**
- Linux (Ubuntu/Debian recommended)
- `fuse` package: `sudo apt install fuse libfuse2`

**Build:**
```bash
npm run build:linux
```

**Output files:**
- `Unauthority-Wallet-0.1.0.AppImage` (universal)
- `unauthority-wallet_0.1.0_amd64.deb` (Debian/Ubuntu)

**Make AppImage executable:**
```bash
chmod +x dist/Unauthority-Wallet-0.1.0.AppImage
```

---

## Cross-Platform Build

Untuk build semua platform dari satu mesin (Linux/macOS):

**Install cross-compilation tools:**
```bash
# On macOS (for Windows build)
brew install wine-stable

# On Linux (for macOS build - limited support)
# Not recommended, use macOS host for macOS builds
```

**Build all platforms:**
```bash
npm run build:all
```

**Caveat:** macOS builds **HARUS** dilakukan di macOS host karena Apple restrictions.

---

## Configuration

Edit `package.json` untuk custom configuration:

```json
{
  "build": {
    "appId": "com.unauthority.wallet",
    "productName": "Unauthority Wallet",
    "directories": {
      "buildResources": "public"
    },
    "files": [
      "dist/**/*",
      "electron/**/*"
    ],
    "mac": {
      "category": "public.app-category.finance",
      "target": ["dmg", "zip"],
      "icon": "public/icon.icns"
    },
    "win": {
      "target": ["nsis", "portable"],
      "icon": "public/icon.ico"
    },
    "linux": {
      "target": ["AppImage", "deb"],
      "category": "Finance",
      "icon": "public/icon.png"
    }
  }
}
```

---

## Icons

Letakkan icon di `public/`:

- **macOS:** `icon.icns` (512x512, 1024x1024)
- **Windows:** `icon.ico` (256x256, 16x16, 32x32, 48x48)
- **Linux:** `icon.png` (512x512)

**Generate icons:**
```bash
# Install electron-icon-builder
npm install -g electron-icon-builder

# Generate from single PNG (1024x1024)
electron-icon-builder --input=icon.png --output=public
```

---

## Testing Installers

### macOS
```bash
# Install DMG
open dist/Unauthority-Wallet-0.1.0.dmg

# Run installed app
open "/Applications/Unauthority Wallet.app"
```

### Windows
```bash
# Run installer
dist/Unauthority-Wallet-Setup-0.1.0.exe

# Or run portable
dist/Unauthority-Wallet-0.1.0-portable.exe
```

### Linux
```bash
# Run AppImage
./dist/Unauthority-Wallet-0.1.0.AppImage

# Install .deb
sudo dpkg -i dist/unauthority-wallet_0.1.0_amd64.deb
```

---

## Distribution

### GitHub Releases

1. Create release on GitHub:
```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

2. Upload installers ke GitHub Releases:
   - `Unauthority-Wallet-0.1.0.dmg`
   - `Unauthority-Wallet-Setup-0.1.0.exe`
   - `Unauthority-Wallet-0.1.0.AppImage`
   - (Ulangi untuk validator dashboard)

3. Add checksums:
```bash
shasum -a 256 dist/* > checksums.txt
```

### IPFS/Web3 Storage

Upload ke decentralized storage:
```bash
# Install IPFS CLI
npm install -g ipfs-http-client

# Upload
ipfs add -r dist/
```

---

## Troubleshooting

### "electron-builder not found"

```bash
npm install --save-dev electron-builder
```

### macOS: "App is damaged"

User perlu klik kanan → Open (first time only) atau:
```bash
xattr -cr "/Applications/Unauthority Wallet.app"
```

### Windows: "Windows Defender blocked"

User perlu klik "More info" → "Run anyway" (normal untuk unsigned apps)

### Linux: "FUSE error"

```bash
sudo apt install fuse libfuse2
```

### Build gagal: out of memory

Increase Node.js memory:
```bash
export NODE_OPTIONS="--max-old-space-size=4096"
npm run build:all
```

---

## File Sizes (Estimated)

| Platform | Wallet | Validator |
|----------|--------|-----------|
| macOS DMG | ~120 MB | ~115 MB |
| Windows EXE | ~100 MB | ~95 MB |
| Linux AppImage | ~130 MB | ~125 MB |

---

## Auto-Update (Future)

Untuk implement auto-update, tambahkan:

```json
{
  "build": {
    "publish": {
      "provider": "github",
      "owner": "unauthoritymky-6236",
      "repo": "unauthority-core"
    }
  }
}
```

Di `electron/main.js`:
```javascript
import { autoUpdater } from 'electron-updater';

autoUpdater.checkForUpdatesAndNotify();
```

---

## Development vs Production

### Development (No installer needed)

```bash
cd frontend-wallet
npm install
npm run electron:dev
```

### Production (Installer required)

Build installer → distribute → users install locally.

---

## Summary

**Quick Commands:**
```bash
# Build wallet for current OS
cd frontend-wallet && npm run electron:build

# Build validator for current OS
cd frontend-validator && npm run electron:build

# Automated script
./scripts/build_installers.sh
```

**Output:**
- `frontend-wallet/dist/` → Wallet installers
- `frontend-validator/dist/` → Validator installers

**Next Steps:**
1. Test installers on target OS
2. (Optional) Code sign binaries
3. Upload to GitHub Releases
4. Update README with download links
