// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';

/// One quoted line of the budget: a quantity of something, at a unit price, inside a poste. See
/// `OcptBudgetLinesTable`'s own doc comment for the money and quantity representation this mirrors.
class OcptBudgetLine extends Equatable {
  /// The stable, unique id of this line (a UUID).
  final String id;

  /// The poste this line belongs to. → `OcptBudgetPoste`
  final String posteId;

  /// This line's display name.
  final String label;

  /// The quantity this line prices, in thousandths (1.5 day is 1500, 1,484 km is 1484000).
  final int quantityMilli;

  /// The unit [quantityMilli] is counted in, free text.
  final String unit;

  /// The unit price this line was typed at, and the tax basis and rate it carries.
  final OcptMoney unitPrice;

  /// The breakdown element this line prices, or null — read by no service before M3.
  final String? elementId;

  /// Free-form notes about this line.
  final String notes;

  /// This line's position within its poste's own flat `sortKey` order.
  final String sortKey;

  /// Class constructor
  const OcptBudgetLine({
    required this.id,
    required this.posteId,
    required this.label,
    required this.quantityMilli,
    required this.unit,
    required this.unitPrice,
    required this.elementId,
    required this.notes,
    required this.sortKey,
  });

  /// Builds an [OcptBudgetLine] from its stored [row].
  factory OcptBudgetLine.fromRow(OcptBudgetLineRow row) => OcptBudgetLine(
    id: row.id,
    posteId: row.posteId,
    label: row.label,
    quantityMilli: row.quantityMilli,
    unit: row.unit,
    unitPrice: OcptMoney(
      amountCents: row.unitAmountCents,
      isTaxInclusive: row.isTaxInclusive,
      vatRateBasisPoints: row.vatRateBasisPoints,
    ),
    elementId: row.elementId,
    notes: row.notes,
    sortKey: row.sortKey,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetLine(id: $id, posteId: $posteId, label: $label)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    posteId,
    label,
    quantityMilli,
    unit,
    unitPrice,
    elementId,
    notes,
    sortKey,
  ];
}
