#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0

# prune-gone-branches.sh - delete local branches whose upstream is gone.
#
# Runs `git fetch -p` first, then force-deletes every local branch whose
# remote-tracking branch no longer exists (merging a PR on GitHub deletes the
# branch there; this cleans up its local leftover). Never-pushed branches have
# no upstream, so they are left untouched.
#
# Gone branches that are checked out in a worktree are only reported, not
# deleted: the worktree may still hold uncommitted work, so removing it is left
# as a deliberate `git worktree remove` for the user (see worktrees/README.md).
set -euo pipefail

git fetch -p

# refname | upstream-track | worktreepath  (worktreepath empty unless checked out in a worktree)
mapfile -t gone < <(git for-each-ref --format '%(refname:short)|%(upstream:track)|%(worktreepath)' refs/heads \
                    | awk -F'|' '$2=="[gone]"{print $1"|"$3}')

deletable=()
for entry in "${gone[@]}"; do
    name=${entry%%|*}
    worktree=${entry#*|}
    if [ -n "$worktree" ]; then
        echo "skip (worktree): $name -> $worktree"
    else
        deletable+=("$name")
    fi
done

[ ${#deletable[@]} -eq 0 ] && { echo "Nothing to prune."; exit 0; }

git branch -D "${deletable[@]}"
