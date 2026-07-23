#!/bin/bash
# Auto-configure IntelliJ IDEA MCP server port to 64343 on user login
if [ -n "$HOME" ] && [ -d "$HOME" ]; then
    JB_DIR="$HOME/.config/JetBrains"
    
    shopt -s nullglob
    IDEA_DIRS=("$JB_DIR"/IntelliJIdea*)
    shopt -u nullglob

    if [ ${#IDEA_DIRS[@]} -eq 0 ]; then
        IDEA_DIRS=("$JB_DIR/IntelliJIdea2024.3")
    fi

    for idea_dir in "${IDEA_DIRS[@]}"; do
        opts_dir="$idea_dir/options"
        config_file="$opts_dir/mcpServer.xml"

        if [ ! -f "$config_file" ]; then
            mkdir -p "$opts_dir"
            cat > "$config_file" << 'EOF'
<application>
  <component name="McpServerOptions">
    <option name="port" value="64343" />
  </component>
</application>
EOF
        else
            if grep -q 'name="port"' "$config_file"; then
                sed -i -E 's/name="port" value="[0-9]+"/name="port" value="64343"/g' "$config_file" 2>/dev/null || true
            elif grep -q '64342' "$config_file"; then
                sed -i 's/64342/64343/g' "$config_file" 2>/dev/null || true
            fi
        fi
        font_config_file="$opts_dir/editor.font.xml"
        if [ ! -f "$font_config_file" ]; then
            mkdir -p "$opts_dir"
            cat > "$font_config_file" << 'EOF'
<application>
  <component name="EditorFont">
    <option name="USE_SECONDARY_FONT_FAMILY" value="true" />
    <option name="SECONDARY_FONT_FAMILY" value="Noto Color Emoji" />
  </component>
</application>
EOF
        fi
    done
fi
