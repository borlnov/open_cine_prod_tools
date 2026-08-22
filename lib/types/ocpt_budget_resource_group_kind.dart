// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What kind of financing a `budget_resources` row stands for — the three groups the financing
/// view gathers its rows into, and the CNC's own financing plan expects separated.
enum OcptBudgetResourceGroupKind {
  /// A grant or subsidy: money awarded by a commission, a region or a fund, rather than earned or
  /// lent.
  subsidy,

  /// A cash contribution: money a co-producer, a partner or the crew itself puts in.
  cash,

  /// A contribution in kind: equipment lent free of charge, volunteer work valued at a figure, a
  /// lab's services offered — never cash, but still counted on both sides of the budget.
  inKind,
}
