<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# The end-user guide for collaboration and sync

The one piece of the collaboration and sync feature still ahead: its **end-user guide** in
`docs-site/` (the Docusaurus filmmaker guide). The whole engine, the relay, the pairing/joining UI,
presence, the on-set server and in-app relay hosting have all shipped, and the **developer** record
for them is already folded into [`../architecture/sync.md`](../architecture/sync.md) and the
operator runbook [`../on-set-server.md`](../on-set-server.md). This plan covers only the
**user-facing** counterpart of that fold, written in the filmmaker's terms, not the engine's — the
reason it is a standalone plan rather than a phase inside a larger one: everything else in the
milestone is done and its plans are deleted.

**Read [`../architecture/sync.md`](../architecture/sync.md) and
[`../on-set-server.md`](../on-set-server.md) first** — they are the source material this guide
summarises for a non-technical reader. This file is deleted once the guide ships.

## Precondition

Runs **only after Benoit has exercised the whole collaboration feature (sharing, joining, offline
edits, presence, the mobile layouts, and hosting) in the real app and is happy with it** — the
guide describes what a user actually sees, so it is written against the settled UI, in one pass,
rather than piecemeal. Settle the section's own user-facing name with Benoit when writing it — he
referred to the whole feature as the **« mode contributeur »**.

## What to write

A new guide section under `docs-site/docs/`, covering the feature end to end in plain language:

- **Sharing a project** — the Partager screen: pairing to a relay, the invite QR and copy-link, and
  the "Héberger sur ce poste" panel for a laptop that is itself the relay (a plain-language pointer
  to the operator runbook for whoever runs it).
- **Joining a project** — the Rejoindre screen: a camera scan on a tablet or a pasted invite link on
  desktop.
- **What offline-first means in practice** — every device holds the whole project; edits queue and
  merge on reconnect; what the sync status indicator's states are telling you.
- **Presence** — who else has the project open, and in which mode.
- **Working on a tablet or phone** — the responsive layouts and the mobile share-sheet export.
- **The on-set server for a shoot** — pointing a device at the set relay by scanning its QR through
  "Changer de relais", with a plain-language pointer to [`../on-set-server.md`](../on-set-server.md)
  for whoever runs the laptop, and the firewall note in a reader's terms.

## Wiring, locales and assets

- **Both locales**: English under `docs-site/docs/`, French under
  `docs-site/i18n/fr/docusaurus-plugin-content-docs/current/`, mirroring the existing structure. The
  guide content is **`CC-BY-4.0`, not `Apache-2.0`** (see `docs-site/README.md`).
- **Navigation**: add the new pages to `docs-site/sidebars.ts`, and any new i18n JSON the
  navbar/category labels need.
- **Screenshots**: capture the Partager and Rejoindre screens, the sync status indicator, the
  presence cluster and the hosting panel through `tool/screenshot-app.sh` into
  `docs-site/static/img/screenshots/`, as the existing mode pages do.

## Verification

The Docusaurus build needs a Node toolchain the devcontainer does **not** carry
(`docs-site/README.md`), so this work's local gate is `dart run tool/check_markdown.dart` plus
`reuse lint`; the site build itself is verified by its own CI workflow, not locally.
