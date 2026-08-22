// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// How far a `budget_resources` row has progressed towards actually financing the production.
///
/// **Flat, four values, nothing hidden or disabled according to the group it belongs to** —
/// `OcptBudgetResourceGroupKind`'s own three values are a different question this enum never asks:
/// the mode's own standing rule is that there is no conditional branch in the UI, only a value that
/// may be absent (`docs/architecture/budget.md`). [valued] is what an in-kind contribution normally
/// wears — it is the step a lent camera or a discounted lab pass reaches once somebody has put a
/// figure on it — but nothing here enforces that pairing: it is the user who says a resource is
/// `valued`, never a branch reading its `OcptBudgetResourceGroupKind` and picking the status for
/// them. A subsidy or a cash contribution is free to sit at `valued` too, if that is what the sheet
/// in front of the user actually says.
enum OcptBudgetResourceStatus {
  /// The resource has been applied for, but nothing has come back yet.
  applied,

  /// The resource has been notified: an answer has come back, favourable, but nothing has actually
  /// moved yet.
  notified,

  /// The resource is secured: a contract, an agreement or a firm commitment is in hand.
  secured,

  /// The resource has been given a figure — typically, though never exclusively, an in-kind
  /// contribution once its value has been assessed.
  valued,
}
