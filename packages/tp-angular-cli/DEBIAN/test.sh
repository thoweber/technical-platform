#!/bin/bash
set -e

echo "Installing tp-angular-cli and verifying ng CLI..."
apt-get update
apt-get install -y tp-angular-cli

echo "Testing Angular CLI as developer user..."
su - developer << 'EOF'
set -e
source /etc/profile
export NG_CLI_ANALYTICS=false
ng version
EOF

echo "✅ Angular CLI (tp-angular-cli) execution passed!"
