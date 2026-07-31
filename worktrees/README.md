<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Git worktrees

This directory is where `git worktree` checkouts of this repository live, so that several branches
can be worked on in parallel without juggling one checkout. Everything here except this README is
gitignored, so the checkouts never show up as untracked content.

A worktree of this repository is **not** usable straight after `git worktree add`: the `actlibs/`
submodule is empty and every generated file is missing. The bring-up below is mandatory. Read the
whole page before creating your first one.

## Create

Always from **inside the dev container**, from the repository root:

```bash
git worktree add worktrees/my-feature -b my-feature
```

Two constraints, both of which silently produce a broken worktree if ignored:

- **Inside the container, not on the host.** The container's system git config sets
  `worktree.useRelativePaths` (see `postCreateCommand` in
  [`../.devcontainer/devcontainer.json`](../.devcontainer/devcontainer.json)), so the links between
  the worktree and the main clone are relative and resolve both at the container path
  (`/workspaces/open_cine_prod_tools`) and at the host's own clone path, which is different. This
  needs git >= 2.48; a host shipping an older git writes absolute paths that do not resolve in the
  container.
- **Under `worktrees/`, nowhere else.** Only the clone is bind-mounted into the container. A worktree
  created outside it (`../my-feature`, `/tmp/…`) exists solely in the container's writable layer and
  is lost when the container is rebuilt.

## Bring up

`git worktree add` checks out tracked files only. Everything gitignored — the submodule contents, the
generated code — is absent, so a fresh worktree fails to build and reports hundreds of spurious
analyzer errors. Run the per-checkout bring-up below. It is the same list as the container's
`postCreateCommand` plus the submodule update, which the container only ever ran for the main clone.

```bash
cd worktrees/my-feature
git submodule update --init --recursive   # actlibs
flutter pub get
(cd packages/fountain_kit && flutter pub get)
./actlibs/tool/pub_get_all.sh
dart run intl_utils:generate
dart run build_runner build
```

What each line is there for:

- `git submodule update --init --recursive` — `actlibs` is checked out as an empty directory. Git
  gives the worktree its own submodule clone under `.git/worktrees/<name>/modules/`, so this is per
  worktree, not shared with the main clone.
- `flutter pub get` (twice) — resolves the app's dependencies, then `packages/fountain_kit`'s.
- `pub_get_all.sh` — resolves the ACT Flutter packages the app depends on by path.
- `intl_utils:generate` — writes `lib/generated/l10n.dart` and the `intl/` messages, both gitignored.
- `build_runner build` — writes drift's `**/*.g.dart`, also gitignored. Without it and the step above,
  `flutter analyze` reports several hundred `uri_does_not_exist` and `undefined_identifier` errors
  that say nothing about your changes.

## Build

Nothing special: the commands in the [agent guidelines](../CLAUDE.md) work unchanged. Each worktree
gets its own `build/` and `.dart_tool/`, so none of them collide.

Budget the disk, though. A worktree that has been analyzed, tested and built for Linux debug runs
around 1.4 GB, over 90% of which is `build/` and `.dart_tool/`.

## Open in an editor

Open a worktree in its own VS Code window. `worktrees/` is excluded from the file watcher, search and
the Dart analyzer in
[`../open_cine_prod_tools.code-workspace`](../open_cine_prod_tools.code-workspace), so the main
window will not index them — each is a complete Flutter tree, and indexing them all multiplies the
workload.

## Remove

Remove a worktree with git rather than `rm -rf`, so its administrative entry under `.git/worktrees/`
goes too.

```bash
git worktree remove --force worktrees/my-feature
git branch -d my-feature
```

`--force` is not optional here: git refuses a plain `git worktree remove` on any worktree containing
an initialized submodule (`fatal: working trees containing submodules cannot be moved or removed`),
and this repository always has one once the bring-up has run. There is no way to satisfy the plain
form short of de-initializing the submodule first, so `--force` is the normal command here, not an
escape hatch — which does mean it also discards uncommitted work without asking. Check `git status`
in the worktree first.

The branch outlives the worktree; delete it separately once its work is merged or abandoned
(`tools/prune-gone-branches.sh` cleans up the ones whose PR has been merged and whose remote branch
is gone, and deliberately skips any branch still checked out in a worktree).

If a worktree directory was deleted by hand, `git worktree prune` drops the leftover administrative
entries.

## Claude Code

Claude Code's built-in worktree feature defaults to `.claude/worktrees/`, not here. That path is
gitignored so a stray checkout does no harm, but the convention for this repository is `worktrees/`
and the bring-up above still applies either way.
