// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// An amount of money, seen from the domain, exactly as `OcptBudgetLinesTable`'s own doc comment
/// argues it: **stored exactly as typed, never reconstructed**, so it is three columns rather than
/// one.
///
/// This model carries no conversion logic of its own — `lib/utils/ocpt_budget_vat.dart` is the
/// only place in the repository allowed to turn one basis into the other, and it is pure so it can
/// be tested without a database.
class OcptMoney extends Equatable {
  /// The amount exactly as typed, in cents.
  final int amountCents;

  /// Whether [amountCents] already includes tax.
  final bool isTaxInclusive;

  /// The VAT rate this amount carries, in basis points (550 for 5.5 %), or null meaning "inherit
  /// the project's own rate" — see `OcptBudgetLinesTable.vatRateBasisPoints`'s own doc comment for
  /// why that null is a different fact from a project's own null.
  final int? vatRateBasisPoints;

  /// Class constructor
  const OcptMoney({
    required this.amountCents,
    required this.isTaxInclusive,
    required this.vatRateBasisPoints,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptMoney(amountCents: $amountCents, isTaxInclusive: $isTaxInclusive, "
      "vatRateBasisPoints: $vatRateBasisPoints)";

  /// Object properties
  @override
  List<Object?> get props => [amountCents, isTaxInclusive, vatRateBasisPoints];
}
