#!/bin/bash
# =============================================================================
# MiniClaw Daemon Controller (Standalone Wrapper)
#
# Simple script to manage the Node.js daemon process.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$HOME/.miniclaw/logs/daemon.log"

case "${1:-status}" in
    start)
        echo "Starting MiniClaw Daemon..."
        cd "$ROOT_DIR"
        pnpm build
        nohup pnpm start:daemon >> "$LOG_FILE" 2>&1 &
        echo $! > /tmp/miniclaw-daemon.pid
        echo "Daemon started (PID: $(cat /tmp/miniclaw-daemon.pid))"
        ;;
    stop)
        if [ -f /tmp/miniclaw-daemon.pid ]; then
            pid=$(cat /tmp/miniclaw-daemon.pid)
            echo "Stopping Daemon (PID: $pid)..."
            kill "$pid" && rm /tmp/miniclaw-daemon.pid
            echo "Stopped."
        else
            echo "No PID file found."
            pkill -f "node dist/daemon.js" || true
        fi
        ;;
    status)
        pgrep -f "node dist/daemon.js" > /dev/null \
            && echo "MiniClaw Daemon is RUNNING" \
            || echo "MiniClaw Daemon is STOPPED"
        ;;
    log)
        tail -f "$LOG_FILE"
        ;;
    *)
        echo "Usage: $0 {start|stop|status|log}"
        exit 1
        ;;
esac
