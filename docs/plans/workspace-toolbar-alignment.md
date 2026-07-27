<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Workspace toolbar alignment

This document is the implementation strategy for bringing the workspace shell's top toolbar in
line with the reference mock-up (Claude Design project *OpenCineProdTools design shell*, file
`OpenCineProdTools App Design.dc.html`). It is written for the Sonnet 5 agents that will build it,
orchestrated and reviewed by the main session, with a user checkpoint between M2 and M3. **Read the
repository `CLAUDE.md` first** — this plan assumes its architecture, ways of working, coding
standards, licensing rules and verification gates, and does not repeat them.

---

## 1. Why this step exists

The workspace shell landed in step 17 with a deliberately minimal toolbar: a back arrow, the
project title, a dirty dot, then whatever the active mode hands in through `toolbarActions` and
`overflowEntries`. The mock-up's toolbar is more structured than that — it splits into a *mode*
group (format controls, dock tabs, editing-mode toggle) and a fixed *chrome* group (dock toggles,
save, overflow) separated by a muted mode label, and it gives the back action a distinct
accent-filled identity.

The colour work is already done: `lib/constants/ocpt_theme.dart` carries the mock-up's surfaces,
radii, dense type scale and the 16 % accent wash for selected icon buttons, and already declares
`ocptToolbarHeight = 44` (currently unused — the toolbar sizes itself from its padding). **This step
is about structure, ordering and two missing controls, not about colour.**

## 2. Current state vs. the mock-up

Mock-up toolbar: `height:44`, background `surfaceContainerLow` (`#17161a`), 1 px bottom border
(`outlineVariant`), `padding:0 12`, `gap:10`.

| # | Mock-up | `OcptWorkspaceToolbar` today |
| --- | --- | --- |
| 1 | Accent-filled 26×26 square (radius 6), white glyph, "back to projects" | plain `arrow_back` `IconButton`, stock sizing |
| 2 | Project title 13 px / w500 | `titleSmall` (12 px) |
| 3 | 6 px filled accent dot for unsaved changes | the text glyph `"●"` in `labelSmall` |
| 4 | spacer | same |
| 5 | Block-type select + B/I/U 26×26, styled mode only | `OcptEditorFormatControls`, same rule ✔ |
| 6 | Preview + syntax dock-tab buttons 28×28, **raw mode only** | preview is raw-only ✔, **syntax shows in both modes** ✘ |
| 7 | Styled/raw editing-mode toggle 28×28 | same ✔ |
| 8 | **Muted 11 px label naming the active mode** | absent |
| 9 | **Left dock toggle** 30×30, accent wash when open | exists, but as a mode-supplied `view_sidebar` action placed before save |
| 10 | **Right dock toggle** 30×30, accent wash when open | absent — the right dock only closes through its own ✕ |
| 11 | Save 30×30 | exists, but placed *before* the dock toggles |
| 12 | `⋮` 30×30, accent wash when open | same ✔ |

Relevant existing state (`lib/ui/pages/editor/editor_state.dart`): the right dock's open/closed
state *is* `rightDockTab` (`null` means closed), so closing it today loses which tab was active.
`autoClosedRightDockTab` only covers the raw → styled transition. `OcptEditorRightDockClosedEvent`
already exists for the ✕.

## 3. Decisions locked with Benoit

1. **Back button**: reproduce the mock-up faithfully — accent-filled square with the window glyph
   (`Icons.web_asset` is the Material equivalent of the mock-up's SVG: a rectangle with a top bar).
   The "back to projects" meaning is carried by the existing tooltip alone.
2. **Dock toggles and save are shell chrome, not mode actions**: `OcptWorkspaceShell` gains
   dedicated parameters for them, so their order is guaranteed by the shell and a future mode
   cannot break it. A mode that does not wire them simply does not render them.
3. **Mode label**: four *new* long ARB strings, as in the mock-up (`Screenplay editor`,
   `Production budget`, `Shooting schedule`, `Shot list`) rather than reusing the mode switcher's
   short names, so the toolbar does not read as a duplicate of the bottom band.
4. **Syntax-guide button**: align with the mock-up — visible in raw mode only. The syntax tab stays
   reachable in styled mode through the right dock's own tab row. `CLAUDE.md`'s statement that the
   guide renders "in both editing modes" stays true of the *panel*; only the toolbar shortcut
   narrows.

## 4. Target layout

```text
[◧ accent] Title ● ────────spacer──────── │ mode actions │ Mode label │ ◧ ◨ │ 💾 │ ⋮
                                            (5)(6)(7)         (8)      (9)(10) (11) (12)
```

- Mode actions = whatever the active mode passes in `toolbarActions` (screenplay: format controls,
  dock-tab buttons, editing-mode toggle). Unchanged contract.
- Everything from (8) rightwards is built by the shell itself.
- Sizes: chrome buttons 30×30, mode buttons 28×28 (already the `iconButtonTheme` minimum), B/I/U
  26×26 (unchanged). Add a `ocptToolbarChromeButtonSize = 30` constant next to `ocptToolbarHeight`
  rather than spelling 30 in the widget.

## 5. Milestones

### M1 — The toolbar widget

`lib/ui/pages/workspace/widgets/ocpt_workspace_toolbar.dart`:

- Fixed `ocptToolbarHeight` height, `surfaceContainerLow` fill, a bottom `Divider` (the divider
  theme already gives it `outlineVariant`, 1 px, no surrounding space), horizontal padding 12,
  `spacing: 10` on the `Row`.
- Back action: 26×26 `Container`/`InkWell` filled with `colorScheme.primary`, `ocptRadiusSmall`
  corners, `Icons.web_asset` in `onPrimary`, existing `editorBackToProjectsTooltip`.
- Dirty marker: a 6×6 circular `Container` in `colorScheme.primary` wrapped in the existing
  `Tooltip`, replacing the `"●"` `Text`.
- Title: `theme.textTheme.titleMedium`.
- New `String? modeLabel` — rendered in `bodySmall` / `onSurfaceVariant` after `actions`.
- New ordered trailing slots: `List<Widget> dockToggles`, `Widget? saveAction`, then the existing
  `⋮` built from `overflowEntries`.

Tests: new `test/ui/pages/workspace/widgets/ocpt_workspace_toolbar_test.dart` (no toolbar test
exists today) covering — back action fires, dirty marker shown/hidden, mode label rendered when
given and absent otherwise, and the trailing controls appearing in the order above.

**Acceptance**: analyze + test green; no call site changed yet beyond the new optional parameters
defaulting to today's behaviour.

### M2 — The shell slots

`ocpt_workspace_shell.dart` gains, all optional, all forwarded to the toolbar:

- `String? modeLabel`.
- `bool isLeftDockOpen` / `VoidCallback? onToggleLeftDock`, same pair for the right dock. The shell
  renders a toggle only when its callback is non-null, with `IconButton`'s `isSelected` driven by
  the matching `is*DockOpen` flag (the icon-button theme already paints the accent wash).
- `VoidCallback? onSave` / `bool isSaving` — the shell renders the save button, or the in-flight
  spinner, exactly as `EditorPage` does today.

`OcptBudgetMode` / `OcptScheduleMode` / `OcptShotListMode` pass `modeLabel` only (no docks, no
dirty state, nothing to save). `ocpt_workspace_shell_test.dart` updated for the new slots.

**Acceptance**: analyze + test green; the screenplay mode still renders its old toolbar (it has not
migrated yet), the three empty modes show their label.

*User checkpoint here.*

### M3 — Screenplay mode wiring

`lib/ui/pages/editor/editor_page.dart`, `editor_bloc.dart`, `editor_event.dart`,
`editor_state.dart`:

- Move the scene-panel toggle out of `toolbarActions` into the shell's left-dock slot, icon
  `Icons.view_sidebar` → a panel-left glyph consistent with the mock-up, `isSelected` bound to
  `isScenePanelVisible`.
- New `OcptEditorRightDockToggledEvent`: closes the dock when one is open, reopens it otherwise on
  the last tab used. That needs a new non-null `lastRightDockTab` field in the state (defaulting to
  `preview`), updated whenever a tab is selected, with the existing styled-mode rule applied on
  reopen — the preview tab does not exist in styled mode, so fall back to `syntax` there. Keep
  `autoClosedRightDockTab`'s behaviour untouched.
- Wire `onSave`/`isSaving` to the shell instead of building the button in `toolbarActions`.
- Restrict the syntax-guide toolbar button to raw mode (decision 4).
- Pass the screenplay `modeLabel`.
- `toolbarActions` is left with format controls, the raw-mode dock-tab buttons and the editing-mode
  toggle, in that order.

Tests: extend `editor_bloc_test.dart` for the new toggle event (close → reopen restores the tab;
reopening in styled mode never lands on `preview`) and `editor_page_test.dart` for the toolbar's
new composition.

**Acceptance**: analyze + test green; toggling either dock from the toolbar and from the dock's own
✕ stay consistent.

### M4 — Localization, documentation, gates

- ARB (`intl_en_GB.arb` + `intl_fr.arb`): the four mode labels, plus tooltips for the two dock
  toggles. Regenerate with `dart run intl_utils:generate`.
- `CLAUDE.md`: update the workspace-shell paragraph of the Architecture section — the shell now
  owns the dock toggles, the save action and the mode label; the syntax toolbar button is raw-only.
- Run the eight verification gates in the devcontainer.

## 6. Definition of done

- The toolbar matches the mock-up's ordering, sizing and grouping in both themes.
- Both docks can be toggled from the toolbar, and reopening the right dock restores the tab that
  was open.
- The three unimplemented modes show the same chrome minus the controls they have no use for.
- One commit per milestone, Conventional Commits, no reference to this plan in the messages.
- All eight gates pass.
