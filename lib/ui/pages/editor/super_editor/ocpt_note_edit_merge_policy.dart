// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:super_editor/super_editor.dart';

/// The [HistoryGroupingPolicy] that keeps what is done to one note, from the card of the margin,
/// in one undo step: the creation of the note, every change of its text, and the removal of the
/// note when it is left empty.
///
/// The policy cannot tell by itself which transactions are edits of a note, since they are
/// ordinary text replacements. The code making the edit says so, by running it through [runEdit]
/// with a token naming the note: a transaction closed in there merges onto the one before it when
/// that one was an edit under the same token, and starts a step of its own otherwise. The token
/// stays alive across the selection changes the writer makes in the meantime (which the stock
/// policy merges onto the last content change) and ends with the first other change of the
/// document, an undo or a redo, and [endSession].
class OcptNoteEditMergePolicy implements HistoryGroupingPolicy {
  /// The token of the edit being executed, or null outside [runEdit].
  String? _runningToken;

  /// The token of the last content transaction, when it was a note edit.
  String? _lastToken;

  /// Create an [OcptNoteEditMergePolicy].
  OcptNoteEditMergePolicy();

  /// Run [edit], an `Editor.execute` call, as an edit of the note [token] names: the transaction
  /// it closes merges onto the previous one when that was an edit of the same note.
  void runEdit(String token, void Function() edit) {
    final wasRunning = _runningToken;
    _runningToken = token;
    try {
      edit();
    } finally {
      _runningToken = wasRunning;
      _lastToken = token;
    }
  }

  /// End the current session of edits: the next edit of any note starts an undo step of its own.
  void endSession() => _lastToken = null;

  /// Merge [newTransaction] onto [previousTransaction] when it is an edit of the note the previous
  /// one edited, and give no opinion otherwise.
  @override
  TransactionMerge shouldMergeLatestTransaction(
    CommandTransaction newTransaction,
    CommandTransaction previousTransaction,
  ) {
    final token = _runningToken;
    if (token != null) {
      return token == _lastToken ? TransactionMerge.mergeOnTop : TransactionMerge.noOpinion;
    }

    final hasContentChange = newTransaction.changes.any(
      (change) => change is! SelectionChangeEvent && change is! ComposingRegionChangeEvent,
    );
    if (hasContentChange) {
      _lastToken = null;
    }
    return TransactionMerge.noOpinion;
  }
}
