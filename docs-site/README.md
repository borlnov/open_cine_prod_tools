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
matches it. The content in `docs/` is the current, unreleased version; a release snapshot is cut
**at an application release tag**, not before:

```bash
cd docs-site
npm run docusaurus docs:version <application-version>   # e.g. 0.1.0-alpha.1
```

That freezes the current content into `versioned_docs/version-<application-version>/` and adds the
version to the navbar's version dropdown. No version is frozen yet: the site is currently serving
only the "next" content while the first public release is prepared.

## Deployment

The `.github/workflows/deploy_docs.yml` workflow builds this site and deploys it to GitHub Pages on
every push to `main` that touches `docs-site/`. GitHub Pages must be enabled for the repository with
its source set to **GitHub Actions**.
