#!/bin/bash
# Environment & performance fixes for IntelliJ IDEA under WSL2/WSLg
export AT_SPI_CLIENT_NO_AT_BRIDGE=1
export NO_AT_BRIDGE=1

if [ -n "$HOME" ] && [ -d "$HOME" ]; then
    # Fix broken snap directory if 'current' was created as a regular directory instead of a symlink
    if [ -d "$HOME/snap/intellij-idea-ultimate/current" ] && [ ! -L "$HOME/snap/intellij-idea-ultimate/current" ]; then
        rm -rf "$HOME/snap/intellij-idea-ultimate/current" 2>/dev/null || true
    fi

    JB_BASE_DIRS=("$HOME/.config/JetBrains")
    
    if [ -d "$HOME/snap/intellij-idea-ultimate/common/.config/JetBrains" ]; then
        JB_BASE_DIRS+=("$HOME/snap/intellij-idea-ultimate/common/.config/JetBrains")
    fi

    for jb_base in "${JB_BASE_DIRS[@]}"; do
        mkdir -p "$jb_base"
        
        # Clean up empty dummy version directories created previously that trigger JetBrains migration freezes
        shopt -s nullglob
        for dummy_dir in "$jb_base"/IntelliJIdea2024.1 "$jb_base"/IntelliJIdea2024.2 "$jb_base"/IntelliJIdea2025.1; do
            if [ -d "$dummy_dir" ]; then
                file_cnt=$(find "$dummy_dir" -type f 2>/dev/null | wc -l)
                if [ "$file_cnt" -le 4 ]; then
                    rm -rf "$dummy_dir" 2>/dev/null || true
                fi
            fi
        done

        IDEA_DIRS=("$jb_base"/IntelliJIdea* "$jb_base"/IdeaIC*)
        shopt -u nullglob

        # If no real JetBrains directory exists yet, target a single default version directory
        if [ ${#IDEA_DIRS[@]} -eq 0 ]; then
            IDEA_DIRS=("$jb_base/IntelliJIdea2024.3")
        fi

        for idea_dir in "${IDEA_DIRS[@]}"; do
            opts_dir="$idea_dir/options"
            mkdir -p "$opts_dir"

            # 1. MCP Server port 64343 in mcpServer.xml
            mcp_file="$opts_dir/mcpServer.xml"
            if [ ! -f "$mcp_file" ]; then
                cat > "$mcp_file" << 'EOF'
<application>
  <component name="McpServerOptions">
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

            # Clean up duplicate files if created previously
            rm -f "$opts_dir/mcp.xml" 2>/dev/null || true
            rm -f "$opts_dir/editor-font.xml" 2>/dev/null || true

            # 2. Configure Noto Color Emoji fallback font in editor.font.xml
            font_file="$opts_dir/editor.font.xml"
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
fi
