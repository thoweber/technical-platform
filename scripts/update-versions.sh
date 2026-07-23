#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="$REPO_ROOT/packages/versions.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found!"
    exit 1
fi

echo "Loading version definitions from packages/versions.env..."
source "$ENV_FILE"

echo "Synchronizing package control files and postinst scripts..."

# Helper function to update control file Version
update_control_version() {
    local control_file="$1"
    local new_version="$2"
    if [ -f "$control_file" ]; then
        sed -i "s/^Version:.*/Version: $new_version/" "$control_file"
        echo "  Updated $(basename "$(dirname "$(dirname "$control_file")")")/DEBIAN/control -> $new_version"
    fi
}

# 1. Update Debian package versions in control files
update_control_version "$REPO_ROOT/packages/tp-sdkman-java/DEBIAN/control" "$TP_SDKMAN_JAVA_PKG_VERSION"
update_control_version "$REPO_ROOT/packages/tp-nvm-node/DEBIAN/control" "$TP_NVM_NODE_PKG_VERSION"
update_control_version "$REPO_ROOT/packages/tp-angular-cli/DEBIAN/control" "$TP_ANGULAR_CLI_PKG_VERSION"
update_control_version "$REPO_ROOT/packages/tp-docker/DEBIAN/control" "$TP_DOCKER_PKG_VERSION"
update_control_version "$REPO_ROOT/packages/tp-intellij-idea/DEBIAN/control" "$TP_INTELLIJ_IDEA_PKG_VERSION"
update_control_version "$REPO_ROOT/packages/tp-antigravity-cli/DEBIAN/control" "$TP_ANTIGRAVITY_CLI_PKG_VERSION"
update_control_version "$REPO_ROOT/packages/tp-intellij-agy-interop/DEBIAN/control" "$TP_INTEROP_PKG_VERSION"

# 2. Update upstream tool versions in postinst scripts
NVM_POSTINST="$REPO_ROOT/packages/tp-nvm-node/DEBIAN/postinst"
if [ -f "$NVM_POSTINST" ]; then
    sed -i "s|v0\.[0-9]*\.[0-9]*|v${TP_NVM_VERSION}|g" "$NVM_POSTINST"
    sed -i "s|nvm install [0-9]*|nvm install ${TP_NODE_VERSION}|g" "$NVM_POSTINST"
    sed -i "s|nvm use [0-9]*|nvm use ${TP_NODE_VERSION}|g" "$NVM_POSTINST"
    sed -i "s|nvm alias default [0-9]*|nvm alias default ${TP_NODE_VERSION}|g" "$NVM_POSTINST"
fi

JAVA_POSTINST="$REPO_ROOT/packages/tp-sdkman-java/DEBIAN/postinst"
if [ -f "$JAVA_POSTINST" ]; then
    sed -i "s|sdk install java .*|sdk install java ${TP_JAVA_VERSION}|g" "$JAVA_POSTINST"
    sed -i "s|sdk default java .*|sdk default java ${TP_JAVA_VERSION}|g" "$JAVA_POSTINST"
fi

echo "✅ All package control files and postinst scripts synchronized with versions.env!"
