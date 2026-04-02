#!/bin/bash
set -e

# Ensure volume mount directories exist (needed for lock file on fresh volumes)
mkdir -p vendor/bundle node_modules

BUNDLE_CHECKSUM_FILE="vendor/bundle/.gemfile_checksum"
NPM_CHECKSUM_FILE="node_modules/.package_checksum"
LOCK_FILE="vendor/bundle/.entrypoint.lock"

# Use a file lock to prevent multiple containers from running installs simultaneously.
# All app containers share the same named volumes, so concurrent npm/bundle installs
# cause race conditions. flock ensures only one runs at a time; others wait then
# skip because the checksum will already match.
exec 200>"$LOCK_FILE"
flock 200

# --- Bundle install (skip if Gemfile.lock unchanged) ---
current_gemfile_checksum=$(md5sum Gemfile.lock 2>/dev/null | awk '{print $1}')
stored_gemfile_checksum=$(cat "$BUNDLE_CHECKSUM_FILE" 2>/dev/null || echo "")

if [ "$current_gemfile_checksum" != "$stored_gemfile_checksum" ]; then
  echo "[entrypoint] Installing Ruby dependencies..."
  bundle lock --add-platform "$(ruby -e 'puts Gem::Platform.local.to_s')" 2>/dev/null
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

# Release the lock before exec (exec replaces the process, so the lock fd closes)
flock -u 200

echo "[entrypoint] Starting: $@"
exec "$@"
