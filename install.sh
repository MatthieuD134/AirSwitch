#!/usr/bin/env bash
set -euo pipefail

REPO="MatthieuD134/AirSwitch"
APP_NAME="AirSwitch.app"
INSTALL_PATH="/Applications/$APP_NAME"
DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/AirSwitch.app.zip"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

printf "⬇️  Downloading latest AirSwitch release...\n"
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/AirSwitch.app.zip"

printf "📦 Installing to %s...\n" "$INSTALL_PATH"
pkill -f "$INSTALL_PATH" 2>/dev/null || true
rm -rf "$INSTALL_PATH"
ditto -x -k "$TMP_DIR/AirSwitch.app.zip" "/Applications"
xattr -cr "$INSTALL_PATH" 2>/dev/null || true

printf "🚀 Launching AirSwitch...\n"
open "$INSTALL_PATH"

printf "✅ AirSwitch installed! Press ⌃⌥A anywhere to toggle your headphones.\n"
