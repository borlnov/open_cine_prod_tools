// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';

/// What `OcptBudgetResourceDialog` collected, handed back to the mode that opened it — one shape
/// for both creating and editing a `budget_resources` row, shaped after
/// `OcptBudgetCommitmentFormFields`'s own reading for the journal's own commitments.
///
/// **Carries no tax basis or rate at all**, unlike every other form of this mode: a financing
/// resource is money coming *in*, and `ocptBudgetResourcesTotalCents`'s own doc comment
/// (`lib/utils/ocpt_budget_financing.dart`) already settles that there is no second basis to read
/// it in, so this dialog asks for none.
class OcptBudgetResourceFormFields extends Equatable {
  /// What kind of financing this resource is.
  final OcptBudgetResourceGroupKind groupKind;

  /// The person this resource comes from, or null — `OcptBudgetResourcesTable.personId`'s own doc
  /// comment: a subsidy names nobody, which is a real fact rather than an unfinished pick.
  final String? personId;

  /// This resource's free-text wording, trimmed — the dialog's own only required field.
  final String label;

  /// The amount this resource comes to, exactly as typed, in cents.
  final int amountCents;

  /// How far this resource has progressed towards actually financing the production.
  final OcptBudgetResourceStatus status;

  /// Whether this resource has to be repaid before the revenue sharing splits what is left.
  final bool isReimbursable;

  /// Free-form notes about this resource, trimmed.
  final String notes;

  /// Class constructor
  const OcptBudgetResourceFormFields({
    required this.groupKind,
    required this.personId,
    required this.label,
    required this.amountCents,
    required this.status,
    required this.isReimbursable,
    required this.notes,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetResourceFormFields(groupKind: $groupKind, personId: $personId, label: $label, "
      "amountCents: $amountCents, status: $status)";

  /// Object properties
  @override
  List<Object?> get props => [
    groupKind,
    personId,
    label,
    amountCents,
    status,
    isReimbursable,
    notes,
  ];
}
