<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Open Cine Prod Tools — user guide site

This folder holds the **multilingual end-user guide** for Open Cine Prod Tools, built with
[Docusaurus](https://docusaurus.io/) and published to GitHub Pages at
<https://borlnov.github.io/open_cine_prod_tools/>.

It is user-facing documentation for filmmakers, distinct from the developer docs under
`docs/architecture/` and `docs/adr/`. The guide content is licensed `CC-BY-4.0`; the site's
configuration and styling are `Apache-2.0`, like the rest of the repository.

## Languages

The guide ships in the two languages the application's UI speaks:

- **English (`en-GB`)** is the default locale; its content lives in `docs/`.
- **French (`fr`)** lives under `i18n/fr/`.

The navbar's locale dropdown switches between them.

## Working on the site locally

The site needs a Node toolchain (Node 18+), which the project's devcontainer does not carry. On a
machine that has one:

```bash
cd docs-site
npm install
npm run start        # dev server with hot reload, on the default (English) locale
npm run start -- --locale fr
npm run build        # what the deploy workflow runs; output in build/
```

## Versioning: tying the guide to an application release

The guide is versioned with Docusaurus so a reader on an older application can find the guide that
matches it, and so the current version number is visible in the navbar's version dropdown.

- The live content in `docs/` (and its French mirror under
  `i18n/fr/docusaurus-plugin-content-docs/current/`) is the **unreleased "Next" version**, served
  under `/next`.
- Each application release freezes a snapshot: the English pages go to
  `versioned_docs/version-<X.Y.Z>/`, the sidebar to `versioned_sidebars/`, the French pages to
  `i18n/fr/docusaurus-plugin-content-docs/version-<X.Y.Z>/`, and the number is appended to
  `versions.json`. The **newest** frozen version is served at the site root, so the dropdown's
  default label is the current version number.
- Frozen versions are **not edited** to fix later issues — an old version documents the app as it
  was. Fixes land in `docs/`, which becomes the next snapshot.

### Cutting a version

Cut a version **on the application release commit**, so the guide number equals the release tag.
Docusaurus's own `docs:version` command only freezes the default locale (English); the French
content must be mirrored too, or French readers of the pinned version silently fall back to English.
The script does both, and refuses to run over a dirty tree or an existing version:

```bash
docs-site/tool/cut-version.sh <X.Y.Z>   # on a machine with Node; the devcontainer has none
```

Then run `reuse lint` from the repository root (the generated JSON is covered by `REUSE.toml`
globs) and commit the snapshot as part of the release. This is wired into the project's release
procedure, [`../docs/RELEASING.md`](../docs/RELEASING.md).

The frozen versions are `0.2.0`, `0.2.1`, `0.2.2` and `0.2.3`; `0.2.3` is the newest, served at the
root. The `0.2.0` and `0.2.1` snapshots are identical; `0.2.2` was the first to differ (the breakdown
guide's own décor section), and `0.2.3` is identical to `0.2.2` (this cycle changed the app, not the
guide), so it matches the "Next" version until the next cycle adds to `docs/`.

## Deployment

The `.github/workflows/deploy_docs.yml` workflow builds this site and deploys it to GitHub Pages on
every push to `main` that touches `docs-site/`. GitHub Pages must be enabled for the repository with
its source set to **GitHub Actions**.
