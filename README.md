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
- [Screenshots](#screenshots)
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

## About this project

This project is a test for me, it's built through vibe coding with Claude. I want to see if I can
build a full-featured application without writing a single line of code (but with guidelines and
linting already written). And if the result at the end is good enough to be used in production.

## Screenshots

Screenshots are coming.

<!-- Screenshots will be inserted here. -->

## Features

What the app does today:

- A workspace shell around the open project - toolbar, resizable side docks, status bar - with a
  bottom mode switcher for the production tools: the screenplay editor is fully featured; budget,
  schedule and shot list are shown as "coming soon" placeholders (see [Roadmap](#roadmap)).
- A styled WYSIWYG screenplay mode with the real page layout: a block-type dropdown, Tab cycling
  between screenplay element types, smart Enter, and bold/italic/underline.
- A raw Fountain mode with a side-by-side, paper-simulated preview.
- `.fountain` import and export.
- PDF export with an options dialog, page numbers, and embedded Courier Prime.
- Page setup: page format and margins.
- Autosave.
- English (`en_GB`) and French interfaces.
- A system-following light/dark theme.

## Roadmap

Planned production tools, in priority order:

- Shot lists (decoupage technique)
- Scenario coverage per shot
- Shooting schedule
- Call sheets
- Budget
- Script supervisor reports
- Storyboard
- Breakdown
- Casting tracker

## Platforms

| Platform | Status |
| --- | --- |
| Linux | ✅ Active development |
| Windows | ✅ Active development |
| Android | 🚧 Scaffolded |
| iOS | 🚧 Scaffolded |
| macOS | 🚧 Scaffolded |

## Installation

Download the `.deb` (Linux) or the installer (Windows) from the
[GitHub Releases](https://github.com/borlnov/open_cine_prod_tools/releases) page.

On Linux:

```bash
sudo apt install ./open-cine-prod-tools_<version>_amd64.deb
```

The binaries are unsigned, so Windows SmartScreen will warn on first run.

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
lib/                  Application source
packages/fountain_kit/ Pure-Dart Fountain parser, serializer and layout metrics
actlibs/               ACT Flutter packages (git submodule)
assets/                Config, fonts, branding and other bundled assets
test/                  Application test suite
tool/                  Developer scripts (branding icon generation)
docs/                  Plans and architecture decision records
.github/               CI workflows and release pipeline
```

## Documentation

- [Architecture decision records](docs/adr/) - the reasoning behind structural choices.
- [CI documentation](.github/ci-doc.md) - build, test and release pipeline.
- [fountain_kit README](packages/fountain_kit/README.md) - the standalone Fountain package.

## Contributing

Everything on GitHub - code, comments, commits, issues, pull requests - is in English, with
[Conventional Commits](https://www.conventionalcommits.org/) and a subject of 50 characters or
less. `flutter analyze` and `flutter test` must pass, and every file needs an SPDX header
(`reuse lint` is enforced in CI).

## License

This project is licensed under Apache-2.0. See the [LICENSES](LICENSES/) directory for the full
license text and for the bundled third-party licenses, including OFL-1.1 for Courier Prime.
