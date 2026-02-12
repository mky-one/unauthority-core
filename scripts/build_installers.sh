#!/bin/bash
# Frontend Installer Builder Script
# This script builds Electron desktop apps for all platforms

set -e

echo "🏗️  LOS Frontend Installer Builder"
echo "=================================="

# Check prerequisites
command -v npm >/dev/null 2>&1 || { echo "❌ npm not found. Install Node.js first."; exit 1; }

# Function to build wallet installer
build_wallet() {
    echo ""
    echo "📦 Building Wallet Installer..."
    cd frontend-wallet
    
    # Install dependencies
    echo "📥 Installing dependencies..."
    npm install
    
    # Install electron-builder if not present
    if ! npm list electron-builder >/dev/null 2>&1; then
        echo "📥 Installing electron-builder..."
        npm install --save-dev electron-builder
    fi
    
    # Build for all platforms
    echo "🔨 Building for macOS..."
    npm run build:mac || echo "⚠️  macOS build skipped (requires macOS host)"
    
    echo "🔨 Building for Windows..."
    npm run build:win || echo "⚠️  Windows build skipped"
    
    echo "🔨 Building for Linux..."
    npm run build:linux || echo "⚠️  Linux build skipped"
    
    echo "✅ Wallet installer(s) built!"
    echo "📂 Check frontend-wallet/dist/ for installers"
    
    cd ..
}

# Function to build validator dashboard installer
build_validator() {
    echo ""
    echo "📦 Building Validator Dashboard Installer..."
    cd frontend-validator
    
    # Install dependencies
    echo "📥 Installing dependencies..."
    npm install
    
    # Install electron-builder if not present
    if ! npm list electron-builder >/dev/null 2>&1; then
        echo "📥 Installing electron-builder..."
        npm install --save-dev electron-builder
    fi
    
    # Build for all platforms
    echo "🔨 Building for macOS..."
    npm run build:mac || echo "⚠️  macOS build skipped (requires macOS host)"
    
    echo "🔨 Building for Windows..."
    npm run build:win || echo "⚠️  Windows build skipped"
    
    echo "🔨 Building for Linux..."
    npm run build:linux || echo "⚠️  Linux build skipped"
    
    echo "✅ Validator dashboard installer(s) built!"
    echo "📂 Check frontend-validator/dist/ for installers"
    
    cd ..
}

# Main menu
echo ""
echo "What would you like to build?"
echo "1) Public Wallet Installer"
echo "2) Validator Dashboard Installer"
echo "3) Both"
echo ""
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        build_wallet
        ;;
    2)
        build_validator
        ;;
    3)
        build_wallet
        build_validator
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🎉 Build complete!"
echo ""
echo "📦 Installer locations:"
echo "  - Wallet: frontend-wallet/dist/"
echo "  - Validator: frontend-validator/dist/"
echo ""
echo "🚀 Next steps:"
echo "  1. Test installers on target OS"
echo "  2. Sign binaries (macOS: codesign, Windows: signtool)"
echo "  3. Upload to GitHub Releases"
