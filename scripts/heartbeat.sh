#!/bin/bash
# =============================================================================
# MiniClaw Heartbeat Scheduler (Legacy / Standalone)
#
# Manages the background heartbeat agent via macOS launchd.
# Heartbeat reads HEARTBEAT.md and interprets it via `claude -p`.
# =============================================================================

set -euo pipefail

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINICLAW_DIR="$HOME/.miniclaw"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
MINICLAW_LAUNCHD_DIR="$MINICLAW_DIR/launchd"
LOG_DIR="$MINICLAW_DIR/logs"
HEARTBEAT_LOG="$LOG_DIR/heartbeat.log"
HEARTBEAT_LOCK="/tmp/miniclaw-heartbeat.lock"
HEARTBEAT_FILE="$MINICLAW_DIR/HEARTBEAT.md"

HEARTBEAT_PLIST_ID="com.miniclaw.heartbeat"
HEARTBEAT_PLIST_FILE="$MINICLAW_LAUNCHD_DIR/$HEARTBEAT_PLIST_ID.plist"
HEARTBEAT_PLIST_SYMLINK="$LAUNCH_AGENTS_DIR/$HEARTBEAT_PLIST_ID.plist"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# macOS system notification helper
notify() {
    local msg="$1" title="${2:-MiniClaw}"
    osascript -e "display notification \"$msg\" with title \"$title\" sound name \"Glass\"" 2>/dev/null || true
}

cmd_heartbeat() {
    mkdir -p "$LOG_DIR"
    if [ -f "$HEARTBEAT_LOCK" ]; then
        local pid; pid=$(cat "$HEARTBEAT_LOCK")
        if kill -0 "$pid" 2>/dev/null; then
            echo "[$(date)] Heartbeat already running (PID: $pid), skipping." >> "$HEARTBEAT_LOG"
            exit 0
        fi
    fi
    echo $$ > "$HEARTBEAT_LOCK"
    trap "rm -f $HEARTBEAT_LOCK" EXIT

    CLI_CMD=""
    CLI_ARGS=""
    if command -v claude &>/dev/null; then
        CLI_CMD="claude"
        CLI_ARGS="-p --output-format text"
    elif command -v gemini &>/dev/null; then
        CLI_CMD="gemini"
        CLI_ARGS="-p"
    else
        echo "[$(date)] Error: No AI CLI found (tried: claude, gemini)." >> "$HEARTBEAT_LOG"
        exit 1
    fi

    if [ ! -f "$HEARTBEAT_FILE" ] || [ ! -s "$HEARTBEAT_FILE" ]; then
        echo "[$(date)] HEARTBEAT.md is empty or missing, skipping." >> "$HEARTBEAT_LOG"
        exit 0
    fi

    echo "[$(date)] Running heartbeat via $CLI_CMD..." >> "$HEARTBEAT_LOG"
    local prompt; prompt=$(cat "$HEARTBEAT_FILE")

    $CLI_CMD $CLI_ARGS "$prompt" >> "$HEARTBEAT_LOG" 2>&1 \
        && { echo "[$(date)] Heartbeat completed ($CLI_CMD)." >> "$HEARTBEAT_LOG"; notify "心跳完成 ✓" "MiniClaw"; } \
        || { echo "[$(date)] Heartbeat failed ($CLI_CMD)." >> "$HEARTBEAT_LOG"; notify "⚠️ 心跳异常，请检查日志" "MiniClaw"; }
}

cmd_install() {
    echo "Installing MiniClaw Heartbeat LaunchAgent..."
    mkdir -p "$LAUNCH_AGENTS_DIR" "$MINICLAW_LAUNCHD_DIR" "$LOG_DIR"
    chmod +x "$SCRIPT_DIR/heartbeat.sh"
    
    cat > "$HEARTBEAT_PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$HEARTBEAT_PLIST_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_DIR/heartbeat.sh</string>
        <string>_heartbeat</string>
    </array>
    <key>StartInterval</key>
    <integer>1800</integer>
    <key>StandardOutPath</key>
    <string>$HEARTBEAT_LOG</string>
    <key>StandardErrorPath</key>
    <string>$HEARTBEAT_LOG</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
    ln -sf "$HEARTBEAT_PLIST_FILE" "$HEARTBEAT_PLIST_SYMLINK"
    launchctl unload "$HEARTBEAT_PLIST_SYMLINK" 2>/dev/null || true
    launchctl load "$HEARTBEAT_PLIST_SYMLINK"
    ok "Loaded heartbeat agent."
}

case "${1:-install}" in
    install)    cmd_install    ;;
    _heartbeat) cmd_heartbeat  ;;
    *)          echo "Usage: $0 {install}"; exit 1 ;;
esac
