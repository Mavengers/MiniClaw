#!/bin/bash
# =============================================================================
# MiniClaw Heartbeat Scheduler
#
# Manages the background heartbeat agent via macOS launchd.
# Heartbeat reads HEARTBEAT.md and interprets it via `claude -p`.
#
# Scheduled jobs (jobs.json) are handled by kernel.ts inside the MCP process.
#
# USAGE:
#   ./heartbeat.sh install     — Install macOS LaunchAgent (heartbeat)
#   ./heartbeat.sh uninstall   — Remove LaunchAgent
#   ./heartbeat.sh status      — Show agent status and recent logs
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

# =============================================================================
# HEARTBEAT — Read HEARTBEAT.md and execute via `claude -p` (every 30 min)
#
# HEARTBEAT.md controls what autonomous background behaviors run each cycle.
# Leave it empty (or with only comments) to disable heartbeats entirely.
# =============================================================================
cmd_heartbeat() {
    mkdir -p "$LOG_DIR"

    # Prevent concurrent runs
    if [ -f "$HEARTBEAT_LOCK" ]; then
        local pid; pid=$(cat "$HEARTBEAT_LOCK")
        if kill -0 "$pid" 2>/dev/null; then
            echo "[$(date)] Heartbeat already running (PID: $pid), skipping." >> "$HEARTBEAT_LOG"
            exit 0
        fi
    fi
    echo $$ > "$HEARTBEAT_LOCK"
    trap "rm -f $HEARTBEAT_LOCK" EXIT

    # Check claude CLI
    if ! command -v claude &>/dev/null; then
        echo "[$(date)] Error: 'claude' command not found." >> "$HEARTBEAT_LOG"
        exit 1
    fi

    # Skip if HEARTBEAT.md is missing or empty (disabled)
    if [ ! -f "$HEARTBEAT_FILE" ] || [ ! -s "$HEARTBEAT_FILE" ]; then
        echo "[$(date)] HEARTBEAT.md is empty or missing, skipping." >> "$HEARTBEAT_LOG"
        exit 0
    fi

    echo "[$(date)] Running heartbeat..." >> "$HEARTBEAT_LOG"

    local prompt
    prompt=$(cat "$HEARTBEAT_FILE")

    claude -p "$prompt" >> "$HEARTBEAT_LOG" 2>&1 \
        && echo "[$(date)] Heartbeat completed." >> "$HEARTBEAT_LOG" \
        || echo "[$(date)] Heartbeat failed." >> "$HEARTBEAT_LOG"
}

# =============================================================================
# INSTALL — Generate and load macOS LaunchAgent plist
# =============================================================================
cmd_install() {
    echo "Installing MiniClaw Heartbeat LaunchAgent..."
    mkdir -p "$LAUNCH_AGENTS_DIR" "$MINICLAW_LAUNCHD_DIR" "$LOG_DIR"
    chmod +x "$SCRIPT_DIR/heartbeat.sh"
    ok "Made script executable"

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
    ok "Generated heartbeat plist: $HEARTBEAT_PLIST_FILE"

    # Create symlink in ~/Library/LaunchAgents so macOS loads it on boot
    ln -sf "$HEARTBEAT_PLIST_FILE" "$HEARTBEAT_PLIST_SYMLINK"

    launchctl unload "$HEARTBEAT_PLIST_SYMLINK" 2>/dev/null || true
    launchctl load "$HEARTBEAT_PLIST_SYMLINK"
    ok "Loaded heartbeat agent (runs every 30 minutes)"

    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo "  Heartbeat : every 30 min — reads $HEARTBEAT_FILE"
    echo "  Log       : $HEARTBEAT_LOG"
    echo "  Note      : Scheduled jobs (jobs.json) are handled by kernel.ts"
    echo ""
    echo "To uninstall: $0 uninstall"
}

# =============================================================================
# UNINSTALL — Remove LaunchAgent
# =============================================================================
cmd_uninstall() {
    echo "Uninstalling MiniClaw Heartbeat LaunchAgent..."
    if [ -f "$HEARTBEAT_PLIST_SYMLINK" ]; then
        launchctl unload "$HEARTBEAT_PLIST_SYMLINK" 2>/dev/null || true
        rm -f "$HEARTBEAT_PLIST_SYMLINK"
        ok "Removed symlink: $HEARTBEAT_PLIST_SYMLINK"
    else
        warn "Not found: $HEARTBEAT_PLIST_SYMLINK"
    fi

    if [ -f "$HEARTBEAT_PLIST_FILE" ]; then
        rm -f "$HEARTBEAT_PLIST_FILE"
        ok "Removed plist file: $HEARTBEAT_PLIST_FILE"
    fi
    echo ""
    echo -e "${GREEN}Uninstallation complete!${NC}"
}

# =============================================================================
# STATUS — Show agent status and recent logs
# =============================================================================
cmd_status() {
    echo "MiniClaw Heartbeat Agent Status:"
    echo ""
    launchctl list | grep -q "$HEARTBEAT_PLIST_ID" \
        && ok  "Heartbeat agent: RUNNING" \
        || warn "Heartbeat agent: NOT RUNNING"
    echo ""
    echo "Recent heartbeat log:"
    tail -10 "$HEARTBEAT_LOG" 2>/dev/null || echo "  (no logs yet)"
}

# =============================================================================
# Main dispatch
# =============================================================================
case "${1:-install}" in
    install)    cmd_install    ;;
    uninstall)  cmd_uninstall  ;;
    status)     cmd_status     ;;
    _heartbeat) cmd_heartbeat  ;;  # internal: called by launchd only
    *)
        echo "Usage: $0 {install|uninstall|status}"
        exit 1
        ;;
esac
