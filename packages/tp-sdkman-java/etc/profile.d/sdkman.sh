#!/bin/bash
# SDKMAN environment setup for all users
export SDKMAN_DIR="/opt/sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
