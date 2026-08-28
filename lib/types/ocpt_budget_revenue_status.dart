// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// How far a `budget_revenues` row has progressed towards actually being paperwork the production
/// can stand behind — never a claim about the cash itself.
///
/// **Flat, three values, and deliberately no fourth, `cashed`.** What a taking has actually brought
/// in is summed from the `budget_entries` credits naming it through `budget_entries.revenueId`,
/// exactly as `OcptBudgetCommitmentStatus`'s own doc comment already argues for its missing
/// `settled` value: a status living beside a figure the journal already answers would be a second
/// copy of one truth, kept in step by hand or by a write nobody could guarantee never to forget. A
/// taking is "brought in" the moment a live credit names it, whatever this status happens to say —
/// this enum only ever tracks the paperwork behind it, from the first announcement to the invoice
/// still waiting to be paid.
enum OcptBudgetRevenueStatus {
  /// The taking has been announced or is hoped for, nothing signed or billed yet.
  expected,

  /// The taking is confirmed: a decision, a notification or a contract is in hand.
  confirmed,

  /// The production has billed this taking and is waiting to be paid.
  invoiced,
}
