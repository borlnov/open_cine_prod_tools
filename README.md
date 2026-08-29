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

What the app does today:

- A workspace shell around the open project - toolbar, resizable side docks, status bar - with a
  bottom mode switcher for the production tools. Screenplay, breakdown, shot list, resources,
  schedule and budget are all implemented. Dock sizes and the mode you were last in come back with
  the project.
- One project, several episodes: a series is one `.ocpt` file, with one screenplay per episode and
  one address book, one set of locations and one schedule shared between them. The modes work on the
  episode the workspace has selected; the schedule reads them all at once, a shooting day regularly
  covering two episodes at one location.
- A styled WYSIWYG screenplay mode with the real page layout: a block-type dropdown, Tab cycling
  between screenplay element types, smart Enter, bold/italic/underline, a title page edited in
  place, and `#N#` scene numbers.
- A raw Fountain mode with a side-by-side, paper-simulated preview, and a read-only Fountain
  syntax guide in the right dock.
- A scene dock to navigate the screenplay, and live statistics in the status bar: pages, scenes,
  characters, words and signs.
- Spell-checking as you type, in both screenplay modes, from French and British English
  dictionaries the app bundles - no internet, no system service. It checks the prose and leaves the
  form alone: scene headings, character cues and transitions are never underlined. Right-click a
  misspelling for suggestions, ignore a word for the session, or add it to the project's own
  dictionary - which you can read, filter and prune from the project settings.
- A breakdown mode (dépouillement): the script read once, as a page, tagging what the shoot must
  provide. Two clicks mark a passage and a popover links it to an element, a character or a set -
  or creates the element, in its category, in one write. A character is never invented here: it is
  the role the screenplay already named. Every tag is stored with its passage verbatim, so an edit
  that shifts it is followed automatically when the words are still there once, and flagged for you
  only when they are not. The same pass reads as a cross-table, one row per target and one column
  per scene, and every scene carries its own progress and its own sheet. Exports the breakdown
  sheets to PDF, one per scene.
- A shot list mode (découpage technique): one sequence per scene, a shot table whose columns you
  choose, and a shot inspector for shot size, framing, camera move, lens, recording format, sound,
  estimated duration, planned takes, shooting day, status, notes, and difficulty rated separately
  for set, camera, acting and sound. Characters come from the ones the screenplay already knows
  about. Each shot can be tied to the passages of the screenplay it covers, and a shot whose
  covered text has changed since is flagged for re-checking rather than silently going stale.
  Exports to XLSX.
- A resources mode: who shoots the film, where, and with what. An address book where one person is
  one entry whatever they do on the film, the cast reconciled against the screenplay's own speaking
  characters (a character who leaves the script keeps their casting and is flagged rather than
  dropped), casting candidates gathered and weighed per role, the locations with their sets, their
  filming permit, their access notes and the windows they may be shot in, and a catalogue of
  everything that has to be on set and is not a person - props, costumes, vehicles, equipment - with
  who owns it, who brings it and whether it is secured, ready or already back. Scenes are linked to
  the sets they are shot in and to the elements they need. Elements and sets carry a code the app
  mints itself (`PRP-3`, `A`) rather than one you have to type and keep unique. Photos and signed
  documents are referenced by path rather than copied into the project file. Exports to XLSX, one
  sheet per tab.
- A schedule mode (plan de travail): when the film is shot. Dated shooting days, each split into
  slots, a slot being a working unit with its own location, set, crew and cast - a real day
  regularly has two. Each slot carries its own timetable, whose hours are computed rather than
  stored: the blocks chain from a single pinned edge, so a slot can be planned backwards from the
  22:00 a studio is booked until, and moving one block re-times the rest of the day. Nobody types a
  call time either: somebody's arrival, the band they are held for between the first and the last
  shooting block, and their departure are all read off the slots they are linked to. Sunrise, sunset
  and the three twilights are computed offline from the day's own coordinates, with no network call
  ever. The plan then reads four ways: the day being built, an agenda (strip, week or month, tinted
  by location or by day/night effect), the positions against the slots, and the people against the
  days. And the app says what it can see coming - somebody convoked while recorded away or booked
  into two units at once, a role a placed shot needs but nobody called, a day that leaves less rest
  than the production says it owes, a filming permit that does not cover the date. Exports the seven
  documents a shoot runs on: the general call sheet and one sheet per recipient, the shooting plan
  as a PDF and as a workbook, the Day Out of Days, the one-line schedule and the day's sides.
- A budget mode, on four pages: an overview, what the film costs, what pays for it, and a drawer of
  tools that re-read those rather than adding to them. The quote against the CNC nomenclature, read
  as the cost report a production actually works from - quote, committed, paid, remaining, final
  cost and variance, poste by poste - and a poste opens on its quote lines, a line on the
  commitment it became and the entry that settled it. Recording a movement is two questions: what
  you are doing, in the words a production actually uses, and then only the fields that answer
  belongs to, direction included. Once the amount and the date are typed the app ranks what the
  movement could be settling and one click writes it, so a sum that already exists is never typed a
  second time. The financing plan says what covers the film and keeps the paperwork apart from the
  money, because a subsidy on paper is not a subsidy in the account; a contribution in kind is
  valued without ever pretending cash will move for it. In the drawer, the cash flow page reads the
  account itself - every movement in date order, the balance it closes on, and what is committed
  and still owed under it - the catering each shooting day costs is read off the schedule rather
  than typed again beside the travel defrayals, typed row by row and provisioned into the quote,
  and the revenue sharing takes the reimbursable contributions off the top before dividing what is
  left. Exports the quote, the financing plan, the cash journal as a workbook and the financial
  report.
- Project versions: named, permanent checkpoints of the whole project, previewed read-only before
  you commit to anything and restored as an edit rather than a reset - the state a restore replaces
  is itself kept as a version, so going back is never a one-way door.
- A project you can hand to somebody: exported as one `.ocptz` package holding the project file
  and every photo, permit and document it points at, and imported back into a folder of its own,
  each file landing where its record expects it. A reference whose file has gone missing is named
  before the package is written and again when it is opened, never silently dropped.
- A project file written by another build of the app is never opened silently: an older one states
  the migration it needs and keeps a copy of itself first, a newer one is refused rather than
  damaged.
- A scenario coverage export: the screenplay printed as usual, with a coloured bar in the margin
  alongside every passage each shot covers, the passages no shot covers washed grey, and optional
  legend and summary pages - so you can see, page by page, what your découpage still leaves out.
- Screenplay import from Fountain, Final Draft (`.fdx`) and Celtx (`.celtx`); Fountain export.
- PDF export with an options dialog, page numbers, optional scene numbers, and embedded Courier
  Prime.
- Page setup: page format and margins, a per-project currency, and the language the screenplays
  are written in.
- Autosave.
- English (`en_GB`) and French interfaces.
- A system-following light/dark theme.

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
