// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';

/// Money committed to a poste but not yet paid. See `OcptBudgetCommitmentsTable`'s own doc comment
/// for the money and status representation this mirrors.
class OcptBudgetCommitment extends Equatable {
  /// The stable, unique id of this commitment (a UUID).
  final String id;

  /// The date this commitment falls due, or null — see `OcptBudgetCommitmentsTable.dueDate`'s own
  /// doc comment: null means "nobody has recorded a due date", never "due immediately".
  final DateTime? dueDate;

  /// This commitment's free-text wording.
  final String label;

  /// The poste this commitment is priced against.
  final String posteId;

  /// The amount committed, and the tax basis and rate it carries.
  final OcptMoney amount;

  /// How far this commitment has progressed towards being paid.
  final OcptBudgetCommitmentStatus status;

  /// The `budget_entries` row that settled this commitment, or null while it remains unpaid.
  final String? settledEntryId;

  /// The quote line this commitment was promoted from, or null when it was typed from scratch —
  /// see `OcptBudgetCommitmentsTable.lineId`, which argues why this is a provenance and not a link
  /// anything is recomputed through.
  final String? lineId;

  /// This commitment's position within the journal's own flat `sortKey` order.
  final String sortKey;

  /// Whether this commitment has been paid.
  ///
  /// Read off [settledEntryId] alone, never off [status]: see
  /// `OcptBudgetCommitmentStatus`'s own doc comment for why settlement is deliberately not a fifth
  /// status value, but the one fact this link carries.
  bool get isSettled => settledEntryId != null;

  /// Class constructor
  const OcptBudgetCommitment({
    required this.id,
    required this.dueDate,
    required this.label,
    required this.posteId,
    required this.amount,
    required this.status,
    required this.settledEntryId,
    required this.lineId,
    required this.sortKey,
  });

  /// Builds an [OcptBudgetCommitment] from its stored [row].
  factory OcptBudgetCommitment.fromRow(OcptBudgetCommitmentRow row) => OcptBudgetCommitment(
    id: row.id,
    dueDate: row.dueDate,
    label: row.label,
    posteId: row.posteId,
    amount: OcptMoney(
      amountCents: row.amountCents,
      isTaxInclusive: row.isTaxInclusive,
      vatRateBasisPoints: row.vatRateBasisPoints,
    ),
    status: row.status,
    settledEntryId: row.settledEntryId,
    lineId: row.lineId,
    sortKey: row.sortKey,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetCommitment(id: $id, label: $label, posteId: $posteId, "
      "status: $status)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    dueDate,
    label,
    posteId,
    amount,
    status,
    settledEntryId,
    lineId,
    sortKey,
  ];
}
