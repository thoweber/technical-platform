#!/usr/bin/env bash
set -e

# Convenience script to create and push a new version release tag.
# Usage:
#   ./release.sh           # Automatically bumps the patch version (e.g. v0.0.3 -> v0.0.4)
#   ./release.sh v1.0.0    # Specifies an explicit target version

echo "Fetching latest tags from remote..."
git fetch --tags --quiet 2>/dev/null || true

# Find the latest tag matching v* using version sorting
LATEST_TAG=$(git tag -l "v*" | sort -V | tail -n 1)

if [ -n "$1" ]; then
    NEW_VERSION="$1"
    [[ "$NEW_VERSION" != v* ]] && NEW_VERSION="v$NEW_VERSION"
    
    # Check if specified version tag already exists
    if git rev-parse -q --verify "refs/tags/$NEW_VERSION" >/dev/null; then
        echo "❌ Error: Specified version tag '$NEW_VERSION' already exists."
        echo "Please specify a higher version number or run without arguments for auto-patch bumping."
        exit 1
    fi
else
    if [ -z "$LATEST_TAG" ]; then
        NEW_VERSION="v0.0.1"
    else
        # Extract major, minor, patch numbers
        VERSION_NO_V="${LATEST_TAG#v}"
        IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION_NO_V"
        
        MAJOR=${MAJOR:-0}
        MINOR=${MINOR:-0}
        PATCH=${PATCH:-0}
        
        NEXT_PATCH=$((PATCH + 1))
        NEW_VERSION="v${MAJOR}.${MINOR}.${NEXT_PATCH}"
        
        # Ensure auto-generated patch tag doesn't collide with existing tags
        while git rev-parse -q --verify "refs/tags/$NEW_VERSION" >/dev/null; do
            NEXT_PATCH=$((NEXT_PATCH + 1))
            NEW_VERSION="v${MAJOR}.${MINOR}.${NEXT_PATCH}"
        done
    fi
fi

echo "=========================================="
if [ -n "$LATEST_TAG" ]; then
    echo " Current latest tag:  $LATEST_TAG"
else
    echo " No existing tags found."
fi
echo " Target release tag:   $NEW_VERSION"
echo "=========================================="

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️ Working directory has uncommitted changes."
    git status --short
    echo ""
    read -p "Do you want to commit all changes before tagging? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter commit message: " COMMIT_MSG
        if [ -z "$COMMIT_MSG" ]; then
            COMMIT_MSG="Prepare release $NEW_VERSION"
        fi
        git add .
        git commit -m "$COMMIT_MSG"
        git push origin main
    else
        echo "Proceeding with uncommitted local changes..."
    fi
fi

# Create annotated tag
echo "Creating tag $NEW_VERSION..."
git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION"

# Push tag to remote
echo "Pushing tag $NEW_VERSION to origin..."
git push origin "$NEW_VERSION"

echo ""
echo "🎉 Successfully pushed tag $NEW_VERSION!"
echo "GitHub Actions will build the WSL image and trigger automated quality gate E2E testing."
