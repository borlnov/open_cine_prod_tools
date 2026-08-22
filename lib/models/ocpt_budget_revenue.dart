// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';

/// One taking the production expects. See `OcptBudgetRevenuesTable`'s own doc comment for the two
/// things this model deliberately does **not** carry: what has actually come in (derived from the
/// journal, never stored) and a tax basis (a revenue is money coming in, always read
/// tax-inclusive).
class OcptBudgetRevenue extends Equatable {
  /// The stable, unique id of this revenue (a UUID).
  final String id;

  /// The date this taking is expected.
  final DateTime date;

  /// This taking's free-text wording.
  final String label;

  /// The amount this taking is expected to bring in, exactly as typed, in cents.
  final int amountCents;

  /// How far this taking's own paperwork has progressed.
  final OcptBudgetRevenueStatus status;

  /// Free-form notes about this taking.
  final String notes;

  /// This revenue's position within the sharing view's own flat `sortKey` order.
  final String sortKey;

  /// Class constructor
  const OcptBudgetRevenue({
    required this.id,
    required this.date,
    required this.label,
    required this.amountCents,
    required this.status,
    required this.notes,
    required this.sortKey,
  });

  /// Builds an [OcptBudgetRevenue] from its stored [row].
  factory OcptBudgetRevenue.fromRow(OcptBudgetRevenueRow row) => OcptBudgetRevenue(
    id: row.id,
    date: row.date,
    label: row.label,
    amountCents: row.amountCents,
    status: row.status,
    notes: row.notes,
    sortKey: row.sortKey,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetRevenue(id: $id, date: $date, label: $label, "
      "amountCents: $amountCents, status: $status)";

  /// Object properties
  @override
  List<Object?> get props => [id, date, label, amountCents, status, notes, sortKey];
}
