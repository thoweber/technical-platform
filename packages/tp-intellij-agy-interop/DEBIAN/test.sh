#!/bin/bash
set -e

echo "Testing tp-intellij-agy-interop automatic APT Post-Invoke installation..."
apt-get update

# Step 1: Install tp-antigravity-cli alone
echo "Installing tp-antigravity-cli alone..."
apt-get install -y tp-antigravity-cli

# Verify interop package is NOT YET installed
if dpkg-query -W -f='${Status}' tp-intellij-agy-interop 2>/dev/null | grep -q "ok installed"; then
    echo "Error: tp-intellij-agy-interop was prematurely installed!"
    exit 1
fi
echo "Verified: tp-intellij-agy-interop is not installed when only Antigravity CLI is present."

# Step 2: Install tp-intellij-idea (triggers APT Post-Invoke hook to auto-install interop)
echo "Installing tp-intellij-idea (should trigger APT Post-Invoke hook to auto-install interop)..."
apt-get install -y tp-intellij-idea

# Step 3: Verify tp-intellij-agy-interop WAS auto-installed
if ! dpkg-query -W -f='${Status}' tp-intellij-agy-interop 2>/dev/null | grep -q "ok installed"; then
    echo "Error: tp-intellij-agy-interop was NOT auto-installed after installing both tools!"
    exit 1
fi
echo "✅ Auto-installation verified: tp-intellij-agy-interop was automatically installed by APT Post-Invoke hook!"

# Step 4: Assert configuration file generation and interop settings as developer user
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

echo "✅ IntelliJ IDEA & MCP Interop auto-installation and configuration assertions passed!"
