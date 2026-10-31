// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';

/// The cash journal's own totals: [debitCents] and [creditCents] summed **row by row, then summed**
/// (`docs/architecture/budget.md`'s own law), each already read tax-inclusive, paired with how many
/// of [entryCount] entries actually contributed to them.
class OcptBudgetCashTotals extends Equatable {
  /// The sum of every covered entry's own tax-inclusive [OcptBudgetEntry.debitCents].
  final int debitCents;

  /// The sum of every covered entry's own tax-inclusive [OcptBudgetEntry.creditCents].
  final int creditCents;

  /// How many of [entryCount] entries actually carried a known rate and were summed into
  /// [debitCents] and [creditCents].
  final int coveredEntryCount;

  /// How many entries this total was asked to sum, covered or not.
  final int entryCount;

  /// The journal's own balance: [creditCents] minus [debitCents], negative once the journal is, on
  /// balance, a cost.
  int get balanceCents => creditCents - debitCents;

  /// Whether every entry carried a known rate — [coveredEntryCount] equals [entryCount].
  bool get isComplete => coveredEntryCount == entryCount;

  /// Class constructor
  const OcptBudgetCashTotals({
    required this.debitCents,
    required this.creditCents,
    required this.coveredEntryCount,
    required this.entryCount,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetCashTotals(debitCents: $debitCents, creditCents: $creditCents, "
      "coveredEntryCount: $coveredEntryCount, entryCount: $entryCount)";

  /// Object properties
  @override
  List<Object?> get props => [debitCents, creditCents, coveredEntryCount, entryCount];
}
