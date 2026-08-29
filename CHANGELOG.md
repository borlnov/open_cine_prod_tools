<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Changelog

## 0.1.0

First stable release. One project is one local SQLite file (`.ocpt`) holding one
or several episodes, with the Fountain text as the source of truth, and a
workspace shell around six production modes reached from a bottom mode switcher.

- Screenplay mode: a styled block editor with the real screenplay layout and a
  raw Fountain view with a paper-simulated preview, Courier Prime throughout,
  scene numbers, a collapsible scene list, and a syntax guide. Spell checking
  (English and French) with a per-project dictionary.
- Screenplay import from Fountain, Final Draft (`.fdx`) and Celtx (`.celtx`);
  Fountain and PDF export, the PDF with page numbers, optional scene numbers and
  embedded Courier Prime.
- Shot list (découpage technique) with per-shot coverage of the scenario, and a
  scenario coverage export showing, page by page, what the shots still leave out.
- Resources mode: the cast reconciled against the screenplay's speaking
  characters, casting candidates weighed per role, the locations with their sets
  and permits, and a catalogue of the physical elements, all exported to XLSX.
- Breakdown mode (dépouillement): the script tagged scene by scene against the
  resources catalogue, with per-scene progress and sheets.
- Schedule mode: the shooting schedule as chained blocks with pinned anchors,
  standing alerts, several views, and PDF and XLSX exports.
- Budget mode: the quote against the CNC nomenclature, the cash journal it is
  measured against, the financing and catering plan, the revenue sharing, and
  their four documents.
- Named project versions of the whole project, a portable project package, and a
  compatibility gate every project file is opened through.
- Desktop packaging for Linux and Windows (macOS built by CI), a system-following
  light/dark theme, autosave, and English (`en_GB`) and French interfaces.
