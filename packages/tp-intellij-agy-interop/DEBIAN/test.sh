#!/bin/bash
set -e

echo "Testing synchronous IntelliJ IDEA & Antigravity-CLI MCP interop configuration..."
apt-get update
apt-get install -y jq

# Clean up any leftover packages from previous test runs
apt-get remove --purge -y tp-intellij-idea tp-antigravity-cli tp-intellij-agy-interop >/dev/null 2>&1 || true
rm -f /home/developer/.config/JetBrains/IntelliJIdea2026.2/options/mcpServer.xml /home/developer/.config/antigravity/config.json

# Step 1: Install tp-antigravity-cli alone
echo "Installing tp-antigravity-cli alone..."
apt-get install -y tp-antigravity-cli

# Verify MCP configuration was NOT YET generated (IntelliJ is missing)
if [ -f "/home/developer/.config/JetBrains/IntelliJIdea2026.2/options/mcpServer.xml" ]; then
    echo "Error: MCP server config was prematurely generated!"
    exit 1
fi
echo "Verified: Interop config is skipped when only Antigravity CLI is present."

# Step 2: Install tp-intellij-idea (triggers synchronous interop setup in postinst)
echo "Installing tp-intellij-idea (should trigger synchronous interop setup)..."
apt-get install -y tp-intellij-idea

# Step 3: Assert configuration file generation and interop settings as developer user
echo "Verifying interop configuration generated synchronously..."
test -f /etc/profile.d/tp-intellij-agy-interop.sh

su - developer << 'EOF'
source /etc/profile 2>/dev/null || true
set -e

mcp_file="$HOME/.config/JetBrains/IntelliJIdea2026.2/options/mcpServer.xml"
test -f "$mcp_file"
test -r "$mcp_file"
test -w "$mcp_file"
owner_mcp=$(stat -c '%U:%G' "$mcp_file")
if [ "$owner_mcp" != "developer:developer" ]; then
    echo "Error: $mcp_file is owned by $owner_mcp instead of developer:developer"
    exit 1
fi

grep -q "McpServerSettings" "$mcp_file"
grep -q "64343" "$mcp_file"

agy_file="$HOME/.config/antigravity/config.json"
test -f "$agy_file"
test -r "$agy_file"
test -w "$agy_file"
owner_agy=$(stat -c '%U:%G' "$agy_file")
if [ "$owner_agy" != "developer:developer" ]; then
    echo "Error: $agy_file is owned by $owner_agy instead of developer:developer"
    exit 1
fi

jq -e '.mcpServers["wsl-isolated-intellij-idea-mcp"].url == "http://127.0.0.1:63343/debugger-mcp/sse"' "$agy_file"
echo "Verified: mcpServer.xml and config.json exist and are owned by developer:developer with read/write access."
EOF

echo "✅ IntelliJ IDEA & MCP Interop synchronous configuration assertions passed!"
