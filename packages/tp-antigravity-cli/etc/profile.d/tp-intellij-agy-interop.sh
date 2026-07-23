#!/bin/bash
# Technical Platform WSL - IntelliJ IDEA & Antigravity-CLI Interoperability

HAS_INTELLIJ=false
HAS_ANTIGRAVITY=false

if command -v intellij-idea-ultimate >/dev/null 2>&1 || [ -d "/opt/intellij-idea-ultimate" ] || dpkg-query -W -f='${Status}' tp-intellij-idea 2>/dev/null | grep -q "ok installed"; then
    HAS_INTELLIJ=true
fi

if command -v agy >/dev/null 2>&1 || [ -f "/usr/local/bin/agy" ] || [ -f "/opt/antigravity/bin/agy" ] || dpkg-query -W -f='${Status}' tp-antigravity-cli 2>/dev/null | grep -q "ok installed"; then
    HAS_ANTIGRAVITY=true
fi

if [ "$HAS_INTELLIJ" = "true" ] && [ "$HAS_ANTIGRAVITY" = "true" ]; then
    ACTUAL_USER="${SUDO_USER:-${USER}}"
    if [ "$ACTUAL_USER" = "root" ] || [ -z "$ACTUAL_USER" ]; then
        ACTUAL_USER=$(getent passwd 1000 | cut -d: -f1)
    fi

    if [ -n "$ACTUAL_USER" ] && [ "$ACTUAL_USER" != "root" ]; then
        USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
        if [ -n "$USER_HOME" ] && [ -d "$USER_HOME" ]; then
            echo "Configuring IntelliJ IDEA and Antigravity-CLI MCP interop for '$ACTUAL_USER'..."

            # 1. Configure IntelliJ IDEA MCP Server settings
            JB_DIR="$USER_HOME/.config/JetBrains"
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
    <option name="port" value="64343" />
  </component>
</application>
EOF
                fi
            done

            # 2. Configure Antigravity CLI config.json for MCP interop
            AGY_DIR="$USER_HOME/.config/antigravity"
            mkdir -p "$AGY_DIR"
            AGY_CFG="$AGY_DIR/config.json"

            if [ ! -f "$AGY_CFG" ]; then
                cat > "$AGY_CFG" << 'EOF'
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
                    tmp_cfg=$(mktemp)
                    jq '.mcpServers["wsl-isolated-intellij-idea-mcp"] = {"url": "http://127.0.0.1:63343/debugger-mcp/sse"}' "$AGY_CFG" > "$tmp_cfg" 2>/dev/null && mv "$tmp_cfg" "$AGY_CFG" || true
                fi
            fi

            chown -R "$ACTUAL_USER:$ACTUAL_USER" "$JB_DIR" "$AGY_DIR" 2>/dev/null || true
        fi
    fi
fi
