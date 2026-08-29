<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0005 - Resizable editor docks

## Status

Accepted

## Context

The editor already had two fixed-width side panels either side of the centre editing area: the
scene list on the left, the formatted preview on the right. Adding a third panel (the Fountain
syntax guide) had nowhere to go: the layout was a plain `Row` of fixed widths plus a `flex: 6`
centre, with no space budget for a third column and no way for a user to reclaim width from a
panel they use less. The visual reference the whole app already follows - DaVinci Resolve - solves
this with a dock system: panels that push the centre rather than overlay it, a draggable divider
between every dock and the centre, remembered widths, and several panels sharing one dock as tabs.

## Decision

Dock widths are stored as **fractions of the editing row's width**, not pixels, so they survive a
window resize or a move to another monitor. `OcptWorkspaceDock.resolveDockWidths` (a pure, static,
unit-tested function in `lib/ui/pages/workspace/widgets/ocpt_workspace_dock.dart`) turns the two
fractions into pixel widths for a given row width, clamping each dock between its minimum pixel
width and maximum fraction, and enforcing a 320 px centre floor: when the row is too narrow to
honour both docks' current widths plus that floor, the right dock gives up width first, then the
left one. `OcptWorkspaceDockDivider` is a small `MouseRegion`/`GestureDetector` pair (no
third-party splitter dependency), reporting raw pixel deltas; the caller converts them to
fractions.

A drag must not emit a bloc state per frame, or the editing subtrees underneath would rebuild on
every frame of a resize. `OcptWorkspaceDockLayoutController extends ChangeNotifier`
(`lib/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart`), owned by the
page's state, holds the two live fractions during a drag and notifies only the `ListenableBuilder`
that resolves widths; the bloc only receives one `OcptEditorDockFractionsChangedEvent` on
`onHorizontalDragEnd`, which persists the final fraction through
`OcptPropertiesManager.editorLeftDockFraction`/`editorRightDockFraction`. The editor page builds
the scene panel, the editor and the preview into local variables once, before the
`ListenableBuilder`, so a drag's rebuild only re-lays-out widths and never rebuilds those subtrees
(`Element.update` short-circuits on the identical widget instance).

The right dock hosts several panels as tabs, one visible at a time - `OcptEditorRightDock`,
switching on `OcptEditorRightDockTab` (`preview`, `syntax`). The toolbar's panel buttons are the
tab selectors: clicking a closed or inactive tab's button opens the dock on it, clicking the
active tab's button closes the dock, and the dock's own `×` always closes it. Styled mode has no
preview tab (its own layout already is the formatted screenplay): switching to styled while the
preview tab is open closes the dock and remembers the tab in `autoClosedRightDockTab`; switching
back to raw reopens it - unless the user explicitly closed the dock themselves at some point, in
which case that memory is cleared and the dock stays closed across any number of further mode
switches.

## Consequences

Every future editor panel has a template to follow instead of inventing its own sizing and
persistence scheme, but that template is now a constraint: a panel that doesn't fit the
fraction/dock/divider model (for example, something that needs to float or overlay rather than
push) will need its own mechanism rather than reusing this one. The per-frame/per-drag split adds
a second piece of state to reason about beyond the bloc (the layout controller), which every
future change to the editing row's layout has to keep in sync with. The right dock's tab/auto-close
rules are a small state machine (`rightDockTab` + `autoClosedRightDockTab`) that a future third
tab has to extend correctly, including the "explicitly closed stays closed" rule, or it will
silently reopen a panel the user chose to hide.

## Alternatives considered

- Keeping both panels at their existing fixed widths: simplest, but leaves no room for the syntax
  guide without either shrinking the preview permanently or overlaying content, and gives users no
  control over the panels' widths at all.
- Adding a third side-by-side fixed column for the guide: fits the guide in, but a `flex: 6`
  preview plus two fixed columns leaves even less width for the centre editing area on common
  laptop screens, and still doesn't let a user reclaim space from a panel they don't need open.
- Stacking the right panels vertically instead of as tabs: avoids a tab-selection state machine,
  but a preview and a syntax guide are both tall, scrollable content; splitting the dock's height
  between them would make both cramped rather than letting either use the full height.
- Taking a third-party resizable-splitter package: less code to maintain directly, but the actual
  divider is roughly 40 lines of `MouseRegion`/`GestureDetector`, well under the cost of vetting
  and pinning an external dependency for it.
