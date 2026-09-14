#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0

# Cut a frozen snapshot of the user guide for a released version of the application.
#
# Docusaurus's own `docs:version` command only versions the default locale (en-GB); the French
# translation is left untouched and would silently fall back to English for the pinned version.
# This script runs the command and then mirrors the French content, so a cut is one reliable step
# that never forgets the second language.
#
# It must run on a machine that has Node and the site's npm dependencies installed (the developer's
# host or CI). The project's devcontainer carries no Node, so it cannot be run there.
#
# Usage, from anywhere in the repository:
#     docs-site/tool/cut-version.sh <X.Y.Z>
# where <X.Y.Z> is the application release tag being cut, without a leading "v".
#
# It does not commit or tag: review the snapshot, then commit it as part of the release.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $(basename "$0") <X.Y.Z>" >&2
  exit 2
fi

version="$1"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: '$version' is not a X.Y.Z version number (no leading 'v')." >&2
  exit 2
fi

# Resolve the site directory from this script's own location, so the command works from any cwd.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
site_dir="$(cd "$script_dir/.." && pwd)"
cd "$site_dir"

fr_current="i18n/fr/docusaurus-plugin-content-docs/current"
fr_versioned="i18n/fr/docusaurus-plugin-content-docs/version-$version"

# Refuse to run over a dirty site tree: the cut must be a clean, reviewable diff on its own.
if [[ -n "$(git status --porcelain -- "$site_dir")" ]]; then
  echo "error: the docs-site working tree is dirty; commit or stash first." >&2
  exit 1
fi

# Refuse to overwrite a version that already exists.
if [[ -d "versioned_docs/version-$version" || -d "$fr_versioned" ]]; then
  echo "error: version $version already has a snapshot; nothing to do." >&2
  exit 1
fi

echo "Cutting guide version $version ..."

# 1. The default-locale snapshot, sidebar and versions.json.
npm run docusaurus docs:version "$version"

# 2. The French mirror the command does not create.
cp -R "$fr_current" "$fr_versioned"

echo
echo "Created:"
echo "  versioned_docs/version-$version/"
echo "  versioned_sidebars/version-$version-sidebars.json"
echo "  $fr_versioned/"
echo "  versions.json (updated)"
echo
echo "Next:"
echo "  - run 'reuse lint' from the repository root (new JSON is covered by REUSE.toml globs);"
echo "  - review the snapshot, then commit it as part of the release."
