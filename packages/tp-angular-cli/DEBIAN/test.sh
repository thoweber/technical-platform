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

# Test package uninstallation teardown
echo "Testing tp-angular-cli removal and teardown..."
apt-get remove -y tp-angular-cli
su - developer << 'EOF'
set -e
source /etc/profile
if command -v ng >/dev/null 2>&1; then
    echo "Error: ng CLI command is still available after package removal!"
    exit 1
fi
EOF
echo "Verified: Angular CLI (@angular/cli) was cleanly uninstalled via npm."

# Reinstall for subsequent package tests in pipeline
apt-get install -y tp-angular-cli
echo "✅ Angular CLI (tp-angular-cli) execution and uninstallation teardown passed!"
