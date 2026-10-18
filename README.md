# rea

Claude Code cloud setup for [REA: Reverse Engineer Anything](https://github.com/morluto/rea)
(`rea-agents@6.5.0`).

## What is here

| Path | Purpose |
|---|---|
| `.claude/skills/reverse-engineer-anything/` | REA workflow skill, vendored from `morluto/rea@47d3c6b` (MIT) |
| `.mcp.json` | Project MCP server `rea`, launched through `scripts/cloud/rea-mcp.sh` |
| `.claude/settings.json` | Auto-enables the project `rea` server |
| `scripts/cloud/setup.sh` | Installs REA and its engines under `/opt/rea-tools` |
| `scripts/cloud/rea-mcp.sh` | MCP launcher; exports engine paths that exist, else falls back to `npx` |
| `scripts/cloud/start-chromium-cdp.sh` | Headless Chromium with a CDP endpoint for REA's web tools |

## Cloud environment setup

1. Open the cloud environment menu in the session title bar → **Edit**.
2. Paste the contents of `scripts/cloud/setup.sh` into **Setup script** and save.
3. Start a new session on this repo. `/mcp` should list `rea` as connected.

First run takes about 2–3 minutes (Ghidra is a 570 MB download). The script
never fails the session; its summary lists `OK`/`FAIL` per component, and
`REA_SETUP_SKIP="ghidra binwalk"` skips components.

Without the setup script, `rea` still starts via `npx` with only the tools that
need no external engine.

## Installed engines

| Engine | Version | Unlocks |
|---|---|---|
| Node.js | 24.22.0 | REA runtime, SQLite inspection |
| Ghidra + JDK 21 | 12.1.4 | Native decompile, xrefs, call graphs (`open_binary`, `procedure_pseudo_code`, …) |
| JADX headless MCP | 0.7.1 | APK class/method decompilation |
| Rizin | 0.9.1 | `execute_rizin_command`, Rizin debugger |
| GDB, binutils | Ubuntu 24.04 | `start_gdb_session`, `inspect_with_objdump` |
| TShark, sigrok-cli | 4.2.2, 0.7.2 | Packet captures, signal recordings |
| adb, apktool | 1.0.41, 2.7.0 | Android device and resource tools |
| WABT | 1.0.42 | `inspect_wasm_artifact` |
| Binwalk, Unblob | 3.1.0, 26.6.4 | Firmware inspection and extraction |
| Wakaru | 1.14.0 | `recover_javascript_sources` |
| pwntools | 4.15.0 | `inspect_binary_layout`, `inspect_recorded_crash` |
| Frida | 17.23.2 | Frida instrumentation tools |
| Chromium (preinstalled) | 141 | Web/CDP tools via `start-chromium-cdp.sh` |

Not available on a Linux cloud host: Hopper and IDA (licensed desktop apps),
JEB (commercial), and the macOS-only tools (`inspect_macho`, `observe_native_ui`, …).

Check readiness inside a session:

```bash
bash scripts/cloud/rea-mcp.sh doctor --json
```
