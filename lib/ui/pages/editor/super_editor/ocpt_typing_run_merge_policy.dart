// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_settle_merge_policy.dart';
import 'package:super_editor/super_editor.dart';

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
  /// How far apart two consecutive text insertions may be and still be merged into one undo step.
  final Duration maxMergeTime;

  /// Creates an [OcptTypingRunMergePolicy] merging runs no more than [maxMergeTime] apart.
  const OcptTypingRunMergePolicy(this.maxMergeTime);

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

    if (newTransaction.firstChangeTime.difference(previousTransaction.lastChangeTime) >
        maxMergeTime) {
      // The writer stopped typing long enough for this to be a new thought.
      return TransactionMerge.noOpinion;
    }

    return TransactionMerge.mergeOnTop;
  }

  /// The changes of [transaction] that actually touch the document, i.e. everything but the
  /// selection and composing-region bookkeeping every transaction carries (mirrors
  /// [MergeRapidTextInputPolicy]'s own filter).
  static Iterable<EditEvent> _contentChangesOf(CommandTransaction transaction) => transaction
      .changes
      .where((change) => change is! SelectionChangeEvent && change is! ComposingRegionChangeEvent);

  /// Whether [change] is a character (or several) being inserted into a node's text.
  static bool _isTextInsertion(EditEvent change) =>
      change is DocumentEdit && change.change is TextInsertionEvent;
}
