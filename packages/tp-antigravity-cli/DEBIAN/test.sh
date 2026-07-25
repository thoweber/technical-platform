#!/bin/bash
set -e

echo "Installing and testing tp-antigravity-cli..."
apt-get update
apt-get install -y tp-antigravity-cli
test -f /usr/local/bin/agy

echo "Verifying user home directory configuration and .bashrc for Antigravity CLI as developer..."
su - developer << 'EOF'
source /etc/profile 2>/dev/null || true
set -e

bashrc="$HOME/.bashrc"
test -f "$bashrc"
grep -q '/opt/antigravity/bin' "$bashrc"

owner_bashrc=$(stat -c '%U:%G' "$bashrc")
if [ "$owner_bashrc" != "developer:developer" ]; then
    echo "Error: $bashrc is owned by $owner_bashrc instead of developer:developer"
    exit 1
fi

config_file="$HOME/.config/antigravity/config.json"
test -f "$config_file"
test -r "$config_file"
test -w "$config_file"

owner_config=$(stat -c '%U:%G' "$config_file")
if [ "$owner_config" != "developer:developer" ]; then
    echo "Error: $config_file is owned by $owner_config instead of developer:developer"
    exit 1
fi
echo "Verified: $config_file exists and is owned by developer:developer"
EOF

# Test apt-get remove teardown
apt-get remove -y tp-antigravity-cli
if [ -f /usr/local/bin/agy ] || [ -d /opt/antigravity ]; then
  echo "Failed: agy binary was not removed on apt-get remove!"
  exit 1
fi

# Reinstall for subsequent package tests
apt-get install -y tp-antigravity-cli
echo "✅ tp-antigravity-cli installation, .bashrc integration & teardown passed!"
