#!/bin/bash
set -e

echo "Installing tp-sdkman-java and asserting configuration..."
apt-get update
apt-get install -y tp-sdkman-java

test -d /opt/sdkman
test -f /etc/profile.d/sdkman.sh

echo "Verifying SDKMAN shell integration in developer user's home directory..."
su - developer << 'EOF'
source /etc/profile 2>/dev/null || true
set -e

bashrc="$HOME/.bashrc"
test -f "$bashrc"
grep -q 'SDKMAN_DIR="/opt/sdkman"' "$bashrc"

owner=$(stat -c '%U:%G' "$bashrc")
if [ "$owner" != "developer:developer" ]; then
    echo "Error: $bashrc is owned by $owner instead of developer:developer"
    exit 1
fi

sdk version
java -version
EOF

echo "✅ tp-sdkman-java package installation and .bashrc integration passed!"
