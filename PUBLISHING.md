# Publishing Guide

This guide describes the complete publishing process for the Technical Platform Ubuntu Distribution, including all workflow options and manual steps.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Workflow Triggers](#workflow-triggers)
4. [Publishing Process](#publishing-process)
5. [Workflow Jobs](#workflow-jobs)
6. [Manual Publishing](#manual-publishing)
7. [Troubleshooting](#troubleshooting)

---

## Overview

The publishing pipeline consists of four automated jobs:

1. **Build Packages** - Compiles custom Debian packages
2. **Update APT Repository** - Manages the APT repository via reprepro and deploys to GitHub Pages
3. **Build WSL Image** - Creates the WSL distribution from Docker image
4. **Create Release** - Publishes GitHub releases with distribution files

## Prerequisites

### Repository Setup

1. **Enable GitHub Pages**:
   - Go to repository Settings → Pages
   - Set Source to "GitHub Actions"
   - Save the configuration

2. **Verify Permissions**:
   The workflow requires the following permissions (already configured in the workflow):
   - `contents: write` - For creating releases
   - `pages: write` - For deploying to GitHub Pages
   - `id-token: write` - For GitHub Pages authentication

3. **Repository Structure**:
   ```
   .
   ├── .github/
   │   └── workflows/
   │       └── build-and-release.yml
   ├── packages/                    # Optional: Custom .deb packages
   │   ├── package-name-1/
   │   │   ├── DEBIAN/
   │   │   │   └── control
   │   │   └── usr/...
   │   └── package-name-2/
   │       └── ...
   ├── Dockerfile
   └── CONTEXT.md
   ```

### Package Directory Structure

Custom packages are stored in the `packages/` directory and are automatically built by the CI/CD pipeline.

#### Package Naming Convention

All custom packages use the **`tp-`** prefix (Technical Platform) to identify them as part of this distribution.

**Naming format:** `tp-<component>-<description>`

Examples:
- `tp-sdkman-java` (SDKMAN with Java)
- `tp-nvm-node` (NVM with Node)
- `tp-docker-tools` (Docker utilities)

#### Included Packages

This distribution includes three optional development environment packages:

1. **tp-sdkman-java** - SDKMAN with Java 25 (Eclipse Temurin)
   - Installs to `/opt/sdkman` (system-wide)
   - Automatically configures environment via `/etc/profile.d/sdkman.sh`
   - Install with: `sudo apt-get install tp-sdkman-java`

2. **tp-nvm-node** - NVM with Node.js 24 LTS and Angular CLI
   - Installs to `/opt/nvm` (system-wide)
   - Includes Angular CLI pre-installed globally
   - Automatically configures environment via `/etc/profile.d/nvm.sh`
   - Install with: `sudo apt-get install tp-nvm-node`

3. **tp-docker** - Docker CE Complete Installation
   - Installs Docker CE, CLI, containerd, Buildx, and Compose plugins
   - Automatically adds current user to docker group
   - Enables and starts Docker service
   - Install with: `sudo apt-get install tp-docker`

#### Creating Custom Packages

Structure your packages as follows (use `tp-` prefix):

```
packages/
└── tp-my-component/
    ├── DEBIAN/
    │   ├── control          # Required: package metadata
    │   ├── postinst         # Optional: post-installation script
    │   ├── prerm            # Optional: pre-removal script
    │   └── postrm           # Optional: post-removal script
    └── usr/
        ├── bin/
        │   └── my-tool
        └── share/
            └── doc/
```

**Example `DEBIAN/control` file**:
```
Package: tp-my-component
Version: 1.0.0
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Your Name <email@example.com>
Description: My custom package for WSL
 Extended description goes here.
```

**Important Notes for postinst scripts**:
- Must be executable: `chmod +x DEBIAN/postinst`
- Should start with `#!/bin/bash` and `set -e`
- Should handle idempotency (check if already installed)
- Should exit with `exit 0` on success

---

## Workflow Triggers

The workflow can be triggered in three ways:

### 1. Automatic Trigger on Push to Main

**When**: Any push to the `main` branch

**What it does**:
- Builds all custom packages
- Updates APT repository and deploys to GitHub Pages
- Builds WSL distribution image
- Does **NOT** create a release (only tags trigger releases)

**Use case**: Continuous integration and testing

```bash
git add .
git commit -m "Update packages"
git push origin main
```

### 2. Automatic Trigger on Version Tag

**When**: Push a tag starting with `v` (e.g., `v1.0.0`, `v2.1.3`)

**What it does**:
- Builds all custom packages
- Updates APT repository
- Builds WSL distribution image
- **Creates a GitHub Release** with all artifacts

**Use case**: Official releases

```bash
# Create and push a version tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

### 3. Manual Trigger (Workflow Dispatch)

**When**: Manually triggered from GitHub Actions UI

**What it does**:
- Same as push to main (no release creation)

**Steps**:
1. Go to Actions tab in GitHub repository
2. Click "Build WSL Distribution and Publish" workflow
3. Click "Run workflow" dropdown
4. Select branch (usually `main`)
5. Click "Run workflow" button

**Use case**: Testing, rebuilding without new commits

---

## Publishing Process

### For Development/Testing (Push to Main)

```bash
# 1. Make your changes
vim packages/my-package/usr/bin/tool
vim Dockerfile

# 2. Commit changes
git add .
git commit -m "Update tool configuration"

# 3. Push to main
git push origin main
```

**Result**: APT repository updated, WSL image built, no release created

### For Production Release (Version Tag)

```bash
# 1. Ensure main branch is ready
git checkout main
git pull origin main

# 2. Create version tag
git tag -a v1.0.0 -m "Release v1.0.0: Add feature X, fix bug Y"

# 3. Push tag to trigger release
git push origin v1.0.0
```

**Result**: Full release with downloadable WSL distribution files

### Tag Naming Convention

Follow semantic versioning:
- **Major** (`v2.0.0`): Breaking changes, major features
- **Minor** (`v1.1.0`): New features, backward compatible
- **Patch** (`v1.0.1`): Bug fixes, small improvements

---

## Workflow Jobs

### Job 1: Build Packages

**Purpose**: Compile custom Debian packages from source

**Runs on**: `ubuntu-latest`

**Steps**:
1. Checkout repository
2. Install build tools (`dpkg-dev`, `build-essential`, `fakeroot`)
3. Build all packages in `packages/` directory
4. Upload packages as artifacts

**Artifacts**: `debian-packages` (all `.deb` files)

**Skip conditions**: None - always runs

---

### Job 2: Update APT Repository

**Purpose**: Manage APT repository with reprepro and deploy to GitHub Pages

**Runs on**: `ubuntu-latest`

**Depends on**: `build-packages`

**Runs when**: Push to `main` OR version tag (not on PRs)

**Steps**:
1. Download built packages
2. Install `reprepro` and `gnupg`
3. Initialize reprepro repository structure:
   - Creates `tp-apt-repo/conf/distributions` file
   - Configures for Ubuntu Noble (`noble` codename)
   - Supports `amd64`, `arm64`, and `source` architectures
4. Add packages to repository (`reprepro includedeb`)
5. Generate repository indexes (`reprepro export`)
6. Create GitHub Pages structure with `dists/` and `pool/`
7. Deploy to GitHub Pages

**Output**: APT repository accessible at `https://<username>.github.io/<repo-name>/`

**Configuration**:
- **Codename**: `noble` (Ubuntu 24.04)
- **Components**: `main`
- **Architectures**: `amd64`, `arm64`, `source`
- **Signing**: Disabled (`SignWith: no`) - uses `[trusted=yes]` in sources.list

---

### Job 3: Build WSL Image

**Purpose**: Build Docker image and export as WSL-compatible tarball

**Runs on**: `ubuntu-latest`

**Depends on**: `update-apt-repo`

**Runs when**: Push to `main` OR version tag

**Steps**:
1. Checkout repository
2. Download package artifacts (if available)
3. Set up Docker Buildx
4. Build Docker image with build arguments:
   - `APT_REPO_URL`: Points to GitHub Pages repository
5. Create container and export filesystem
6. Compress to `.tar.gz` and create `.wsl` copy
7. Generate installation instructions (`INSTALL.txt`)
8. Create SHA256 checksums for verification
9. Upload artifacts

**Artifacts**: `wsl-distribution` containing:
- `TechnicalPlatform.tar.gz` - Standard gzipped tarball
- `TechnicalPlatform.wsl` - WSL installer format
- `TechnicalPlatform.tar.gz.sha256` - Checksum file
- `TechnicalPlatform.wsl.sha256` - Checksum file
- `INSTALL.txt` - Installation instructions

**Environment Variables**:
- `DOCKER_IMAGE_NAME`: `tp-ubuntu`
- `DISTRIBUTION_NAME`: `TechnicalPlatform`
- `CODENAME`: `noble`

---

### Job 4: Create Release

**Purpose**: Publish GitHub release with distribution files

**Runs on**: `ubuntu-latest`

**Depends on**: `build-wsl-image`

**Runs when**: **ONLY** on version tags (`refs/tags/v*`)

**Steps**:
1. Checkout repository
2. Download distribution artifacts
3. Create GitHub Release with:
   - Tag name as release name
   - Auto-generated release notes
   - Custom release body with features and instructions
   - All distribution files attached

**Release Assets**:
- `TechnicalPlatform.tar.gz`
- `TechnicalPlatform.wsl`
- `TechnicalPlatform.tar.gz.sha256`
- `TechnicalPlatform.wsl.sha256`
- `INSTALL.txt`

**Release Configuration**:
- `draft`: `false` - Published immediately
- `prerelease`: `false` - Marked as stable
- `generate_release_notes`: `true` - Auto-generates changelog

---

## Manual Publishing

### Building Locally

If you need to build the distribution locally without CI/CD:

```bash
# 1. Build packages manually
cd packages/my-package
dpkg-deb --build . ../../built-packages/my-package.deb

# 2. Build Docker image
docker build \
  --build-arg APT_REPO_URL="https://username.github.io/repo-name" \
  --tag tp-ubuntu:latest \
  --file Dockerfile \
  .

# 3. Export rootfs
container_id=$(docker create tp-ubuntu:latest)
docker export $container_id | gzip > TechnicalPlatform.tar.gz
docker rm $container_id

# 4. Import to WSL
wsl --import TechnicalPlatform C:\WSL\TechnicalPlatform TechnicalPlatform.tar.gz
```

### Managing APT Repository Manually

```bash
# Install reprepro
sudo apt-get install reprepro

# Initialize repository
mkdir -p tp-apt-repo/conf
cat > tp-apt-repo/conf/distributions <<EOF
Origin: Technical Platform Repository
Label: Technical Platform
Codename: noble
Architectures: amd64 arm64 source
Components: main
Description: Custom packages for WSL Ubuntu distribution
SignWith: no
EOF

# Add packages
cd apt-repo
reprepro includedeb noble ../packages/my-package.deb

# Export and list
reprepro export noble
reprepro list noble
```

### Deploying to GitHub Pages Manually

```bash
# Copy repository structure
mkdir -p gh-pages
cp -r tp-apt-repo/dists gh-pages/
cp -r tp-apt-repo/pool gh-pages/

# Deploy using gh-pages branch
git checkout --orphan gh-pages
git rm -rf .
cp -r gh-pages/* .
git add .
git commit -m "Update APT repository"
git push origin gh-pages --force
```

---

## Troubleshooting

### Workflow Fails at "Build Packages"

**Issue**: No packages found or build errors

**Solutions**:
- Verify `packages/*/DEBIAN/control` files exist and are valid
- Check package directory structure matches Debian standards
- Review build logs for `dpkg-deb` errors
- Ensure `DEBIAN` directory name is uppercase

### Workflow Fails at "Update APT Repository"

**Issue**: Reprepro errors or GitHub Pages deployment fails

**Solutions**:
- Check GitHub Pages is enabled in repository settings
- Verify workflow has `pages: write` permission
- Ensure `.deb` files are valid: `dpkg-deb -I package.deb`
- Check reprepro configuration in `tp-apt-repo/conf/distributions`

### Workflow Fails at "Build WSL Image"

**Issue**: Docker build fails or export errors

**Solutions**:
- Review Dockerfile syntax and build context
- Check Docker build logs for missing dependencies
- Verify base image `ubuntu:noble` is accessible
- Ensure sufficient disk space for image export

### Release Not Created

**Issue**: Tag pushed but no release appears

**Solutions**:
- Verify tag starts with `v` (e.g., `v1.0.0`, not `1.0.0`)
- Check workflow has `contents: write` permission
- Review previous jobs completed successfully
- Look for errors in "Create Release" job logs

### APT Repository Returns 404

**Issue**: Cannot access repository at GitHub Pages URL

**Solutions**:
- Wait 2-5 minutes for GitHub Pages deployment
- Verify GitHub Pages is published: Settings → Pages → Visit site
- Check repository visibility (public repositories work best)
- Ensure `dists/` and `pool/` directories exist in gh-pages

### WSL Import Fails

**Issue**: `wsl --import` returns error

**Solutions**:
- Verify `.tar.gz` or `.wsl` file is not corrupted (check SHA256)
- Ensure WSL2 is installed: `wsl --set-default-version 2`
- Try with full path: `wsl --import TechnicalPlatform C:\WSL\TechnicalPlatform C:\Downloads\TechnicalPlatform.wsl`
- Check Windows has sufficient disk space

---

## Additional Resources

### Useful Commands

```bash
# View workflow runs
gh run list

# View specific run logs
gh run view <run-id> --log

# Download artifacts
gh run download <run-id>

# List all tags
git tag -l

# Delete a tag (local and remote)
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0

# View APT repository contents
curl https://username.github.io/repo-name/dists/noble/main/binary-amd64/Packages
```

### Environment Variables Reference

Modify these in `.github/workflows/build-and-release.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_IMAGE_NAME` | `tp-ubuntu` | Docker image tag name |
| `DISTRIBUTION_NAME` | `TechnicalPlatform` | Output filename and WSL distribution name |
| `REPREPRO_DIR` | `tp-apt-repo` | Directory for APT repository structure |
| `CODENAME` | `noble` | Ubuntu codename (noble = 24.04) |

### Workflow Customization

To modify workflow behavior, edit `.github/workflows/build-and-release.yml`:

**Change supported architectures**:
```yaml
# In update-apt-repo job, distributions file
Architectures: amd64 arm64 i386 source
```

**Enable package signing**:
```yaml
# In update-apt-repo job
- name: Import GPG key
  run: echo "${{ secrets.GPG_PRIVATE_KEY }}" | gpg --import

# Update distributions file
SignWith: your-key-id
```

**Change base Ubuntu version**:
```yaml
env:
  CODENAME: jammy  # Ubuntu 22.04
```

Then update `Dockerfile`:
```dockerfile
FROM ubuntu:jammy AS base
```

---

## Quick Reference

### Publishing Checklist

- [ ] Packages built successfully
- [ ] Dockerfile updated if needed
- [ ] Changes committed to main branch
- [ ] Version tag created (for releases)
- [ ] Tag pushed to remote
- [ ] Workflow runs successfully
- [ ] GitHub Pages deployed
- [ ] APT repository accessible
- [ ] Release created with assets (for tags)
- [ ] Distribution tested locally

### Support

For issues or questions:
- Check workflow logs in GitHub Actions tab
- Review this guide's Troubleshooting section
- Open an issue in the repository
