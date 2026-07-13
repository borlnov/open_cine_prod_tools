<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Devcontainer & Claude Code

The dev container builds from [`Dockerfile`](./Dockerfile): a recent git, the Flutter SDK (pinned
to the version the ACT packages this app depends on expect), the Linux desktop build toolchain
(GTK3, clang, lld...), and [reuse](https://reuse.software/) for license linting. It additionally
ships the [Claude Code](https://claude.com/claude-code) CLI and the GitHub CLI (`gh`) via
devcontainer features so you can run them **inside** the container.

It is **Docker Compose based** ([`docker-compose.yml`](./docker-compose.yml), service `dev`). The
old `runArgs` / `workspaceMount` / `build` keys are gone — Compose ignores them — so host
networking, the X11 socket, the `GH_TOKEN` env var and the workspace mount all live in the compose
service now. `devcontainer.json` just points at it. The clone is always mounted at
`/workspaces/open_cine_prod_tools`, so the static `workspaceFolder` works whichever mount mode
(below) you pick.

## Git worktrees for parallel agents (optional)

By default the container runs in **simple mode**: just this clone is mounted at
`/workspaces/open_cine_prod_tools` and nothing else from the host is visible. You don't have to do
anything.

To run several agents on different branches in parallel, switch to **worktree mode**, which mounts
the *project root* one level above the clone so the clone and its sibling worktrees are all visible
inside the container.

1. **Lay out the project as `root/open_cine_prod_tools` on the host.** Keep an outer folder and move
   the clone into an `open_cine_prod_tools/` subfolder beside which worktrees will live:

   ```text
   ~/git/open-cine-prod-tools-project/    <- project root, mounted at /workspaces
     open_cine_prod_tools/                <- this clone; OPEN THIS in VS Code
                                              -> /workspaces/open_cine_prod_tools
     <some-branch>/                       <- worktrees added later -> /workspaces/<some-branch>
   ```

   The in-container path the clone maps to (`/workspaces/open_cine_prod_tools`) is owned by
   `workspaceFolder` in devcontainer.json; everything else derives from it (`WORKSPACE_DIR` via
   `${containerWorkspaceFolder}`), except the simple-mode default mount target in
   docker-compose.yml, which a mount target inherently has to match. To use a different name, change
   those two values (they cross-reference each other in comments) and rename this host subfolder to
   match.

   For an existing clone (close VS Code first, then from the parent dir):

   ```bash
   cd ~/git
   mv open_cine_prod_tools open_cine_prod_tools.tmp
   mkdir open-cine-prod-tools-project
   mv open_cine_prod_tools.tmp open-cine-prod-tools-project/open_cine_prod_tools
   ```

   Re-open the **`open_cine_prod_tools/`** folder in VS Code (not the root).

2. **Enable the mount.** Copy the template and uncomment both lines:

   ```bash
   cp .devcontainer/.env.example .devcontainer/.env
   # WORKSPACE_MOUNT_SOURCE=../..
   # WORKSPACE_MOUNT_TARGET=/workspaces
   ```

   `.devcontainer/.env` is gitignored (per-user). Rebuild the container.

3. **Create worktrees from inside the container**, as siblings of `open_cine_prod_tools`:

   ```bash
   git worktree add ../my-feature -b my-feature
   ```

   `worktree.useRelativePaths` is set globally in the container (postCreate), so worktree links use
   relative paths and resolve no matter where `/workspaces` is mounted. This needs git ≥ 2.48, which
   the container's from-source-built git provides.

## Claude Code install & auth

Claude Code is installed via the official devcontainer feature
(`ghcr.io/anthropics/devcontainer-features/claude-code`); the `node` feature is added alongside it
because the base image has no Node.js. The GitHub CLI (`gh`) is installed the same way
(`ghcr.io/devcontainers/features/github-cli`) for PR/issue workflows.

**Authentication is interactive — run `claude` once and sign in through the wizard.** There is no
token to mint or paste; everything else (Flutter, reuse) works regardless of whether you've signed
in.

The login persists, so **you only do this once**. `CLAUDE_CONFIG_DIR` (set in `devcontainer.json`)
points Claude's entire config — both the `~/.claude` data dir and `~/.claude.json`, which holds the
credentials, onboarding and trusted-folder state — at an **isolated named Docker volume**
(`ocpt-claude-config`, declared in [`docker-compose.yml`](./docker-compose.yml)). A named volume,
not a host bind mount: Claude's plugin index stores **absolute in-container paths**, so sharing the
host `~/.claude` would leak them across containers (a sibling devcontainer then breaks with
`Source path does not exist: /home/...`). The volume persists across rebuilds and **starts empty** —
the image pre-creates `~/.claude` so the fresh volume is owned by the container user, and on the first
build you sign in (and re-add any plugin marketplaces) once.

`DISABLE_AUTOUPDATER=1` is set so the feature-managed binary doesn't try to self-update.

### Other tool tokens (gh, …)

There's no Claude token to manage. For tools that authenticate from an env var — currently just `gh`
(`GH_TOKEN`) — put the value in the gitignored `.devcontainer/.env` (see
[`.env.example`](./.env.example)). Docker Compose auto-loads that file and `docker-compose.yml`
forwards `GH_TOKEN` into the container via its `environment:` block. The file is optional: without it,
`gh` just falls back to `gh auth login`.

## Running the Flutter app's GUI

The container forwards the X11 socket and `DISPLAY` so `flutter run -d linux` can open a window on
the host's X server. This requires an X11 (or XWayland) display reachable from the container — no
extra setup is needed on a typical Linux desktop; on WSL, make sure an X server (e.g. WSLg, which
ships by default on recent Windows 11) is running.

## First run

1. Open the folder in VS Code and reopen in the container (or run
   `docker compose -f .devcontainer/docker-compose.yml up -d` manually).
2. Run `claude` once and sign in.
3. `postCreateCommand` already ran `flutter pub get` (and any other dependency install that applies
   at the repo's current state — see `devcontainer.json`); if you add a submodule or package later,
   rebuild or re-run the relevant command by hand.
4. `flutter run -d linux` to launch the app.
