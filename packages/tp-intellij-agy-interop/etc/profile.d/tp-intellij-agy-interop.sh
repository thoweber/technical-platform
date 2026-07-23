#!/bin/bash
# Auto-configure IntelliJ IDEA & Antigravity CLI MCP interoperability
if [ -n "$HOME" ] && [ -d "$HOME" ]; then

    # 1. Antigravity CLI MCP Server Config (~/.config/antigravity/config.json)
    AGY_DIR="$HOME/.config/antigravity"
    AGY_CONFIG="$AGY_DIR/config.json"

    mkdir -p "$AGY_DIR"

    if [ ! -f "$AGY_CONFIG" ]; then
        cat > "$AGY_CONFIG" << 'EOF'
{
  "mcpServers": {
    "wsl-isolated-intellij-idea-mcp": {
      "url": "http://127.0.0.1:63343/debugger-mcp/sse"
    }
  }
}
EOF
    else
        if command -v jq >/dev/null 2>&1; then
            tmp_json=$(mktemp)
            if jq '.mcpServers["wsl-isolated-intellij-idea-mcp"] = {"url": "http://127.0.0.1:63343/debugger-mcp/sse"}' "$AGY_CONFIG" > "$tmp_json" 2>/dev/null; then
                mv "$tmp_json" "$AGY_CONFIG"
            else
                rm -f "$tmp_json"
            fi
        fi
    fi

    # 2. IntelliJ IDEA MCP Server Settings (~/.config/JetBrains/IntelliJIdea*/options/mcpServer.xml)
    JB_DIR="$HOME/.config/JetBrains"
    mkdir -p "$JB_DIR"

    shopt -s nullglob
    IDEA_DIRS=("$JB_DIR"/IntelliJIdea* "$JB_DIR"/IdeaIC*)
    shopt -u nullglob

    if [ ${#IDEA_DIRS[@]} -eq 0 ]; then
        IDEA_DIRS=("$JB_DIR/IntelliJIdea2026.2")
    fi

    for idea_dir in "${IDEA_DIRS[@]}"; do
        opts_dir="$idea_dir/options"
        mkdir -p "$opts_dir"

        mcp_file="$opts_dir/mcpServer.xml"
        if [ ! -f "$mcp_file" ]; then
            cat > "$mcp_file" << 'EOF'
<application>
  <component name="McpServerSettings">
    <option name="enableMcpServer" value="true" />
    <option name="port" value="64343" />
    <option name="mcpServerPort" value="64343" />
  </component>
</application>
EOF
        else
            if grep -q '<component name="McpServer' "$mcp_file"; then
                if ! grep -q 'enableMcpServer' "$mcp_file"; then
                    sed -i '/<component name="McpServer.*/a \    <option name="enableMcpServer" value="true" />' "$mcp_file" 2>/dev/null || true
                fi
                if grep -q 'name="port"' "$mcp_file"; then
                    sed -i -E 's/name="port" value="[0-9]+"/name="port" value="64343"/g' "$mcp_file" 2>/dev/null || true
                fi
                if grep -q 'name="mcpServerPort"' "$mcp_file"; then
                    sed -i -E 's/name="mcpServerPort" value="[0-9]+"/name="mcpServerPort" value="64343"/g' "$mcp_file" 2>/dev/null || true
                fi
            fi
        fi
    done
fi
