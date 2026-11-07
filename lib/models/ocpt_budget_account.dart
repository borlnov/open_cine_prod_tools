// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';

/// A budget account (a CNC chapter, or one the user added of their own) with the quote lines it
/// holds.
///
/// **No `quotedAmount` field**: an account's quoted amount is the sum of [lines], computed by
/// `lib/models/rules/ocpt_budget_totals.dart`, and is never stored — see
/// `OcptBudgetAccountsTable`'s own doc comment. [estimateToCompleteCents] is not a counter-example,
/// for the same reason argued there: it is a human's judgement about the future, derivable from
/// nothing [lines] holds, and its null means "nobody has judged", not zero.
class OcptBudgetAccount extends Equatable {
  /// The stable, unique id of this account (a UUID).
  final String id;

  /// The CNC account number as printed, free text.
  final String code;

  /// This account's display name.
  final String label;

  /// This account's name in the mode's simplified header state, or null — see
  /// `OcptBudgetAccountsTable.simpleLabel`'s own doc comment for why null falls back to [label]
  /// rather than meaning "no name at all".
  final String? simpleLabel;

  /// This account's position within the catalogue's own flat `sortKey` order.
  final String sortKey;

  /// The quote lines this account holds, in `sortKey` order.
  final List<OcptBudgetLine> lines;

  /// What is still expected to be spent on this account beyond what has already been paid and
  /// committed against it, in cents, typed by a human — or null, meaning "derive it". See
  /// `OcptBudgetAccountsTable.estimateToCompleteCents`'s own doc comment for why null is not zero,
  /// and `ocptBudgetEstimateToCompleteCents` (`lib/models/rules/ocpt_budget_totals.dart`) for the
  /// derivation.
  final int? estimateToCompleteCents;

  /// Class constructor
  const OcptBudgetAccount({
    required this.id,
    required this.code,
    required this.label,
    required this.simpleLabel,
    required this.sortKey,
    required this.lines,
    required this.estimateToCompleteCents,
  });

  /// Build an [OcptBudgetAccount] from its stored [row] and the [lines] it holds.
  factory OcptBudgetAccount.fromRow({
    required OcptBudgetAccountRow row,
    required List<OcptBudgetLine> lines,
  }) => OcptBudgetAccount(
    id: row.id,
    code: row.code,
    label: row.label,
    simpleLabel: row.simpleLabel,
    sortKey: row.sortKey,
    lines: lines,
    estimateToCompleteCents: row.estimateToCompleteCents,
  );

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetAccount(id: $id, code: $code, label: $label, "
      "lines: ${lines.length})";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [
    id,
    code,
    label,
    simpleLabel,
    sortKey,
    lines,
    estimateToCompleteCents,
  ];
}
