<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0006 - Workspace shell as a slot widget

## Status

Accepted

## Context

The editor page used to own the entire application chrome: the toolbar, the left scene dock, the
right tabbed dock, the status bar, and the dock geometry tying them together, all in one 536-line
page backed by an 827-line bloc. That bloc already juggled the Fountain source, two editing
engines, autosave, import, export and pagination - the largest and most delicate file in the repo.
The roadmap adds three more production tools (budget, schedule, shot list) behind a DaVinci
Resolve-style bottom mode switcher, and every one of them would either have to rebuild that chrome
from scratch or graft its own state into a bloc that was never designed to host more than one
tool's concerns.

## Decision

The shell is a **stateless slot widget**, not a mode-aware bloc: `OcptWorkspaceShell`
(`lib/ui/pages/workspace/widgets/`) takes typed slots - title, dirty flag, back action, toolbar
actions, overflow entries, left panel, right panel, centre, status bar, dock controller - and lays
them out top to bottom (toolbar, docks row, status bar). It imports nothing from a specific
production mode; a mode builds its own content and hands it to the shell as slot values.

The only new bloc, `OcptWorkspaceBloc`, owns exactly one thing: which `OcptWorkspaceMode` is
active, persisted through `OcptPropertiesManager.workspaceMode` so the last mode used is restored
on open. It knows nothing about a mode's internal state. Each mode keeps its own bloc (or none, for
the three empty-state modes) and its own dock geometry: the screenplay mode is still `EditorPage`,
unmoved, still owning `OcptEditorBloc` and the dock fractions it always persisted, now expressed as
an `OcptWorkspaceShell` instead of a hand-assembled `Column`/`Row`. `WorkspacePage` mounts
`OcptWorkspaceBloc` and switches on its mode to decide which mode widget to build; the mode widget
is entirely responsible for what fills the shell's slots.

## Consequences

`OcptEditorBloc` stays untouched in substance - the refactor moved its chrome out from under it,
not its logic - which keeps the highest-risk file in the repo out of scope for a UI-shaped change.
Adding a fifth production mode later means writing a new mode widget that builds an
`OcptWorkspaceShell`, not touching the shell or the switcher bloc at all. The cost is that dock
geometry, resizing and persistence are not shared infrastructure: each mode that wants resizable
docks (as the screenplay mode does, via `OcptWorkspaceDock`/`OcptWorkspaceDockLayoutController`)
must wire its own controller and its own persisted fractions, the same way the screenplay mode
does today, rather than getting them for free from the shell. A mode with no docks (today's three
empty states) pays nothing for that machinery, which would not be true of a shared per-mode dock
state living in `OcptWorkspaceBloc`.

## Alternatives considered

- A mode-aware god-bloc: one `OcptWorkspaceBloc` holding every mode's state (the screenplay's
  editing state included) behind a sealed union. Rejected because it either forces `OcptEditorBloc`
  to be rewritten into that union now, or duplicates its state alongside it - both put the app's
  most delicate bloc back in the blast radius of a chrome-only refactor.
- An inheritance hierarchy (an abstract `OcptProductionModePage` base class each mode extends,
  providing the chrome via `super` calls). Rejected because Flutter composition (a widget taking
  slots) already expresses "shared layout, mode-specific content" without coupling every mode's
  page class to a common ancestor's constructor shape, and without the fragile-base-class problem
  a future chrome change would otherwise create.
- Sharing dock geometry and persistence in the shell itself, so a mode only supplies dock content
  and gets resizing for free. Rejected for this step because only the screenplay mode has docks
  today; building shared per-mode persistence for three modes that render an empty state would be
  speculative, and the screenplay mode's own dock code (already resizable, already persisted from
  step 15) is proof the pattern can be replicated cheaply mode by mode if a second consumer shows
  up.
