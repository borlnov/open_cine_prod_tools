// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';

/// What `OcptBudgetAllowanceDialog` collected, handed back to the mode that opened it — one shape
/// for both creating and editing, mirroring `OcptBudgetResourceFormFields` exactly.
///
/// **Carries no tax basis and no VAT rate**, like the row it fills in: a defrayal is what the
/// provisioning reads to write a quote line, and it is that line which states the tax —
/// `OcptBudgetAllowancesTable`'s own doc comment argues it.
class OcptBudgetAllowanceFormFields extends Equatable {
  /// The person this defrayal is owed to, or null.
  final String? personId;

  /// What this defrayal is for.
  final OcptBudgetAllowanceKind kind;

  /// This defrayal's free-text wording.
  final String label;

  /// The day it applies to, or the day a stay begins — null while nobody has said.
  final DateTime? date;

  /// The day a stay ends, or null.
  final DateTime? endDate;

  /// How many kilometres, nights or meals it covers, in thousandths.
  final int quantityMilli;

  /// What one of them is paid back at, in thousandths of a cent.
  final int unitAmountMilliCents;

  /// Free-form notes.
  final String notes;

  /// Class constructor
  const OcptBudgetAllowanceFormFields({
    required this.personId,
    required this.kind,
    required this.label,
    required this.date,
    required this.endDate,
    required this.quantityMilli,
    required this.unitAmountMilliCents,
    required this.notes,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetAllowanceFormFields(personId: $personId, kind: $kind, label: $label, "
      "quantityMilli: $quantityMilli, unitAmountMilliCents: $unitAmountMilliCents)";

  /// Object properties
  @override
  List<Object?> get props => [
    personId,
    kind,
    label,
    date,
    endDate,
    quantityMilli,
    unitAmountMilliCents,
    notes,
  ];
}
