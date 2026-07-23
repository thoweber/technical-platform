# SPDX-License-Identifier: MIT
# Multi-stage Dockerfile for Technical Platform Ubuntu Distribution
# Base: Ubuntu Noble Minimal with systemd, SDKMAN, Node 24 LTS, and custom APT repository

FROM ubuntu:resolute AS base

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
# - tp-nvm-node: Installs NVM with Node 24 LTS
# - tp-angular-cli: Installs Angular CLI (@angular/cli) globally via npm
# - tp-docker: Installs Docker CE complete suite and adds user to docker group
# - tp-intellij-idea: Installs IntelliJ IDEA Ultimate via snap
# - tp-antigravity-cli: Installs Antigravity CLI binary (agy)
# - tp-intellij-agy-interop: Configures IntelliJ & Antigravity MCP integration
# Install with: apt-get install tp-sdkman-java tp-nvm-node tp-angular-cli tp-docker tp-intellij-idea tp-antigravity-cli tp-intellij-agy-interop

# Switch to user for configuration
USER $USERNAME
WORKDIR /home/$USERNAME

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
