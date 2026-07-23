#!/bin/bash
set -e

echo "Testing first boot and WSL configuration..."
uname -a
cat /etc/os-release
grep -q "systemd=true" /etc/wsl.conf
grep -q "default=developer" /etc/wsl.conf
grep -q "appendWindowsPath=false" /etc/wsl.conf
grep -q "DEBIAN_FRONTEND=noninteractive" /etc/environment
echo "✅ First boot & WSL wsl.conf configuration verified!"
