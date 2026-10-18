#!/usr/bin/env bash
# Starts a headless Chromium with a loopback DevTools endpoint for REA's web
# tools (list_browser_targets, inspect_web_page, ...). Usage:
#   bash scripts/cloud/start-chromium-cdp.sh [URL] [PORT]
set -euo pipefail

url="${1:-about:blank}"
port="${2:-9222}"
chrome="$(readlink -f /opt/pw-browsers/chromium)"
profile="$(mktemp -d)"

"$chrome" --headless=new --no-sandbox --disable-gpu \
  --remote-debugging-address=127.0.0.1 --remote-debugging-port="$port" \
  --user-data-dir="$profile" "$url" >/dev/null 2>&1 &

for _ in $(seq 1 50); do
  curl -fsS "http://127.0.0.1:$port/json/version" >/dev/null 2>&1 && break
  sleep 0.2
done
echo "CDP endpoint: http://127.0.0.1:$port (pid $!)"
