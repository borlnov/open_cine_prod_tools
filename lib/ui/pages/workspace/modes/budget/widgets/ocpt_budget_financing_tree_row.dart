// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_family.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_row_figures.dart';

/// One flattened row of the resources tree — see `OcptBudgetFinancing._rowsOf`'s own doc
/// comment.
sealed class OcptBudgetFinancingTreeRow {
  const OcptBudgetFinancingTreeRow();
}

/// A family row — the tree's own top level.
class OcptBudgetFinancingFamilyTreeRow extends OcptBudgetFinancingTreeRow {
  /// The family this row draws.
  final OcptBudgetResourceFamily family;

  /// This family's own three aggregate figures.
  final OcptBudgetFinancingRowFigures aggregates;

  /// Whether this family is currently expanded.
  final bool isExpanded;

  /// Class constructor
  const OcptBudgetFinancingFamilyTreeRow({
    required this.family,
    required this.aggregates,
    required this.isExpanded,
  });
}

/// A resource row — one step under its own family.
class OcptBudgetFinancingResourceTreeRow extends OcptBudgetFinancingTreeRow {
  /// The resource this row draws.
  final OcptBudgetResource resource;

  /// This resource's own figures.
  final OcptBudgetFinancingRowFigures figures;

  /// Whether this resource has at least one receipt to expand onto.
  final bool isExpandable;

  /// Whether this resource is currently expanded.
  final bool isExpanded;

  /// Class constructor
  const OcptBudgetFinancingResourceTreeRow({
    required this.resource,
    required this.figures,
    required this.isExpandable,
    required this.isExpanded,
  });
}

/// A revenue row — one step under the takings family, mirrors [OcptBudgetFinancingResourceTreeRow].
class OcptBudgetFinancingRevenueTreeRow extends OcptBudgetFinancingTreeRow {
  /// The revenue this row draws.
  final OcptBudgetRevenue revenue;

  /// This revenue's own figures.
  final OcptBudgetFinancingRowFigures figures;

  /// Whether this revenue has at least one receipt to expand onto.
  final bool isExpandable;

  /// Whether this revenue is currently expanded.
  final bool isExpanded;

  /// Class constructor
  const OcptBudgetFinancingRevenueTreeRow({
    required this.revenue,
    required this.figures,
    required this.isExpandable,
    required this.isExpanded,
  });
}

/// A receipt sub-row — two steps under its own family, drawn only while its parent resource or
/// revenue is expanded.
class OcptBudgetFinancingReceiptTreeRow extends OcptBudgetFinancingTreeRow {
  /// The journal entry this row draws.
  final OcptBudgetEntry entry;

  /// Class constructor
  const OcptBudgetFinancingReceiptTreeRow({required this.entry});
}
