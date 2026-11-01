// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_settle_merge_policy.dart';
import 'package:super_editor/super_editor.dart';

/// The undo and redo handling of a styled editor: the grouping policy its editors run on, and the
/// two flags that tell a restored document apart from an edit of the writer's.
///
/// The editor is resolved through a callback at call time, since the styled editor replaces it
/// whenever its text is rebuilt from outside.
final class OcptStyledHistory {
  /// Creates an [OcptStyledHistory].
  OcptStyledHistory({
    required Editor Function() editorOf,
    required void Function() syncSceneNumbers,
    required void Function() reportReadState,
  }) : mergePolicy = OcptSettleMergePolicy(),
       _isRedoStackStale = false,
       _isApplyingHistory = false,
       _editorOf = editorOf,
       _syncSceneNumbers = syncSceneNumbers,
       _reportReadState = reportReadState;

  /// Resolves the editor whose history is undone and redone.
  final Editor Function() _editorOf;

  /// Renumbers the scene headings of a restored document.
  final void Function() _syncSceneNumbers;

  /// Reports the fresh history state to the toolbar.
  final void Function() _reportReadState;

  /// The editor whose history is undone and redone.
  Editor get _editor => _editorOf();

  /// The undo-grouping policy every editor this state builds runs on: what makes one Ctrl+Z
  /// give back one gesture of the writer's plus everything this widget derived from it, rather
  /// than one keystroke or one derived pass (see [OcptSettleMergePolicy]).
  ///
  /// Owned here rather than built per [Editor]: it carries the "a derived pass is running
  /// right now" flag [runDerivedPass] raises, which every derived pass has to reach.
  final OcptSettleMergePolicy mergePolicy;

  /// Whether the transactions the editor's `future` list still holds have been overtaken by an
  /// edit made since they were undone, i.e. whether a redo would replay them onto a document that
  /// has moved on (see [canRedo]).
  ///
  /// `Editor` never clears that list itself — its own `future` getter documents that it should,
  /// and no code in the package does it — so its emptiness says nothing about whether a redo is
  /// still meaningful. This flag is what says it instead: raised by [markRedoStale] on every
  /// change that is neither an undo/redo of ours nor a pass this widget derived, lowered by
  /// [undo].
  bool _isRedoStackStale;

  /// Whether [undo] or [redo] is currently applying a change to the document, which is how
  /// the document listener tells a restored document apart from an edit of the writer's: an undo
  /// or a redo must not mark its own document change as one that invalidates the redo stack.
  bool _isApplyingHistory;

  /// Whether [undo] or [redo] is currently applying a change, which is how the document listener
  /// tells a restored document apart from an edit of the writer's.
  bool get isApplying => _isApplyingHistory;

  /// Marks the redo stack as overtaken by an edit made since the last undo.
  void markRedoStale() => _isRedoStackStale = true;

  /// Clears the stale flag: a fresh `Editor` starts with an empty history and an empty future, so
  /// nothing can be stale about a redo stack that does not exist yet.
  void reset() => _isRedoStackStale = false;

  /// Runs [derivedPass] — any pass that writes back to the document what this widget *derived* from
  /// the writer's last gesture, rather than what the writer did — with [mergePolicy]'s settling
  /// flag raised, so every transaction it closes merges onto the gesture's own instead of becoming
  /// an undo step of its own.
  ///
  /// The flag has to go around the `execute` calls themselves, never around the debounce that
  /// schedules them: `Editor.endTransaction` is what consults the policy, and it runs
  /// synchronously inside `execute`.
  void runDerivedPass(void Function() derivedPass) => mergePolicy.runDerivedPass(derivedPass);

  /// Whether there is a gesture of the writer's left to take back, i.e. whether the `⋮` menu's
  /// `Undo` entry has anything to offer.
  bool get canUndo => _editor.history.isNotEmpty;

  /// Whether the last undone gesture can still be put back: there is one to put back, *and* no
  /// edit has been made since it was undone (see [_isRedoStackStale] for why the second half
  /// cannot be read off `Editor.future` alone).
  bool get canRedo => !_isRedoStackStale && _editor.future.isNotEmpty;

  /// Takes back the writer's last gesture, plus everything this widget derived from it (see
  /// [OcptSettleMergePolicy] for what makes those one step).
  ///
  /// The staleness flag is lowered *before* the undo runs, not after: the document listener fires
  /// synchronously from inside `Editor.undo()`, and it is what reports [canRedo] to the
  /// controller — reading it a moment too early would report a redo that is available as refused.
  void undo() {
    if (!canUndo) {
      return;
    }

    _isRedoStackStale = false;
    _applyHistoryChange(_editor.undo);
  }

  /// Puts back the last undone gesture, or does nothing at all when [canRedo] refuses.
  ///
  /// That refusal is the whole point of this method existing rather than `Editor.redo()` being
  /// bound straight to Ctrl+Shift+Z: replaying a transaction that a later edit has overtaken
  /// writes text the writer never wrote (see `ocptRedoAction`).
  void redo() {
    if (!canRedo) {
      return;
    }

    _applyHistoryChange(_editor.redo);
  }

  /// Runs [historyChange] — `Editor.undo` or `Editor.redo` — with [_isApplyingHistory] raised, so
  /// the document change it makes is not mistaken for an edit of the writer's, renumbers the
  /// scene headings inside that same window, then reports the fresh history state to the
  /// controller (a no-op when neither [canUndo] nor [canRedo] moved,
  /// `OcptStyledEditorController.updateReadState` only notifying on an actual change).
  ///
  /// That renumbering is not a detail: `Editor.undo()`/`redo()` restore every `Editable` to the
  /// snapshot `MutableDocument` took in its own constructor and replay the historical
  /// transactions, and the load-time scene numbering pass' load-time pass is deliberately *not* one of them, so
  /// every restore drops what it had corrected — on any screenplay whose headings the editor
  /// numbered when it opened them, which is every screenplay written without `#N#` tags by hand.
  /// Left to the debounced settle to notice instead, that renumbering would come back as a
  /// document change of its own: it would mark the redo stack stale (no redo would ever survive
  /// an undo) and, once the history is empty again, append a transaction whose only content is a
  /// numbering nobody asked to change — an undo step that un-numbers the screenplay. Re-derived
  /// here, non-historically and while [_isApplyingHistory] is still raised, it is simply part of
  /// the state being restored, and the settle that follows finds nothing left to do.
  void _applyHistoryChange(void Function() historyChange) {
    _isApplyingHistory = true;
    try {
      historyChange();
      _syncSceneNumbers();
    } finally {
      _isApplyingHistory = false;
    }
    _reportReadState();
  }
}
