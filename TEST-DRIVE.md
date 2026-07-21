# Test Drive Guide

This guide explains how to test the Technical Platform distribution locally before publishing.

## Quick Test Drive

### Option 1: Build and Import Locally (Recommended)

**Prerequisites:**
- Docker installed on your system
- WSL2 installed on Windows

**Steps:**

```bash
# 1. Build the Docker image locally
docker build -t tp-ubuntu:test .

# 2. Export the rootfs to a tar.gz file
container_id=$(docker create tp-ubuntu:test)
docker export $container_id | gzip > TechnicalPlatform-test.tar.gz
docker rm $container_id

# 3. Import into WSL (run in PowerShell/Command Prompt on Windows)
wsl --import TechnicalPlatform-Test C:\WSL\TechnicalPlatform-Test TechnicalPlatform-test.tar.gz

# 4. Launch the distribution
wsl -d TechnicalPlatform-Test

# 5. Set default user (optional)
ubuntu config --default-user developer
# Or manually:
wsl -d TechnicalPlatform-Test -u developer
```

---

## Testing Custom Packages

### Build Packages Locally

```bash
# Build all packages
cd packages
for pkg_dir in tp-*/; do
    pkg_name=$(basename "$pkg_dir")
    echo "Building $pkg_name..."
    dpkg-deb --build "$pkg_dir" "../${pkg_name}.deb"
done
cd ..

# Copy packages into the WSL distribution
# From Windows (PowerShell):
wsl -d TechnicalPlatform-Test --user root -- mkdir -p /tmp/test-packages
wsl.exe -d TechnicalPlatform-Test cp tp-sdkman-java.deb /tmp/test-packages/
wsl.exe -d TechnicalPlatform-Test cp tp-nvm-node.deb /tmp/test-packages/
wsl.exe -d TechnicalPlatform-Test cp tp-docker.deb /tmp/test-packages/

# Install packages in WSL
wsl -d TechnicalPlatform-Test --user root
cd /tmp/test-packages
dpkg -i tp-sdkman-java.deb
dpkg -i tp-nvm-node.deb
dpkg -i tp-docker.deb

# Fix any dependency issues
apt-get install -f -y
```

### Verify Package Installation

```bash
# Test tp-sdkman-java
source /etc/profile.d/sdkman.sh
java -version
sdk version

# Test tp-nvm-node
source /etc/profile.d/nvm.sh
node --version
npm --version
ng version

# Test tp-docker
docker --version
docker compose version
docker run hello-world
```

---

## Testing the Full CI/CD Pipeline

### Local GitHub Actions Testing with `act`

Install `act` to run GitHub Actions locally:

```bash
# Install act (https://github.com/nektos/act)
# macOS
brew install act

# Linux
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Windows (via Scoop)
scoop install act

# Run the workflow locally
act push -W .github/workflows/build-and-release.yml

# Run specific job
act -j build-packages
act -j update-apt-repo
act -j build-wsl-image
```

---

## Quick Validation Checklist

Once inside the WSL distribution, verify:

### Base System
- [ ] `systemctl status` - Systemd is running
- [ ] `uname -a` - Kernel version
- [ ] `lsb_release -a` - Ubuntu Noble 24.04
- [ ] `df -h` - Disk space usage

### Repositories
- [ ] `cat /etc/apt/sources.list.d/docker.list` - Docker repo configured
- [ ] `cat /etc/apt/sources.list.d/technical-platform.list` - Custom repo configured
- [ ] `apt-get update` - All repos accessible

### Optional Packages (if installed)
- [ ] `java -version` - Java 25 available
- [ ] `sdk version` - SDKMAN working
- [ ] `node --version` - Node 24 available
- [ ] `nvm --version` - NVM working
- [ ] `ng version` - Angular CLI working
- [ ] `docker --version` - Docker available
- [ ] `docker ps` - Docker works without sudo

### WSL Features
- [ ] `snap list` - Snap daemon running
- [ ] `echo $DISPLAY` - WSLg display configured
- [ ] `glxinfo | grep "OpenGL"` - GPU acceleration (if WSLg enabled)

---

## Testing Individual Components

### Test Dockerfile Stages

```bash
# Build only base stage
docker build --target base -t tp-wsl:base .

# Build development stage
docker build --target development -t tp-wsl:dev .

# Build final export stage
docker build --target export -t tp-wsl:export .

# Inspect image size
docker images tp-wsl:*
```

### Test Package Installation Order

```bash
# Test installing packages in different orders
wsl -d TechnicalPlatform-Test --user root

# Order 1: Java first
apt-get update
apt-get install tp-sdkman-java
source /etc/profile.d/sdkman.sh
java -version

# Order 2: Node next
apt-get install tp-nvm-node
source /etc/profile.d/nvm.sh
node --version

# Order 3: Docker last
apt-get install tp-docker
docker --version
```

### Test Package Removal

```bash
# Remove packages and verify cleanup
apt-get remove tp-docker
apt-get remove tp-nvm-node
apt-get remove tp-sdkman-java

# Verify removal
which docker  # Should return nothing
which node    # Should return nothing
which java    # Should return nothing
```

---

## Performance Testing

### Measure Build Time

```bash
# Time the Docker build
time docker build -t tp-wsl:test .

# Time package builds
time dpkg-deb --build packages/tp-sdkman-java tp-sdkman-java.deb
time dpkg-deb --build packages/tp-nvm-node tp-nvm-node.deb
time dpkg-deb --build packages/tp-docker tp-docker.deb
```

### Check Image Size

```bash
# Base image size
docker images ubuntu:noble

# Built image size
docker images tp-wsl:test

# Exported tarball size
ls -lh TechnicalPlatform-test.tar.gz

# Package sizes
ls -lh *.deb
```

---

## Cleanup After Testing

```bash
# Remove WSL distribution
wsl --unregister TechnicalPlatform-Test

# Remove Docker images
docker rmi tp-ubuntu:test
docker rmi tp-wsl:base tp-wsl:dev tp-wsl:export

# Remove exported files
rm TechnicalPlatform-test.tar.gz
rm *.deb
```

---

## Troubleshooting

### WSL Import Fails

```powershell
# Check WSL version
wsl --version

# List distributions
wsl --list --verbose

# Set default version to WSL2
wsl --set-default-version 2

# Update WSL
wsl --update
```

### Docker Build Fails

```bash
# Check Docker daemon
docker info

# Clear build cache
docker builder prune -a

# Build with verbose output
docker build --progress=plain -t tp-wsl:test .

# Build without cache
docker build --no-cache -t tp-wsl:test .
```

### Package Installation Fails

```bash
# Check package structure
dpkg-deb --info tp-sdkman-java.deb
dpkg-deb --contents tp-sdkman-java.deb

# Check dependencies
apt-cache policy docker-ce
apt-cache policy curl

# Fix broken dependencies
apt-get install -f
```

### Systemd Not Working in WSL

Check `/etc/wsl.conf`:
```ini
[boot]
systemd=true
```

Then restart WSL:
```powershell
wsl --shutdown
wsl -d TechnicalPlatform-Test
```

---

## Advanced Testing

### Test with Different Users

```bash
# Create additional test users
wsl -d TechnicalPlatform-Test --user root
useradd -m -s /bin/bash testuser
passwd testuser

# Test as different user
wsl -d TechnicalPlatform-Test -u testuser

# Verify package access
source /etc/profile.d/sdkman.sh
java -version
```

### Test Persistence

```bash
# Create a file
echo "test" > /home/developer/test.txt

# Exit and restart
exit
wsl -d TechnicalPlatform-Test

# Verify file persists
cat /home/developer/test.txt
```

### Test Network Connectivity

```bash
# Test DNS
ping -c 3 google.com

# Test APT repository access
apt-get update

# Test Docker Hub access (if Docker installed)
docker pull hello-world
```

---

## Automated Testing Script

Create `test-distribution.sh`:

```bash
#!/bin/bash
set -e

echo "🧪 Testing Technical Platform Distribution..."

# Build packages
echo "📦 Building packages..."
for pkg_dir in packages/tp-*/; do
    pkg_name=$(basename "$pkg_dir")
    dpkg-deb --build "$pkg_dir" "${pkg_name}.deb"
done

# Build Docker image
echo "🐳 Building Docker image..."
docker build -t tp-wsl:test .

# Export rootfs
echo "📤 Exporting rootfs..."
container_id=$(docker create tp-wsl:test)
docker export $container_id | gzip > TechnicalPlatform-test.tar.gz
docker rm $container_id

# Get file sizes
echo "📊 Build artifacts:"
ls -lh TechnicalPlatform-test.tar.gz
ls -lh *.deb

echo "✅ Build complete! Import with:"
echo "   wsl --import TechnicalPlatform-Test C:\\WSL\\TechnicalPlatform-Test TechnicalPlatform-test.tar.gz"
```

Run with:
```bash
chmod +x test-distribution.sh
./test-distribution.sh
```

---

## Questions to Verify

Before publishing, ask yourself:

1. ✅ Does the WSL distribution boot successfully?
2. ✅ Is systemd working properly?
3. ✅ Can users install all tp-* packages?
4. ✅ Do installed packages work correctly?
5. ✅ Are users added to necessary groups (docker)?
6. ✅ Is the Docker CE repository accessible?
7. ✅ Is the custom APT repository configured?
8. ✅ Are file sizes reasonable?
9. ✅ Does WSLg work for GUI applications?
10. ✅ Can users switch between different tool versions?

---

## Testing Published GitHub Releases

Once you've published a release via CI/CD, test the distribution as end-users would:

### Download and Install from GitHub Release

#### Method 1: Download Release Assets

```powershell
# In PowerShell on Windows:

# 1. Download the .wsl file from GitHub Releases
# Go to: https://github.com/YOUR_USERNAME/technical-platform/releases
# Download: TechnicalPlatform.wsl

# 2. Import the distribution
wsl --import TechnicalPlatform C:\WSL\TechnicalPlatform TechnicalPlatform.wsl

# 3. Launch the distribution
wsl -d TechnicalPlatform

# 4. Set default user
wsl -d TechnicalPlatform -u developer
```

#### Method 2: Using GitHub CLI

```powershell
# Install GitHub CLI (if not already installed)
winget install GitHub.cli

# Download latest release
gh release download --repo YOUR_USERNAME/technical-platform --pattern "TechnicalPlatform.wsl"

# Import to WSL
wsl --import TechnicalPlatform C:\WSL\TechnicalPlatform TechnicalPlatform.wsl

# Launch
wsl -d TechnicalPlatform
```

#### Method 3: Direct Download via curl/wget

```bash
# On Linux/WSL/macOS:

# Download latest release
REPO="YOUR_USERNAME/technical-platform"
curl -L -o TechnicalPlatform.wsl "https://github.com/$REPO/releases/latest/download/TechnicalPlatform.wsl"

# Import to WSL (from Windows PowerShell)
wsl --import TechnicalPlatform C:\WSL\TechnicalPlatform TechnicalPlatform.wsl
```

### Verify Release Checksums

```bash
# Download checksum file
curl -L -o TechnicalPlatform.wsl.sha256 "https://github.com/YOUR_USERNAME/technical-platform/releases/latest/download/TechnicalPlatform.wsl.sha256"

# Verify checksum (Linux/macOS/WSL)
sha256sum -c TechnicalPlatform.wsl.sha256

# Verify checksum (PowerShell)
$expected = (Get-Content TechnicalPlatform.wsl.sha256).Split(" ")[0]
$actual = (Get-FileHash TechnicalPlatform.wsl -Algorithm SHA256).Hash.ToLower()
if ($expected -eq $actual) { Write-Host "✅ Checksum verified!" } else { Write-Host "❌ Checksum mismatch!" }
```

---

## Testing the Published APT Repository

Once the workflow publishes to GitHub Pages, test the APT repository:

### Verify Repository Accessibility

```bash
# Launch your WSL distribution
wsl -d TechnicalPlatform

# Check repository configuration
cat /etc/apt/sources.list.d/technical-platform.list

# Update package lists
sudo apt-get update

# Search for tp-* packages
apt-cache search tp-

# List available tp-* packages
apt-cache pkgnames | grep ^tp-

# Show package information
apt-cache show tp-sdkman-java
apt-cache show tp-nvm-node
apt-cache show tp-docker
```

### Test Package Installation from Repository

```bash
# Install packages from published repository
sudo apt-get update
sudo apt-get install tp-sdkman-java

# Verify installation
source /etc/profile.d/sdkman.sh
java -version
sdk version

# Install additional packages
sudo apt-get install tp-nvm-node tp-docker

# Verify all packages
node --version
docker --version
```

### Check GitHub Pages Deployment

Visit your repository's GitHub Pages URL:
```
https://YOUR_USERNAME.github.io/technical-platform/
```

You should see:
- Repository index page
- `dists/` directory with Release files
- `pool/` directory with .deb packages

Manually verify package listings:
```bash
# Check repository structure
curl https://YOUR_USERNAME.github.io/technical-platform/dists/noble/main/binary-amd64/Packages

# Check if specific package is listed
curl https://YOUR_USERNAME.github.io/technical-platform/dists/noble/main/binary-amd64/Packages | grep "Package: tp-"
```

---

## End-to-End Release Testing

Complete workflow to test a published release:

### 1. Pre-Release Checklist

- [ ] GitHub Actions workflow completed successfully
- [ ] Release created with all assets
- [ ] GitHub Pages deployed
- [ ] All artifacts present (TechnicalPlatform.wsl, .tar.gz, checksums, INSTALL.txt)

### 2. Download and Install

```powershell
# Download from GitHub Release
gh release download --repo YOUR_USERNAME/technical-platform

# Verify checksum
Get-FileHash TechnicalPlatform.wsl -Algorithm SHA256

# Import to WSL
wsl --import TechnicalPlatform-Release-Test C:\WSL\TechnicalPlatform-Release-Test TechnicalPlatform.wsl

# Launch
wsl -d TechnicalPlatform-Release-Test
```

### 3. First Boot Verification

```bash
# Check system info
uname -a
lsb_release -a
systemctl status

# Check repository configuration
cat /etc/apt/sources.list.d/technical-platform.list
cat /etc/apt/sources.list.d/docker.list

# Update package lists
sudo apt-get update
```

### 4. Test Package Installation

```bash
# Install all tp-* packages
sudo apt-get install tp-sdkman-java tp-nvm-node tp-docker

# Wait for installations to complete
# Note: This may take 5-10 minutes for first-time downloads

# Test Java
source /etc/profile.d/sdkman.sh
java -version
javac -version

# Test Node
source /etc/profile.d/nvm.sh
node --version
npm --version
ng version

# Test Docker (may need to log out/in for group membership)
docker --version
docker compose version

# Log out and back in for docker group
exit
wsl -d TechnicalPlatform-Release-Test

# Run Docker test
docker run hello-world
```

### 5. Test Docker CE from Official Repo

```bash
# Docker should already be installed via tp-docker
# But verify the repository is working

sudo apt-get update
apt-cache policy docker-ce

# Should show the Docker CE repository URL
```

### 6. Stress Test

```bash
# Create a test project
mkdir -p ~/test-project
cd ~/test-project

# Test Java compilation
echo 'public class Hello { public static void main(String[] args) { System.out.println("Hello from Java 25!"); }}' > Hello.java
javac Hello.java
java Hello

# Test Node project
npm init -y
npm install express
echo 'console.log("Hello from Node 24!");' > index.js
node index.js

# Test Angular
ng new test-app --skip-git --skip-install
cd test-app
npm install
ng version

# Test Docker
docker run --rm node:24 node --version
docker run --rm eclipse-temurin:25 java -version
```

### 7. Performance Metrics

```bash
# Check disk usage
df -h

# Check installed package sizes
dpkg-query -W -f='${Installed-Size}\t${Package}\n' | grep tp-

# Check memory usage
free -h

# Check systemd services
systemctl list-units --type=service --state=running
```

---

## Testing Release Updates

When you publish a new version, test the upgrade process:

### Test Package Updates

```bash
# In an existing installation
sudo apt-get update

# Check for updates
apt list --upgradable | grep tp-

# Upgrade packages
sudo apt-get upgrade

# Verify new versions
dpkg -l | grep tp-
```

### Test Clean Installation vs Upgrade

```powershell
# Keep one distribution as "upgraded"
wsl -d TechnicalPlatform-Release-Test

# Import fresh distribution for comparison
wsl --import TechnicalPlatform-Release-Fresh C:\WSL\TechnicalPlatform-Release-Fresh TechnicalPlatform.wsl

# Compare behavior between upgraded and fresh installs
```

---

## Common Release Testing Issues

### Issue: APT Repository Returns 404

```bash
# Check GitHub Pages deployment
curl -I https://YOUR_USERNAME.github.io/technical-platform/

# Verify repository URL in WSL
cat /etc/apt/sources.list.d/technical-platform.list

# Check if repository structure is correct
curl https://YOUR_USERNAME.github.io/technical-platform/dists/noble/Release
```

**Solution:** Ensure GitHub Pages is enabled and deployed. Check Actions tab for deployment status.

### Issue: Package Installation Fails

```bash
# Check package availability
apt-cache show tp-sdkman-java

# Check dependencies
apt-cache depends tp-docker

# Force update
sudo apt-get update --allow-releaseinfo-change
```

**Solution:** Wait for GitHub Pages cache to update (can take 5-10 minutes).

### Issue: Checksum Verification Fails

```bash
# Re-download the file
rm TechnicalPlatform.wsl
curl -L -o TechnicalPlatform.wsl "https://github.com/YOUR_USERNAME/technical-platform/releases/latest/download/TechnicalPlatform.wsl"

# Verify again
sha256sum TechnicalPlatform.wsl
cat TechnicalPlatform.wsl.sha256
```

**Solution:** Ensure you downloaded both files from the same release.

---

## Automated Release Testing Script

Create `test-release.ps1` (PowerShell):

```powershell
# Test published GitHub release
param(
    [string]$Repo = "YOUR_USERNAME/technical-platform",
    [string]$DistroName = "TechnicalPlatform-Test"
)

Write-Host "🧪 Testing GitHub Release..." -ForegroundColor Cyan

# Download release
Write-Host "📥 Downloading latest release..." -ForegroundColor Yellow
gh release download --repo $Repo --pattern "TechnicalPlatform.wsl"
gh release download --repo $Repo --pattern "TechnicalPlatform.wsl.sha256"

# Verify checksum
Write-Host "🔐 Verifying checksum..." -ForegroundColor Yellow
$expected = (Get-Content TechnicalPlatform.wsl.sha256).Split(" ")[0]
$actual = (Get-FileHash TechnicalPlatform.wsl -Algorithm SHA256).Hash.ToLower()

if ($expected -eq $actual) {
    Write-Host "✅ Checksum verified!" -ForegroundColor Green
} else {
    Write-Host "❌ Checksum mismatch!" -ForegroundColor Red
    exit 1
}

# Import to WSL
Write-Host "📦 Importing to WSL..." -ForegroundColor Yellow
$installPath = "C:\WSL\$DistroName"
wsl --import $DistroName $installPath TechnicalPlatform.wsl

# Launch and test
Write-Host "🚀 Launching distribution..." -ForegroundColor Yellow
wsl -d $DistroName -u root -- apt-get update

Write-Host "📋 Installing test packages..." -ForegroundColor Yellow
wsl -d $DistroName -u root -- apt-get install -y tp-sdkman-java

Write-Host "✅ Release test complete!" -ForegroundColor Green
Write-Host "Launch with: wsl -d $DistroName" -ForegroundColor Cyan
```

Run with:
```powershell
.\test-release.ps1 -Repo "YOUR_USERNAME/technical-platform"
```

---

## Next Steps

### After Local Testing

1. ✅ Commit and push changes to trigger CI/CD
2. ✅ Monitor GitHub Actions workflow
3. ✅ Verify all jobs complete successfully
4. ✅ Check GitHub Pages deployment

### After Release Published

1. ✅ Download and verify checksums
2. ✅ Import to fresh WSL instance
3. ✅ Test APT repository access
4. ✅ Install and verify all tp-* packages
5. ✅ Run stress tests and performance checks
6. ✅ Document any issues or improvements
7. ✅ Share with team for broader testing

### Continuous Testing

- Test each new release before announcing
- Keep at least one "production" and one "test" WSL instance
- Document breaking changes in release notes
- Collect feedback from users
