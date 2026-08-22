// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';

/// One line of the production's financing plan. See `OcptBudgetResourcesTable`'s own doc comment
/// for the two things this model deliberately does **not** carry: what has actually been received
/// (derived from the journal, never stored) and a tax basis (a financing resource is money coming
/// in, always read tax-inclusive).
class OcptBudgetResource extends Equatable {
  /// The stable, unique id of this resource (a UUID).
  final String id;

  /// What kind of financing this resource is.
  final OcptBudgetResourceGroupKind groupKind;

  /// The person this resource comes from, or null. See `OcptBudgetResourcesTable.personId`'s own
  /// doc comment: a subsidy names nobody, which is a real fact rather than an unfinished pick.
  final String? personId;

  /// This resource's free-text wording.
  final String label;

  /// The amount this resource comes to, exactly as typed, in cents.
  final int amountCents;

  /// How far this resource has progressed towards actually financing the production.
  final OcptBudgetResourceStatus status;

  /// Whether this resource has to be repaid before the revenue sharing splits what is left.
  final bool isReimbursable;

  /// Free-form notes about this resource.
  final String notes;

  /// This resource's position within the financing plan's own flat `sortKey` order.
  final String sortKey;

  /// Class constructor
  const OcptBudgetResource({
    required this.id,
    required this.groupKind,
    required this.personId,
    required this.label,
    required this.amountCents,
    required this.status,
    required this.isReimbursable,
    required this.notes,
    required this.sortKey,
  });

  /// Builds an [OcptBudgetResource] from its stored [row].
  factory OcptBudgetResource.fromRow(OcptBudgetResourceRow row) => OcptBudgetResource(
    id: row.id,
    groupKind: row.groupKind,
    personId: row.personId,
    label: row.label,
    amountCents: row.amountCents,
    status: row.status,
    isReimbursable: row.isReimbursable,
    notes: row.notes,
    sortKey: row.sortKey,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetResource(id: $id, groupKind: $groupKind, personId: $personId, "
      "label: $label, amountCents: $amountCents, status: $status)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    groupKind,
    personId,
    label,
    amountCents,
    status,
    isReimbursable,
    notes,
    sortKey,
  ];
}
