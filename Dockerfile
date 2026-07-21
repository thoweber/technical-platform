# Multi-stage Dockerfile for Custom WSL Ubuntu Distribution
# Base: Ubuntu Noble with systemd, SDKMAN, Node 20, and custom APT repository

FROM ubuntu:noble AS base

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set up systemd and basic utilities
RUN apt-get update && apt-get install -y \
    systemd \
    systemd-sysv \
    dbus \
    apt-transport-https \
    ca-certificates \
    curl \
    wget \
    git \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    zip \
    build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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

RUN apt-get update && apt-get install -y sudo && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && (groupadd --gid $USER_GID $USERNAME 2>/dev/null || groupmod -n $USERNAME $(getent group $USER_GID | cut -d: -f1)) \
    && (useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash 2>/dev/null || usermod -l $USERNAME -d /home/$USERNAME -m $(getent passwd $USER_UID | cut -d: -f1)) \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Stage 2: Install development tools and configure custom APT repository
FROM base AS development

# Install Snap (for IntelliJ IDEA Ultimate)
RUN apt-get update && apt-get install -y snapd \
    && systemctl enable snapd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set up custom APT repository configuration
# This will be replaced with actual repository URL during CI/CD
ARG APT_REPO_URL="https://thoweber.github.io/technical-platform"
RUN echo "deb [trusted=yes] ${APT_REPO_URL} noble main" > /etc/apt/sources.list.d/custom-wsl.list

# Install custom packages from APT repository
# Note: Local packages can be added during workflow by downloading built artifacts
RUN apt-get update || true && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Switch to user for SDKMAN and Node installation
USER $USERNAME
WORKDIR /home/$USERNAME

# Install SDKMAN
RUN curl -s "https://get.sdkman.io" | bash \
    && bash -c "source $HOME/.sdkman/bin/sdkman-init.sh && sdk install java 21.0.5-tem && sdk default java 21.0.5-tem"

# Install Node 24 LTS via NVM
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && bash -c "source $HOME/.nvm/nvm.sh && nvm install 24 && nvm use 24 && nvm alias default 24"

# Install Angular CLI
RUN bash -c "source $HOME/.nvm/nvm.sh && npm install -g @angular/cli"

# Install Antigravity binary
RUN mkdir -p ~/.local/bin && \
    curl -L -o ~/.local/bin/antigravity https://github.com/example/antigravity/releases/latest/download/antigravity-linux-amd64 && \
    chmod +x ~/.local/bin/antigravity

# Configure MCP server port override in .bashrc
RUN echo '' >> ~/.bashrc && \
    echo '# Auto-configure IntelliJ MCP server port to 64343' >> ~/.bashrc && \
    echo 'MCP_CONFIG="$HOME/.config/JetBrains/IntelliJIdea*/options/mcpServer.xml"' >> ~/.bashrc && \
    echo 'if [ -f "$MCP_CONFIG" ]; then' >> ~/.bashrc && \
    echo '    sed -i "s/64342/64343/g" "$MCP_CONFIG" 2>/dev/null || true' >> ~/.bashrc && \
    echo 'fi' >> ~/.bashrc && \
    echo '' >> ~/.bashrc && \
    echo '# Add local bin to PATH' >> ~/.bashrc && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Switch back to root for final configuration
USER root

# Enable WSLg GUI support
RUN apt-get update && apt-get install -y \
    x11-apps \
    mesa-utils \
    libgl1-mesa-dri \
    libglx-mesa0 \
    libgl1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set default user
USER $USERNAME
WORKDIR /home/$USERNAME

# Final stage: Export-ready rootfs
FROM development AS export

USER root

# Set systemd as init system
CMD ["/lib/systemd/systemd"]
