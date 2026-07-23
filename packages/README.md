# Technical Platform (tp-*) Packages

This directory contains custom Debian packages for the Technical Platform WSL distribution.

## Package Naming Convention

All packages use the **`tp-`** prefix (Technical Platform) to identify them as part of this distribution.

**Format:** `tp-<component>-<description>`

---

## Available Packages

### tp-sdkman-java
**SDKMAN with Java 25 (Eclipse Temurin)**

Installs SDKMAN and Java 25 system-wide for all users.

**Installation:**
```bash
sudo apt-get update
sudo apt-get install tp-sdkman-java
```

**Usage:**
```bash
# Java is automatically available after installation
java -version

# Use SDKMAN to manage Java versions
sdk list java
sdk install java 17.0.9-tem
sdk use java 17.0.9-tem
```

**Location:** `/opt/sdkman`

---

### tp-nvm-node
**NVM with Node.js 24 LTS and Angular CLI**

Installs NVM, Node.js 24 LTS, and Angular CLI system-wide for all users.

**Installation:**
```bash
sudo apt-get update
sudo apt-get install tp-nvm-node
```

**Usage:**
```bash
# Node and npm are automatically available
node --version
npm --version

# Angular CLI is pre-installed
ng version

# Use NVM to manage Node versions
nvm list
nvm install 20
nvm use 20
```

**Location:** `/opt/nvm`

---

### tp-docker
**Docker CE Complete Installation**

Installs the complete Docker CE suite including Docker Engine, CLI, containerd, Buildx, and Compose plugins. Automatically adds the current user to the docker group.

**Installation:**
```bash
sudo apt-get update
sudo apt-get install tp-docker
```

**Usage:**
```bash
# Docker is automatically available (may need to log out/in for group membership)
docker --version
docker compose version
docker buildx version

# Test Docker installation
docker run hello-world

# Run containers without sudo
docker ps
docker run -d nginx
```

**Includes:**
- Docker CE Engine
- Docker CLI
- containerd runtime
- Docker Buildx plugin
- Docker Compose plugin

**Note:** You may need to log out and log back in for docker group membership to take effect.

---

### tp-intellij-idea
**IntelliJ IDEA Ultimate via Snap**

Installs IntelliJ IDEA Ultimate via snapd and configures the MCP server port to 64343.

**Installation:**
```bash
sudo apt-get update
sudo apt-get install tp-intellij-idea
```

**Usage:**
```bash
intellij-idea-ultimate &
```

---

### tp-antigravity-cli
**Antigravity CLI Binary**

Installs the Antigravity CLI binary (`agy`) system-wide in `/opt/antigravity` and configures environment PATH.

**Installation:**
```bash
sudo apt-get update
sudo apt-get install tp-antigravity-cli
```

**Usage:**
```bash
agy --version
```

---

### tp-intellij-agy-interop
**IntelliJ IDEA & Antigravity-CLI MCP Interoperability**

Configures Model Context Protocol (MCP) server integration between IntelliJ IDEA and Antigravity CLI. Adds `wsl-isolated-mcp` to `~/.config/antigravity/config.json` and pre-configures IntelliJ IDEA's `mcpServer.xml`.

**Installation:**
```bash
sudo apt-get update
sudo apt-get install tp-intellij-agy-interop
```

---

## Installing Complete Development Environment

To install everything (Java, Node, Docker, IntelliJ IDEA, Antigravity CLI, and MCP Interop):

```bash
sudo apt-get update
sudo apt-get install tp-sdkman-java tp-nvm-node tp-docker tp-intellij-idea tp-antigravity-cli tp-intellij-agy-interop
```

After installation, restart your shell or run:
```bash
source /etc/profile
```

---

## Package Development

### Building Packages Manually

```bash
# Build a single package
dpkg-deb --build packages/tp-sdkman-java ./tp-sdkman-java.deb

# Install locally
sudo dpkg -i tp-sdkman-java.deb
```

### Testing Packages

After building, test the package:

```bash
# Install
sudo dpkg -i ./tp-sdkman-java.deb

# Verify installation
dpkg -l | grep tp-sdkman-java

# Test functionality
source /etc/profile.d/sdkman.sh
sdk version
java -version

# Remove
sudo apt-get remove tp-sdkman-java
```

---

## Package Structure

Each package follows standard Debian packaging conventions with the `tp-` prefix:

```
tp-package-name/
├── DEBIAN/
│   ├── control       # Package metadata
│   └── postinst      # Post-installation script
└── etc/
    └── profile.d/
        └── script.sh # Environment configuration
```

### Key Files

- **control**: Defines package metadata (name, version, dependencies, description)
- **postinst**: Executed after package installation (must be executable)
- **/etc/profile.d/**: Shell scripts sourced on login for all users

---

## Notes

- Both packages install to `/opt/` for system-wide availability
- Environment variables are configured via `/etc/profile.d/` scripts
- Packages are automatically built by CI/CD when changes are pushed
- Published to the APT repository at GitHub Pages
