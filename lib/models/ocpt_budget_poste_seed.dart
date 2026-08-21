// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One poste `OcptBudgetQuoteService.loadPostes` is asked to seed a project's `budget_postes` table
/// with, on the first read of a table holding no row at all.
///
/// **Already localized**, on purpose: `lib/constants/ocpt_budget_cnc_postes.dart` carries only ARB
/// key names, since `lib/constants/` and every service under `lib/managers/` must stay free of
/// `Tr` — the mode resolving `ocptBudgetCncPostes` into this type, one per entry, is the one place
/// in the app allowed to turn a `labelKey` into a word.
class OcptBudgetPosteSeed extends Equatable {
  /// The constant id this poste is seeded with — see `OcptBudgetCncPoste.id`'s own doc comment for
  /// why it is never a freshly minted one.
  final String id;

  /// The CNC poste number as printed, seeded into `budget_postes.code`.
  final String code;

  /// This poste's resolved, localized detailed-header label.
  final String label;

  /// This poste's resolved, localized simplified-header label, or null.
  final String? simpleLabel;

  /// Class constructor
  const OcptBudgetPosteSeed({
    required this.id,
    required this.code,
    required this.label,
    required this.simpleLabel,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetPosteSeed(id: $id, code: $code, label: $label)";

  /// Object properties
  @override
  List<Object?> get props => [id, code, label, simpleLabel];
}
