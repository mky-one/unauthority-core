#!/bin/bash
cd "$(dirname "$0")/../frontend-validator"
npm install
echo "✅ Validator dependencies installed!"
cd ..
echo ""
echo "Now you can run: ./start_all.sh"
