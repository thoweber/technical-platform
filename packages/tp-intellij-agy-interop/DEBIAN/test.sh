#!/bin/bash
set -e

echo "Installing tp-intellij-agy-interop and asserting MCP configurations..."
apt-get update
apt-get install -y tp-intellij-idea tp-intellij-agy-interop

test -f /etc/profile.d/tp-intellij-agy-interop.sh

su - developer << 'EOF'
set -e
source /etc/profile

mcp_file="$HOME/.config/JetBrains/IntelliJIdea2026.2/options/mcpServer.xml"
test -f "$mcp_file"
grep -q "McpServerSettings" "$mcp_file"
grep -q "64343" "$mcp_file"

agy_file="$HOME/.config/antigravity/config.json"
test -f "$agy_file"
jq -e '.mcpServers["wsl-isolated-intellij-idea-mcp"].url == "http://127.0.0.1:63343/debugger-mcp/sse"' "$agy_file"
EOF

echo "✅ IntelliJ IDEA & MCP Interop configuration assertions passed!"
