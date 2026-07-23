#!/bin/bash
# Auto-configure IntelliJ IDEA MCP server port to 64343 and Noto Color Emoji fallback font on user login
if [ -n "$HOME" ] && [ -d "$HOME" ]; then
    JB_BASE_DIRS=(
        "$HOME/.config/JetBrains"
        "$HOME/snap/intellij-idea-ultimate/current/.config/JetBrains"
        "$HOME/snap/intellij-idea-ultimate/common/.config/JetBrains"
    )

    for jb_base in "${JB_BASE_DIRS[@]}"; do
        mkdir -p "$jb_base"
        
        shopt -s nullglob
        IDEA_DIRS=("$jb_base"/IntelliJIdea* "$jb_base"/IdeaIC*)
        shopt -u nullglob

        if [ ${#IDEA_DIRS[@]} -eq 0 ]; then
            IDEA_DIRS=(
                "$jb_base/IntelliJIdea2024.1"
                "$jb_base/IntelliJIdea2024.2"
                "$jb_base/IntelliJIdea2024.3"
                "$jb_base/IntelliJIdea2025.1"
            )
        fi

        for idea_dir in "${IDEA_DIRS[@]}"; do
            opts_dir="$idea_dir/options"
            mkdir -p "$opts_dir"

            # Configure MCP Server port 64343 in mcpServer.xml & mcp.xml
            for mcp_file in "$opts_dir/mcpServer.xml" "$opts_dir/mcp.xml"; do
                if [ ! -f "$mcp_file" ]; then
                    cat > "$mcp_file" << 'EOF'
<application>
  <component name="McpServerOptions">
    <option name="port" value="64343" />
  </component>
  <component name="McpServerService">
    <option name="port" value="64343" />
  </component>
</application>
EOF
                else
                    if grep -q 'name="port"' "$mcp_file"; then
                        sed -i -E 's/name="port" value="[0-9]+"/name="port" value="64343"/g' "$mcp_file" 2>/dev/null || true
                    elif grep -q '64342' "$mcp_file"; then
                        sed -i 's/64342/64343/g' "$mcp_file" 2>/dev/null || true
                    fi
                fi
            done

            # Configure Noto Color Emoji fallback font in editor-font.xml & editor.font.xml
            for font_file in "$opts_dir/editor-font.xml" "$opts_dir/editor.font.xml"; do
                if [ ! -f "$font_file" ]; then
                    cat > "$font_file" << 'EOF'
<application>
  <component name="EditorFont">
    <option name="USE_SECONDARY_FONT_FAMILY" value="true" />
    <option name="SECONDARY_FONT_FAMILY" value="Noto Color Emoji" />
  </component>
</application>
EOF
                else
                    if ! grep -q 'SECONDARY_FONT_FAMILY' "$font_file"; then
                        sed -i '/<component name="EditorFont">/a \    <option name="USE_SECONDARY_FONT_FAMILY" value="true" />\n    <option name="SECONDARY_FONT_FAMILY" value="Noto Color Emoji" />' "$font_file" 2>/dev/null || true
                    fi
                fi
            done
        done
    done
fi
