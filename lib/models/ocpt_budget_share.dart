// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// One participant's share of the revenue sharing. See `OcptBudgetSharesTable`'s own doc comment
/// for the two things this model deliberately does **not** carry: what has actually been paid
/// (derived from the journal, never stored) and an enforced sum across every live share.
class OcptBudgetShare extends Equatable {
  /// The stable, unique id of this share (a UUID).
  final String id;

  /// The person this share names, or null — a role such as "Production" is a real participant
  /// naming no one person.
  final String? personId;

  /// This share's free-text wording.
  final String label;

  /// This participant's share of the whole pot, in per mille (400 is 40 %).
  final int sharePermille;

  /// The fraction of this participant's *own* [sharePermille] they reinvest in the next
  /// production, in per mille.
  final int reinvestPermille;

  /// Free-form notes about this share.
  final String notes;

  /// This share's position within the sharing view's own flat `sortKey` order.
  final String sortKey;

  /// Class constructor
  const OcptBudgetShare({
    required this.id,
    required this.personId,
    required this.label,
    required this.sharePermille,
    required this.reinvestPermille,
    required this.notes,
    required this.sortKey,
  });

  /// Builds an [OcptBudgetShare] from its stored [row].
  factory OcptBudgetShare.fromRow(OcptBudgetShareRow row) => OcptBudgetShare(
    id: row.id,
    personId: row.personId,
    label: row.label,
    sharePermille: row.sharePermille,
    reinvestPermille: row.reinvestPermille,
    notes: row.notes,
    sortKey: row.sortKey,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetShare(id: $id, personId: $personId, label: $label, "
      "sharePermille: $sharePermille, reinvestPermille: $reinvestPermille)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    personId,
    label,
    sharePermille,
    reinvestPermille,
    notes,
    sortKey,
  ];
}
