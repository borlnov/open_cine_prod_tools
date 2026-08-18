// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:super_editor/super_editor.dart';

/// How far apart two consecutive text insertions may be, in wall-clock time, and still be given
/// back by a single Ctrl+Z.
///
/// super_editor's own [mergeRapidTextInputPolicy] uses 100 ms, which is shorter than the gap
/// between two keystrokes of a 60 wpm hand (~200 ms): every character would then be its own undo
/// step. This value is comfortably above a fast typist's inter-key gap and well below the pause
/// that means "I finished that sentence" — and it is only ever the *upper* bound of a run, since
/// [MergeRapidTextInputPolicy] refuses to merge anything but pure text insertions, so a caret
/// move, an Enter, a Tab, a paste or a deletion all end the run on their own whatever the timing.
const Duration ocptTypingMergeWindow = Duration(milliseconds: 700);

/// The `historyGroupingPolicy` the styled screenplay editor's `Editor` runs on: what decides
/// where one Ctrl+Z stops.
///
/// One undo step is **one gesture of the writer's, plus everything the editor derived from it** —
/// a keystroke run, an Enter, a Tab, a dropdown pick, a paste or a replace, together with the
/// reclassification, the uppercasing, the `#N#` renumbering and the metadata the editor computed
/// *because* of it. Never the derived half alone.
///
/// Those derived passes run 120 ms after the gesture, on a debounce, and each of their `execute`
/// calls would otherwise be a transaction of its own stacked on top of the gesture's — which is
/// what makes a manual Tab impossible to undo at all: Ctrl+Z would pop the derived transaction,
/// the document would change, the debounce would restart, and the pass would re-derive exactly
/// what was just undone and push it back as a *new* transaction, forever. A
/// [HistoryGroupingPolicy] is the only merge hook `Editor` offers, so this class is how a derived
/// pass joins the transaction that caused it: [runDerivedPass] raises [isSettling] around the
/// `execute` calls themselves (never around the debounce — `Editor.endTransaction` is what
/// consults the policy, and it runs synchronously inside `execute`), and every transaction closed
/// while it is up merges onto the one before it.
///
/// Outside a derived pass this defers to super_editor's own two policies, exactly as
/// `defaultMergePolicy` does, with [ocptTypingMergeWindow] in place of their 100 ms default.
///
/// Note that `mergeOnTop` on an *empty* history means "append as a new transaction"
/// (`Editor.endTransaction`'s `_history.isEmpty` branch), so a derived pass that runs before the
/// writer has touched anything — the load-time scene-number normalization — cannot be kept out of
/// history by this class at all: that one is refused history by its own commands instead (see
/// `sceneNumberNormalizationRequests`'s `isHistorical`).
class OcptSettleMergePolicy implements HistoryGroupingPolicy {
  /// Creates an [OcptSettleMergePolicy].
  OcptSettleMergePolicy();

  /// The policies a transaction closed outside a derived pass is judged by: super_editor's own
  /// repeat-selection policy, plus this app's own typing-run policy in place of
  /// [MergeRapidTextInputPolicy] (see [OcptTypingRunMergePolicy] for why the stock one cannot be
  /// used here).
  static const _writerGesturePolicies = HistoryGroupingPolicyList([
    mergeRepeatSelectionChangesPolicy,
    OcptTypingRunMergePolicy(ocptTypingMergeWindow),
  ]);

  /// Whether a derived pass is currently executing, i.e. whether the transaction being closed
  /// belongs to the editor's own settle/renumber/repaginate work rather than to a gesture of the
  /// writer's. Raised only by [runDerivedPass].
  bool get isSettling => _isSettling;
  bool _isSettling = false;

  /// Runs [derivedPass] with [isSettling] raised, so every transaction it closes merges onto the
  /// transaction that caused it instead of becoming an undo step of its own.
  ///
  /// Re-entrant on purpose (the flag is restored, not cleared): a settle pass can trigger a
  /// document change whose own listener schedules another one, and the outer pass must not lose
  /// its flag when an inner one finishes.
  void runDerivedPass(void Function() derivedPass) {
    final wasSettling = _isSettling;
    _isSettling = true;
    try {
      derivedPass();
    } finally {
      _isSettling = wasSettling;
    }
  }

  /// Merges every transaction closed during a derived pass onto the one before it; defers to
  /// [_writerGesturePolicies] for every other transaction.
  @override
  TransactionMerge shouldMergeLatestTransaction(
    CommandTransaction newTransaction,
    CommandTransaction previousTransaction,
  ) => _isSettling
      ? TransactionMerge.mergeOnTop
      : _writerGesturePolicies.shouldMergeLatestTransaction(newTransaction, previousTransaction);
}

/// The [HistoryGroupingPolicy] that keeps a run of typing one undo step: this app's replacement
/// for super_editor's own [MergeRapidTextInputPolicy].
///
/// The stock policy merges two transactions only when **both** of them consist of nothing but
/// text insertions. That holds for a plain sentence, but not for the very lines a screenplay
/// editor exists to write: the moment a run reads as a scene heading, a character cue or a
/// transition, [OcptSettleMergePolicy] merges the derived reclassification and uppercasing onto
/// the run's own transaction — and from then on the stock policy sees a *previous* transaction
/// that is no longer pure text input and refuses to merge anything else onto it. Measured on the
/// real editor: typing `Ext. house - day` that way takes **nine** Ctrl+Z to take back, one per
/// character typed after the line first classified as a heading, which is precisely the "never
/// the derived half alone" rule this whole policy exists to enforce, broken from the other end.
///
/// So this one asks the question that actually matters: is the transaction being closed a pure
/// continuation of typing, and was the one before it *a run of typing* — whatever the editor
/// derived onto it afterwards? The previous transaction therefore only has to **contain** a text
/// insertion, not consist solely of them. Everything else is the stock policy's own rule,
/// deliberately unchanged: a transaction carrying any non-insertion change of its own (an Enter
/// split, a Tab, a Backspace, a paste, a block-type pick) never merges, so a gesture that is not
/// typing always starts its own undo step, and so does typing that resumes more than
/// [maxMergeTime] after the previous run stopped.
class OcptTypingRunMergePolicy implements HistoryGroupingPolicy {
  /// Creates an [OcptTypingRunMergePolicy] merging runs no more than [maxMergeTime] apart.
  const OcptTypingRunMergePolicy(this.maxMergeTime);

  /// How far apart two consecutive text insertions may be and still be merged into one undo step.
  final Duration maxMergeTime;

  /// The changes of [transaction] that actually touch the document, i.e. everything but the
  /// selection and composing-region bookkeeping every transaction carries (mirrors
  /// [MergeRapidTextInputPolicy]'s own filter).
  static Iterable<EditEvent> _contentChangesOf(CommandTransaction transaction) =>
      transaction.changes.where((change) => change is! SelectionChangeEvent && change is! ComposingRegionChangeEvent);

  /// Whether [change] is a character (or several) being inserted into a node's text.
  static bool _isTextInsertion(EditEvent change) => change is DocumentEdit && change.change is TextInsertionEvent;

  /// Merges [newTransaction] onto [previousTransaction] when the former is nothing but text
  /// insertions, the latter contains at least one, and they happened within [maxMergeTime] of each
  /// other.
  @override
  TransactionMerge shouldMergeLatestTransaction(
    CommandTransaction newTransaction,
    CommandTransaction previousTransaction,
  ) {
    final newContentChanges = _contentChangesOf(newTransaction).toList();
    if (newContentChanges.isEmpty || !newContentChanges.every(_isTextInsertion)) {
      // Either nothing was typed at all (a pure selection move: let another policy decide), or
      // this transaction did something other than type — which always starts its own undo step.
      return TransactionMerge.noOpinion;
    }

    if (!_contentChangesOf(previousTransaction).any(_isTextInsertion)) {
      // The previous transaction was not a run of typing (a Tab, an Enter split, a paste, a
      // deletion, or a derived pass of the editor's own), so this run starts a fresh step.
      return TransactionMerge.noOpinion;
    }

    if (newTransaction.firstChangeTime.difference(previousTransaction.lastChangeTime) > maxMergeTime) {
      // The writer stopped typing long enough for this to be a new thought.
      return TransactionMerge.noOpinion;
    }

    return TransactionMerge.mergeOnTop;
  }
}
