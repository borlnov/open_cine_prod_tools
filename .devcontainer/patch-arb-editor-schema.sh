#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#
# Work around a bug in the bundled JSON schema of the google.arb-editor VS Code extension.
#
# The schema declares three patternProperties for an ARB file:
#   - "^@(?!@).+$"  -> metadata objects (e.g. "@myKey": { ... })
#   - "^@@x-.+$"    -> custom global attributes
#   - "^(?!@@).+$"  -> message ids, whose value must be a string
#
# In JSON Schema every matching patternProperties subschema applies. The message-id pattern only
# excludes keys starting with "@@", so a single-"@" metadata key (e.g. "@myKey") ALSO matches it and
# is therefore validated as a string. Its value is an object, so the editor flags every metadata
# block with: Incorrect type. Expected "string". Both lib/l10n/intl_en_GB.arb and lib/l10n/intl_fr.arb
# carry one metadata block per message, so this is every one of them.
#
# The message-id pattern should exclude anything starting with "@", not only "@@". This script
# rewrites "^(?!@@).+$" to "^(?!@).+$" in place. The bug is present in every published version of the
# extension (schema unchanged upstream since 2022), so there is no version to upgrade to; the
# extension is also reinstalled on every dev container rebuild, which is why this runs from a
# container hook rather than being applied by hand.
#
# The replacement is idempotent: once patched the source pattern no longer exists, so re-running is a
# no-op. Safe to run whether or not the extension is installed.

set -euo pipefail
shopt -s nullglob

# The source pattern used only for the grep guard below.
old='"^(?!@@).+$"'

patched=0
for schema in "$HOME"/.vscode-server*/extensions/google.arb-editor-*/schemas/arb.json; do
  if grep -qF "$old" "$schema"; then
    # q{} keeps the strings literal: Perl does not interpolate the special "$"" variable inside them.
    # \Q..\E then quotemeta-escapes the regex characters so the match is treated as a plain string.
    perl -i -pe 'BEGIN { $o = q{"^(?!@@).+$"}; $n = q{"^(?!@).+$"} } s/\Q$o\E/$n/g' "$schema"
    echo "patched arb-editor schema: $schema"
    patched=1
  fi
done

if [ "$patched" -eq 0 ]; then
  echo "arb-editor schema: nothing to patch (already fixed or extension not installed)"
fi
