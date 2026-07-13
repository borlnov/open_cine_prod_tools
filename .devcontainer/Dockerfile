# SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# Open Cine Prod Tools Development Container
# =============================================================================
# Multi-stage build for Flutter Linux desktop development
# =============================================================================

FROM debian:trixie AS base

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install base dependencies
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    git \
    curl \
    wget \
    unzip \
    xz-utils \
    file \
    # Libraries for Flutter Linux desktop
    libsecret-1-dev \
    libgtk-3-dev \
    libblkid-dev \
    liblzma-dev \
    libglu1-mesa \
    lld \
    binutils \
    # Native SQLite library: `sqlite3_flutter_libs` bundles it into built app binaries, but
    # `flutter test` runs as a plain Dart VM process and needs it available on the system for
    # drift/sqlite3's dart:ffi bindings (package:sqlite3) to dlopen at test time.
    libsqlite3-0 \
    libsqlite3-dev \
    # Flutter's Linux desktop build needs clang
    clang \
    # Additional utilities
    rsync \
    sudo \
    locales \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Recent git from source (>= 2.48 for relative worktree support)
# =============================================================================
# The apt git on Debian trixie is 2.47.x, which predates the `relativeWorktrees`
# repository extension (git 2.48) that this repo relies on for `git worktree`
# with relative paths (worktree.useRelativePaths, see devcontainer.json). Build
# a newer git from the official release tarball into /usr/local, which precedes
# /usr/bin on PATH. This is done here rather than via the git devcontainer
# feature (whose from-source build proved unreliable across rebuilds).
ARG GIT_VERSION=2.51.0
RUN apt-get update && apt-get install -y --no-install-recommends \
    zlib1g-dev \
    libssl-dev \
    libexpat1-dev \
    libpcre2-dev \
    # git's HTTP(S) transport (http.o, remote-curl) needs the curl headers
    libcurl4-openssl-dev \
    gettext \
    && curl -fsSL "https://mirrors.edge.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.xz" \
       | tar -xJ -C /tmp \
    && make -C "/tmp/git-${GIT_VERSION}" prefix=/usr/local NO_TCLTK=1 USE_LIBPCRE=YesPlease -j"$(nproc)" all \
    && make -C "/tmp/git-${GIT_VERSION}" prefix=/usr/local NO_TCLTK=1 USE_LIBPCRE=YesPlease install \
    && rm -rf "/tmp/git-${GIT_VERSION}" /var/lib/apt/lists/* \
    && git --version

# Set locale
RUN apt-get update && apt-get install -y \
    locales \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# =============================================================================
# User setup
# =============================================================================
ARG USERNAME=debian

# Use bash as the login shell: the Node.js devcontainer feature runs its nvm setup as this user via
# `su`, which uses the login shell. The default (/bin/sh -> dash) lacks `source` and fails the build.
RUN useradd -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && usermod -a -G dialout,plugdev $USERNAME

# =============================================================================
# Flutter Stage
# =============================================================================
FROM base AS flutter

# WORKSPACE_DIR is NOT set here: it is injected via devcontainer.json containerEnv as
# ${containerWorkspaceFolder}, so it always tracks the single source of truth (workspaceFolder)
# instead of being a second copy that can drift.
# 3.41.9 matches actlibs/tool/.flutter_version, the pinned Flutter version of the ACT packages
# this app depends on.
ARG FLUTTER_VERSION=3.41.9

ENV FLUTTER_HOME=/home/${USERNAME}/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

# Allow user to run sudo without password
USER root
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# Switch to user for flutter installation
USER ${USERNAME}

# Download and install Flutter
RUN git clone https://github.com/flutter/flutter.git -b ${FLUTTER_VERSION} --depth 1 ${FLUTTER_HOME} \
    && flutter precache --linux \
    && flutter config --no-analytics \
    && flutter config --enable-linux-desktop \
    && dart --disable-analytics

# Switch back to root user
USER root

# =============================================================================
# Reuse installation
# =============================================================================
# Install pipx
RUN apt-get update && apt-get install -y \
    pipx \
    && rm -rf /var/lib/apt/lists/*

# Switch to user to install reuse in a user environment
USER ${USERNAME}
RUN pipx install reuse \
    && pipx ensurepath

# pipx ensurepath only edits ~/.bashrc, which non-login/non-interactive shells (docker exec, the
# image verification below) never source. Bake the pipx shim dir into PATH so `reuse` resolves
# everywhere.
ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

# Switch back to root user
USER root

# =============================================================================
# Dev container final setup
# =============================================================================

# Login shells (`bash -l`, su -) run Debian's /etc/profile, which RESETS PATH and clobbers the ENV
# set in this Dockerfile. Non-login shells (VS Code terminals, docker exec) inherit the ENV and are
# fine. Add a profile.d snippet so flutter/dart and the pipx shims resolve in login shells too.
# /etc/profile sources /etc/profile.d/*.sh after setting its own PATH, so this wins.
RUN printf 'export PATH="%s:%s:$PATH"\n' "/home/${USERNAME}/.local/bin" "${FLUTTER_HOME}/bin" \
    > /etc/profile.d/flutter-dev.sh

# Default to the user's home; the real workspace is provided by the docker-compose bind mount at
# runtime (and VS Code cd's into workspaceFolder anyway). No chown is needed: the bind mount keeps
# the host's ownership, and debian (UID 1000) matches the host user.
WORKDIR /home/${USERNAME}

# Pre-create the workspace parent so it is owned by the user, not root.
# In simple mode docker-compose bind-mounts only /workspaces/open_cine_prod_tools; Docker would
# otherwise auto-create the /workspaces parent as root, leaving the user unable to `git worktree add`
# sibling worktrees (/workspaces/<branch>). Baking the dir in with user ownership fixes that without
# a runtime chown. In worktree mode /workspaces is itself the bind mount, which harmlessly shadows
# this dir. Keep this path in sync with the mount target in docker-compose.yml / devcontainer.json.
RUN mkdir -p /workspaces && chown ${USERNAME}:${USERNAME} /workspaces

# Switch to user
USER ${USERNAME}

# Pre-create ~/.claude (owned by the user) so the isolated named volume mounted here
# (ocpt-claude-config, see docker-compose.yml) inherits user ownership when Docker first initialises
# it. Without this the fresh volume is root-owned and Claude can't write to it. Baking it in avoids
# any runtime chown. CLAUDE_CONFIG_DIR (devcontainer.json) points Claude's whole config — including
# ~/.claude.json — in here, so a single browser login persists across rebuilds.
RUN mkdir -p /home/${USERNAME}/.claude

# Pre-create ~/.pub-cache (owned by the user) for the same volume-ownership reason as ~/.claude
# above: a named volume (ocpt-pub-cache, see docker-compose.yml) is mounted here so downloaded pub
# packages survive across `docker compose run` invocations instead of being re-fetched every time.
RUN mkdir -p /home/${USERNAME}/.pub-cache

# Set default shell
SHELL ["/bin/bash", "-c"]

# Verify installations
RUN echo "=== Development Environment ===" \
    && echo "Git: $(git --version)" \
    && echo "Flutter: $(flutter --version | head -1)" \
    && echo "Dart: $(dart --version)" \
    && echo "Reuse: $(reuse --version)" \
    && echo "================================"

# Default command
CMD ["/bin/bash"]
