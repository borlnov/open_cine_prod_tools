<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Open Cine Prod Tools <!-- omit from toc -->

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

| Platform | Status               |
| -------- | -------------------- |
| Linux    | ✅ Active development |
| Windows  | ✅ Active development |
| Android  | 🚧 Scaffolded         |
| iOS      | 🚧 Scaffolded         |
| macOS    | 🚧 Scaffolded         |

## Installation

Download the `.deb` (Linux) or the installer (Windows) from the
[GitHub Releases](https://github.com/borlnov/open_cine_prod_tools/releases) page.

On Linux:

```bash
sudo apt install ./open-cine-prod-tools_<version>_amd64.deb
```

The binaries are unsigned, so Windows SmartScreen will warn on first run.

## Building from source

```bash
git clone --recurse-submodules https://github.com/borlnov/open_cine_prod_tools.git
cd open_cine_prod_tools
# Open in the provided devcontainer (Flutter 3.44.6), then:
flutter pub get
dart run intl_utils:generate
dart run build_runner build
flutter run -d linux
```

Run the test suites with `flutter test` and, inside `packages/fountain_kit`, `dart test`.

## Repository layout

```text
lib/                  Application source
packages/fountain_kit/ Pure-Dart Fountain parser, serializer and layout metrics
actlibs/               ACT Flutter packages (git submodule)
assets/                Config, fonts and other bundled assets
test/                  Application test suite
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
