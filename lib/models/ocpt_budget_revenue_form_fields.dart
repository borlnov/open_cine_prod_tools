// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';

/// What `OcptBudgetRevenueDialog` collected, handed back to the mode that opened it — one shape for
/// both creating and editing a `budget_revenues` row, shaped after
/// `OcptBudgetResourceFormFields`'s own reading for the financing plan's own resources.
///
/// **Carries no tax basis or rate at all**, unlike every other form of this mode: a revenue is
/// money coming *in*, and `OcptBudgetRevenuesTable`'s own doc comment already settles that there is
/// no second basis to read it in, so this dialog asks for none.
class OcptBudgetRevenueFormFields extends Equatable {
  /// The date this taking is expected.
  final DateTime date;

  /// This taking's free-text wording, trimmed — the dialog's own only required field besides
  /// [date].
  final String label;

  /// The amount this taking is expected to bring in, exactly as typed, in cents.
  final int amountCents;

  /// How far this taking's own paperwork has progressed.
  final OcptBudgetRevenueStatus status;

  /// Free-form notes about this taking, trimmed.
  final String notes;

  /// Class constructor
  const OcptBudgetRevenueFormFields({
    required this.date,
    required this.label,
    required this.amountCents,
    required this.status,
    required this.notes,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetRevenueFormFields(date: $date, label: $label, "
      "amountCents: $amountCents, status: $status)";

  /// Object properties
  @override
  List<Object?> get props => [date, label, amountCents, status, notes];
}
