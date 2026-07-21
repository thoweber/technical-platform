# Multi-stage Dockerfile for Technical Platform Ubuntu Distribution
# Base: Ubuntu Noble Minimal with systemd, SDKMAN, Node 24 LTS, and custom APT repository

FROM ubuntu:noble AS base

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Set up systemd and basic utilities in a single layer
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
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

# Configure systemd for WSL2
RUN cd /lib/systemd/system/sysinit.target.wants/ && \
    ls | grep -v systemd-tmpfiles-setup | xargs rm -f $1 && \
    rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/basic.target.wants/* \
    /lib/systemd/system/anaconda.target.wants/* \
    /lib/systemd/system/plymouth* \
    /lib/systemd/system/systemd-update-utmp*

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

# Install Snap and WSLg support packages in one layer
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    snapd \
    x11-apps \
    mesa-utils \
    libgl1-mesa-dri \
    libglx-mesa0 \
    libgl1 \
    && systemctl enable snapd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add Docker CE official repository
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
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
# Install with: apt-get install tp-sdkman-java tp-nvm-node tp-docker

# Switch to user for configuration
USER $USERNAME
WORKDIR /home/$USERNAME

# Install Antigravity binary
RUN mkdir -p ~/.local/bin \
    && curl -fsSL -o ~/.local/bin/antigravity https://github.com/example/antigravity/releases/latest/download/antigravity-linux-amd64 \
    && chmod +x ~/.local/bin/antigravity || echo "Antigravity binary not available"

# Configure shell environment
RUN cat >> ~/.bashrc <<'EOF'

# Auto-configure IntelliJ MCP server port to 64343
MCP_CONFIG="$HOME/.config/JetBrains/IntelliJIdea*/options/mcpServer.xml"
if [ -f "$MCP_CONFIG" ]; then
    sed -i "s/64342/64343/g" "$MCP_CONFIG" 2>/dev/null || true
fi

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"
EOF

# Final stage: Export-ready rootfs
FROM development AS export

# Switch to root and set systemd as init system
USER root
WORKDIR /root

# Final cleanup to minimize image size
RUN apt-get autoremove -y \
    && apt-get autoclean -y \
    && rm -rf /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    /usr/share/doc/* \
    /usr/share/man/* \
    /var/cache/debconf/*

CMD ["/lib/systemd/systemd"]
