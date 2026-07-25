<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Step 15 — Editor docks & Fountain syntax guide

This document is the implementation strategy for step 15. It is written for the Sonnet 5 agents
that will build the feature, orchestrated and reviewed by the main session, with a user checkpoint
between each milestone. Read the repository `CLAUDE.md` first — this plan assumes its architecture,
ways of working, coding standards, and verification gates.

## Context

Open Cine Prod Tools is a Fountain screenplay editor. Steps 0–14 are done; **step 15 adds a
Fountain syntax guide**: a read-only reference panel listing the block types, their forcing
markers and the inline notation, so a writer using the raw source mode does not have to leave the
app to remember how to spell a scene heading or force a character cue.

The guide itself is a small, static, well-understood piece of UI. What makes this step bigger than
step 14 is where it lands: the editor already shows a fixed-width scene panel on the left and a
`flex: 6` preview on the right, and there is no room for a third fixed column. Rather than bolting
a fourth panel onto a layout that cannot absorb it, this step **first gives the editor a proper
dock system modelled on DaVinci Resolve** — the visual reference `CLAUDE.md` already names for the
whole application — and then plugs the guide into it as a tab of the right dock.

Building the guide on the current fixed-width layout and migrating it afterwards would be wasted
work, which is why the dock infrastructure comes first (M1–M2) and the guide second (M3–M4).

### Decisions locked with Benoit

1. **Side panels behave like DaVinci Resolve's docks.** Concretely, and in this order of
   importance: panels *push* the central editing area instead of overlaying it (already true);
   every dock is separated from the centre by a **draggable divider** with a resize cursor and
   enforced minimum widths; dock widths are **remembered between sessions**; the toolbar buttons
   that open a dock are **lit while their panel is visible**; and a **"Reset panel layout"** action
   restores the defaults (Resolve's `Workspace ▸ Reset UI Layout`).
2. **The right dock hosts several panels as tabs, one visible at a time** — Resolve's
   Inspector/Metadata dock. The formatted preview and the syntax guide are its two tabs. This is
   what makes a third panel fit at all: the guide never competes with the preview for width.
3. **The toolbar buttons are tab selectors.** Clicking the button of a panel that is not visible
   opens the dock on that tab; clicking the button of the tab already active closes the dock.
4. **Styled mode keeps no preview tab** (unchanged: the styled layout already *is* the formatted
   screenplay). Switching raw → styled while the preview tab is active **closes** the dock,
   remembering the tab, and switching back to raw re-opens it on the preview. The styled mode never
   force-opens the syntax guide the user did not ask for.
5. **The guide is read-only and available in both modes.** No insertion of examples into the
   screenplay, no coupling to either editing engine.
6. **Guide content**: the 11 assignable block types with their forcing markers, plus dual dialogue,
   notes, the boneyard, inline emphasis and the title page.
7. **Guide text lives in ARB keys** (`intl_en_GB.arb` + `intl_fr.arb`), with a `const` Dart table
   holding the structure and the Fountain snippets. The snippets themselves are syntax literals,
   not prose, and are **not** translated.
8. **What is persisted**: the two dock width fractions, and nothing else. Whether a dock is open
   and which tab is active stay session-local, exactly like today's `isScenePanelVisible` and
   `isPreviewVisible`.

### Target layout

```text
┌──────────────────────────────────────────────────────────────────────┐
│ ←  My film             [B I U]  💾  ▤  📄  ?  </>  ⋮                 │
│                                      ▲   ▲                           │
│                            scenes ───┘   └─── right dock (lit)       │
├──────────────┊───────────────────────────┊──────────────────────────┤
│ Scenes       ┊  INT. KITCHEN - DAY       ┊ ┌────────┬────────┐      │
│              ┊                           ┊ │Preview │ Syntax │  ×   │
│ 1  INT. KIT  ┊  She walks in, breathless.┊ ├────────┴────────┴──────┤
│ 2  EXT. STR  ┊                           ┊ │ Scene heading          │
│ 3  INT. OFF  ┊  MARIE                    ┊ │  INT. PLACE - DAY      │
│              ┊  You are late.            ┊ │  .FORCED PLACE         │
├──────────────┴───────────────────────────┴─┴──────────────────────────┤
│ 12 pages · 34 scenes · 8 characters · Saved 2 minutes ago             │
└──────────────────────────────────────────────────────────────────────┘
   ┊ = draggable divider (resize cursor on hover, width persisted)
```

---

## Architecture & reuse map (consume these, do not reinvent)

| Concern | Existing asset to reuse | Path |
| --- | --- | --- |
| Side panel idiom (fixed width, `surfaceContainerLow`, header row + list) | `OcptEditorScenePanel` | `lib/ui/pages/editor/widgets/ocpt_editor_scene_panel.dart` |
| Toolbar idiom (`IconButton`, `size: 20`, localized tooltip, `PopupMenuButton` overflow) | `OcptEditorToolbar` | `lib/ui/pages/editor/widgets/ocpt_editor_toolbar.dart` |
| Where the panels are laid out (the `Row` under the toolbar) | `_EditorViewState.build`, lines ~171-217 | `lib/ui/pages/editor/editor_page.dart` |
| Panel-visibility plumbing template (state field + event + handler + toolbar callback) | `isScenePanelVisible` / `OcptEditorScenePanelToggledEvent` / `_onScenePanelToggled` | `editor_state.dart`, `editor_event.dart`, `editor_bloc.dart` |
| Persisted editor preference template (load once in `_onLoadRequested`, store on change) | `isPageSimulationEnabled` (`SharedPreferencesItem<bool>`) | `lib/managers/ocpt_properties_manager.dart`, `editor_bloc.dart:153,379` |
| A `ChangeNotifier` owned by the page state, bridging live UI to the bloc without per-frame states | `OcptStyledEditorController` | `lib/ui/pages/editor/ocpt_styled_editor_controller.dart` |
| Block type labels, already localized in both locales | `editorBlockType*` ARB keys + the `_labelOf` switch | `lib/ui/pages/editor/widgets/ocpt_editor_block_type_dropdown.dart`, `lib/l10n/*.arb` |
| Ground truth for forcing markers and classification | `FountainLineClassifier`, `FountainLineWriter` | `packages/fountain_kit/lib/src/parser/`, `.../serializer/` |
| Courier Prime font family for the snippets | `OcptEditorPreviewLayout.fontFamily` (`"CourierPrime"`) | `lib/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart` |
| App-level enum convention | `ocpt_editor_mode.dart`, `ocpt_inline_style.dart` | `lib/types/` |
| ADR format, numbering and index | `0000-template.md`, `README.md` | `docs/adr/` |

**Hard constraints.** `actlibs/` is an untouchable submodule; `packages/fountain_kit` stays
Flutter-free (this step adds nothing to it); `lib/generated/` is generated. Every new Dart file
gets the 3-line Apache-2.0 SPDX header; ARB keys are covered by the blanket `REUSE.toml`. All
navigation and dialogs go through `OcptRouterManager`. Every user-visible string goes through
`Tr.of(context)` and exists in **both** ARB files. Never reference the plan, step numbers, or these
instructions in code or commit messages.

**No third-party splitter.** Neither `actlibs/` nor `pubspec.yaml` provides a resizable-divider
widget, and none is to be added: the divider is ~40 lines of `MouseRegion` + `GestureDetector`.

---

## Milestones (one Sonnet 5 agent per milestone, checkpoint between each)

### M1 — Dock infrastructure, retrofitted onto the existing panels

No new content and no visible feature: at the end of M1 the editor looks the same, but its two
existing panels are resizable and remember their width.

**Sizing model.** Dock widths are stored as a **fraction of the editing row's width**, not as
pixels: a fraction survives a window resize or a move to another monitor, where a stored pixel
width would eventually exceed the window. Fractions are resolved to pixels at layout time and
clamped:

| Dock | Min | Default fraction | Max fraction |
| --- | --- | --- | --- |
| Left (scenes) | 180 px | 0.18 | 0.40 |
| Right (preview / syntax) | 300 px | 0.45 | 0.65 |

The centre editing area keeps a **320 px floor**: when the row is too narrow to honour both docks
plus the floor, the right dock gives up width first, then the left one. Put these numbers in one
place, as named `static const` fields of the dock widget, and document each.

**Work.**

- New `lib/ui/pages/editor/widgets/ocpt_editor_dock.dart`, holding:
  - `OcptEditorDock` — a `StatelessWidget` wrapping a panel child at a resolved pixel width, with
    the `surfaceContainerLow` background the panels use today (move the `ColoredBox`/`SizedBox`
    out of `OcptEditorScenePanel`, which becomes width-agnostic and fills what it is given).
  - `OcptDockDivider` — a `MouseRegion(cursor: SystemMouseCursors.resizeLeftRight)` around a
    `GestureDetector(behavior: HitTestBehavior.opaque, onHorizontalDragUpdate: ...)`, an 8 px hit
    area drawn as a centred 1 px `outlineVariant` line, tinted `primary` while hovered or dragged.
    It reports drag deltas in pixels; converting them to a fraction is the caller's job.
  - The clamping helper (row width + both fractions → the two resolved pixel widths) as a pure
    static function, so it is unit-testable without pumping a widget.
- New `lib/ui/pages/editor/ocpt_editor_dock_layout_controller.dart`: an
  `OcptEditorDockLayoutController extends ChangeNotifier` owned by `_EditorViewState`, holding the
  two live fractions. It is the same pattern as `OcptStyledEditorController`, and it exists for a
  performance reason that must not be undone: **a drag must not emit a bloc state per frame**, or
  every frame rebuilds `OcptStyledScreenplayEditor` and the preview. The controller notifies during
  the drag; the page dispatches **one** bloc event on `onHorizontalDragEnd`, which persists the
  final value.
- Rebuild scoping in `editor_page.dart`: build the panel/editor/preview children into local
  variables **before** the `ListenableBuilder` that listens to the controller, and pass those same
  widget instances inside it. Flutter short-circuits `Element.update` on an identical widget
  instance, so a drag then only re-lays-out the widths and never rebuilds the editing subtrees.
  Wrap the editing `Row` in a `LayoutBuilder` to know the row width the fractions apply to.
- `OcptPropertiesManager`: two new items, documented like their neighbours —
  `editorLeftDockFraction` and `editorRightDockFraction`, both
  `SharedPreferencesItem<double>` (verified supported by `act_local_storage_manager`'s
  `PropertiesSingleton`), null meaning "never stored, use the default".
- Bloc/state: `leftDockFraction` and `rightDockFraction` (`double`) on `OcptEditorState`, loaded in
  `_onLoadRequested` next to `isPageSimulationEnabled`, threaded through `copyWith` and `props`;
  one `OcptEditorDockFractionsChangedEvent({double? left, double? right})` whose handler emits and
  persists; one `OcptEditorDockLayoutResetEvent` restoring both defaults and persisting them.
- Toolbar: a "Reset panel layout" entry in the `⋮` menu, plus the new ARB keys for it.
- Tests: the clamping helper (centre floor honoured, right dock yields first, min/max respected,
  degenerate widths); `editor_bloc_test.dart` (fractions load from the properties manager, a change
  event persists, the reset event restores the defaults); `editor_page_test.dart` (dragging the
  divider changes the panel's width, and releasing dispatches exactly one bloc event).

### M2 — The right dock becomes tabbed

The preview stops being a `flex: 6` column and becomes the first tab of the right dock. This
changes UI Benoit has already validated, so **this milestone ends with a visual checkpoint**.

- New `lib/types/ocpt_editor_right_dock_tab.dart`: `enum OcptEditorRightDockTab { preview, syntax }`
  (the `syntax` tab renders a placeholder until M4).
- `OcptEditorState`: **replace** `isPreviewVisible` with
  - `rightDockTab` (`OcptEditorRightDockTab?`, null = the dock is closed), initialised to
    `preview`, and
  - `autoClosedRightDockTab` (`OcptEditorRightDockTab?`, null by default), the tab that a mode
    switch force-closed.

  Both need a `clear…` flag in `copyWith` (they legitimately go back to null), following the
  `ioNotice`/`clearIoNotice` idiom already in the file — the `document`-style "never null back"
  shortcut does not apply here.
- Transition rules, implemented in the mode handler and applied identically in `_onLoadRequested`
  once the persisted mode is known:
  - to styled, with `rightDockTab == preview` → `autoClosedRightDockTab = preview`,
    `rightDockTab = null`;
  - to raw, with `rightDockTab == null && autoClosedRightDockTab != null` → restore it and clear
    `autoClosedRightDockTab`;
  - **any explicit user action on the dock clears `autoClosedRightDockTab`**, so a dock the user
    closed on purpose is never re-opened behind their back.
- `OcptEditorPreviewToggledEvent` becomes `OcptEditorRightDockTabSelectedEvent({required tab})`
  with the toggle semantics of decision 3 (same tab → close, other tab → switch), plus
  `OcptEditorRightDockClosedEvent` for the dock's own `×`.
- New `lib/ui/pages/editor/widgets/ocpt_editor_right_dock.dart`: the dock chrome — a compact tab
  row (`labelSmall`, the active tab tinted `primary` with a 2 px underline, the others
  `onSurfaceVariant`), a trailing `×` close button, and the active tab's body below. In styled mode
  the preview tab is **not rendered at all**; the bar still renders, with the syntax tab alone.
- Toolbar: the preview `IconButton` keeps its `article`/`article_outlined` icons and its raw-only
  visibility but now takes `isSelected: rightDockTab == preview`; add the syntax button
  (`Icons.help_outline` / `Icons.help`, `isSelected: rightDockTab == syntax`) visible in **both**
  modes, placed just before the `⋮` menu.
- Tests: the tab-selection semantics (open, switch, close-on-same-tab); the raw↔styled dance
  including "explicitly closed stays closed"; the preview renders inside the dock and receives its
  width from it; the toolbar buttons expose the right `isSelected`.

### M3 — Guide content model and localization (no layout work)

- New `lib/types/ocpt_fountain_syntax_topic.dart`: `OcptFountainSyntaxTopic` (16 values) and
  `OcptFountainSyntaxSection` (`structure`, `organisation`, `formatting`, `titlePage`).

  | Section | Topics |
  | --- | --- |
  | structure | `sceneHeading`, `action`, `character`, `parenthetical`, `dialogue`, `dualDialogue`, `transition`, `centeredText`, `lyrics`, `pageBreak` |
  | organisation | `section`, `synopsis`, `note`, `boneyard` |
  | formatting | `emphasis` (bold, italic and underline in a single entry, three snippet lines) |
  | titlePage | `titlePage` |

- New `lib/models/ocpt_fountain_syntax_entry.dart`: an immutable `OcptFountainSyntaxEntry` (topic,
  section, `List<String> snippetLines`, and the optional `FountainLineType` the topic maps to) plus
  the `const` ordered table of the 16 entries. The snippets are English screenplay literals
  (`INT. KITCHEN - DAY`, `@McCLANE`, `> CUT TO:`, `**bold**`, `[[a note]]`, `MARIE ^`, …) and stay
  untranslated.
- l10n, in **both** ARB files, following the existing entry shape (`description`, `context`,
  `type`, `placeholders`):
  - **Reuse the 11 existing `editorBlockType*` keys** as the titles of the block-type topics, so
    the guide and the toolbar dropdown name things identically. Only add titles for the 5 topics
    they do not cover: `editorSyntaxGuideDualDialogueTitle`, `…NoteTitle`, `…BoneyardTitle`,
    `…EmphasisTitle`, `…TitlePageTitle`.
  - One description per topic: `editorSyntaxGuide<Topic>Description` (×16), one or two sentences,
    naming the forcing marker where there is one.
  - Section headers (×4), plus the panel chrome: panel title, tab label, toolbar tooltip, close
    tooltip.
  - Regenerate `Tr` with `dart run intl_utils:generate`.
- Tests (`test/models/ocpt_fountain_syntax_entry_test.dart`):
  - table completeness — every `OcptFountainSyntaxTopic` appears exactly once, in section order,
    with non-empty snippets;
  - **snippet correctness against the real parser** — for every entry carrying a `FountainLineType`,
    feed its snippet through `FountainParser` and assert the advertised line type comes back. This
    is what keeps the guide from drifting away from `fountain_kit`'s actual behaviour, and it is
    cheap; do not skip it.

### M4 — The guide panel, wired into the dock

- New `lib/ui/pages/editor/widgets/ocpt_editor_syntax_guide_panel.dart`: a `StatelessWidget`
  rendering the four sections as a scrollable list — a section header (`titleSmall`, tinted
  `primary`), then one entry per topic: title (`labelLarge`), snippet block (Courier Prime via
  `OcptEditorPreviewLayout.fontFamily`, `surfaceContainerHigh` background, rounded 4 px, selectable
  text so a writer can copy it), description (`bodySmall`, `onSurfaceVariant`). A private
  `_labelOf(Tr, topic)` switch resolves the titles, exactly like
  `OcptEditorBlockTypeDropdown._labelOf`.
- Replace the M2 placeholder with this panel; the guide is available in both editing modes.
- Tests: every section header and every entry renders; the snippets use Courier Prime; the list
  scrolls without overflow at a small height; the panel renders identically in both modes.

### M5 — Documentation & closure

No code. Once M1–M4 are done:

- Flip step 15 to ✅ in the `CLAUDE.md` development-plan table.
- Add to the `CLAUDE.md` "Architecture" section: one line for the dock system (fractions persisted
  in `OcptPropertiesManager`, the layout controller's per-frame/per-drag split, the centre floor)
  and one for the syntax guide (topic enum + `const` table + ARB titles reused from
  `editorBlockType*`).
- Write `docs/adr/0005-resizable-editor-docks.md` from `0000-template.md`, status **Accepted**, and
  add its row to the `docs/adr/README.md` index. The dock system qualifies under the ADR criteria:
  it is a structural UI decision that constrains how every future editor panel is added.
  Alternatives to record: keeping fixed-width panels; adding a third side-by-side column; stacking
  the right panels vertically; taking a third-party splitter dependency.

---

## Verification (every milestone, inside the devcontainer)

Run the `CLAUDE.md` gates before each commit:
`flutter pub get` → `dart run intl_utils:generate` → `dart run build_runner build
--delete-conflicting-outputs` → `flutter analyze` (0 issues) → `flutter test` (green) →
`flutter build linux --debug` → `reuse lint` (compliant) → `git grep -l 'allcircuits.com'
-- ':!actlibs'` (empty).

Remember the repository's testing pitfalls: no full-app-boot widget test (`PackageInfo
.fromPlatform()` hangs), so pump pages and widgets directly, and set
`BlinkController.indeterminateAnimationsEnabled = false` before pumping anything containing the
styled editor.

**End-to-end manual check** (after M2, then again after M4): drag both dividers and confirm the
cursor changes, the minimums block the drag, and the centre never collapses below its floor; close
and reopen the project and confirm the widths came back; narrow the window until the docks give way
and confirm nothing overflows; switch raw ↔ styled with the preview open and confirm the dock
closes then comes back; close the dock by hand in raw mode, switch to styled and back, and confirm
it stays closed; open the syntax guide in both modes and check the snippets are legible in light
**and** dark themes; run "Reset panel layout" and confirm both docks return to their defaults.

**Per-commit trailer** for Sonnet agents:
`Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`. New Dart files get the 3-line Apache-2.0
SPDX header; ARB keys are covered by the blanket `REUSE.toml`.
