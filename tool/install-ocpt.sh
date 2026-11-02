#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0

# install-ocpt.sh - download & install the Debian package built by CI.
#
# The Build workflow (.github/workflows/build.yml) uploads one .deb artifact per
# run, named OpenCineProdTools_<version>_amd64.deb, so a run can be installed
# without building anything locally.
#
# Usage:
#   tool/install-ocpt.sh <run-id>     # a Build workflow run ID
#   tool/install-ocpt.sh pr <number>  # latest Build run for that PR
#
# Requires: gh (authenticated), apt/sudo.
set -euo pipefail

REPO="borlnov/open_cine_prod_tools"
readonly REPO

if [[ "${1:-}" == "pr" ]]; then
    [[ -n "${2:-}" ]] || { echo "Usage: ${0} pr <number>" >&2; exit 1; }
    BRANCH=$(gh pr view "${2}" --repo "${REPO}" --json headRefName -q .headRefName)
    RUN_ID=$(gh run list --repo "${REPO}" --workflow build.yml \
        --branch "${BRANCH}" --limit 1 --json databaseId -q '.[0].databaseId')
    [[ -n "${RUN_ID}" ]] || {
        echo "No Build run found for PR #${2} (branch '${BRANCH}')" >&2
        exit 1
    }
    echo "PR #${2} -> branch '${BRANCH}' -> run ${RUN_ID}"
else
    [[ -n "${1:-}" ]] || { echo "Usage: ${0} <run-id> | ${0} pr <number>" >&2; exit 1; }
    RUN_ID="${1}"
fi
readonly RUN_ID

TMP_DIR=$(mktemp -d)
readonly TMP_DIR
trap 'rm -rf "${TMP_DIR}"' EXIT

# The artifact name ends in ".deb", so it unzips into a directory of that name
# containing the actual .deb file - hence the `find` below.
gh run download "${RUN_ID}" --repo "${REPO}" --pattern '*amd64.deb' -D "${TMP_DIR}"

mapfile -t debs < <(find "${TMP_DIR}" -type f -name '*.deb')
[[ ${#debs[@]} -gt 0 ]] || {
    echo "No .deb artifact on run ${RUN_ID} (expired after 10 days, or a docs-only run?)" >&2
    exit 1
}

printf 'Installing:\n'; printf '  %s\n' "${debs[@]}"
sudo apt-get update -y
# `apt install ./file.deb` (not `dpkg -i`) so runtime deps resolve automatically.
sudo apt install -y "${debs[@]}"
