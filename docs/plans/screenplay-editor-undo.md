<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Screenplay editor — undo and redo

This document is the implementation strategy for
[issue 58](https://github.com/borlnov/open_cine_prod_tools/issues/58). It is written for the
Sonnet 5 agents that will build it, orchestrated and reviewed by the main session, with a user
checkpoint between each milestone. **Read the repository `CLAUDE.md` first**, then
[`docs/architecture/screenplay.md`](../architecture/screenplay.md) — this plan assumes their
architecture, ways of working, coding standards, licensing rules and verification gates, and does
not repeat them.

---

## 1. What the ground truth actually is

The issue's diagnosis needs one correction, and the correction changes the shape of the work. The
keyboard binding is **not** what is missing: `ocptFountainKeyboardActions` spreads
`defaultImeKeyboardActions` minus `_ocptExcludedDefaultActions`, and that list already carries
`undoWhenCmdZOrCtrlZIsPressed` and `redoWhenCmdShiftZOrCtrlShiftZIsPressed`
(`super_editor/lib/src/default_editor/super_editor.dart`). Ctrl+Z already reaches `Editor.undo()`
today.

It does nothing because **`Editor.isHistoryEnabled` defaults to `false`** and
`_OcptStyledScreenplayEditorState._rebuildEditorFrom` never passes it. With history off, `undo()`
returns immediately and `history`/`future` stay empty, whatever every command's
`HistoryBehavior.undoable` says.

Everything below was measured, not guessed: a throw-away spike enabled history on the real editor
and drove it through the existing `ocpt_styled_screenplay_editor_test.dart` harness. Its four
findings are what the milestones are built around.

### 1.1 Finding A — undo crashes the editor as the document is built today

With history on and nothing else changed, the first Ctrl+Z throws
`type 'List<DocumentNode>' is not a subtype of type 'Iterable<ParagraphNode>'` from
`MutableDocument.reset` (`editor.dart:1414`) and **leaves the document empty**, because `reset`
clears the node list before it throws.

`Editor.undo()` does not invert commands: it resets every `Editable` to the snapshot taken in
`MutableDocument`'s constructor, then replays the whole history minus its last transaction. That
reset is `_nodes..clear()..addAll(_latestNodesSnapshot)`, where `_latestNodesSnapshot` is a
`List<DocumentNode>` while `_nodes` is whatever list the constructor was handed — and
`OcptWysiwygCodec` hands it a `List<ParagraphNode>` (`ocpt_wysiwyg_codec.dart:295` and `:334`, plus
the scratch document in `_flushPendingSync`). A one-line typing fix per site, but nothing works
before it.

### 1.2 Finding B — the settle pass makes a manual gesture unundoable

Tab on an action line, then Ctrl+Z three times: the block stays `character`, stays
`ocptTypeLocked`, and its text stays uppercased. Not "undone one step too far" — *nothing happens
at all, ever*.

The reason is the 120 ms debounce. The Tab's own requests are one transaction; `_settleDocument`'s
reclassify/uppercase/scene-number passes land 120 ms later as up to three more. Ctrl+Z pops the
last of those, the document changes, `_onDocumentChanged` restarts the debounce, and the settle
re-derives exactly what was just undone — and pushes it as a *new* transaction. The user is
walking down a staircase that rebuilds its own step behind them.

### 1.3 Finding C — a plain typing undo eats one character at a time

`mergeRapidTextInputPolicy`, super_editor's own grouping policy, merges consecutive text
insertions only when they are less than **100 ms** of `clock.now()` apart. A 60 wpm hand types a
character every ~200 ms, so nothing merges and every Ctrl+Z gives back one letter.

The machinery itself is sound: the same spike run inside `withClock(Clock.fixed(…))` collapses a
six-character run into a single undo step. Only the window is wrong, and it is a constructor
argument (`MergeRapidTextInputPolicy(Duration)`).

### 1.4 Finding D — redo replays a transaction that no longer applies

`Editor` never clears `_future` when a new edit arrives; the code comment on the `future` getter
says it should, and no code does it (grep `_future` in `editor.dart`: it is only touched by `undo`
and `redo`). Measured consequence: type `abcdef`, Ctrl+Z (`abcde`), type `XY` (`abcdeXY`), then
Ctrl+Shift+Z, and the document becomes **`abcdefXY`** — a text the writer never wrote. The stale
transaction is replayed blind on top of a document that has moved on.

We own the keyboard action list, so we own the fix, and it has to be ours: the package is pinned.

---

## 2. What one undo step is

The rule this plan implements, stated once, since every milestone below serves it:

> One undo step is **one gesture of the writer's**, plus everything the editor derived from it.

A keystroke run, an Enter, a Tab, a dropdown pick, a paste, a replace — each of those, together
with the reclassification, the uppercasing, the `#N#` renumbering and the metadata the editor
computed *because* of it. Never the derived half alone, and never a derived pass on its own when
no gesture opened it.

Three consequences, all of them checkable:

- a settle transaction merges onto the transaction that caused it (M2);
- a settle pass that runs as a consequence of an undo or a redo writes no history at all (M2);
- the scene-number normalization that runs at load time, before the writer has touched anything,
  is not an undo step either (M2).

---

## 3. M1 — Make undo possible at all

The plumbing, with no behavioural design in it. It ends with Ctrl+Z working and being wrong in the
ways findings B, C and D describe — that is expected, and M2/M3 are what fix it.

1. Build every `MutableDocument` from a `List<DocumentNode>` (finding A): `ocpt_wysiwyg_codec.dart`
   at both decode sites and both encode-scratch sites, and the settled scratch document in
   `_flushPendingSync`. Document *why* on each: a typed node list makes `reset()` throw and wipes
   the document. This is invisible to every existing test, so it needs one of its own that undoes
   an edit on a decoded document.
2. `Editor(isHistoryEnabled: true, historyGroupingPolicy: …)` in `_rebuildEditorFrom`. The scratch
   editor in `_flushPendingSync` keeps history off: it exists for one synchronous encode and is
   thrown away.
3. `OcptNoOpCommand.historyBehavior` becomes `HistoryBehavior.nonHistorical`
   (`ocpt_title_page_guard_requests.dart`). Its doc comment currently argues that a command logging
   no change cannot become an undo step; that stops being true the moment history is on —
   `Editor.endTransaction` keys on `commands.isNotEmpty`, not on the changes — and a refused
   title-page edit would become a Ctrl+Z that visibly does nothing. Rewrite the comment with the
   real reason.
4. Ctrl+Y: super_editor binds Ctrl+Z and Ctrl+Shift+Z only. Add an action for the Windows habit,
   next to the redo guard M3 introduces, and keep it in the same file as the rest
   (`ocpt_fountain_keyboard_actions.dart`).

Exit criterion: on the standalone editor, typing then Ctrl+Z gives characters back and Ctrl+Shift+Z
takes them again, with no exception.

---

## 4. M2 — One gesture, one step

The heart of the issue, and the milestone to review most carefully.

### 4.1 The settle pass joins the gesture's transaction

`_settleDocument` runs up to three `execute` calls on the debounce, each its own transaction. They
must merge onto whatever transaction the writer's gesture left behind. A `HistoryGroupingPolicy`
is the only merge hook `Editor` offers, and it is enough: the state owns a small policy object
with an `isSettling` flag, set around every `_settleDocument` call (and around `_syncSceneNumbers`,
same nature), which answers `TransactionMerge.mergeOnTop` while it is set and defers to the
default policies otherwise.

Two details the implementer must not get wrong:

- the flag is set around the `execute` calls themselves, not around the debounce, since
  `endTransaction` is what consults the policy, and it runs synchronously inside `execute`;
- `mergeOnTop` on an empty history falls through to "append as a new transaction"
  (`Editor.endTransaction`'s `_history.isEmpty` branch), which is exactly the load-time case
  §4.3 handles.

### 4.2 A settle triggered by an undo writes no history

Once §4.1 holds, the settle commands are part of the replayed history, so the document an undo
lands on is already settled and the follow-up settle should find nothing to do — no requests, no
`execute`, no transaction. **That is a claim to verify, not to assume**: it is the exact failure of
finding B, and the milestone does not pass until a test drives Tab → Ctrl+Z → Ctrl+Z on a
reclassifying edit and reads the intermediate documents.

Belt and braces, because the cost of being wrong is an editor that cannot be undone at all: the
state also carries a "the last document change came from undo/redo" flag, set by our own undo/redo
actions and cleared on the next genuine edit, and a settle running under it is executed with the
policy still in `isSettling` — i.e. merged into the transaction being restored rather than stacked
on top of it. If the verification above shows the settle is genuinely a no-op after an undo, this
flag stays anyway as the guard for the day a new derived pass is added.

### 4.3 Load-time normalization is not a step

`_syncSceneNumbers` runs immediately after `_rebuildEditorFrom` and corrects a badly ordered `#N#`
typed elsewhere. It happens before the writer has done anything, so it must not be the first undo
step — Ctrl+Z on a freshly opened screenplay would otherwise un-correct it.

`Editor` exposes no way to clear history, and `isHistoryEnabled` is `final`, so the only lever is
the commands' own `historyBehavior`. `OcptChangeNodeMetadataRequest` and `OcptReplaceNodeTextRequest`
therefore gain a `isHistorical` flag (default `true`), carried into their commands, and
`sceneNumberNormalizationRequests` is called with it `false` on the load path only. Everything else
keeps today's behaviour, and the flag is part of the requests' equality.

### 4.4 The typing window

Replace the default policy with
`HistoryGroupingPolicyList([mergeRepeatSelectionChangesPolicy, MergeRapidTextInputPolicy(<window>)])`
plus our settle policy. **Proposed window: 700 ms** — comfortably above a fast typist's inter-key
gap, well below the pause that means "I finished that sentence". A pause, a caret move, a
non-typing gesture or a paste all break the run on their own, since the policy only merges pure
text insertions.

This is a feel decision as much as a technical one, so it is a checkpoint item: the agent ships
700 ms, Benoit types in the real app, and the constant moves if it feels wrong. It is one number,
named once, in `ocpt_fountain_keyboard_actions.dart`'s neighbourhood.

### 4.5 What travels with the step

The issue lists `ocptTypeLocked`, `ocptBlankLinesBefore` and the scene-number metadata. They travel
for free once §4.1 holds — they are written by `OcptChangeNodeMetadataCommand`, which is
`undoable`, so undo's replay reproduces them exactly. The tests are what proves it, one per
metadata key, on the gesture that writes it.

### 4.6 The caret

`MutableDocumentComposer` is an `Editable` too, and `ChangeSelectionCommand` is undoable, so the
selection is restored by the same replay. What has to be checked is that it lands *where the undone
edit was* rather than where the caret happened to be, on the three cases that move it: an undone
Enter split, an undone paste, and an undone `Replace all`.

### 4.7 Autosave and the reported text

Nothing to do, and the reason belongs in the plan so nobody adds a special case: an undo is an
ordinary document change, `_onDocumentChanged` restarts the debounce, `_encodeAndReportIfChanged`
reports the restored text, and the 2 s autosave writes what is on screen. The editor is not
rebuilt from that report either — `_lastSyncedText` is updated by the same path — so the history
survives.

### 4.8 The performance gate

`Editor.undo()` is O(history): it resets the document to the snapshot taken when it was built and
replays every transaction but the last, and each undo re-runs `_syncAfterEdit`'s full encode. A
long writing session therefore makes Ctrl+Z progressively slower, and **the package offers no way
to cap the history length** — `_history` is private and never trimmed.

M2 must measure it rather than hope: on the demo project's feature-length screenplay
(`test/seed_demo_project.dart`, or `tool/screenshot-app.sh`'s own project), script a session of a
few hundred edits and time the first, hundredth and five-hundredth undo. If a Ctrl+Z after a
realistic morning's work costs more than a frame or two, say so at the checkpoint: the only
remedies are upstream (a `maxHistoryLength`, an inverse-command undo) and none of them is in scope
here.

---

## 5. M3 — Redo that cannot invent text

Finding D, fixed where we can fix it:

- exclude `redoWhenCmdShiftZOrCtrlShiftZIsPressed` from the inherited defaults, alongside the
  clipboard actions already excluded, and bind our own redo action (Ctrl+Shift+Z and Ctrl+Y);
- our action refuses when the redo stack is stale — a flag raised by `_onDocumentChanged` on any
  change that is not itself an undo or a redo, and lowered by an undo. `Editor.future` being
  non-empty is *not* sufficient, since that list is exactly what is never cleared;
- the same predicate is what any button in M4 reads for its enabled state, so it lives on the
  state and is exposed through `OcptStyledEditorController`, not duplicated.

Undo needs no such guard: it always pops a transaction that genuinely happened.

---

## 6. M4 — The affordances

Keyboard-only would already close the issue; making undo *visible* is a UI addition, and Benoit
settled its shape before this milestone was written:

- two entries in the screenplay `⋮` menu, `Undo` and `Redo`, each stating its shortcut on the
  right through `OcptToolbarMenuItemLabel`/`ocptPrimaryShortcutLabel`, exactly as `Find…` and
  `Find and replace…` do — no new toolbar icons, the toolbar being already dense;
- **active in both editing modes**, driven by whichever surface is showing (§7.2), never a menu
  whose entries appear and vanish with the mode;
- withheld, not disabled, when there is nothing to undo, and withheld entirely under a read-only
  preview (there is no editing surface there at all);
- two ARB keys per entry, in both `intl_en_GB.arb` and `intl_fr.arb`.

---

## 7. Raw mode — what it would cost

Benoit's question. The answer splits in three, and only the middle one is a real decision.

### 7.1 Ctrl+Z in raw mode already works, and costs nothing

`OcptEditorSourceField` is a plain `TextField`, so `EditableText` gives it Flutter's own
`UndoHistory` and `DefaultTextEditingShortcuts` binds Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z on Linux and
Windows. The page-level `Shortcuts` claims none of them, so they reach the field. **Cost: one
regression test** proving it, so a future page-level shortcut cannot silently steal them.

### 7.2 The same *affordances* in raw mode — small, half a milestone, and decided in

M4's menu entries work in whichever mode is showing — a menu that answers only half the time is
worse than no menu. Part of M4, not an option. That means:

- the page state owns an `UndoHistoryController`, handed to `OcptEditorSourceField` and to the
  `TextField`'s `undoController` — it is a `ValueNotifier<UndoHistoryValue>` exposing
  `canUndo`/`canRedo`, which is exactly what drives the entries' withheld state;
- `OcptStyledEditorController` gains `canUndo`/`canRedo`/`undo()`/`redo()`, forwarded to its
  delegate, so the page asks *the active surface* rather than branching on the mode in two places;
- the menu entries call one or the other depending on `state.mode`.

No new dependency, no new widget, no super_editor import outside its directory. Roughly the size
of the format-controls bridge that already exists.

One wrinkle to accept rather than fix: Flutter's `UndoHistoryController` has no "clear" API, and
`_onStateChanged` pushes text into the raw controller programmatically (initial load, an edit made
in styled mode, an import, a version restore). Those pushes enter the field's undo stack, so Ctrl+Z
in raw mode can walk back to a text the writer never typed. That is today's behaviour already, it
is bounded by the session, and the alternative — swapping the controller on every programmatic
push — would throw away the writer's own raw-mode history at each mode toggle.

### 7.3 One history shared across both modes — expensive, and left out

Making a single stack survive a raw ⇄ styled toggle is a different project: the styled editor is
rebuilt wholesale on the toggle (and on an episode switch), so the stack would have to live above
both, in the bloc, as full Fountain snapshots plus a caret mapping between a source offset and a
document position — the very mapping `OcptWysiwygLineMapping` only does best-effort, per ADR 0012.
It would also have to override, not cooperate with, both engines' own stacks.

The honest framing for the writer: **the undo history belongs to the editing surface, and switching
surface starts a fresh one**, which is what every editor with two views does. Out of scope.

---

## 8. Out of scope

- Undo in the other production modes. The issue already says it: those write straight to the
  database, and the answer there is `OcptConfirmDialog` plus the project versions.
- Undoing a screenplay import, a version restore or an episode switch. Each of those replaces the
  document wholesale and already has its own confirmation or its own version entry.
- Any change to `actlibs/` or to the pinned super_editor. Findings A and D are package bugs; if
  they are worth reporting upstream, that is a separate task and the workaround stands either way.

---

## 9. Tests

Beyond each milestone's own, the cases that must exist before this ships, all on the standalone
styled editor harness (`ocpt_styled_screenplay_editor_test.dart`'s `_pumpStandaloneEditor`,
`_sendCtrl`, `BlinkController.indeterminateAnimationsEnabled = false`):

- typing a run, one Ctrl+Z, the whole run is gone — under `withClock` so the merge window is not
  at the mercy of the test VM's real-time gaps, which is what made the spike's unfrozen run undo
  one character at a time;
- Tab, one Ctrl+Z: type, lock and text all back to what they were, and a second Ctrl+Z goes to the
  step before rather than doing nothing;
- typing `EXT. …` in front of an action line, one Ctrl+Z: no half-reclassified state, no orphan
  uppercase;
- an Enter split and a Fountain paste, undone in one step each, caret included;
- a refused title-page edit (Backspace at the start of `Credit`) followed by Ctrl+Z: the undo skips
  it and reaches the writer's previous real edit;
- undo → new edit → redo: the redo is refused and the text is untouched;
- `Replace all` undone in one step;
- a freshly loaded screenplay with a badly ordered `#N#`: Ctrl+Z does not un-normalize it;
- raw mode's Ctrl+Z still reaching the field (§7.1).

---

## 10. Verification

Every milestone runs the eight code gates before its commit, and `dart run tool/check_markdown.dart`
whenever it touches a `.md` file. No schema change, no ARB change before M4.

Screenshots for a checkpoint come from `tool/screenshot-app.sh`, never from launching the app by
hand.

---

## 11. When this is done

Delete this file. `docs/architecture/screenplay.md` records what one undo step is, the settle-merge
policy, the typing window, the redo guard and the per-surface history rule. The code, that file and
the ADRs are the record from then on.
