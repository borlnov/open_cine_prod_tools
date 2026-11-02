// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// How stretched a poste is against its own quote — the colour the cost-tracking view paints it in
/// is the widget's own business, not this pure util's: it switches over this enum rather than
/// re-deriving the comparison.
enum OcptBudgetPosteStrain {
  /// Paid plus committed is at or below `_ocptBudgetNearStrainRatio` of the quote.
  within,

  /// Paid plus committed is above `_ocptBudgetNearStrainRatio` of the quote, but not over it yet.
  near,

  /// Paid plus committed exceeds the quote.
  over,
}
