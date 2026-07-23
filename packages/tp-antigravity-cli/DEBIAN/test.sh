#!/bin/bash
set -e

echo "Installing and testing tp-antigravity-cli..."
apt-get update
apt-get install -y tp-antigravity-cli
test -f /usr/local/bin/agy

# Test apt-get remove teardown
apt-get remove -y tp-antigravity-cli
if [ -f /usr/local/bin/agy ] || [ -d /opt/antigravity ]; then
  echo "Failed: agy binary was not removed on apt-get remove!"
  exit 1
fi

# Reinstall for subsequent package tests
apt-get install -y tp-antigravity-cli
echo "✅ tp-antigravity-cli installation & teardown passed!"
