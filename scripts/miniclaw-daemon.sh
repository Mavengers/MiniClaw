#!/bin/bash
# =============================================================================
# MiniClaw Daemon Manager (Unified Controller)
#
# Manages the background autonomic process via macOS launchd.
# The daemon runs kernel.heartbeat() (Metabolism) and internal cognitive pulses.
#
# USAGE:
#   ./miniclaw-daemon.sh install     — Install macOS LaunchAgent
#   ./miniclaw-daemon.sh uninstall   — Remove LaunchAgent
#   ./miniclaw-daemon.sh status      — Show daemon status and recent logs
#   ./miniclaw-daemon.sh start       — Manually start the daemon service
#   ./miniclaw-daemon.sh stop        — Stop the daemon service
#   ./miniclaw-daemon.sh pulse       — Force a one-off heartbeat/cognitive pulse
# =============================================================================

set -euo pipefail

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MINICLAW_DIR="$HOME/.miniclaw"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
MINICLAW_LAUNCHD_DIR="$MINICLAW_DIR/launchd"
LOG_DIR="$MINICLAW_DIR/logs"
DAEMON_LOG="$LOG_DIR/daemon.log"

DAEMON_PLIST_ID="com.miniclaw.daemon"
DAEMON_PLIST_FILE="$MINICLAW_LAUNCHD_DIR/$DAEMON_PLIST_ID.plist"
DAEMON_PLIST_SYMLINK="$LAUNCH_AGENTS_DIR/$DAEMON_PLIST_ID.plist"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# =============================================================================
# INSTALL — Generate and load macOS LaunchAgent plist
# =============================================================================
cmd_install() {
    echo "Installing MiniClaw Autonomous Daemon..."
    mkdir -p "$LAUNCH_AGENTS_DIR" "$MINICLAW_LAUNCHD_DIR" "$LOG_DIR"
    
    echo "Building project..."
    cd "$ROOT_DIR"
    pnpm build
    ok "Build complete"

    cat > "$DAEMON_PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$DAEMON_PLIST_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which node)</string>
        <string>$ROOT_DIR/dist/daemon.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$ROOT_DIR</string>
    <key>StandardOutPath</key>
    <string>$DAEMON_LOG</string>
    <key>StandardErrorPath</key>
    <string>$DAEMON_LOG</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
    ok "Generated daemon plist: $DAEMON_PLIST_FILE"

    chmod +x "$SCRIPT_DIR/miniclaw-daemon.sh"
    ln -sf "$DAEMON_PLIST_FILE" "$DAEMON_PLIST_SYMLINK"
    launchctl unload "$DAEMON_PLIST_SYMLINK" 2>/dev/null || true
    launchctl load "$DAEMON_PLIST_SYMLINK"
    ok "Loaded daemon (starts automatically on login)"

    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo "  Log       : $DAEMON_LOG"
    echo ""
}

# =============================================================================
# ACTIONS
# =============================================================================
cmd_uninstall() {
    echo "Uninstalling MiniClaw Daemon..."
    launchctl unload "$DAEMON_PLIST_SYMLINK" 2>/dev/null || true
    rm -f "$DAEMON_PLIST_SYMLINK" "$DAEMON_PLIST_FILE"
    ok "Uninstalled."
}

cmd_start() {
    launchctl load "$DAEMON_PLIST_SYMLINK"
    ok "Daemon started."
}

cmd_stop() {
    launchctl unload "$DAEMON_PLIST_SYMLINK"
    ok "Daemon stopped."
}

cmd_status() {
    echo "MiniClaw Daemon Status:"
    launchctl list | grep -q "$DAEMON_PLIST_ID" \
        && ok  "Daemon: ACTIVE" \
        || warn "Daemon: INACTIVE"
    echo ""
    echo "Recent daemon log:"
    tail -n 10 "$DAEMON_LOG" 2>/dev/null || echo "  (no logs yet)"
}

cmd_pulse() {
    echo "Forcing manual heartbeat..."
    cd "$ROOT_DIR"
    node -e "import { ContextKernel } from './dist/kernel.js'; const k = new ContextKernel(); k.heartbeat().then(() => process.exit(0)).catch(err => { console.error(err); process.exit(1); });"
}

# =============================================================================
# Main dispatch
# =============================================================================
case "${1:-status}" in
    install)    cmd_install    ;;
    uninstall)  cmd_uninstall  ;;
    start)      cmd_start      ;;
    stop)       cmd_stop       ;;
    status)     cmd_status     ;;
    pulse)      cmd_pulse      ;;
    *)
        echo "Usage: $0 {install|uninstall|start|stop|status|pulse}"
        exit 1
        ;;
esac
