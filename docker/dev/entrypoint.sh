#!/bin/bash
set -e

BUNDLE_CHECKSUM_FILE="vendor/bundle/.gemfile_checksum"
NPM_CHECKSUM_FILE="node_modules/.package_checksum"

# --- Bundle install (skip if Gemfile.lock unchanged) ---
current_gemfile_checksum=$(md5sum Gemfile.lock 2>/dev/null | awk '{print $1}')
stored_gemfile_checksum=$(cat "$BUNDLE_CHECKSUM_FILE" 2>/dev/null || echo "")

if [ "$current_gemfile_checksum" != "$stored_gemfile_checksum" ]; then
  echo "[entrypoint] Installing Ruby dependencies..."
  bundle install
  echo "$current_gemfile_checksum" > "$BUNDLE_CHECKSUM_FILE"
else
  echo "[entrypoint] Ruby dependencies up to date."
fi

# --- npm install (skip if package.json unchanged) ---
current_package_checksum=$(md5sum package.json 2>/dev/null | awk '{print $1}')
stored_package_checksum=$(cat "$NPM_CHECKSUM_FILE" 2>/dev/null || echo "")

if [ "$current_package_checksum" != "$stored_package_checksum" ]; then
  echo "[entrypoint] Installing Node dependencies..."
  npm install
  echo "$current_package_checksum" > "$NPM_CHECKSUM_FILE"
else
  echo "[entrypoint] Node dependencies up to date."
fi

# --- Build CSS on first run ---
if [ ! -f "app/assets/builds/application.css" ]; then
  echo "[entrypoint] Building CSS (first run)..."
  npm run build:css
fi

echo "[entrypoint] Starting: $@"
exec "$@"
