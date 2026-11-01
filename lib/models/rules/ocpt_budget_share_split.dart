// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_shares.dart';

/// One participant's line in the split: what they are due out of the pot, what they have actually
/// been paid, and what of their due they reinvest.
///
/// Named `…Split` rather than `…Row` because `OcptBudgetShareRow` is already drift's own data class
/// for `budget_shares`, and a computed reading and a stored row must not wear one name.
class OcptBudgetShareSplit extends Equatable {
  /// The share this line reads.
  final OcptBudgetShare share;

  /// What this participant is due out of the pot, in cents —
  /// `shareableCents × sharePermille ÷ 1000`, rounded to the nearest cent.
  final int dueCents;

  /// What has actually been paid to them — [ocptBudgetPaidByShareId]'s own figure for this share,
  /// or a zero-amount total covering nothing when no entry names them.
  final OcptBudgetCoveredTotal paid;

  /// What of [dueCents] this participant reinvests in the next production, in cents —
  /// `dueCents × reinvestPermille ÷ 1000`, rounded to the nearest cent.
  final int reinvestedCents;

  /// [dueCents] less [reinvestedCents]: what is theirs to actually take.
  int get takeHomeCents => dueCents - reinvestedCents;

  /// Class constructor
  const OcptBudgetShareSplit({
    required this.share,
    required this.dueCents,
    required this.paid,
    required this.reinvestedCents,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetShareSplit(share: ${share.id}, dueCents: $dueCents, paid: $paid, "
      "reinvestedCents: $reinvestedCents)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [share, dueCents, paid, reinvestedCents];
}
