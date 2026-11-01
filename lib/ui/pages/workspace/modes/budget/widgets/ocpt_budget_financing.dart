// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_family.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_coverage_band.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_family_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_header_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_receipt_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_resource_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_revenue_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_row_figures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_total_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_tree_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_horizontal_scroll_view.dart';

/// The budget mode's resources document: a nesting tree — three family rows (subsidies,
/// contributions, takings), each opening onto its own resources or takings, each of those opening
/// onto the receipts that name it — a total row, a creation footer and, under everything, the
/// coverage band answering whether the plan covers the film.
///
/// **The tree is flattened once, top to bottom, into [_rowsOf]' own list**, mirroring
/// `OcptBudgetCostTracking._rowsOf`'s own reading exactly: a family row draws whenever it holds
/// at least one resource or taking, its own children draw only while its id — `.name`, since a
/// family mints no id of its own — sits in [expandedNodeIds]; a resource's or a revenue's own
/// receipts draw only while *its* id sits there too, and only once it holds at least one.
///
/// **Three explicit creation gestures fold into one family reading.** `OcptBudgetResourceGroupKind`
/// still answers *how* a `budget_resources` row was created — a subsidy, a cash contribution, an
/// in-kind one — exactly as it always has; `OcptBudgetResourceFamily` answers *which card a row
/// draws in*, merging cash and in-kind together the way the mock's own `Apports` card does. Neither
/// table nor dialog ever reads the family: it is a display grouping alone.
///
/// **Money.** A row's own `Promis` is its `amountCents`. `Rentré` is null for an in-kind resource
/// no entry has ever named — "An in-kind contribution is valued, not collected"
/// (`docs/architecture/budget.md`) — and the honest received figure for every other row, in-kind
/// included the moment an entry does name it. `Reste à venir` is `amount − received`, null wherever
/// `Rentré` is, drawn in the error colour when negative. A family's own three figures are the sum
/// of its rows' own: `Promis` always known, `Rentré`/`Reste à venir` summing only the rows whose
/// own figure is known and reading null only when **every** row's own is — never a family with one
/// unentered in-kind resource losing the whole family's own honest figure to it.
///
/// **A composite panel** (`docs/architecture/foundations.md`'s own idiom): takes [isReadOnly]
/// rather than a null callback per affordance, and withholds — never disables — every one of its
/// own writing affordances: the creation footer and a resource's or a revenue's own `⋮` menu.
class OcptBudgetFinancing extends StatelessWidget {
  /// Every live resource, in `sortKey` order.
  final List<OcptBudgetResource> resources;

  /// Every live taking, in `sortKey` order.
  final List<OcptBudgetRevenue> revenues;

  /// Every live journal entry of the project, in chronological order — narrowed, row by row, to the
  /// live credits naming the one resource or revenue each receipt sub-row draws.
  final List<OcptBudgetEntry> entries;

  /// Every live poste of the quote, lines included — read only for [_needsOf]'s own total, the
  /// coverage band's own `needs` figure.
  final List<OcptBudgetPoste> postes;

  /// The project's default VAT rate, in basis points, or null while nobody has recorded one — read
  /// only for [_needsOf]'s own total.
  final int? defaultVatRateBasisPoints;

  /// What has actually come in against each resource, keyed by its own id — read raw, rather than
  /// through [receivedCentsOf], for the one reading that needs to tell "no entry names this
  /// resource at all" from "entries name it and sum to zero" — see the class doc comment.
  final Map<String, OcptBudgetCoveredTotal> receivedByResourceId;

  /// A resource's own received total, in cents, tax-inclusive, honestly zero the moment its own
  /// entries are known to sum to nothing — `OcptBudgetState.receivedCentsOf`. Read by every row but
  /// an in-kind one carrying no entry at all, which reads [receivedByResourceId] instead.
  final int Function(String resourceId) receivedCentsOf;

  /// What has actually come in against each taking, keyed by its own id — read raw: a taking's own
  /// "no entry names it" reads null directly off this map, with no `?? 0` reading of its own.
  final Map<String, OcptBudgetCoveredTotal> receivedByRevenueId;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// What is currently selected for the right dock's own fiche, or null while none is.
  final OcptBudgetSelection? selection;

  /// Which nodes of the resources tree are currently expanded — an `OcptBudgetResourceFamily`'s own
  /// `name`, a resource id or a revenue id, see `OcptBudgetState.expandedNodeIds`'s own doc
  /// comment.
  final Set<String> expandedNodeIds;

  /// Whether the mode shows a project version being previewed read-only — see the class doc
  /// comment.
  final bool isReadOnly;

  /// Called with a family's, a resource's or a revenue's own node id when its twisty is clicked.
  final ValueChanged<String> onNodeExpansionToggled;

  /// Called with a resource's id when its row is clicked — selects it and opens the fiche.
  final ValueChanged<String> onResourceSelected;

  /// Called with a resource when its row's own `⋮` menu asks to edit it, or null while
  /// [isReadOnly]. Opens `OcptBudgetResourceDialog` on it.
  final ValueChanged<OcptBudgetResource>? onResourceEditRequested;

  /// Called with a resource when its row's own `⋮` menu asks to record a receipt against it, or
  /// null while [isReadOnly]. Opens `OcptBudgetEntryDialog` pre-filled from it, as a credit.
  ///
  /// The row itself further withholds the menu entry that calls this — never disables it — once
  /// the resource is fully received or is an in-kind one: see the class doc comment.
  final ValueChanged<OcptBudgetResource>? onResourceReceiptRequested;

  /// Called with a resource when its row's own `⋮` menu asks to undo the most recent receipt
  /// against it, or null while [isReadOnly].
  ///
  /// The row itself further withholds the menu entry that calls this until the resource has
  /// actually received something.
  final ValueChanged<OcptBudgetResource>? onResourceReceiptUndoRequested;

  /// Called with a resource's id when its row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onResourceDeletionRequested;

  /// Called with a revenue's id when its row is clicked — selects it and opens the fiche.
  final ValueChanged<String> onRevenueSelected;

  /// Called with a revenue when its row's own `⋮` menu asks to edit it, or null while [isReadOnly].
  /// Opens `OcptBudgetRevenueDialog` on it.
  final ValueChanged<OcptBudgetRevenue>? onRevenueEditRequested;

  /// Called with a revenue when its row's own `⋮` menu asks to record a receipt against it, or null
  /// while [isReadOnly]. Opens `OcptBudgetEntryDialog` pre-filled from it, as a credit.
  final ValueChanged<OcptBudgetRevenue>? onRevenueReceiptRequested;

  /// Called with a revenue's id and a direction when its row's own `⋮` menu asks to move it, or
  /// null while [isReadOnly]. Withheld at its own end of the takings family.
  final void Function(String revenueId, {required bool moveUp})? onRevenueReorderRequested;

  /// Called with a revenue's id when its row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onRevenueDeletionRequested;

  /// Called with a receipt's own entry id when its sub-row is clicked — selects it and opens the
  /// fiche on it as a receipt.
  final ValueChanged<String> onReceiptSelected;

  /// Called when the coverage band's own action is clicked, returning to the expenses document.
  final VoidCallback onExpensesRequested;

  /// Class constructor
  const OcptBudgetFinancing({
    super.key,
    required this.resources,
    required this.revenues,
    required this.entries,
    required this.postes,
    required this.defaultVatRateBasisPoints,
    required this.receivedByResourceId,
    required this.receivedCentsOf,
    required this.receivedByRevenueId,
    required this.currencyCode,
    required this.selection,
    required this.expandedNodeIds,
    required this.isReadOnly,
    required this.onNodeExpansionToggled,
    required this.onResourceSelected,
    required this.onResourceEditRequested,
    required this.onResourceReceiptRequested,
    required this.onResourceReceiptUndoRequested,
    required this.onResourceDeletionRequested,
    required this.onRevenueSelected,
    required this.onRevenueEditRequested,
    required this.onRevenueReceiptRequested,
    required this.onRevenueReorderRequested,
    required this.onRevenueDeletionRequested,
    required this.onReceiptSelected,
    required this.onExpensesRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final isEmpty = resources.isEmpty && revenues.isEmpty;
    final rows = isEmpty ? const <OcptBudgetFinancingTreeRow>[] : _rowsOf();
    final grandTotal = _familyAggregatesOf(resources, revenues);
    final drawnFamilyCount = OcptBudgetResourceFamily.values
        .where(
          (family) => _familyResources(family).isNotEmpty || _familyRevenues(family).isNotEmpty,
        )
        .length;
    final hasInKind = resources.any(
      (resource) => resource.groupKind == OcptBudgetResourceGroupKind.inKind,
    );
    final valuedCents = resources.fold(
      0,
      (sum, resource) =>
          sum +
          (resource.groupKind == OcptBudgetResourceGroupKind.inKind ? resource.amountCents : 0),
    );
    final needs = _needsOf();
    final coverage = ocptBudgetResourcesCoverageOf(
      needs: needs,
      resources: resources,
      revenues: revenues,
      receivedByResourceId: receivedByResourceId,
      receivedByRevenueId: receivedByRevenueId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => OcptHorizontalScrollView(
              child: SizedBox(
                width: math.max(constraints.maxWidth, ocptBudgetFinancingMinTableWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const OcptBudgetFinancingHeaderRow(),
                    Expanded(
                      child: isEmpty
                          ? OcptWorkspaceEmptyMode(
                              icon: Icons.savings_outlined,
                              message: tr.budgetFinancingEmptyHint,
                            )
                          : ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (context, index) => _rowOf(rows[index]),
                            ),
                    ),
                    if (!isEmpty)
                      OcptBudgetFinancingTotalRow(
                        familyCount: drawnFamilyCount,
                        aggregates: grandTotal,
                        currencyCode: currencyCode,
                        hasInKind: hasInKind,
                        valuedCents: valuedCents,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (needs.amountCents > 0) ...[
          const SizedBox(height: 16),
          OcptBudgetFinancingCoverageBand(
            coverage: coverage,
            currencyCode: currencyCode,
            onExpensesRequested: onExpensesRequested,
          ),
        ],
      ],
    );
  }

  /// The quote's own total, read **tax-inclusive always** — money coming in is always read
  /// tax-inclusive (`docs/architecture/budget.md`'s "Money that has moved is read tax-inclusive,
  /// always"), and this document carries no tax-basis switch of its own to read a different basis
  /// from, mirroring `OcptBudgetNeedsResourcesBalance`'s own reading — the financing-plan and
  /// financial-report PDFs' own balance figure.
  OcptBudgetCoveredTotal _needsOf() {
    final allLines = [for (final poste in postes) ...poste.lines];
    return ocptBudgetTotalOf(
      allLines,
      basis: OcptBudgetTaxBasis.includingTax,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
  }

  /// [resources]' own rows belonging to [family] — subsidies stay their own, cash and in-kind fold
  /// into contributions, takings holds none (a revenue carries no group kind at all).
  List<OcptBudgetResource> _familyResources(OcptBudgetResourceFamily family) =>
      family == OcptBudgetResourceFamily.takings
      ? const []
      : [
          for (final resource in resources)
            if (OcptBudgetResourceFamily.of(resource.groupKind) == family) resource,
        ];

  /// [revenues], for [OcptBudgetResourceFamily.takings] alone.
  List<OcptBudgetRevenue> _familyRevenues(OcptBudgetResourceFamily family) =>
      family == OcptBudgetResourceFamily.takings ? revenues : const [];

  /// The whole tree, flattened top to bottom into one list — see the class doc comment.
  List<OcptBudgetFinancingTreeRow> _rowsOf() {
    final rows = <OcptBudgetFinancingTreeRow>[];

    for (final family in OcptBudgetResourceFamily.values) {
      final familyResources = _familyResources(family);
      final familyRevenues = _familyRevenues(family);
      if (familyResources.isEmpty && familyRevenues.isEmpty) {
        continue;
      }

      final aggregates = _familyAggregatesOf(familyResources, familyRevenues);
      final isExpanded = expandedNodeIds.contains(family.name);
      rows.add(
        OcptBudgetFinancingFamilyTreeRow(
          family: family,
          aggregates: aggregates,
          isExpanded: isExpanded,
        ),
      );
      if (!isExpanded) {
        continue;
      }

      for (final resource in familyResources) {
        final receipts = _receiptsOfResource(resource.id);
        final isRowExpanded = receipts.isNotEmpty && expandedNodeIds.contains(resource.id);
        rows.add(
          OcptBudgetFinancingResourceTreeRow(
            resource: resource,
            figures: _resourceFigures(resource),
            isExpandable: receipts.isNotEmpty,
            isExpanded: isRowExpanded,
          ),
        );
        if (isRowExpanded) {
          for (final receipt in receipts) {
            rows.add(OcptBudgetFinancingReceiptTreeRow(entry: receipt));
          }
        }
      }

      for (final revenue in familyRevenues) {
        final receipts = _receiptsOfRevenue(revenue.id);
        final isRowExpanded = receipts.isNotEmpty && expandedNodeIds.contains(revenue.id);
        rows.add(
          OcptBudgetFinancingRevenueTreeRow(
            revenue: revenue,
            figures: _revenueFigures(revenue),
            isExpandable: receipts.isNotEmpty,
            isExpanded: isRowExpanded,
          ),
        );
        if (isRowExpanded) {
          for (final receipt in receipts) {
            rows.add(OcptBudgetFinancingReceiptTreeRow(entry: receipt));
          }
        }
      }
    }

    return rows;
  }

  /// Every live credit naming [resourceId], in the chronological order [entries] is already loaded
  /// in — the receipts a resource's own twisty reveals.
  List<OcptBudgetEntry> _receiptsOfResource(String resourceId) => [
    for (final entry in entries)
      if (entry.resourceId == resourceId && entry.creditCents > 0) entry,
  ];

  /// Every live credit naming [revenueId] — mirrors [_receiptsOfResource].
  List<OcptBudgetEntry> _receiptsOfRevenue(String revenueId) => [
    for (final entry in entries)
      if (entry.revenueId == revenueId && entry.creditCents > 0) entry,
  ];

  /// [resource]'s own `Promis`/`Rentré`/`Reste à venir` — see the class doc comment for the
  /// in-kind reading.
  OcptBudgetFinancingRowFigures _resourceFigures(OcptBudgetResource resource) {
    final isUnentriedInKind =
        resource.groupKind == OcptBudgetResourceGroupKind.inKind &&
        !receivedByResourceId.containsKey(resource.id);
    final receivedCents = isUnentriedInKind ? null : receivedCentsOf(resource.id);
    final outstandingCents = receivedCents == null
        ? null
        : ocptBudgetResourceOutstandingCents(
            amountCents: resource.amountCents,
            receivedCents: receivedCents,
          );

    return OcptBudgetFinancingRowFigures(
      promisedCents: resource.amountCents,
      receivedCents: receivedCents,
      outstandingCents: outstandingCents,
    );
  }

  /// [revenue]'s own `Promis`/`Rentré`/`Reste à venir` — a taking's own "no entry names it" reads
  /// null directly off [receivedByRevenueId], with no group-kind branch of its own.
  OcptBudgetFinancingRowFigures _revenueFigures(OcptBudgetRevenue revenue) {
    final receivedCents = receivedByRevenueId[revenue.id]?.amountCents;
    final outstandingCents = receivedCents == null
        ? null
        : ocptBudgetResourceOutstandingCents(
            amountCents: revenue.amountCents,
            receivedCents: receivedCents,
          );

    return OcptBudgetFinancingRowFigures(
      promisedCents: revenue.amountCents,
      receivedCents: receivedCents,
      outstandingCents: outstandingCents,
    );
  }

  /// Folds every one of [familyResources]' and [familyRevenues]' own figures into one triple — see
  /// the class doc comment for the "known rows only" rule [Rentré]/[Reste à venir] follow. Also
  /// used with the *whole* project's own resources and revenues for the grand total row.
  OcptBudgetFinancingRowFigures _familyAggregatesOf(
    List<OcptBudgetResource> familyResources,
    List<OcptBudgetRevenue> familyRevenues,
  ) {
    var promisedCents = 0;
    var receivedCents = 0;
    var outstandingCents = 0;
    var anyKnown = false;

    for (final resource in familyResources) {
      final figures = _resourceFigures(resource);
      promisedCents += figures.promisedCents;
      if (figures.receivedCents != null) {
        anyKnown = true;
        receivedCents += figures.receivedCents!;
        outstandingCents += figures.outstandingCents!;
      }
    }
    for (final revenue in familyRevenues) {
      final figures = _revenueFigures(revenue);
      promisedCents += figures.promisedCents;
      if (figures.receivedCents != null) {
        anyKnown = true;
        receivedCents += figures.receivedCents!;
        outstandingCents += figures.outstandingCents!;
      }
    }

    return OcptBudgetFinancingRowFigures(
      promisedCents: promisedCents,
      receivedCents: anyKnown ? receivedCents : null,
      outstandingCents: anyKnown ? outstandingCents : null,
    );
  }

  /// Builds the widget for one flattened [row].
  Widget _rowOf(OcptBudgetFinancingTreeRow row) => switch (row) {
    OcptBudgetFinancingFamilyTreeRow() => OcptBudgetFinancingFamilyRow(
      family: row.family,
      aggregates: row.aggregates,
      currencyCode: currencyCode,
      isExpanded: row.isExpanded,
      onTwistyTap: () => onNodeExpansionToggled(row.family.name),
    ),
    OcptBudgetFinancingResourceTreeRow() => OcptBudgetFinancingResourceRow(
      resource: row.resource,
      figures: row.figures,
      currencyCode: currencyCode,
      isSelected: _isResourceSelected(row.resource.id),
      isExpandable: row.isExpandable,
      isExpanded: row.isExpanded,
      onTwistyTap: () => onNodeExpansionToggled(row.resource.id),
      onTap: () => onResourceSelected(row.resource.id),
      onEditRequested: isReadOnly || onResourceEditRequested == null
          ? null
          : () => onResourceEditRequested?.call(row.resource),
      onReceiptRequested:
          isReadOnly ||
              onResourceReceiptRequested == null ||
              !_canOfferReceipt(row.resource, row.figures)
          ? null
          : () => onResourceReceiptRequested?.call(row.resource),
      onReceiptUndoRequested:
          isReadOnly ||
              onResourceReceiptUndoRequested == null ||
              !_hasReceivedSomething(row.figures)
          ? null
          : () => onResourceReceiptUndoRequested?.call(row.resource),
      onDeletionRequested: isReadOnly || onResourceDeletionRequested == null
          ? null
          : () => onResourceDeletionRequested?.call(row.resource.id),
    ),
    OcptBudgetFinancingRevenueTreeRow() => OcptBudgetFinancingRevenueRow(
      revenue: row.revenue,
      figures: row.figures,
      currencyCode: currencyCode,
      isSelected: _isRevenueSelected(row.revenue.id),
      isExpandable: row.isExpandable,
      isExpanded: row.isExpanded,
      onTwistyTap: () => onNodeExpansionToggled(row.revenue.id),
      onTap: () => onRevenueSelected(row.revenue.id),
      onEditRequested: isReadOnly || onRevenueEditRequested == null
          ? null
          : () => onRevenueEditRequested?.call(row.revenue),
      onReceiptRequested: isReadOnly || onRevenueReceiptRequested == null
          ? null
          : () => onRevenueReceiptRequested?.call(row.revenue),
      onMoveUpRequested:
          isReadOnly || onRevenueReorderRequested == null || _isFirstRevenue(row.revenue.id)
          ? null
          : () => onRevenueReorderRequested?.call(row.revenue.id, moveUp: true),
      onMoveDownRequested:
          isReadOnly || onRevenueReorderRequested == null || _isLastRevenue(row.revenue.id)
          ? null
          : () => onRevenueReorderRequested?.call(row.revenue.id, moveUp: false),
      onDeletionRequested: isReadOnly || onRevenueDeletionRequested == null
          ? null
          : () => onRevenueDeletionRequested?.call(row.revenue.id),
    ),
    OcptBudgetFinancingReceiptTreeRow() => OcptBudgetFinancingReceiptRow(
      entry: row.entry,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      currencyCode: currencyCode,
      isSelected: _isReceiptSelected(row.entry.id),
      onTap: () => onReceiptSelected(row.entry.id),
    ),
  };

  /// Whether [figures] show anything actually received — what `Undo the last receipt` is withheld
  /// until, there being no last receipt to undo before then.
  bool _hasReceivedSomething(OcptBudgetFinancingRowFigures figures) =>
      figures.receivedCents != null && figures.receivedCents! > 0;

  /// `Record a receipt` has nothing left to offer on an in-kind resource (valued, never collected)
  /// or on one that has already received at least its own amount — see the class doc comment.
  bool _canOfferReceipt(OcptBudgetResource resource, OcptBudgetFinancingRowFigures figures) =>
      resource.groupKind != OcptBudgetResourceGroupKind.inKind &&
      (figures.receivedCents ?? 0) < resource.amountCents;

  /// Whether resource [resourceId] is the currently selected one.
  bool _isResourceSelected(String resourceId) {
    final selection = this.selection;
    return selection is OcptBudgetResourceSelection && selection.resourceId == resourceId;
  }

  /// Whether revenue [revenueId] is the currently selected one.
  bool _isRevenueSelected(String revenueId) {
    final selection = this.selection;
    return selection is OcptBudgetRevenueSelection && selection.revenueId == revenueId;
  }

  /// Whether receipt (journal entry) [receiptId] is the currently selected one.
  bool _isReceiptSelected(String receiptId) {
    final selection = this.selection;
    return selection is OcptBudgetReceiptSelection && selection.receiptId == receiptId;
  }

  /// Whether [revenueId] is the first taking of the whole project — `Move up` withheld there.
  bool _isFirstRevenue(String revenueId) => revenues.isNotEmpty && revenues.first.id == revenueId;

  /// Whether [revenueId] is the last taking of the whole project — `Move down` withheld there.
  bool _isLastRevenue(String revenueId) => revenues.isNotEmpty && revenues.last.id == revenueId;
}
