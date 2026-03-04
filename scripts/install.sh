#!/bin/bash
# MiniClaw Universal Installer v0.6.0
# Usage: ./install.sh [client1 client2 ...]
# Clients: claude-code, claude-desktop, cursor, windsurf, antigravity, qoder

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
DIST_PATH="$PLUGIN_ROOT/dist/index.js"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${BLUE}🦞 MiniClaw v0.6.0 Installer${NC}"
echo "================================"

# 1. Build
echo -e "\n${BLUE}[1/3] Building...${NC}"
cd "$PLUGIN_ROOT"
[ ! -d "node_modules" ] && npm install
npm run build
echo -e "${GREEN}✅ Build OK${NC}"

# 2. Configure clients
CLIENT_NAMES=(claude-code claude-desktop cursor windsurf antigravity qoder)

get_client_path() {
    case "$1" in
        claude-code) echo "$HOME/.config/claude-code/config.json" ;;
        claude-desktop) echo "$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
        cursor) echo "$HOME/.cursor/mcp.json" ;;
        windsurf) echo "$HOME/.codeium/windsurf/mcp_config.json" ;;
        antigravity) echo "$HOME/.gemini/antigravity/mcp_config.json" ;;
        qoder) echo "$HOME/.qoder/mcp.json" ;;
        *) echo "" ;;
    esac
}

configure_client() {
    local config_file="$1" client_name="$2"
    mkdir -p "$(dirname "$config_file")"
    node -e "
const fs = require('fs');
const f = '$config_file';
let c = {};
if (fs.existsSync(f)) { try { c = JSON.parse(fs.readFileSync(f,'utf8')); } catch {} }
if (!c.mcpServers) c.mcpServers = {};
c.mcpServers.miniclaw = { command:'node', args:['$DIST_PATH'], env:{ MINICLAW_TOKEN_BUDGET:'12000' } };
fs.writeFileSync(f, JSON.stringify(c, null, 2));
"
    echo -e "  ${GREEN}✅ $client_name${NC}"
}

echo -e "\n${BLUE}[2/3] Configuring MCP clients...${NC}"

if [ $# -eq 0 ]; then
    echo -e "${YELLOW}用法: ./install.sh [client1 client2 ...]${NC}"
    echo "可用客户端: ${CLIENT_NAMES[*]}"
    echo -e "示例: ./install.sh cursor antigravity"
    echo -e "\n${YELLOW}⏭️  未指定客户端，跳过配置${NC}"
else
    for client in "$@"; do
        client_path=$(get_client_path "$client")
        if [ -n "$client_path" ]; then
            configure_client "$client_path" "$client"
        else
            echo -e "  ${RED}❌ 未知客户端: $client${NC}"
        fi
    done
fi

# 3. Configure Background Heartbeat Agent
echo -e "\n${BLUE}[3/3] Installing Background Heartbeat Agent...${NC}"
bash "$SCRIPT_DIR/heartbeat.sh" install

echo -e "\n${GREEN}🎉 安装完成！重启 MCP 客户端即可使用。后台心跳也将按 HEARTBEAT.md 配置执行。${NC}"
