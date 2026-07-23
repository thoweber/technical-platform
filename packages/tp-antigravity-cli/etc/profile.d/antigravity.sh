#!/bin/bash
# Add Antigravity CLI to system PATH for all users
if [ -d "/opt/antigravity/bin" ]; then
    case ":$PATH:" in
        *:/opt/antigravity/bin:*) ;;
        *) export PATH="/opt/antigravity/bin:$PATH" ;;
    esac
fi
