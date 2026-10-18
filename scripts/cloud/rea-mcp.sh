#!/usr/bin/env bash
# Launches the REA MCP server (stdio) for .mcp.json. Uses the toolchain that
# scripts/cloud/setup.sh installs under $REA_TOOLS and exports each engine's
# path only when it is present; without it, falls back to plain npx.
# Extra arguments run another rea command in the same environment, e.g.
#   bash scripts/cloud/rea-mcp.sh doctor --json
set -euo pipefail

REA_TOOLS="${REA_TOOLS:-/opt/rea-tools}"
REA_VERSION="6.5.0"

# export_if VAR PATH: export VAR=PATH when PATH exists and VAR is not set yet.
export_if() {
  if [[ -z "${!1:-}" && -e "$2" ]]; then export "$1=$2"; fi
}

export_if GHIDRA_INSTALL_DIR "$REA_TOOLS/ghidra_12.1.4_PUBLIC"
export_if REA_JADX_MCP_JAR "$REA_TOOLS/android/jadx-headless-mcp-0.7.1-all.jar"
export_if REA_WABT_BIN_DIRECTORY "$REA_TOOLS/wabt-1.0.42/bin"
export_if REA_RIZIN_COMMAND "$REA_TOOLS/rizin-0.9.1/bin/rizin"
export_if REA_BINWALK_COMMAND "$REA_TOOLS/binwalk-3.1.0/bin/binwalk"
export_if REA_UNBLOB_COMMAND "$REA_TOOLS/unblob-26.6.4/bin/unblob"
export_if REA_WAKARU_COMMAND "$REA_TOOLS/wakaru-1.14.0/wakaru"
export_if REA_PWNTOOLS_PYTHON "$REA_TOOLS/pwntools-4.15.0/bin/python"
for tool in TSHARK:tshark CAPINFOS:capinfos SIGROK:sigrok-cli APKTOOL:apktool; do
  export_if "REA_${tool%%:*}_COMMAND" "$(command -v "${tool#*:}" || true)"
done
export_if REA_ADB_PATH "$(command -v adb || true)"
export_if REA_BROWSER_EXECUTABLE "$(readlink -f /opt/pw-browsers/chromium 2>/dev/null || true)"
if command -v javac >/dev/null; then
  export_if JAVA_HOME "$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
fi
# Cloud containers run as root, where Chromium refuses its sandbox.
[[ "$(id -u)" == 0 ]] && export REA_BROWSER_NO_SANDBOX="${REA_BROWSER_NO_SANDBOX:-true}"

for bin in "$REA_TOOLS/rizin-0.9.1/bin" "$REA_TOOLS/node/bin"; do
  [[ -d "$bin" ]] && PATH="$bin:$PATH"
done
export PATH

if [[ -x "$REA_TOOLS/rea/node_modules/.bin/rea" ]]; then
  exec "$REA_TOOLS/rea/node_modules/.bin/rea" "${@:-mcp}"
fi
exec npx -y "rea-agents@$REA_VERSION" "${@:-mcp}"
