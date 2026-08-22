// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The header's excluding/including-tax toggle: which basis the `Quote` column and the cost
/// tracking totals are currently **read** in.
///
/// This is never the basis anything is *stored* in — ADR 0025 is explicit
/// that an amount is stored exactly as it was typed, in whichever of the two bases its own
/// `isTaxInclusive` names, and never reconstructed. This enum only names which of the two bases the
/// screen currently converts every row into before summing them (`lib/utils/ocpt_budget_vat.dart`),
/// a display preference the header always offers and that is never persisted (mirrors the
/// schedule's own agenda mode).
enum OcptBudgetTaxBasis {
  /// Every amount is read tax-included.
  includingTax,

  /// Every amount is read tax-excluded.
  excludingTax,
}
