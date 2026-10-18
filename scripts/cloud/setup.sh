#!/usr/bin/env bash
# install_* functions are invoked indirectly through run().
# shellcheck disable=SC2317
# Installs REA (rea-agents) and its analysis engines for Claude Code cloud
# sessions (Ubuntu 24.04 x86_64, root). Self-contained: paste it into the cloud
# environment's "Setup script", or run `bash scripts/cloud/setup.sh`.
#
# Everything lands under $REA_TOOLS (default /opt/rea-tools). Each component is
# idempotent and independent: one failure is reported and the rest continue.
# Skip components with REA_SETUP_SKIP="ghidra binwalk ...".
set -uo pipefail

REA_TOOLS="${REA_TOOLS:-/opt/rea-tools}"
REA_VERSION="6.5.0"

NODE_VERSION="24.22.0"
NODE_SHA256="cc2f601cee82d9a5a233302fe307abc600727035fd7d2c3a3571755989e95008"
GHIDRA_VERSION="12.1.4"
GHIDRA_URL="https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip"
GHIDRA_SHA256="ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db"
JADX_URL="https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar"
JADX_SHA256="6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75"
WABT_VERSION="1.0.42"
WABT_URL="https://github.com/WebAssembly/wabt/releases/download/1.0.42/wabt-1.0.42-linux-x64.tar.gz"
WABT_SHA256="84895407a6bbb80e918f33b16b2fb2206021c150b6bc9ff6f761263a745ab131"
RIZIN_VERSION="0.9.1"
RIZIN_URL="https://github.com/rizinorg/rizin/releases/download/v0.9.1/rizin-v0.9.1-static-x86_64.tar.xz"
RIZIN_SHA256="9102249a9f0b6319c5334a2e5cf8d9cc3f2035e1d3def027c41f6a90f647e8cf"
BINWALK_VERSION="3.1.0"
UNBLOB_VERSION="26.6.4"
WAKARU_URL="https://github.com/pionxzh/wakaru/releases/download/v1.14.0/wakaru-linux-x64.tar.gz"
WAKARU_SHA256="664fa06782a61eda7ed15885134b52525fd565dd77607e642062ceb6cd927c38"
PWNTOOLS_PINS=(pwntools==4.15.0 pyelftools==0.33 unicorn==2.1.2)

export DEBIAN_FRONTEND=noninteractive
DOWNLOADS="$REA_TOOLS/downloads"
mkdir -p "$DOWNLOADS"
declare -a RESULTS=()

log() { printf '[rea-setup] %s\n' "$*"; }

skipped() { [[ " ${REA_SETUP_SKIP:-} " == *" $1 "* ]]; }

# fetch URL SHA256 DEST: download (resuming cut-off transfers, up to 3
# attempts) and verify the pinned digest.
fetch() {
  local url="$1" sha="$2" dest="$3" attempt
  for attempt in 1 2 3; do
    if [[ ! -s "$dest" ]]; then
      curl -fsSL --retry 4 --retry-delay 2 --retry-all-errors -C - -o "$dest.part" "$url" &&
        mv "$dest.part" "$dest"
    fi
    echo "$sha  $dest" | sha256sum -c --quiet - 2>/dev/null && return 0
    log "download attempt $attempt failed: ${url##*/}"
    rm -f "$dest"
    sleep $((attempt * 4))
  done
  rm -f "$dest.part"
  return 1
}

run() {
  local name="$1"; shift
  if skipped "$name"; then RESULTS+=("SKIP  $name"); return; fi
  log "installing $name"
  if "$@"; then RESULTS+=("OK    $name"); else RESULTS+=("FAIL  $name (exit $?)"); fi
}

install_apt() {
  # tshark: answer the setcap question up front so install stays non-interactive.
  echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections
  apt-get update -qq &&
  apt-get install -y -qq --no-install-recommends \
    ca-certificates curl unzip xz-utils procps util-linux file \
    binutils gdb tshark sigrok-cli adb apktool python3-venv \
    build-essential pkg-config libfontconfig1-dev liblzma-dev libbz2-dev \
    android-sdk-libsparse-utils e2fsprogs lz4 lzop p7zip-full unar zstd libmagic1 >/dev/null
}

install_node() {
  local dir="$REA_TOOLS/node"
  [[ -x "$dir/bin/node" && "$("$dir/bin/node" -v)" == "v$NODE_VERSION" ]] && return 0
  local tar="$DOWNLOADS/node-v$NODE_VERSION-linux-x64.tar.xz"
  fetch "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" "$NODE_SHA256" "$tar" &&
  rm -rf "$dir" && mkdir -p "$dir" && tar -xJf "$tar" -C "$dir" --strip-components=1
}

install_rea() {
  local dir="$REA_TOOLS/rea"
  [[ -x "$dir/node_modules/.bin/rea" ]] && grep -q "\"version\": \"$REA_VERSION\"" "$dir/node_modules/rea-agents/package.json" && return 0
  mkdir -p "$dir" &&
  PATH="$REA_TOOLS/node/bin:$PATH" npm install --prefix "$dir" --no-fund --no-audit --loglevel=error "rea-agents@$REA_VERSION"
}

install_ghidra() {
  local dir="$REA_TOOLS/ghidra_${GHIDRA_VERSION}_PUBLIC"
  [[ -f "$dir/Ghidra/application.properties" ]] && return 0
  local zip="$DOWNLOADS/${GHIDRA_URL##*/}"
  fetch "$GHIDRA_URL" "$GHIDRA_SHA256" "$zip" &&
  unzip -q -o "$zip" -d "$REA_TOOLS" &&
  [[ -x "$dir/Ghidra/Features/Decompiler/os/linux_x86_64/decompile" ]]
}

install_jadx() {
  mkdir -p "$REA_TOOLS/android" && fetch "$JADX_URL" "$JADX_SHA256" "$REA_TOOLS/android/${JADX_URL##*/}"
}

install_wabt() {
  local dir="$REA_TOOLS/wabt-$WABT_VERSION"
  [[ -x "$dir/bin/wasm-validate" ]] && return 0
  local tar="$DOWNLOADS/${WABT_URL##*/}"
  fetch "$WABT_URL" "$WABT_SHA256" "$tar" && mkdir -p "$dir" && tar -xzf "$tar" -C "$dir" --strip-components=1
}

install_rizin() {
  local dir="$REA_TOOLS/rizin-$RIZIN_VERSION"
  [[ -x "$dir/bin/rizin" ]] && return 0
  local tar="$DOWNLOADS/${RIZIN_URL##*/}"
  fetch "$RIZIN_URL" "$RIZIN_SHA256" "$tar" && mkdir -p "$dir" && tar -xJf "$tar" -C "$dir"
}

install_binwalk() {
  local dir="$REA_TOOLS/binwalk-$BINWALK_VERSION"
  [[ -x "$dir/bin/binwalk" ]] && return 0
  local cargo; cargo="$(command -v cargo || echo "$HOME/.cargo/bin/cargo")"
  [[ -x "$cargo" ]] || { log "cargo not found"; return 1; }
  "$cargo" install --quiet --locked --root "$dir" binwalk --version "$BINWALK_VERSION"
}

install_unblob() {
  local dir="$REA_TOOLS/unblob-$UNBLOB_VERSION"
  [[ -x "$dir/bin/unblob" ]] && return 0
  python3 -m venv "$dir" && "$dir/bin/pip" install --quiet "unblob==$UNBLOB_VERSION"
}

install_wakaru() {
  local dir="$REA_TOOLS/wakaru-1.14.0"
  [[ -x "$dir/wakaru" ]] && echo "$WAKARU_SHA256  $dir/wakaru" | sha256sum -c --quiet - && return 0
  mkdir -p "$dir" &&
  curl -fsSL --retry 4 "$WAKARU_URL" | tar -xz -C "$dir" wakaru &&
  echo "$WAKARU_SHA256  $dir/wakaru" | sha256sum -c --quiet -
}

install_pwntools() {
  local dir="$REA_TOOLS/pwntools-4.15.0"
  [[ -x "$dir/bin/python" ]] && "$dir/bin/python" -c "import pwn" 2>/dev/null && return 0
  python3 -m venv "$dir" && "$dir/bin/pip" install --quiet "${PWNTOOLS_PINS[@]}"
}

run apt     install_apt
run node    install_node
run rea     install_rea
run ghidra  install_ghidra
run jadx    install_jadx
run wabt    install_wabt
run rizin   install_rizin
run binwalk install_binwalk
run unblob  install_unblob
run wakaru  install_wakaru
run pwntools install_pwntools

# Archives are only needed until extraction; installed dirs make reruns no-ops.
rm -rf "$DOWNLOADS"

log "summary (tools in $REA_TOOLS):"
printf '  %s\n' "${RESULTS[@]}"
# Never fail the session start: missing engines only disable their REA tools.
exit 0
