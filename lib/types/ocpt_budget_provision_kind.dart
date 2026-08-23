// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One nature the régie view provisions into the quote — one quote line each.
///
/// **The value's own `name` is what `budget_lines.provisionKey` stores**, so a stored key is
/// readable in the file and a value may never be renamed without a migration. It names a *nature*
/// rather than a row, because the provisioning sums across every shooting day and every defrayal of
/// that nature: there is no single row on the other end for a foreign key to point at.
///
/// The two catering values come from the schedule, read through `ocpt_budget_regie.dart`; the four
/// others each stand for one `OcptBudgetAllowanceKind`, and are named apart from it so that a
/// catering meal — what the production feeds the unit on a shooting day — and a defrayed meal —
/// what one person is paid back for a meal the production did not provide — never collapse into one
/// line.
enum OcptBudgetProvisionKind {
  /// The meals the schedule implies, at the project's own meal price.
  meal,

  /// The craft-service servings the schedule implies, at the project's own price.
  snack,

  /// Every `OcptBudgetAllowanceKind.travel` defrayal, summed.
  travelAllowance,

  /// Every `OcptBudgetAllowanceKind.accommodation` defrayal, summed.
  accommodationAllowance,

  /// Every `OcptBudgetAllowanceKind.meal` defrayal, summed — never the catering above.
  mealAllowance,

  /// Every `OcptBudgetAllowanceKind.other` defrayal, summed.
  otherAllowance,
}
