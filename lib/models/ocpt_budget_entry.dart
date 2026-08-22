// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';

/// One movement of the cash journal: money that actually left or entered the account. See
/// `OcptBudgetEntriesTable`'s own doc comment for the money and nullability representation this
/// mirrors.
class OcptBudgetEntry extends Equatable {
  /// The stable, unique id of this entry (a UUID).
  final String id;

  /// The date this movement is recorded under.
  final DateTime date;

  /// This entry's free-text wording.
  final String label;

  /// The poste this entry is priced against, or null — see `OcptBudgetEntriesTable.posteId`'s own
  /// doc comment: null is money that moved without pricing any one poste, most often cash coming
  /// in.
  final String? posteId;

  /// What left the account, exactly as typed, in cents.
  final int debitCents;

  /// What came into the account, exactly as typed, in cents.
  final int creditCents;

  /// Whether [debitCents]/[creditCents] already include tax.
  final bool isTaxInclusive;

  /// The VAT rate this entry's figures carry, in basis points, or null meaning "inherit the
  /// project's own rate".
  final int? vatRateBasisPoints;

  /// The accounting reference this entry was minted with, e.g. `J-014`.
  final String voucherNumber;

  /// This entry's position within the journal's own flat `sortKey` order.
  final String sortKey;

  /// The financing resource this movement settles, or null — see `OcptBudgetEntriesTable
  /// .resourceId`'s own doc comment: null is the normal case, a movement that settles no resource.
  final String? resourceId;

  /// The taking this credit is the actual cash for, or null — see `OcptBudgetEntriesTable
  /// .revenueId`'s own doc comment: null is the normal case, a movement that is not a taking
  /// coming in.
  final String? revenueId;

  /// The participant this debit actually pays, or null — see `OcptBudgetEntriesTable.shareId`'s
  /// own doc comment: null is the normal case, a movement that pays no share of the revenue
  /// sharing.
  final String? shareId;

  /// This entry's tax triple ([debitCents], [creditCents], [isTaxInclusive],
  /// [vatRateBasisPoints]), read as a single signed cash figure: [OcptMoney.amountCents] is
  /// [creditCents] minus [debitCents], negative when this entry is, on balance, a cost.
  ///
  /// A helper reading over [debitCents] and [creditCents] rather than a stored field of its own —
  /// both plain fields stay on this model too, since `lib/utils/ocpt_budget_projection.dart` (the
  /// journal's running balance) needs to tell a debit from a credit apart, not only their sum.
  OcptMoney get signedAmount => OcptMoney(
    amountCents: creditCents - debitCents,
    isTaxInclusive: isTaxInclusive,
    vatRateBasisPoints: vatRateBasisPoints,
  );

  /// Class constructor
  const OcptBudgetEntry({
    required this.id,
    required this.date,
    required this.label,
    required this.posteId,
    required this.debitCents,
    required this.creditCents,
    required this.isTaxInclusive,
    required this.vatRateBasisPoints,
    required this.voucherNumber,
    required this.sortKey,
    required this.resourceId,
    required this.revenueId,
    required this.shareId,
  });

  /// Builds an [OcptBudgetEntry] from its stored [row].
  factory OcptBudgetEntry.fromRow(OcptBudgetEntryRow row) => OcptBudgetEntry(
    id: row.id,
    date: row.date,
    label: row.label,
    posteId: row.posteId,
    debitCents: row.debitCents,
    creditCents: row.creditCents,
    isTaxInclusive: row.isTaxInclusive,
    vatRateBasisPoints: row.vatRateBasisPoints,
    voucherNumber: row.voucherNumber,
    sortKey: row.sortKey,
    resourceId: row.resourceId,
    revenueId: row.revenueId,
    shareId: row.shareId,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetEntry(id: $id, date: $date, label: $label, "
      "voucherNumber: $voucherNumber)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    date,
    label,
    posteId,
    debitCents,
    creditCents,
    isTaxInclusive,
    vatRateBasisPoints,
    voucherNumber,
    sortKey,
    resourceId,
    revenueId,
    shareId,
  ];
}
