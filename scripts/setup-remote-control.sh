#!/usr/bin/env bash
# setup-remote-control.sh — Set up Claude Code remote control as a persistent server
# Works on macOS (launchd) and Linux (systemd)
# Usage: ./scripts/setup-remote-control.sh [project-directory]
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────
PROJECT_DIR="${1:-$(pwd)}"
CLAUDE_BIN=$(command -v claude 2>/dev/null || echo "")

# ── Helpers ───────────────────────────────────────────────────────
info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$1"; }
ok()    { printf '\033[1;32m[OK]\033[0m    %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$1"; }
err()   { printf '\033[1;31m[ERR]\033[0m   %s\n' "$1"; exit 1; }

# ── Preflight checks ─────────────────────────────────────────────
if [[ -z "$CLAUDE_BIN" ]]; then
  err "claude binary not found in PATH. Install Claude Code first: https://docs.anthropic.com/en/docs/claude-code"
fi
info "Claude binary: $CLAUDE_BIN"

if [[ ! -d "$PROJECT_DIR" ]]; then
  err "Project directory does not exist: $PROJECT_DIR"
fi
PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)  # resolve to absolute path
info "Project directory: $PROJECT_DIR"

# ── Detect platform ──────────────────────────────────────────────
OS=$(uname -s)

setup_macos() {
  local plist_dir="$HOME/Library/LaunchAgents"
  local plist_file="$plist_dir/com.claude.remote-control.plist"

  info "Setting up launchd service (macOS)..."

  mkdir -p "$plist_dir"

  cat > "$plist_file" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.remote-control</string>
    <key>ProgramArguments</key>
    <array>
        <string>${CLAUDE_BIN}</string>
        <string>remote-control</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${PROJECT_DIR}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/claude-remote-control.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claude-remote-control.err</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:${HOME}/.local/bin</string>
    </dict>
</dict>
</plist>
PLIST

  # Unload first if already loaded (ignore errors)
  launchctl bootout "gui/$(id -u)/com.claude.remote-control" 2>/dev/null || true

  launchctl bootstrap "gui/$(id -u)" "$plist_file"
  ok "launchd service installed and started"
  info "Plist: $plist_file"
  info "Logs:  /tmp/claude-remote-control.log"
  info "Errors: /tmp/claude-remote-control.err"
  echo ""
  info "Management commands:"
  echo "  Stop:    launchctl bootout gui/\$(id -u)/com.claude.remote-control"
  echo "  Start:   launchctl bootstrap gui/\$(id -u) $plist_file"
  echo "  Status:  launchctl print gui/\$(id -u)/com.claude.remote-control"
  echo "  Logs:    tail -f /tmp/claude-remote-control.log"
}

setup_linux() {
  local service_dir="$HOME/.config/systemd/user"
  local service_file="$service_dir/claude-remote-control.service"

  info "Setting up systemd user service (Linux)..."

  mkdir -p "$service_dir"

  cat > "$service_file" <<SERVICE
[Unit]
Description=Claude Code Remote Control Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${CLAUDE_BIN} remote-control
WorkingDirectory=${PROJECT_DIR}
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
SERVICE

  systemctl --user daemon-reload
  systemctl --user enable claude-remote-control.service
  systemctl --user start claude-remote-control.service
  ok "systemd user service installed and started"
  info "Service file: $service_file"
  echo ""
  info "Management commands:"
  echo "  Stop:    systemctl --user stop claude-remote-control"
  echo "  Start:   systemctl --user start claude-remote-control"
  echo "  Status:  systemctl --user status claude-remote-control"
  echo "  Logs:    journalctl --user -u claude-remote-control -f"
  echo "  Disable: systemctl --user disable claude-remote-control"
}

# ── Main ──────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Claude Code Remote Control — Persistent Server     ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

case "$OS" in
  Darwin) setup_macos ;;
  Linux)  setup_linux ;;
  *)      err "Unsupported platform: $OS (supports macOS and Linux)" ;;
esac

echo ""
ok "Remote control server is running!"
info "Open the Claude iOS/Android app → Claude Code tab to connect."
info "Or visit https://claude.ai/code from any browser."
echo ""
