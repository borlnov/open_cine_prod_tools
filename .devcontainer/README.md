<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Devcontainer & Claude Code

The dev container builds from [`Dockerfile`](./Dockerfile): a recent git built from source, the
GitHub CLI (`gh`), the Flutter SDK (pinned to the version the ACT packages this app depends on
expect), the Linux desktop build toolchain (GTK3, clang, lld…), the native SQLite library
`flutter test` needs, and [reuse](https://reuse.software/) for license linting. The
[Claude Code](https://claude.com/claude-code) CLI is installed at container creation (see below).

There are **no devcontainer features**: every tool is installed directly in the image, which keeps
versions explicit and the build reproducible. In particular there is no Node.js runtime — nothing here
needs one.

It is **Docker Compose based** ([`docker-compose.yml`](./docker-compose.yml), service `dev`). The old
`runArgs` / `workspaceMount` / `build` keys are gone — Compose ignores them — so host networking, the
X11 socket, the workspace mount and the config volumes all live in the compose service now.
`devcontainer.json` just points at it. The clone is mounted at `/workspaces/open_cine_prod_tools`,
which is the single source of truth `workspaceFolder` owns and everything else derives from
(`WORKSPACE_DIR` via `${containerWorkspaceFolder}`); the mount target in `docker-compose.yml` is the
one copy that has to be kept in sync by hand, and the two files cross-reference each other.

## Git worktrees

Worktrees live in the gitignored [`worktrees/`](../worktrees/README.md) directory at the repository
root, so no extra mount or configuration is involved. Two things here exist for them:

- **A recent git.** `worktree.useRelativePaths` (set on the system config by `postCreateCommand`)
  makes a worktree's links relative, so they resolve both inside the container and on the host, whose
  clone path is different. It needs git >= 2.48 and Debian trixie ships 2.47, which is why the
  Dockerfile builds git from source into `/usr/local`.
- **Editor exclusions.** `worktrees/` is kept out of the file watcher, search and the Dart analyzer in
  [`open_cine_prod_tools.code-workspace`](../open_cine_prod_tools.code-workspace), since each worktree
  is a full copy of the repository.

The workflow itself, and the several ways it goes wrong, are documented in
[`../worktrees/README.md`](../worktrees/README.md) — **read that before creating your first
worktree**.

## Claude Code install & auth

Claude Code is installed by `postCreateCommand` with the official installer
(`curl -fsSL https://claude.ai/install.sh | bash -s latest`), which fetches a self-contained native
binary — no Node.js runtime is involved. It runs as the unprivileged container user because
everything lands under `$HOME`:

| Path | Contents |
| --- | --- |
| `~/.local/bin/claude` | launcher (put on `PATH` by the Dockerfile) |
| `~/.local/share/claude/` | versioned binaries, and the self-update target |
| `~/.claude/` | config, credentials, sessions — the named volume, see below |

Because the binary lives outside `~/.claude`, the volume mounted there does not shadow it, and Claude
owns its own install directory and can self-update normally.

It is installed at container creation rather than baked into the image on purpose. Each version is
around 250MB, and the CLI keeps self-updating to new ones; in the container's writable layer the CLI's
own cleanup can reclaim the old ones, whereas an image layer would pin the original copy forever. It
also means the install sees `CLAUDE_CONFIG_DIR` (a runtime-only setting), so its state file goes into
the config dir instead of beside it. The trade-off is that creating the container takes about half a
minute longer and needs network access; a failure there is reported by VS Code and leaves the rest of
the environment usable — rerun the command by hand to recover.

**Authentication is interactive — run `claude` once and sign in through the wizard.** There is no
token to mint or paste; everything else (Flutter, reuse) works regardless of whether you've signed
in.

The login persists, so **you only do this once**. `CLAUDE_CONFIG_DIR` (set in `devcontainer.json`)
points Claude's entire config — both the `~/.claude` data dir and `~/.claude.json`, which holds the
credentials, onboarding and trusted-folder state — at an **isolated named Docker volume**
(`ocpt-claude-config`, declared in [`docker-compose.yml`](./docker-compose.yml)). A named volume, not
a host bind mount: Claude's plugin index stores **absolute in-container paths**, so sharing the host
`~/.claude` would leak them across containers (a sibling devcontainer then breaks with `Source path
does not exist: /home/...`). The volume persists across rebuilds and **starts empty** — the image
pre-creates `~/.claude` so the fresh volume is owned by the container user, and on the first build you
sign in (and re-add any plugin marketplaces) once.

## GitHub CLI (gh) auth

`gh` comes from GitHub's own apt repository rather than Debian's, whose package trails upstream by
years. Like Claude Code, **it is signed into from inside the container — run `gh auth login` once**.
No token has to be minted, pasted or stored in a file: the browser flow prints a one-time code and a
URL you open on the host, so it works even though the container has no browser of its own.

The login persists, so **you only do this once**. `gh` writes its credentials to `hosts.yml` in the
directory `GH_CONFIG_DIR` points at (`devcontainer.json`), which is an isolated named Docker volume
(`ocpt-gh-config`, declared in [`docker-compose.yml`](./docker-compose.yml)) — the same arrangement as
Claude Code above, for the same reason: it survives rebuilds and is shared with nothing, so a
container never depends on how the host happens to store its own GitHub login.

Two answers to give the wizard:

- **Preferred protocol for git operations: SSH.** Git authenticates through the host `~/.ssh`, which
  is bind-mounted into the container.
- **"Authenticate Git with your GitHub credentials?": no.** For the same reason — and the credential
  helper it would install goes into `~/.gitconfig`, which is not persisted.

`gh` also reads a token from `GH_TOKEN` if one is exported, which is useful for headless or CI
invocations. Be aware that it takes precedence over the stored login and that `gh auth login` then
refuses to store credentials at all (`the value of the GH_TOKEN environment variable is being used
for authentication`), so keep it to the command or shell that needs it — the container deliberately
does not set it.

## Running the Flutter app's GUI

The container forwards the X11 socket and `DISPLAY` so `flutter run -d linux` can open a window on
the host's X server. This requires an X11 (or XWayland) display reachable from the container — no
extra setup is needed on a typical Linux desktop; on WSL, make sure an X server (e.g. WSLg, which
ships by default on recent Windows 11) is running.

## First run

1. Open the folder in VS Code and reopen in the container (or run
   `docker compose -f .devcontainer/docker-compose.yml up -d` manually).
2. Run `claude` once and sign in, and `gh auth login` once.
3. `postCreateCommand` already ran `flutter pub get` (and any other dependency install that applies
   at the repo's current state — see `devcontainer.json`); if you add a submodule or package later,
   rebuild or re-run the relevant command by hand.
4. `flutter run -d linux` to launch the app.
