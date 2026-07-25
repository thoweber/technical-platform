#!/bin/bash
set -e

echo "Installing tp-nvm-node and asserting configuration..."
apt-get update
apt-get install -y tp-nvm-node

test -d /opt/nvm
test -f /etc/profile.d/nvm.sh

echo "Verifying NVM shell integration in developer user's home directory..."
su - developer << 'EOF'
source /etc/profile 2>/dev/null || true
set -e

bashrc="$HOME/.bashrc"
test -f "$bashrc"
grep -q 'NVM_DIR="/opt/nvm"' "$bashrc"

owner=$(stat -c '%U:%G' "$bashrc")
if [ "$owner" != "developer:developer" ]; then
    echo "Error: $bashrc is owned by $owner instead of developer:developer"
    exit 1
fi

nvm --version
node --version
EOF

echo "✅ tp-nvm-node package installation and .bashrc integration passed!"
