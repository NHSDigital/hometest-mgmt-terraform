#!/bin/bash
# Build script for HomeTest Lambda functions and SPA

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "======================================"
echo "Building HomeTest Applications"
echo "======================================"

# Build Lambda functions
echo ""
echo "📦 Building Lambda Functions..."
echo "--------------------------------------"

cd "$ROOT_DIR/examples/lambdas"

# API 1 Handler
echo "Building api1-handler..."
cd api1-handler
npm install --silent
npm run build
npm run package
echo "✅ api1-handler built: api1-handler.zip"
cd ..

# API 2 Handler
echo "Building api2-handler..."
cd api2-handler
npm install --silent
npm run build
npm run package
echo "✅ api2-handler built: api2-handler.zip"
cd ..

# Build SPA
echo ""
echo "🌐 Building SPA..."
echo "--------------------------------------"

cd "$ROOT_DIR/examples/spa"

# Default to dev1 if no environment specified
ENVIRONMENT=${1:-dev1}

export VITE_API1_URL="https://api1.${ENVIRONMENT}.hometest.service.nhs.uk"
export VITE_API2_URL="https://api2.${ENVIRONMENT}.hometest.service.nhs.uk"

echo "Building for environment: $ENVIRONMENT"
echo "API1_URL: $VITE_API1_URL"
echo "API2_URL: $VITE_API2_URL"

npm install --silent
npm run build

echo "✅ SPA built: dist/"

echo ""
echo "======================================"
echo "Build Complete!"
echo "======================================"
echo ""
echo "Lambda packages:"
echo "  - examples/lambdas/api1-handler/api1-handler.zip"
echo "  - examples/lambdas/api2-handler/api2-handler.zip"
echo ""
echo "SPA output:"
echo "  - examples/spa/dist/"
echo ""
echo "Next steps:"
echo "  1. Upload Lambda packages to S3"
echo "  2. Deploy with: cd infrastructure/environments/poc && terragrunt run-all apply"
