// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';

/// One defrayal the production owes somebody back. See `OcptBudgetAllowancesTable`'s own doc
/// comment for why nothing here is deduced from the schedule, and why a person's own commute and
/// mileage rate only ever pre-fill this row rather than deciding it.
class OcptBudgetAllowance extends Equatable {
  /// The stable, unique id of this defrayal (a UUID).
  final String id;

  /// The person this defrayal is owed to, or null.
  final String? personId;

  /// What this defrayal is for.
  final OcptBudgetAllowanceKind kind;

  /// This defrayal's free-text wording.
  final String label;

  /// The day this defrayal applies to, or the day a stay begins — null while nobody has said.
  final DateTime? date;

  /// The day a stay ends, or null — normally null, only a stay spanning two dates carries one.
  final DateTime? endDate;

  /// How many kilometres, nights or meals this defrayal covers, in thousandths.
  final int quantityMilli;

  /// What one kilometre, night or meal is paid back at, in thousandths of a cent.
  final int unitAmountMilliCents;

  /// Free-form notes about this defrayal.
  final String notes;

  /// This defrayal's position within the régie view's own flat `sortKey` order.
  final String sortKey;

  /// Class constructor
  const OcptBudgetAllowance({
    required this.id,
    required this.personId,
    required this.kind,
    required this.label,
    required this.date,
    required this.endDate,
    required this.quantityMilli,
    required this.unitAmountMilliCents,
    required this.notes,
    required this.sortKey,
  });

  /// Builds an [OcptBudgetAllowance] from its stored [row].
  factory OcptBudgetAllowance.fromRow(OcptBudgetAllowanceRow row) => OcptBudgetAllowance(
    id: row.id,
    personId: row.personId,
    kind: row.kind,
    label: row.label,
    date: row.date,
    endDate: row.endDate,
    quantityMilli: row.quantityMilli,
    unitAmountMilliCents: row.unitAmountMilliCents,
    notes: row.notes,
    sortKey: row.sortKey,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetAllowance(id: $id, personId: $personId, kind: $kind, label: $label, "
      "quantityMilli: $quantityMilli, unitAmountMilliCents: $unitAmountMilliCents)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    personId,
    kind,
    label,
    date,
    endDate,
    quantityMilli,
    unitAmountMilliCents,
    notes,
    sortKey,
  ];
}
