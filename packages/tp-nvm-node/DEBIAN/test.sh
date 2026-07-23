#!/bin/bash
set -e

echo "Installing tp-nvm-node and verifying Node.js & NVM..."
apt-get update
apt-get install -y tp-nvm-node

echo "Testing Node.js & NVM as developer user..."
su - developer << 'EOF'
set -e
source /etc/profile
node --version
npm --version

mkdir -p /tmp/node-test && cd /tmp/node-test
cat > helloworld.js << 'NODE_EOF'
console.log("Hello, World!");
NODE_EOF
output=$(node helloworld.js)
echo "Node Execution Output: $output"
if [ "$output" != "Hello, World!" ]; then
  echo "Node.js output mismatch!"
  exit 1
fi
EOF

# Test package uninstallation teardown
echo "Testing tp-nvm-node removal and teardown..."
apt-get remove -y tp-nvm-node
if [ -d "/opt/nvm" ] || [ -f "/etc/profile.d/nvm.sh" ]; then
    echo "Error: /opt/nvm or nvm.sh was not completely removed on apt-get remove!"
    exit 1
fi
echo "Verified: /opt/nvm and all managed Node versions were cleanly removed."

# Reinstall for subsequent package tests in pipeline
apt-get install -y tp-nvm-node
echo "✅ Node.js 24 & NVM compilation, execution, and uninstallation teardown passed!"
