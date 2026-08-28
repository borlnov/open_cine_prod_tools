// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';

/// The three families the resources tree groups its rows into — a **display grouping**, never a
/// stored fact: no table, column or dialog names one. `OcptBudgetResourceGroupKind`'s own three
/// values answer *how a `budget_resources` row was created*, which stays exactly as it was (the
/// product owner's own three creation gestures, "An in-kind contribution is valued, not collected"
/// in `docs/architecture/budget.md`); this enum answers *which card a row draws in*, merging cash
/// and in-kind contributions into one family the mock draws as `Apports` while a subsidy stays its
/// own.
///
/// `OcptBudgetRevenue` carries no group kind at all — it never named one — so [takings] is not
/// [of]'s own target: a taking's own row is family [takings] simply by being a revenue, decided by
/// the caller rather than through this mapping.
///
/// Used as [name] for a node's own id in `OcptBudgetState.expandedNodeIds`, since a family is not a
/// database row and mints no id of its own.
enum OcptBudgetResourceFamily {
  /// A grant or subsidy — [OcptBudgetResourceGroupKind.subsidy] alone.
  subsidies,

  /// A cash or an in-kind contribution — [OcptBudgetResourceGroupKind.cash] and
  /// [OcptBudgetResourceGroupKind.inKind] together.
  contributions,

  /// A taking the production expects — every live `OcptBudgetRevenue`.
  takings;

  /// The family a resource of [groupKind] draws in — see the class doc comment for why a subsidy
  /// stays apart while cash and in-kind fold into one.
  static OcptBudgetResourceFamily of(OcptBudgetResourceGroupKind groupKind) => switch (groupKind) {
    OcptBudgetResourceGroupKind.subsidy => OcptBudgetResourceFamily.subsidies,
    OcptBudgetResourceGroupKind.cash || OcptBudgetResourceGroupKind.inKind =>
      OcptBudgetResourceFamily.contributions,
  };
}
