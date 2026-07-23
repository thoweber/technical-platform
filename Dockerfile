# SPDX-License-Identifier: MIT
# Multi-stage Dockerfile for Technical Platform Ubuntu Distribution
# Base: Ubuntu Noble Minimal with systemd, SDKMAN, Node 24 LTS, and custom APT repository

FROM ubuntu:noble AS base

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Use Azure Ubuntu mirror for both archive and security packages for fast downloads on GitHub Actions runners & configure APT retries
RUN sed -i -E 's/(archive|security)\.ubuntu\.com/azure.archive.ubuntu.com/g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || \
    sed -i -E 's/(archive|security)\.ubuntu\.com/azure.archive.ubuntu.com/g' /etc/apt/sources.list 2>/dev/null || true \
    && mkdir -p /etc/apt/apt.conf.d/ \
    && echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80retry \
    && echo 'Acquire::http::Timeout "30";' >> /etc/apt/apt.conf.d/80retry \
    && echo 'Acquire::ftp::Timeout "30";' >> /etc/apt/apt.conf.d/80retry

# Set up debconf non-interactive defaults and basic utilities in a single layer
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && echo 'DEBIAN_FRONTEND=noninteractive' >> /etc/environment \
    && apt-get update && apt-get install -y --no-install-recommends \
    apt-utils \
    dialog \
    systemd \
    systemd-sysv \
    dbus \
    ca-certificates \
    curl \
    wget \
    git \
    gnupg \
    unzip \
    zip \
    sudo \
    build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure WSL2 settings with systemd enabled as init system
RUN cat > /etc/wsl.conf <<'EOF'
[boot]
systemd=true

[user]
default=developer

[interop]
enabled=true
appendWindowsPath=false
EOF

# Create default user
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000

RUN (groupadd --gid $USER_GID $USERNAME 2>/dev/null || groupmod -n $USERNAME $(getent group $USER_GID | cut -d: -f1)) \
    && (useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash 2>/dev/null || usermod -l $USERNAME -d /home/$USERNAME -m $(getent passwd $USER_UID | cut -d: -f1)) \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Stage 2: Install development tools and configure custom APT repository
FROM base AS development

# Install Snap, WSLg support, X11/AWT GUI libraries, fontconfig, and Noto Sans & Color Emoji fonts
RUN apt-get update && apt-get install -y --no-install-recommends \
    snapd \
    x11-apps \
    mesa-utils \
    libgl1-mesa-dri \
    libglx-mesa0 \
    libgl1 \
    libxtst6 \
    libxrender1 \
    libxi6 \
    libxrandr2 \
    libxcursor1 \
    libxinerama1 \
    fontconfig \
    fonts-noto-core \
    fonts-noto-ui-core \
    fonts-noto-color-emoji \
    fonts-liberation \
    && printf '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n<fontconfig>\n  <alias>\n    <family>sans-serif</family>\n    <prefer>\n      <family>Noto Sans</family>\n      <family>Noto Color Emoji</family>\n    </prefer>\n  </alias>\n  <alias>\n    <family>serif</family>\n    <prefer>\n      <family>Noto Serif</family>\n      <family>Noto Color Emoji</family>\n    </prefer>\n  </alias>\n</fontconfig>\n' > /etc/fonts/local.conf \
    && fc-cache -f 2>/dev/null || true \
    && systemctl enable snapd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add Docker CE official repository
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL --connect-timeout 10 --max-time 30 https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update

# Set up custom APT repository configuration
ARG APT_REPO_URL="https://thoweber.github.io/technical-platform"
RUN echo "deb [trusted=yes] ${APT_REPO_URL} noble main" > /etc/apt/sources.list.d/technical-platform.list

# Note: Development tools are available as optional tp-* packages:
# - tp-sdkman-java: Installs SDKMAN with Java 25
# - tp-nvm-node: Installs NVM with Node 24 LTS and Angular CLI
# - tp-docker: Installs Docker CE complete suite and adds user to docker group
# - tp-intellij-idea: Installs IntelliJ IDEA Ultimate via snap
# Install with: apt-get install tp-sdkman-java tp-nvm-node tp-docker tp-intellij-idea

# Switch to user for configuration
USER $USERNAME
WORKDIR /home/$USERNAME

# Install Antigravity binary
RUN mkdir -p ~/.local/bin \
    && echo 'export PATH="/home/$USERNAME/.local/bin:$PATH"' >> ~/.bashrc \
    && (curl -fsSL --connect-timeout 10 --max-time 30 https://antigravity.google/cli/install.sh | bash || echo "Antigravity binary not available") \
    && (chmod +x ~/.local/bin/agy 2>/dev/null || true)

# Configure shell environment
RUN cat >> ~/.bashrc <<'EOF'

# Auto-configure IntelliJ MCP server port to 64343 & Noto Color Emoji fallback font
if [ -n "$HOME" ] && [ -d "$HOME" ]; then
    # Fix broken snap directory if 'current' was created as a regular directory instead of a symlink
    if [ -d "$HOME/snap/intellij-idea-ultimate/current" ] && [ ! -L "$HOME/snap/intellij-idea-ultimate/current" ]; then
        rm -rf "$HOME/snap/intellij-idea-ultimate/current" 2>/dev/null || true
    fi

    JB_BASE_DIRS=("$HOME/.config/JetBrains")
    
    if [ -d "$HOME/snap/intellij-idea-ultimate/common/.config/JetBrains" ]; then
        JB_BASE_DIRS+=("$HOME/snap/intellij-idea-ultimate/common/.config/JetBrains")
    fi

    for jb_base in "${JB_BASE_DIRS[@]}"; do
        mkdir -p "$jb_base"
        
        shopt -s nullglob
        IDEA_DIRS=("$jb_base"/IntelliJIdea* "$jb_base"/IdeaIC*)
        shopt -u nullglob

        if [ ${#IDEA_DIRS[@]} -eq 0 ]; then
            IDEA_DIRS=(
                "$jb_base/IntelliJIdea2024.1"
                "$jb_base/IntelliJIdea2024.2"
                "$jb_base/IntelliJIdea2024.3"
                "$jb_base/IntelliJIdea2025.1"
            )
        fi

        for idea_dir in "${IDEA_DIRS[@]}"; do
            opts_dir="$idea_dir/options"
            mkdir -p "$opts_dir"

            # MCP Server port 64343 (mcpServer.xml & mcp.xml)
            for mcp_file in "$opts_dir/mcpServer.xml" "$opts_dir/mcp.xml"; do
                if [ ! -f "$mcp_file" ]; then
                    cat > "$mcp_file" << 'XML_EOF'
<application>
  <component name="McpServerOptions">
    <option name="port" value="64343" />
  </component>
  <component name="McpServerService">
    <option name="port" value="64343" />
  </component>
</application>
XML_EOF
                else
                    if grep -q 'name="port"' "$mcp_file"; then
                        sed -i -E 's/name="port" value="[0-9]+"/name="port" value="64343"/g' "$mcp_file" 2>/dev/null || true
                    elif grep -q '64342' "$mcp_file"; then
                        sed -i 's/64342/64343/g' "$mcp_file" 2>/dev/null || true
                    fi
                fi
            done

            # Noto Color Emoji fallback font (editor-font.xml & editor.font.xml)
            for font_file in "$opts_dir/editor-font.xml" "$opts_dir/editor.font.xml"; do
                if [ ! -f "$font_file" ]; then
                    cat > "$font_file" << 'FONT_XML_EOF'
<application>
  <component name="EditorFont">
    <option name="USE_SECONDARY_FONT_FAMILY" value="true" />
    <option name="SECONDARY_FONT_FAMILY" value="Noto Color Emoji" />
  </component>
</application>
FONT_XML_EOF
                else
                    if ! grep -q 'SECONDARY_FONT_FAMILY' "$font_file"; then
                        sed -i '/<component name="EditorFont">/a \    <option name="USE_SECONDARY_FONT_FAMILY" value="true" />\n    <option name="SECONDARY_FONT_FAMILY" value="Noto Color Emoji" />' "$font_file" 2>/dev/null || true
                    fi
                fi
            done
        done
    done
fi

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"
EOF

# Final stage: Export-ready rootfs
FROM development AS export

# Switch to root and set systemd as init system
USER root
WORKDIR /root

# Restore standard official Ubuntu sources, remove build configs, and perform final cleanup in a single layer
RUN printf 'Types: deb\nURIs: http://archive.ubuntu.com/ubuntu/\nSuites: noble noble-updates noble-backports\nComponents: main restricted universe multiverse\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n\nTypes: deb\nURIs: http://security.ubuntu.com/ubuntu/\nSuites: noble-security\nComponents: main restricted universe multiverse\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n' > /etc/apt/sources.list.d/ubuntu.sources \
    && rm -f /etc/apt/apt.conf.d/80retry \
    && apt-get autoremove -y \
    && apt-get autoclean -y \
    && rm -rf /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    /usr/share/doc/* \
    /usr/share/man/* \
    /var/cache/debconf/*

CMD ["/lib/systemd/systemd"]
