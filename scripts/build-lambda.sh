#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LAMBDA_DIR="$PROJECT_DIR/lambda"
PACKAGE_DIR="$LAMBDA_DIR/package"

echo "==> Cleaning previous build..."
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

echo "==> Installing dependencies with uv..."
uv pip install \
    --target "$PACKAGE_DIR" \
    -r "$LAMBDA_DIR/requirements.txt" \
    --quiet

echo "==> Copying handler..."
cp "$LAMBDA_DIR/handler.py" "$PACKAGE_DIR/handler.py"

echo "==> Build complete. Package dir: $PACKAGE_DIR"
