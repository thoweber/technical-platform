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

echo "✅ Node.js 24 & NVM execution passed!"
