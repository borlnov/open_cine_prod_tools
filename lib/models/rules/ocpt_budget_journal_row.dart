// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';

/// One row of the cash journal view: [entry] itself, its debit and credit read tax-inclusive, and
/// the running balance once it has fallen — each null together when [entry] cannot be read.
class OcptBudgetJournalRow extends Equatable {
  /// The entry this row prints.
  final OcptBudgetEntry entry;

  /// [entry]'s own [OcptBudgetEntry.debitCents], read tax-inclusive, or null when unreadable.
  final int? debitCents;

  /// [entry]'s own [OcptBudgetEntry.creditCents], read tax-inclusive, or null when unreadable.
  final int? creditCents;

  /// The running balance once [entry] has been taken into account, or null when [entry] is
  /// unreadable — see [ocptBudgetJournalRowsOf]'s own doc comment for why a hole in this one
  /// column, rather than a guess, is what an unreadable movement earns.
  final int? balanceAfterCents;

  /// Class constructor
  const OcptBudgetJournalRow({
    required this.entry,
    required this.debitCents,
    required this.creditCents,
    required this.balanceAfterCents,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetJournalRow(entry: ${entry.id}, debitCents: $debitCents, "
      "creditCents: $creditCents, balanceAfterCents: $balanceAfterCents)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [entry, debitCents, creditCents, balanceAfterCents];
}
