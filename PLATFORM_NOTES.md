# Platform-Specific Notes

This document covers known issues, testing status, and platform-specific behavior for LOS Wallet and LOS Validator.

---

## ✅ Testing Status

| Platform | Local Testing | CI Testing | Bundle Verification | Status |
|----------|---------------|------------|---------------------|--------|
| **macOS (Intel + Apple Silicon)** | ✅ Extensive | ✅ Pass | ✅ DMG verified | 🟢 Production-ready |
| **Linux (x86_64)** | ⚠️ Limited | ✅ Pass | ✅ tar.gz verified | 🟡 CI-only (needs field testing) |
| **Windows (x86_64)** | ⚠️ Limited | ✅ Pass | ✅ zip verified | 🟡 CI-only (needs field testing) |

### Key Notes
- **macOS:** Fully tested locally on M1/M2 and Intel Macs. All features verified.
- **Linux:** GitHub Actions builds successfully, all components bundled. **Not tested on real Linux desktop.**
- **Windows:** GitHub Actions builds successfully, all components bundled. **Not tested on real Windows machine.**

**CI Test Results:**
- ✅ Cross-platform builds pass (ubuntu-latest, macos-latest, windows-latest runners)
- ✅ Native library builds from source on each platform
- ✅ los-node binary builds and bundles correctly
- ✅ Flutter apps compile without errors
- ✅ Release artifacts created successfully (DMG, tar.gz, zip)

**What Still Needs Verification:**
- 🔲 Tor auto-download on real Linux desktop (Ubuntu 22.04/24.04, Fedora, Arch)
- 🔲 Tor auto-download on real Windows 10/11
- 🔲 Native library loading on Linux (LD_LIBRARY_PATH via run.sh)
- 🔲 Native library loading on Windows (DLL search path)
- 🔲 los-node binary execution on Linux/Windows (file permissions, dependencies)
- 🔲 Flutter UI rendering on Linux X11/Wayland
- 🔲 Flutter UI rendering on Windows (high-DPI displays)

---

## 🐧 Linux-Specific Notes

### Bundled Components
- **Native Library:** `lib/liblos_crypto_ffi.so` (Dilithium5 post-quantum crypto)
- **los-node Binary:** `los-node` (validator only, 21MB)
- **Launcher Script:** `run.sh` (sets `LD_LIBRARY_PATH` automatically)

### Installation
```bash
tar -xzf LOS-{Wallet|Validator}-*-linux-x64.tar.gz
cd bundle
chmod +x run.sh flutter_{wallet|validator} los-node  # los-node only for validator
./run.sh
```

### Known Issues & Workarounds

#### 1. **Native Library Not Found**
**Error:** `liblos_crypto_ffi.so: cannot open shared object file`

**Cause:** Binary executed directly (not via `run.sh`), so `LD_LIBRARY_PATH` not set.

**Fix:**
```bash
# Option A: Always use run.sh
./run.sh

# Option B: Set env var manually
export LD_LIBRARY_PATH="$(pwd)/lib:$LD_LIBRARY_PATH"
./flutter_wallet  # or flutter_validator
```

#### 2. **Tor Auto-Download Fails**
**Error:** `Failed to download Tor Expert Bundle`

**Cause:** Firewall blocking HTTPS to torproject.org, or missing `libssl`/`ca-certificates`.

**Fix:**
```bash
# Install system Tor (wallet/validator will detect automatically)
sudo apt install tor  # Debian/Ubuntu
sudo dnf install tor  # Fedora/RHEL
sudo pacman -S tor    # Arch Linux

# Start Tor service (optional, apps can start their own instance)
sudo systemctl start tor
```

#### 3. **Tor Binary Not Executable**
**Error:** `Permission denied: tor`

**Cause:** Extracted Tor binary missing +x permissions.

**Fix:**
```bash
# Find Tor directory (in app data)
find ~/.local/share -name "tor" -type f
# Make executable
chmod +x ~/.local/share/flutter_wallet/tor/tor  # adjust path as needed
```

#### 4. **GLIBC Version Mismatch**
**Error:** `version 'GLIBC_2.29' not found`

**Cause:** App built on newer glibc than system provides.

**Fix:**
- Update OS to Ubuntu 20.04+, Fedora 32+, or Debian 11+
- Or: Run via Docker (see Dockerfile in repo)

#### 5. **Missing Dependencies**
**Error:** `error while loading shared libraries: libgtk-3.so.0`

**Cause:** Flutter requires GTK3 libraries on Linux.

**Fix:**
```bash
# Ubuntu/Debian
sudo apt install libgtk-3-0 libblkid1 liblzma5

# Fedora
sudo dnf install gtk3

# Arch
sudo pacman -S gtk3
```

---

## 🪟 Windows-Specific Notes

### Bundled Components
- **Native Library:** `los_crypto_ffi.dll` (in same directory as .exe)
- **los-node Binary:** `los-node.exe` (validator only, 21MB)
- **No Launcher Script:** Windows uses standard DLL search order (current dir → System32 → PATH)

### Installation
1. Extract `LOS-{Wallet|Validator}-*-windows-x64.zip` to `C:\LOS-Wallet\` (or any folder)
2. Run `flutter_wallet.exe` or `flutter_validator.exe`
3. If Windows Defender blocks: Click "More info" → "Run anyway"

### Known Issues & Workarounds

#### 1. **Windows Defender SmartScreen Warning**
**Warning:** "Windows protected your PC"

**Cause:** App not signed with EV code signing certificate (requires $300+/year).

**Fix:**
- Click "**More info**"
- Click "**Run anyway**"
- (One-time prompt per new version)

#### 2. **DLL Not Found**
**Error:** `The code execution cannot proceed because los_crypto_ffi.dll was not found`

**Cause:** DLL not in same directory as .exe (extraction error).

**Fix:**
- Verify `los_crypto_ffi.dll` is in the same folder as `flutter_wallet.exe` or `flutter_validator.exe`
- Re-extract the full .zip file (don't move files individually)

#### 3. **Tor Auto-Download Fails**
**Error:** `Failed to download Tor Expert Bundle`

**Cause:** Windows Firewall or antivirus blocking HTTPS to torproject.org.

**Fix:**
```powershell
# Option A: Allow app through firewall
# Windows Defender Firewall → Allow an app → Browse → select flutter_wallet.exe

# Option B: Install Tor manually
# 1. Download Tor Expert Bundle: https://dist.torproject.org/torbrowser/
# 2. Extract to C:\Tor\
# 3. Add C:\Tor\ to PATH or place tor.exe in app directory
```

#### 4. **Firewall Blocking los-node.exe**
**Error:** Validator dashboard shows "Node Offline"

**Cause:** Windows Firewall blocking `los-node.exe` from listening on ports.

**Fix:**
- Windows shows a popup: "Allow los-node.exe to communicate on networks"
- Check "Private networks" and "Public networks"
- Click "Allow access"

#### 5. **High DPI Scaling Issues**
**Issue:** Blurry UI or tiny text on 4K displays

**Fix:**
- Right-click `flutter_wallet.exe` → Properties → Compatibility
- Click "Change high DPI settings"
- Check "Override high DPI scaling behavior"
- Select "System (Enhanced)" from dropdown

---

## 🍎 macOS-Specific Notes

### Bundled Components
- **Native Library:** `liblos_crypto_ffi.dylib` (universal binary: arm64 + x86_64)
- **los-node Binary:** `los-node` (validator only, universal binary)
- **DMG Installer:** Drag-and-drop to Applications

### Installation
1. Download `.dmg` file
2. Open `.dmg` (may need to approve in System Settings if downloaded via browser)
3. Drag app icon to Applications folder
4. Launch from Applications
5. If blocked: System Settings → Privacy & Security → "Open Anyway"

### Known Issues & Workarounds

#### 1. **"App is damaged and can't be opened"**
**Error:** macOS Gatekeeper blocking app

**Cause:** App not notarized (requires Apple Developer account $99/year).

**Fix:**
```bash
# Remove ALL quarantine attributes (recommended)
xattr -cr /Applications/LOS\ Wallet.app
xattr -cr /Applications/LOS\ Validator\ Node.app

# Or remove specific attribute only
xattr -d com.apple.quarantine /Applications/LOS\ Wallet.app
```

**Alternative:** System Settings → Privacy & Security → Click "Open Anyway" below the error message.

> **Note:** `-cr` (clear + recursive) is more thorough than `-d` (delete single attribute).

#### 2. **Tor Permissions Issue**
**Error:** `Operation not permitted: tor`

**Cause:** macOS sandboxing preventing Tor execution.

**Fix:**
- Install system Tor via Homebrew: `brew install tor`
- App will auto-detect and use system Tor

#### 3. **Apple Silicon (M1/M2) Performance**
**Status:** ✅ Fully supported via universal binary (native arm64 + x86_64)

**Performance Notes:**
- Native arm64 code runs 2-3x faster than Rosetta 2 (universal binary includes both)
- los-node consensus validation: ~5ms latency on M1, ~12ms on Intel (same workload)

---

## 🔧 Multi-Platform Debugging

### Enable Debug Logging
```bash
# Linux/macOS
export RUST_LOG=debug
./run.sh  # or ./flutter_wallet

# Windows (PowerShell)
$env:RUST_LOG="debug"
.\flutter_wallet.exe
```

### Check Native Library Loading
```bash
# Linux
ldd bundle/flutter_wallet | grep los_crypto_ffi
# Should show: liblos_crypto_ffi.so => .../lib/liblos_crypto_ffi.so

# macOS
otool -L /Applications/LOS\ Wallet.app/Contents/MacOS/los_wallet | grep los_crypto_ffi
# Should show: @rpath/liblos_crypto_ffi.dylib

# Windows (PowerShell)
Get-Process flutter_wallet | Select-Object -ExpandProperty Modules | Where-Object { $_.ModuleName -like "*los_crypto*" }
# Should show: los_crypto_ffi.dll
```

### Verify Tor Connectivity
```bash
# Test Tor SOCKS proxy (after app starts)
curl --socks5 127.0.0.1:19151 https://check.torproject.org/ | grep -i congratulations
# Should show: "Congratulations. This browser is configured to use Tor."
```

### Test los-node Binary (Validator)
```bash
# Check dependencies
# Linux
ldd los-node

# macOS
otool -L los-node

# Windows
dumpbin /dependents los-node.exe  # requires Visual Studio
```

---

## 📊 CI/CD Pipeline Details

### GitHub Actions Runners
- **ubuntu-latest:** Ubuntu 22.04, glibc 2.35, gcc 11.4
- **macos-latest:** macOS 14 (Sonoma), Xcode 15.4
- **windows-latest:** Windows Server 2022, MSVC 2022

### Build Process
1. **Install Rust:** `rustup` stable 1.93.0
2. **Install Flutter:** 3.38.4 stable
3. **Build Native Library:**
   ```bash
   cd flutter_{wallet|validator}/native/los_crypto_ffi
   cargo build --release
   # Output: target/release/liblos_crypto_ffi.{so|dylib|dll}
   ```
4. **Build los-node (Validator only):**
   ```bash
   cargo build --release -p los-node
   # Output: target/release/los-node{.exe}
   ```
5. **Bundle:**
   - Copy native lib to Flutter app structure
   - Copy los-node binary (validator only)
   - Create installer (DMG/tar.gz/zip)
6. **Upload to GitHub Release**

### Artifacts
- **macOS:** `.dmg` (code-signed with ad-hoc signature, not notarized)
- **Linux:** `.tar.gz` with `run.sh` launcher (sets LD_LIBRARY_PATH)
- **Windows:** `.zip` with DLL in root directory

---

## 🧪 Recommended Testing Before Public Launch

### Validation Checklist
- [ ] **Linux Ubuntu 22.04/24.04:** Install, run wallet, send transaction, run validator
- [ ] **Linux Fedora 40+:** Same as above
- [ ] **Linux Arch:** Same as above
- [ ] **Windows 10:** Install, run wallet, send transaction
- [ ] **Windows 11:** Install, run validator, register, earn rewards
- [ ] **High-DPI Windows:** Check UI scaling on 4K display
- [ ] **Linux Wayland:** Check window management and clipboard
- [ ] **Tor Auto-Download:** Test on fresh Linux/Windows VM (no system Tor)
- [ ] **Firewall Test:** Enable restrictive firewall, verify Tor still connects
- [ ] **Multi-Validator:** Run 2-3 validators on same Linux/Windows machine (different ports)

### Automated Testing (Future)
- Docker images for Linux testing (Ubuntu, Fedora, Arch)
- Wine testing for Windows (on Linux CI runner)
- Virtual machine testing via qemu (automated snapshots)

---

## 📞 Reporting Platform-Specific Issues

If you encounter platform-specific bugs:

1. **Check This Document:** Issue may already be documented above
2. **Enable Debug Logging:** Set `RUST_LOG=debug` before running
3. **Gather System Info:**
   - OS version (`uname -a` on Linux/macOS, `systeminfo` on Windows)
   - Flutter version (`flutter --version`)
   - Rust version (`rustc --version`)
   - Tor version (`tor --version`)
4. **Open GitHub Issue:** [https://github.com/monkey-one/unauthority-core/issues](https://github.com/monkey-one/unauthority-core/issues)
   - Title: `[Platform] Brief description` (e.g., `[Linux] Tor auto-download fails on Fedora 40`)
   - Include: Error messages, logs, steps to reproduce

---

**Last Updated:** Feb 15, 2025  
**CI Build:** [![CI](https://github.com/monkey-one/unauthority-core/actions/workflows/ci.yml/badge.svg)](https://github.com/monkey-one/unauthority-core/actions/workflows/ci.yml)
