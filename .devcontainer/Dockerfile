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

# =============================================================================
# GitHub CLI (gh)
# =============================================================================
# From GitHub's own apt repository rather than Debian's: trixie ships gh 2.46
# (early 2024), while upstream is years ahead. gh is used alongside Claude Code
# for PR/issue workflows. Installed here rather than via the github-cli
# devcontainer feature, which would pull in the same stale-or-unpinned choice
# without the explicit version this gives. Authentication is interactive: run
# `gh auth login` once and the credentials persist in a named volume (see
# docker-compose.yml and README.md).
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/* \
    && gh --version

# Set locale (the `locales` package comes from the base apt block above)
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# =============================================================================
# User setup
# =============================================================================
ARG USERNAME=debian

# bash (not the default /bin/sh -> dash) as the login shell: the Claude Code installer and the pipx
# shims source shell snippets that rely on bash builtins, and it is what an interactive terminal
# expects anyway.
RUN useradd -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && usermod -a -G dialout,plugdev $USERNAME

# =============================================================================
# Flutter Stage
# =============================================================================
FROM base AS flutter

# WORKSPACE_DIR is NOT set here: it is injected via devcontainer.json containerEnv as
# ${containerWorkspaceFolder}, so it always tracks the single source of truth (workspaceFolder)
# instead of being a second copy that can drift.
# 3.44.6 matches actlibs/tool/.flutter_version, the pinned Flutter version of the ACT packages
# this app depends on.
ARG FLUTTER_VERSION=3.44.6

ENV FLUTTER_HOME=/home/${USERNAME}/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

# Switch to user for flutter installation (passwordless sudo was granted in the user setup stage)
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
# image verification below) never source. Bake the shim dir into PATH so `reuse` resolves everywhere.
# ~/.local/bin also holds the Claude Code launcher that postCreateCommand installs at container
# creation (see devcontainer.json), so this covers both.
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

# Pre-create the three directories that docker-compose.yml mounts named volumes on, so they are
# owned by the user: Docker initialises a fresh named volume from the image content at its mount
# point, and a mount point that does not exist in the image yields a root-owned volume the tool
# cannot write to. Baking the dirs in avoids any runtime chown. Keep all three paths in sync with the
# volume targets in docker-compose.yml.
# - ~/.claude: CLAUDE_CONFIG_DIR (devcontainer.json) points Claude's whole config — including
#   ~/.claude.json — in here, so a single browser login persists across rebuilds.
# - ~/.config/gh: gh writes its credentials to hosts.yml in here (GH_CONFIG_DIR, devcontainer.json),
#   so a single `gh auth login` persists across rebuilds.
# - ~/.pub-cache: downloaded pub packages survive across `docker compose run` invocations instead of
#   being re-fetched every time.
RUN mkdir -p /home/${USERNAME}/.claude /home/${USERNAME}/.config/gh /home/${USERNAME}/.pub-cache

# Claude Code is deliberately NOT installed here — it is installed by postCreateCommand (see
# devcontainer.json), which keeps its ~250MB of self-updating binaries out of the image layers.
# It lands in ~/.local/bin, which is already on PATH above.

# Set default shell
SHELL ["/bin/bash", "-c"]

# Verify installations
RUN echo "=== Development Environment ===" \
    && echo "Git: $(git --version)" \
    && echo "GitHub CLI: $(gh --version | head -1)" \
    && echo "Flutter: $(flutter --version | head -1)" \
    && echo "Dart: $(dart --version)" \
    && echo "Reuse: $(reuse --version)" \
    && echo "================================"

# Default command
CMD ["/bin/bash"]
