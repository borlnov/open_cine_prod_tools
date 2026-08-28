// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';

/// A budget poste (a CNC chapter, or one the user added of their own) with the quote lines it
/// holds.
///
/// **No `quotedAmount` field**: a poste's quoted amount is the sum of [lines], computed by
/// `lib/utils/ocpt_budget_totals.dart`, and is never stored — see `OcptBudgetPostesTable`'s own doc
/// comment. [estimateToCompleteCents] is not a counter-example, for the same reason argued there:
/// it is a human's judgement about the future, derivable from nothing [lines] holds, and its null
/// means "nobody has judged", not zero.
class OcptBudgetPoste extends Equatable {
  /// The stable, unique id of this poste (a UUID).
  final String id;

  /// The CNC poste number as printed, free text.
  final String code;

  /// This poste's display name.
  final String label;

  /// This poste's name in the mode's simplified header state, or null — see
  /// `OcptBudgetPostesTable.simpleLabel`'s own doc comment for why null falls back to [label]
  /// rather than meaning "no name at all".
  final String? simpleLabel;

  /// This poste's position within the catalogue's own flat `sortKey` order.
  final String sortKey;

  /// The quote lines this poste holds, in `sortKey` order.
  final List<OcptBudgetLine> lines;

  /// What is still expected to be spent on this poste beyond what has already been paid and
  /// committed against it, in cents, typed by a human — or null, meaning "derive it". See
  /// `OcptBudgetPostesTable.estimateToCompleteCents`'s own doc comment for why null is not zero, and
  /// `ocptBudgetEstimateToCompleteCents` (`lib/utils/ocpt_budget_totals.dart`) for the derivation.
  final int? estimateToCompleteCents;

  /// Class constructor
  const OcptBudgetPoste({
    required this.id,
    required this.code,
    required this.label,
    required this.simpleLabel,
    required this.sortKey,
    required this.lines,
    required this.estimateToCompleteCents,
  });

  /// Builds an [OcptBudgetPoste] from its stored [row] and the [lines] it holds.
  factory OcptBudgetPoste.fromRow({
    required OcptBudgetPosteRow row,
    required List<OcptBudgetLine> lines,
  }) => OcptBudgetPoste(
    id: row.id,
    code: row.code,
    label: row.label,
    simpleLabel: row.simpleLabel,
    sortKey: row.sortKey,
    lines: lines,
    estimateToCompleteCents: row.estimateToCompleteCents,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetPoste(id: $id, code: $code, label: $label, "
      "lines: ${lines.length})";

  /// Object properties
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
