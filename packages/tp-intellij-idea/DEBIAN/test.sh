#!/bin/bash
set -e

echo "Installing tp-intellij-idea and asserting configuration..."
apt-get update
apt-get install -y tp-intellij-idea

test -f /etc/profile.d/tp-intellij.sh

su - developer << 'EOF'
source /etc/profile 2>/dev/null || true
set -e

test "$AT_SPI_CLIENT_NO_AT_BRIDGE" = "1"
test "$NO_AT_BRIDGE" = "1"

font_file="$HOME/.config/JetBrains/IntelliJIdea2026.2/options/editor-font.xml"
test -f "$font_file"
grep -q "DefaultFont" "$font_file"
grep -q "Noto Color Emoji" "$font_file"
EOF

echo "✅ IntelliJ IDEA package installation passed!"
