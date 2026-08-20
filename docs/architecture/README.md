<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture

`AGENTS.md` carries the invariants that hold everywhere; this directory carries the detail, split
so that a session loads the part it is about to touch and no more. **Read the file covering the
code you are changing before you change it** — most of what is written here is a decision that has
already been made and argued, and re-deciding it in code is how two parts of the app come to
disagree.

`docs/adr/` is the other half of the record: an ADR argues *why* a structural choice was made, a
file here says what the code does because of it.

| File | What it covers | The code it governs |
| --- | --- | --- |
| [foundations.md](foundations.md) | Managers, routing, the BLoC pattern, the workspace shell, its episodes and its cross-mode navigation, config, licenses, page setup, theme, branding, the spell-check manager and the project dictionary, desktop packaging, the drift schema, project versions, the sync-ready data model, binary assets, erasing a person, the portable project package, the compatibility gate every project file is opened through, the `Versions` dock tab and the read-only preview | `lib/managers/`, `lib/models/`, `lib/services/`, `lib/ui/pages/workspace/` (the shell, its widgets and its blocs), `lib/constants/`, `lib/utils/`, the platform directories |
| [screenplay.md](screenplay.md) | `fountain_kit` and what it guarantees, source provenance, the statistics, the styled editor's document model, scene numbers, the title page, the spell-checking, the editor docks and the syntax guide | `packages/fountain_kit/`, `packages/spell_kit/`, `lib/ui/pages/editor/` |
| [exports.md](exports.md) | The export panel every mode reaches its documents from, `OcptExportManager` and its fifteen services, the scenario coverage PDF | `lib/managers/export/`, `lib/ui/pages/workspace/widgets/` (the export dialog) |
| [resources.md](resources.md) | The address book, the cast, the locations and their sets, the elements catalogue, and the mode's two documents | `lib/ui/pages/workspace/modes/resources/` |
| [breakdown.md](breakdown.md) | The *dépouillement*: tags, the scene pass, the script and recap views, and the mode's two documents | `lib/ui/pages/workspace/modes/breakdown/` |
| [schedule.md](schedule.md) | The shooting days, slots and blocks, the time model, convocations, the four views, the alerts, and the seven documents a production runs on | `lib/ui/pages/workspace/modes/schedule/`, `lib/utils/ocpt_shooting_*.dart`, `lib/utils/ocpt_schedule_*.dart` |

A change that crosses two of them — a new synchronised table, a new export, a new production
mode — touches `foundations.md` too: that file is where the rules the others inherit are written.
