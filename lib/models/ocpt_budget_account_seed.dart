// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One account `OcptBudgetQuoteService.loadAccounts` is asked to seed a project's `budget_postes`
/// table with, on the first read of a table holding no row at all.
///
/// **Already localized**, on purpose: `lib/constants/ocpt_budget_cnc_accounts.dart` carries only
/// ARB key names, since `lib/constants/` and every service under `lib/managers/` must stay free of
/// `Tr` — the mode resolving `ocptBudgetCncAccounts` into this type, one per entry, is the one
/// place in the app allowed to turn a `labelKey` into a word.
class OcptBudgetAccountSeed extends Equatable {
  /// The constant id this account is seeded with — see `OcptBudgetCncAccount.id`'s own doc comment
  /// for why it is never a freshly minted one.
  final String id;

  /// The CNC account number as printed, seeded into `budget_postes.code`.
  final String code;

  /// This account's resolved, localized detailed-header label.
  final String label;

  /// This account's resolved, localized simplified-header label, or null.
  final String? simpleLabel;

  /// Class constructor
  const OcptBudgetAccountSeed({
    required this.id,
    required this.code,
    required this.label,
    required this.simpleLabel,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetAccountSeed(id: $id, code: $code, label: $label)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [id, code, label, simpleLabel];
}
