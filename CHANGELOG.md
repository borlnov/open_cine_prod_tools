<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Changelog

## 0.2.1

A shot's characters become the production's roles, and the user guide is
versioned.

- Shot list: a shot's characters are now the production's roles rather than free
  text. A shot's cast is picked from the roles, a role shared across several
  shots is flagged, and roles can be merged or deleted with their attachments
  following along. Entering a mode surfaces a role that needs attention.
- The online user guide is now versioned: its navigation bar shows the guide's
  version, and a reader can browse the guide for an earlier release.

## 0.2.0

Collaboration and sync, a mobile-usable app, and a balanced budget in-kind
contribution.

- Collaboration and sync: offline-first sharing of a project between several
  people, backed by a self-hostable, domain-blind relay with live push and
  presence; pairing a device by scanning a QR code or opening a link; a
  portable on-set server and in-app relay hosting for a production with no
  outside network; and a sync status indicator in the workspace shell.
- The app is now usable on tablets and phones, with an Android build alongside
  the desktop ones.
- Budget mode: an in-kind contribution now balances against a counterpart
  quote line, so valuing it nets the needs and the resources it is measured
  against back to zero.
- The collaboration and sync end-user guide.

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
