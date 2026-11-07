// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_typing_run_merge_policy.dart';
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
/// pass joins the transaction that caused it: [runDerivedPass] raises a flag around the
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
  bool _isSettling;

  /// Create an [OcptSettleMergePolicy].
  OcptSettleMergePolicy() : _isSettling = false;

  /// Run [derivedPass] with the settling flag raised, so every transaction it closes merges onto
  /// the transaction that caused it instead of becoming an undo step of its own.
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

  /// Merge every transaction closed during a derived pass onto the one before it; defers to
  /// [_writerGesturePolicies] for every other transaction.
  @override
  TransactionMerge shouldMergeLatestTransaction(
    CommandTransaction newTransaction,
    CommandTransaction previousTransaction,
  ) => _isSettling
      ? TransactionMerge.mergeOnTop
      : _writerGesturePolicies.shouldMergeLatestTransaction(newTransaction, previousTransaction);
}
