// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What `OcptBudgetLineFormBody` collected, handed back to the mode that opened it — the fields a
/// quote line can be **born filled with**, mirroring `OcptBudgetResourceFormFields`'s own shape for
/// a form that only ever creates.
///
/// **Carries no tax basis and no VAT rate override**, unlike `OcptBudgetCommitmentFormFields`'s
/// own reading of the same triple: `OcptBudgetQuoteService.createLine` accepts none either, a
/// freshly minted line inheriting the table's own default tax basis and the project's own rate
/// exactly as a line born blank from the `+ Add` footer already does. Nothing here changes that —
/// this model only closes the gap between a line born blank and a line born already carrying the
/// three figures a human actually typed for it.
class OcptBudgetLineFormFields extends Equatable {
  /// This line's display name.
  final String label;

  /// The quantity this line prices, in thousandths (1.5 day is 1500, 1,484 km is 1484000) — see
  /// `OcptBudgetLine.quantityMilli`'s own doc comment for why thousandths.
  final int quantityMilli;

  /// The unit [quantityMilli] is counted in, free text (e.g. "day", "km", "unit").
  final String unit;

  /// The unit price this line is typed at, exactly as typed, in cents.
  final int unitAmountCents;

  /// Class constructor
  const OcptBudgetLineFormFields({
    required this.label,
    required this.quantityMilli,
    required this.unit,
    required this.unitAmountCents,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetLineFormFields(label: $label, quantityMilli: $quantityMilli, unit: $unit, "
      "unitAmountCents: $unitAmountCents)";

  /// Object properties
  @override
  List<Object?> get props => [label, quantityMilli, unit, unitAmountCents];
}
