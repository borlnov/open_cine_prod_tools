// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// A total, paired with how many of the rows it was asked to sum actually carried a known rate —
/// `lib/models/rules/ocpt_budget_vat.dart`'s "null, never zero" rule applied to a whole table: a
/// row whose rate nobody has recorded contributes to neither [amountCents] nor [coveredLineCount],
/// so the coverage the UI reports (`10,349 € · over 2 of the 5 postes`) is a plain fact about the
/// data, not a string this class formats.
///
/// **A "line" here is any row a total was asked to sum** — a quote line
/// (`ocptBudgetExcludingTaxTotalOf`/`ocptBudgetTotalOf`), a journal entry
/// (`lib/models/rules/ocpt_budget_journal.dart`), a commitment
/// (`lib/models/rules/ocpt_budget_projection.dart`) or a catering-and-travel figure
/// (`lib/models/rules/ocpt_budget_regie.dart`) — a day's own meals and buffet, or a traveller's own
/// mileage reimbursement: this class is shared across every one of them rather than reimplemented
/// per table, since the coverage arithmetic and the honesty it argues for are exactly the same
/// regardless of what is being priced.
///
/// **No `Tr` and no formatted string here** — `lib/models/rules/` is pure; the mode's own view
/// resolves the words.
class OcptBudgetCoveredTotal extends Equatable {
  /// The sum of every covered line's own total, in cents.
  final int amountCents;

  /// How many of [lineCount] lines — a quote line, a journal entry or a commitment — actually
  /// carried a known rate and were summed into [amountCents].
  final int coveredLineCount;

  /// How many lines — quote lines, journal entries or commitments, whichever this total sums —
  /// were asked for, covered or not.
  final int lineCount;

  /// Tell whether every line carried a known rate — [coveredLineCount] equals [lineCount]. Once
  /// true,
  /// the UI stops saying how many lines the figure covers: it has become the complete answer.
  bool get isComplete => coveredLineCount == lineCount;

  /// Class constructor
  const OcptBudgetCoveredTotal({
    required this.amountCents,
    required this.coveredLineCount,
    required this.lineCount,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetCoveredTotal(amountCents: $amountCents, coveredLineCount: $coveredLineCount, "
      "lineCount: $lineCount)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [amountCents, coveredLineCount, lineCount];
}
