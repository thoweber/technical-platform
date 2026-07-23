#!/bin/bash
# Environment & performance fixes for IntelliJ IDEA under WSL2/WSLg
export AT_SPI_CLIENT_NO_AT_BRIDGE=1
export NO_AT_BRIDGE=1

if [ -n "$HOME" ] && [ -d "$HOME" ]; then
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

        # Configure Noto Color Emoji fallback font in editor-font.xml (Component: DefaultFont)
        font_file="$opts_dir/editor-font.xml"
        if [ ! -f "$font_file" ]; then
            cat > "$font_file" << 'EOF'
<application>
  <component name="DefaultFont">
    <option name="VERSION" value="1" />
    <option name="SECONDARY_FONT_FAMILY" value="Noto Color Emoji" />
  </component>
</application>
EOF
        else
            if ! grep -q 'SECONDARY_FONT_FAMILY' "$font_file"; then
                if grep -q '<component name="DefaultFont">' "$font_file"; then
                    sed -i '/<component name="DefaultFont">/a \    <option name="SECONDARY_FONT_FAMILY" value="Noto Color Emoji" />' "$font_file" 2>/dev/null || true
                fi
            fi
        fi
    done
fi
