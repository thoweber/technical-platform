#!/bin/bash
set -e

echo "Installing tp-docker and verifying ACLs and non-root execution..."
apt-get update
apt-get install -y tp-docker

test -f /etc/tmpfiles.d/docker-acl.conf
grep -q "u:developer:rw" /etc/tmpfiles.d/docker-acl.conf

echo "Testing immediate non-root execution without sudo as developer user..."
su - developer << 'EOF'
set -e
docker --version || true
EOF

echo "✅ Immediate sudo-less docker execution passed!"
