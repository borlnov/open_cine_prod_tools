<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Open Cine Prod Tools <!-- omit from toc -->

![Open Cine Prod Tools logo](assets/branding/ocpt_logo_light.svg)

[![Build](https://github.com/borlnov/open_cine_prod_tools/actions/workflows/build.yml/badge.svg)](https://github.com/borlnov/open_cine_prod_tools/actions/workflows/build.yml)
[![Dart Checks](https://github.com/borlnov/open_cine_prod_tools/actions/workflows/flutter_lint.yml/badge.svg)](https://github.com/borlnov/open_cine_prod_tools/actions/workflows/flutter_lint.yml)
[![REUSE status](https://api.reuse.software/badge/github.com/borlnov/open_cine_prod_tools)](https://api.reuse.software/info/github.com/borlnov/open_cine_prod_tools)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSES/Apache-2.0.txt)

## Table of contents

- [Table of contents](#table-of-contents)
- [Introduction](#introduction)
- [About this project](#about-this-project)
- [Features](#features)
- [Roadmap](#roadmap)
- [Platforms](#platforms)
- [Installation](#installation)
- [Building from source](#building-from-source)
- [Repository layout](#repository-layout)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

## Introduction

Open Cine Prod Tools is an open-source suite of film-production tools. The first tool being
built is a Fountain screenplay editor; more production tools will follow. Projects are stored
locally, one `.ocpt` file each, and everything stays exportable to human-readable formats.

📖 **[Read the user guide](https://borlnov.github.io/open_cine_prod_tools/)** — a walkthrough of
every mode, in English and French, with screenshots.

## About this project

This project is a test for me, it's built through vibe coding with Claude. I want to see if I can
build a full-featured application without writing a single line of code (but with guidelines and
linting already written). And if the result at the end is good enough to be used in production.

## Features

What the app does today, in broad strokes - the
[user guide](https://borlnov.github.io/open_cine_prod_tools/) walks through each of these in
detail:

- A workspace shell around the open project, with a bottom mode switcher between the production
  tools; dock sizes and the last mode come back with the project.
- One project, several episodes: a series is one `.ocpt` file, sharing one address book, one set
  of locations and one schedule across its episodes.
- A screenplay mode, styled WYSIWYG or raw Fountain with a paper-simulated preview, with a scene
  dock, live statistics and offline spell-checking in French and British English.
- A breakdown mode: tag on the page what the shoot must provide, read back as a cross-table and
  per-scene sheets.
- A shot list mode: one sequence per scene, a configurable shot table and a detailed shot
  inspector.
- A resources mode: the address book, the cast, the casting candidates, the locations and their
  sets, and the catalogue of physical elements.
- A schedule mode: dated shooting days split into slots, computed timetables and call times, an
  agenda in several views, and conflict warnings.
- A budget mode: the quote against the CNC nomenclature read as a cost report, the cash journal,
  the financing plan and the revenue sharing.
- Project versions: named, permanent checkpoints, restored as an edit rather than a reset.
- A portable `.ocptz` package that bundles the project with every photo, permit and document it
  points at.
- Imports from Fountain, Final Draft (`.fdx`) and Celtx (`.celtx`), and exports to PDF, Fountain
  and XLSX - including a scenario coverage export that shows what the shot list still leaves out.
- Autosave, a system-following light/dark theme, and English (`en_GB`) and French interfaces.

## Roadmap

Planned production tools, in priority order:

- Call sheets beyond the ones the schedule mode already prints
- Script supervisor reports
- Storyboard

## Platforms

| Platform | Status |
| --- | --- |
| Linux | ✅ Active development |
| Windows | ✅ Active development |
| macOS | ⚠️ Build available (unsigned, untested) |
| Android | 🚧 Scaffolded |
| iOS | 🚧 Scaffolded |

> ⚠️ **The macOS build has never been tested.** The `.dmg` is produced by the CI on a
> GitHub-hosted macOS runner and checked structurally (architectures, signature, disk image
> layout), but nobody has run the application on a Mac yet — there is none available to this
> project. Treat that build as untried: it is published so it can be tried, and reports are
> welcome. Linux and Windows are the platforms actually being developed against.

## Installation

Download the `.deb` (Linux), the installer (Windows) or the `.dmg` (macOS) from the
[GitHub Releases](https://github.com/borlnov/open_cine_prod_tools/releases) page.

On Linux:

```bash
sudo apt install ./open-cine-prod-tools_<version>_amd64.deb
```

On macOS, open the `.dmg` and drag **Open Cine Prod Tools** onto the `Applications` shortcut
next to it — keeping in mind the warning above.

The binaries are unsigned, so Windows SmartScreen warns on first run, and macOS Gatekeeper refuses
to launch the application at all. Get past Gatekeeper either by right-clicking the app in
`Applications` and choosing **Open** (then **Open** again in the dialog that follows), or by
clearing the quarantine flag once:

```bash
xattr -dr com.apple.quarantine "/Applications/Open Cine Prod Tools.app"
```

## Building from source

The project ships a [devcontainer](.devcontainer/) (Debian trixie, Flutter 3.44.6, the Linux
desktop build toolchain, `reuse`) with everything needed to build and run the app — nothing to
install by hand.

```bash
git clone --recurse-submodules https://github.com/borlnov/open_cine_prod_tools.git
cd open_cine_prod_tools
```

Then either:

- **VS Code**: open the folder and "Reopen in Container". Its `postCreateCommand` installs
  dependencies and runs the code generators automatically.
- **Manually**, from the repo root:

  ```bash
  cd .devcontainer && docker compose up -d
  docker compose exec dev bash
  # inside the container:
  cd /workspaces/open_cine_prod_tools
  flutter pub get
  dart run intl_utils:generate
  dart run build_runner build
  flutter run -d linux
  ```

  Skipping `intl_utils:generate` / `build_runner build` is the most common cause of a fresh build
  failing with a missing `part '*.g.dart'` (or `l10n.dart`) file: both are git-ignored generated
  code (see `docs/adr/`) that only get produced automatically through VS Code's "Reopen in
  Container" flow, not by a plain `docker compose up`.

Run the test suites with `flutter test` and, inside `packages/fountain_kit`, `dart test`.

`flutter run -d linux` opens a window on the host's X server: the container forwards the X11
socket, so a typical Linux desktop needs nothing extra. On **Windows with WSL2**, make sure WSLg
is enabled (ships by default on recent Windows 11). If a window appears in the taskbar but stays
invisible with a `[WARN:COPY MODE]` title, that's a known WSLg bug, not this project: recent WSL
releases sometimes fail to mount `/mnt/shared_memory` at boot
([microsoft/WSL#40618](https://github.com/microsoft/WSL/issues/40618)). Workaround, run once from
a WSL shell on the host:

```bash
sudo mkdir -p /mnt/shared_memory
sudo mount -t tmpfs tmpfs /mnt/shared_memory
```

See [.devcontainer/README.md](.devcontainer/README.md) for the full devcontainer setup (Claude
Code and `gh` auth, git worktrees, GUI forwarding).

## Repository layout

```text
lib/                   Application source
packages/fountain_kit/ Pure-Dart Fountain parser, serializer and layout metrics
packages/script_import_kit/ Pure-Dart Final Draft and Celtx readers, emitting Fountain
packages/spell_kit/    Pure-Dart hunspell reader, spell checker and suggester
actlibs/               ACT Flutter packages (git submodule)
assets/                Config, fonts, branding, dictionaries and other bundled assets
test/                  Application test suite
tool/                  Developer scripts (branding icon generation)
docs/                  Architecture, plans and decision records
.github/               CI workflows and release pipeline
```

## Documentation

- [User guide](https://borlnov.github.io/open_cine_prod_tools/) - the end-user guide for
  filmmakers, in English and French (source under [`docs-site/`](docs-site/)).
- [Architecture](docs/architecture/) - what the code does, one file per area.
- [Architecture decision records](docs/adr/) - the reasoning behind structural choices.
- [CI documentation](.github/ci-doc.md) - build, test and release pipeline.
- [fountain_kit README](packages/fountain_kit/README.md) - the standalone Fountain package.
- [script_import_kit README](packages/script_import_kit/README.md) - Final Draft and Celtx import.
- [spell_kit README](packages/spell_kit/README.md) - the standalone spell-checking package.

## Contributing

Everything on GitHub - code, comments, commits, issues, pull requests - is in English, with
[Conventional Commits](https://www.conventionalcommits.org/) and a subject of 50 characters or
less. `flutter analyze` and `flutter test` must pass, and every file needs an SPDX header
(`reuse lint` is enforced in CI).

## License

This project is licensed under Apache-2.0. See the [LICENSES](LICENSES/) directory for the full
license text and for the bundled third-party licenses: OFL-1.1 for Courier Prime, MPL-2.0 for the
French dictionary and the SCOWL notice for the British English one. Each dictionary also carries
its upstream licence text next to the files it covers, under `assets/dictionaries/`.
