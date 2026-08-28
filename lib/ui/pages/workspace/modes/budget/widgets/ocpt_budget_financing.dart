// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_family.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_horizontal_scroll_view.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The `Dossier` column's own fixed width, in logical pixels — matches
/// `OcptBudgetCostTracking`'s own status-shaped columns.
const double _ocptResourcesDossierColumnWidth = 132;

/// The `Promis`, `Rentré` and `Reste à venir` columns' own fixed width, in logical pixels.
const double _ocptResourcesAmountColumnWidth = 108;

/// The trailing `⋮` menu column's own fixed width, in logical pixels — matches every other table
/// of this mode's own menu column.
const double _ocptResourcesMenuColumnWidth = 36;

/// The narrowest the `Ressource` column is ever drawn, in logical pixels — past this, the table
/// scrolls sideways inside its own frame rather than crushing a resource's or a taking's own name,
/// mirroring `OcptBudgetCostTracking`'s own `_ocptCostTrackingPosteColumnMinWidth`.
const double _ocptResourcesRessourceColumnMinWidth = 220;

/// The narrowest the whole table is ever drawn at, in logical pixels — every fixed column's own
/// width plus [_ocptResourcesRessourceColumnMinWidth] and the row's own 24 px inset
/// (`ocptTableRowHorizontalPadding`, symmetric). Mirrors `OcptBudgetCashJournal`'s own
/// `_ocptCashJournalMinTableWidth`, and "The journal scrolls rather than losing a column" in
/// `docs/architecture/budget.md`.
const double _ocptResourcesMinTableWidth =
    _ocptResourcesDossierColumnWidth +
    3 * _ocptResourcesAmountColumnWidth +
    _ocptResourcesMenuColumnWidth +
    _ocptResourcesRessourceColumnMinWidth +
    2 * ocptTableRowHorizontalPadding;

/// A family, a resource or a revenue row's own fixed height, in logical pixels.
const double _ocptResourcesRowHeight = 44;

/// A receipt sub-row's own fixed height, in logical pixels — one step shorter than
/// [_ocptResourcesRowHeight], mirroring `OcptBudgetCostTracking`'s own
/// `_ocptCostTrackingSubRowHeight`.
const double _ocptResourcesReceiptRowHeight = 32;

/// The header row's own fixed height, in logical pixels.
const double _ocptResourcesHeaderRowHeight = 36;

/// The total row's own fixed height, in logical pixels — tall enough for the `Dossier` column's
/// own two-line valued caption.
const double _ocptResourcesTotalRowHeight = 44;

/// How far a row indents for every step of tree depth, in logical pixels — a resource or a taking
/// sits one step in from its own family, a receipt two, mirroring
/// `OcptBudgetCostTracking`'s own `_ocptCostTrackingIndentStep`.
const double _ocptResourcesIndentStep = 16;

/// The twisty's own fixed width, in logical pixels, whether it draws an arrow or sits blank. 28,
/// the theme's own floor for an icon button's own tap target, not the 20 an earlier pass
/// under-sized it at (`docs/architecture/budget.md`) — its own
/// tap target runs the full height of the row it sits on, see [_OcptResourcesTwisty]'s own doc
/// comment.
const double _ocptResourcesTwistyWidth = 28;

/// A receipt sub-row's own leading dot, in logical pixels.
const double _ocptResourcesDotDiameter = 8;

/// The coverage band's own leading column width, in logical pixels — what the film costs, stated
/// at a width of its own so a long coverage read-out wraps inside it rather than pushing the bar
/// beside it off the card.
const double _ocptResourcesCoverageNeedsColumnWidth = 200;

/// The two-tone coverage bar's own height, in logical pixels.
const double _ocptResourcesCoverageBarHeight = 8;

/// The budget mode's resources document: a nesting tree — three family rows (subsidies,
/// contributions, takings), each opening onto its own resources or takings, each of those opening
/// onto the receipts that name it — a total row, a creation footer and, under everything, the
/// coverage band answering whether the plan covers the film.
///
/// **The tree is flattened once, top to bottom, into [_buildRows]' own list**, mirroring
/// `OcptBudgetCostTracking._buildRows`'s own reading exactly: a family row draws whenever it holds
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
/// **Money.** A row's own `Promis` is its `amountCents`. `Rentré` is null for an in-kind resource no
/// entry has ever named — "An in-kind contribution is valued, not collected"
/// (`docs/architecture/budget.md`) — and the honest received figure for every other row, in-kind
/// included the moment an entry does name it. `Reste à venir` is `amount − received`, null wherever
/// `Rentré` is, drawn in the error colour when negative. A family's own three figures are the sum of
/// its rows' own: `Promis` always known, `Rentré`/`Reste à venir` summing only the rows whose own
/// figure is known and reading null only when **every** row's own is — never a family with one
/// unentered in-kind resource losing the whole family's own honest figure to it.
///
/// **A composite panel** (`docs/architecture/foundations.md`'s own idiom): takes [isReadOnly] rather
/// than a null callback per affordance, and withholds — never disables — every one of its own
/// writing affordances: the creation footer and a resource's or a revenue's own `⋮` menu.
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
  /// `name`, a resource id or a revenue id, see `OcptBudgetState.expandedNodeIds`'s own doc comment.
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
    final rows = isEmpty ? const <_OcptResourcesTreeRow>[] : _buildRows();
    final grandTotal = _familyAggregatesOf(resources, revenues);
    final drawnFamilyCount = OcptBudgetResourceFamily.values
        .where((family) => _familyResources(family).isNotEmpty || _familyRevenues(family).isNotEmpty)
        .length;
    final hasInKind = resources.any((resource) => resource.groupKind == OcptBudgetResourceGroupKind.inKind);
    final valuedCents = resources.fold(
      0,
      (sum, resource) =>
          sum + (resource.groupKind == OcptBudgetResourceGroupKind.inKind ? resource.amountCents : 0),
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
                width: math.max(constraints.maxWidth, _ocptResourcesMinTableWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _OcptResourcesHeaderRow(),
                    Expanded(
                      child: isEmpty
                          ? OcptWorkspaceEmptyMode(
                              icon: Icons.savings_outlined,
                              message: tr.budgetFinancingEmptyHint,
                            )
                          : ListView(children: [for (final row in rows) _rowOf(row)]),
                    ),
                    if (!isEmpty)
                      _OcptResourcesTotalRow(
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
          _OcptResourcesCoverageBand(
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
          : [for (final resource in resources) if (OcptBudgetResourceFamily.of(resource.groupKind) == family) resource];

  /// [revenues], for [OcptBudgetResourceFamily.takings] alone.
  List<OcptBudgetRevenue> _familyRevenues(OcptBudgetResourceFamily family) =>
      family == OcptBudgetResourceFamily.takings ? revenues : const [];

  /// The whole tree, flattened top to bottom into one list — see the class doc comment.
  List<_OcptResourcesTreeRow> _buildRows() {
    final rows = <_OcptResourcesTreeRow>[];

    for (final family in OcptBudgetResourceFamily.values) {
      final familyResources = _familyResources(family);
      final familyRevenues = _familyRevenues(family);
      if (familyResources.isEmpty && familyRevenues.isEmpty) {
        continue;
      }

      final aggregates = _familyAggregatesOf(familyResources, familyRevenues);
      final isExpanded = expandedNodeIds.contains(family.name);
      rows.add(_OcptFamilyTreeRow(family: family, aggregates: aggregates, isExpanded: isExpanded));
      if (!isExpanded) {
        continue;
      }

      for (final resource in familyResources) {
        final receipts = _receiptsOfResource(resource.id);
        final isRowExpanded = receipts.isNotEmpty && expandedNodeIds.contains(resource.id);
        rows.add(
          _OcptResourceTreeRow(
            resource: resource,
            figures: _resourceFigures(resource),
            isExpandable: receipts.isNotEmpty,
            isExpanded: isRowExpanded,
          ),
        );
        if (isRowExpanded) {
          for (final receipt in receipts) {
            rows.add(_OcptReceiptTreeRow(entry: receipt));
          }
        }
      }

      for (final revenue in familyRevenues) {
        final receipts = _receiptsOfRevenue(revenue.id);
        final isRowExpanded = receipts.isNotEmpty && expandedNodeIds.contains(revenue.id);
        rows.add(
          _OcptRevenueTreeRow(
            revenue: revenue,
            figures: _revenueFigures(revenue),
            isExpandable: receipts.isNotEmpty,
            isExpanded: isRowExpanded,
          ),
        );
        if (isRowExpanded) {
          for (final receipt in receipts) {
            rows.add(_OcptReceiptTreeRow(entry: receipt));
          }
        }
      }
    }

    return rows;
  }

  /// Every live credit naming [resourceId], in the chronological order [entries] is already loaded
  /// in — the receipts a resource's own twisty reveals.
  List<OcptBudgetEntry> _receiptsOfResource(String resourceId) => [
    for (final entry in entries) if (entry.resourceId == resourceId && entry.creditCents > 0) entry,
  ];

  /// Every live credit naming [revenueId] — mirrors [_receiptsOfResource].
  List<OcptBudgetEntry> _receiptsOfRevenue(String revenueId) => [
    for (final entry in entries) if (entry.revenueId == revenueId && entry.creditCents > 0) entry,
  ];

  /// [resource]'s own `Promis`/`Rentré`/`Reste à venir` — see the class doc comment for the
  /// in-kind reading.
  _OcptRowFigures _resourceFigures(OcptBudgetResource resource) {
    final isUnentriedInKind =
        resource.groupKind == OcptBudgetResourceGroupKind.inKind &&
        !receivedByResourceId.containsKey(resource.id);
    final receivedCents = isUnentriedInKind ? null : receivedCentsOf(resource.id);
    final outstandingCents = receivedCents == null
        ? null
        : ocptBudgetResourceOutstandingCents(amountCents: resource.amountCents, receivedCents: receivedCents);

    return _OcptRowFigures(
      promisedCents: resource.amountCents,
      receivedCents: receivedCents,
      outstandingCents: outstandingCents,
    );
  }

  /// [revenue]'s own `Promis`/`Rentré`/`Reste à venir` — a taking's own "no entry names it" reads
  /// null directly off [receivedByRevenueId], with no group-kind branch of its own.
  _OcptRowFigures _revenueFigures(OcptBudgetRevenue revenue) {
    final receivedCents = receivedByRevenueId[revenue.id]?.amountCents;
    final outstandingCents = receivedCents == null
        ? null
        : ocptBudgetResourceOutstandingCents(amountCents: revenue.amountCents, receivedCents: receivedCents);

    return _OcptRowFigures(
      promisedCents: revenue.amountCents,
      receivedCents: receivedCents,
      outstandingCents: outstandingCents,
    );
  }

  /// Folds every one of [familyResources]' and [familyRevenues]' own figures into one triple — see
  /// the class doc comment for the "known rows only" rule [Rentré]/[Reste à venir] follow. Also used
  /// with the *whole* project's own resources and revenues for the grand total row.
  _OcptRowFigures _familyAggregatesOf(
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

    return _OcptRowFigures(
      promisedCents: promisedCents,
      receivedCents: anyKnown ? receivedCents : null,
      outstandingCents: anyKnown ? outstandingCents : null,
    );
  }

  /// Builds the widget for one flattened [row].
  Widget _rowOf(_OcptResourcesTreeRow row) => switch (row) {
    _OcptFamilyTreeRow() => _OcptResourcesFamilyRow(
      family: row.family,
      aggregates: row.aggregates,
      currencyCode: currencyCode,
      isExpanded: row.isExpanded,
      onTwistyTap: () => onNodeExpansionToggled(row.family.name),
    ),
    _OcptResourceTreeRow() => _OcptResourcesResourceRow(
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
          isReadOnly || onResourceReceiptRequested == null || !_canOfferReceipt(row.resource, row.figures)
          ? null
          : () => onResourceReceiptRequested?.call(row.resource),
      onReceiptUndoRequested:
          isReadOnly || onResourceReceiptUndoRequested == null || !_hasReceivedSomething(row.figures)
          ? null
          : () => onResourceReceiptUndoRequested?.call(row.resource),
      onDeletionRequested: isReadOnly || onResourceDeletionRequested == null
          ? null
          : () => onResourceDeletionRequested?.call(row.resource.id),
    ),
    _OcptRevenueTreeRow() => _OcptResourcesRevenueRow(
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
      onMoveUpRequested: isReadOnly || onRevenueReorderRequested == null || _isFirstRevenue(row.revenue.id)
          ? null
          : () => onRevenueReorderRequested?.call(row.revenue.id, moveUp: true),
      onMoveDownRequested: isReadOnly || onRevenueReorderRequested == null || _isLastRevenue(row.revenue.id)
          ? null
          : () => onRevenueReorderRequested?.call(row.revenue.id, moveUp: false),
      onDeletionRequested: isReadOnly || onRevenueDeletionRequested == null
          ? null
          : () => onRevenueDeletionRequested?.call(row.revenue.id),
    ),
    _OcptReceiptTreeRow() => _OcptResourcesReceiptRow(
      entry: row.entry,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      currencyCode: currencyCode,
      isSelected: _isReceiptSelected(row.entry.id),
      onTap: () => onReceiptSelected(row.entry.id),
    ),
  };

  /// Whether [figures] show anything actually received — what `Undo the last receipt` is withheld
  /// until, there being no last receipt to undo before then.
  bool _hasReceivedSomething(_OcptRowFigures figures) =>
      figures.receivedCents != null && figures.receivedCents! > 0;

  /// `Record a receipt` has nothing left to offer on an in-kind resource (valued, never collected)
  /// or on one that has already received at least its own amount — see the class doc comment.
  bool _canOfferReceipt(OcptBudgetResource resource, _OcptRowFigures figures) =>
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

/// One resource's, one revenue's or one family's own `Promis`/`Rentré`/`Reste à venir`, in cents —
/// [receivedCents]/[outstandingCents] null wherever the figure cannot be read, see
/// `OcptBudgetFinancing`'s own class doc comment.
class _OcptRowFigures {
  /// This row's own promised amount — always known.
  final int promisedCents;

  /// This row's own received amount, or null while it cannot be read.
  final int? receivedCents;

  /// This row's own outstanding amount, or null alongside [receivedCents].
  final int? outstandingCents;

  /// Class constructor
  const _OcptRowFigures({required this.promisedCents, required this.receivedCents, required this.outstandingCents});
}

/// One flattened row of the resources tree — see `OcptBudgetFinancing._buildRows`'s own doc
/// comment.
sealed class _OcptResourcesTreeRow {
  const _OcptResourcesTreeRow();
}

/// A family row — the tree's own top level.
class _OcptFamilyTreeRow extends _OcptResourcesTreeRow {
  /// The family this row draws.
  final OcptBudgetResourceFamily family;

  /// This family's own three aggregate figures.
  final _OcptRowFigures aggregates;

  /// Whether this family is currently expanded.
  final bool isExpanded;

  /// Class constructor
  const _OcptFamilyTreeRow({required this.family, required this.aggregates, required this.isExpanded});
}

/// A resource row — one step under its own family.
class _OcptResourceTreeRow extends _OcptResourcesTreeRow {
  /// The resource this row draws.
  final OcptBudgetResource resource;

  /// This resource's own figures.
  final _OcptRowFigures figures;

  /// Whether this resource has at least one receipt to expand onto.
  final bool isExpandable;

  /// Whether this resource is currently expanded.
  final bool isExpanded;

  /// Class constructor
  const _OcptResourceTreeRow({
    required this.resource,
    required this.figures,
    required this.isExpandable,
    required this.isExpanded,
  });
}

/// A revenue row — one step under the takings family, mirrors [_OcptResourceTreeRow].
class _OcptRevenueTreeRow extends _OcptResourcesTreeRow {
  /// The revenue this row draws.
  final OcptBudgetRevenue revenue;

  /// This revenue's own figures.
  final _OcptRowFigures figures;

  /// Whether this revenue has at least one receipt to expand onto.
  final bool isExpandable;

  /// Whether this revenue is currently expanded.
  final bool isExpanded;

  /// Class constructor
  const _OcptRevenueTreeRow({
    required this.revenue,
    required this.figures,
    required this.isExpandable,
    required this.isExpanded,
  });
}

/// A receipt sub-row — two steps under its own family, drawn only while its parent resource or
/// revenue is expanded.
class _OcptReceiptTreeRow extends _OcptResourcesTreeRow {
  /// The journal entry this row draws.
  final OcptBudgetEntry entry;

  /// Class constructor
  const _OcptReceiptTreeRow({required this.entry});
}

/// The column header row: `Ressource` · `Dossier` · `Promis` · `Rentré` · `Reste à venir`, then a
/// blank cell over the `⋮` menu column.
class _OcptResourcesHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptResourcesHeaderRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: _ocptResourcesHeaderRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ocptTableRowHorizontalPadding),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(tr.budgetFinancingColumnResource.toUpperCase(), style: labelStyle),
                ),
              ),
              SizedBox(
                width: _ocptResourcesDossierColumnWidth,
                child: Text(tr.budgetFinancingColumnDossier.toUpperCase(), style: labelStyle),
              ),
              _amountHeaderCell(tr.budgetFinancingColumnAmount, labelStyle),
              _amountHeaderCell(tr.budgetFinancingColumnReceived, labelStyle),
              _amountHeaderCell(tr.budgetFinancingColumnOutstanding, labelStyle),
              const SizedBox(width: _ocptResourcesMenuColumnWidth),
            ],
          ),
        ),
      ),
    );
  }

  /// One amount column's own header cell, right-aligned like the figures underneath it.
  Widget _amountHeaderCell(String label, TextStyle? style) => SizedBox(
    width: _ocptResourcesAmountColumnWidth,
    child: Text(
      label.toUpperCase(),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    ),
  );
}

/// The twisty every family, resource and revenue row draws — an arrow while [isExpandable],
/// nothing but its own reserved width otherwise, so a row with nothing to expand still lines its
/// own label up with a sibling that does.
///
/// **Its own tap target is [_ocptResourcesTwistyWidth] wide over the whole of [rowHeight]**, not a
/// square of the twisty's own width — mirrors `OcptBudgetCostTracking`'s own
/// `_OcptCostTrackingTwisty` exactly, the theme's own floor for an icon button already exceeding a
/// column this narrow (`docs/architecture/budget.md`).
class _OcptResourcesTwisty extends StatelessWidget {
  /// Whether this row has anything at all to expand onto.
  final bool isExpandable;

  /// Whether this row is currently expanded.
  final bool isExpanded;

  /// Called when this twisty is clicked, or null while [isExpandable] is false.
  final VoidCallback? onTap;

  /// The row this twisty sits on own fixed height, in logical pixels — its own tap target fills it
  /// edge to edge.
  final double rowHeight;

  /// Class constructor
  const _OcptResourcesTwisty({
    required this.isExpandable,
    required this.isExpanded,
    this.onTap,
    required this.rowHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (!isExpandable) {
      return const SizedBox(width: _ocptResourcesTwistyWidth);
    }

    return SizedBox(
      width: _ocptResourcesTwistyWidth,
      height: rowHeight,
      child: InkWell(
        onTap: onTap,
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
        child: Icon(
          isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One amount cell, right-aligned, reading [ocptBudgetEmptyValue] while [cents] is null, blank
/// while [showBlank] (a receipt sub-row's own untouched columns), and the given amount otherwise.
Widget _ocptResourcesAmountCell(
  BuildContext context,
  int? cents,
  String currencyCode, {
  bool showBlank = false,
  TextStyle? style,
}) {
  final theme = Theme.of(context);
  final isNegative = cents != null && cents < 0;
  final baseStyle = style ?? theme.textTheme.bodySmall;

  return SizedBox(
    width: _ocptResourcesAmountColumnWidth,
    child: Text(
      showBlank ? "" : (cents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(cents, currencyCode)),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: baseStyle?.copyWith(
        color: isNegative ? theme.colorScheme.error : null,
        fontWeight: isNegative ? FontWeight.w600 : null,
      ),
    ),
  );
}

/// A family row: bold, a twisty, the three money aggregates, no `Dossier` cell and no menu.
class _OcptResourcesFamilyRow extends StatelessWidget {
  /// The family this row shows.
  final OcptBudgetResourceFamily family;

  /// This family's own three aggregate figures.
  final _OcptRowFigures aggregates;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this family is currently expanded.
  final bool isExpanded;

  /// Called when this row's own twisty is clicked.
  final VoidCallback onTwistyTap;

  /// Class constructor
  const _OcptResourcesFamilyRow({
    required this.family,
    required this.aggregates,
    required this.currencyCode,
    required this.isExpanded,
    required this.onTwistyTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final boldStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700);

    return SizedBox(
      height: _ocptResourcesRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ocptTableRowHorizontalPadding),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _OcptResourcesTwisty(
                    isExpandable: true,
                    isExpanded: isExpanded,
                    onTap: onTwistyTap,
                    rowHeight: _ocptResourcesRowHeight,
                  ),
                  Expanded(
                    child: Text(
                      ocptBudgetResourceFamilyLabel(tr, family),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: boldStyle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _ocptResourcesDossierColumnWidth),
            _ocptResourcesAmountCell(context, aggregates.promisedCents, currencyCode, style: boldStyle),
            _ocptResourcesAmountCell(context, aggregates.receivedCents, currencyCode, style: boldStyle),
            _ocptResourcesAmountCell(context, aggregates.outstandingCents, currencyCode, style: boldStyle),
            const SizedBox(width: _ocptResourcesMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}

/// One resource row: the label with its notes underneath, the `Dossier` badge, the three money
/// cells, then its own `⋮` menu — see `OcptBudgetFinancing`'s own class doc comment for the money
/// rules and the menu's own withholding rules.
class _OcptResourcesResourceRow extends StatelessWidget {
  /// The resource this row draws.
  final OcptBudgetResource resource;

  /// This resource's own figures.
  final _OcptRowFigures figures;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this resource is the currently selected one.
  final bool isSelected;

  /// Whether this resource has at least one receipt to expand onto.
  final bool isExpandable;

  /// Whether this resource is currently expanded.
  final bool isExpanded;

  /// Called when this row's own twisty is clicked, or null while [isExpandable] is false.
  final VoidCallback? onTwistyTap;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Called when this row's own `⋮` menu asks to edit it, or null while withheld.
  final VoidCallback? onEditRequested;

  /// Called when this row's own `⋮` menu asks to record a receipt against it, or null while
  /// withheld.
  final VoidCallback? onReceiptRequested;

  /// Called when this row's own `⋮` menu asks to undo the most recent receipt against it, or null
  /// while withheld.
  final VoidCallback? onReceiptUndoRequested;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptResourcesResourceRow({
    required this.resource,
    required this.figures,
    required this.currencyCode,
    required this.isSelected,
    required this.isExpandable,
    required this.isExpanded,
    required this.onTwistyTap,
    required this.onTap,
    required this.onEditRequested,
    required this.onReceiptRequested,
    required this.onReceiptUndoRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final hasMenu =
        onEditRequested != null ||
        onReceiptRequested != null ||
        onReceiptUndoRequested != null ||
        onDeletionRequested != null;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha) : Colors.transparent,
        child: SizedBox(
          height: _ocptResourcesRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ocptTableRowHorizontalPadding),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: _ocptResourcesIndentStep, right: 8),
                    child: Row(
                      children: [
                        _OcptResourcesTwisty(
                          isExpandable: isExpandable,
                          isExpanded: isExpanded,
                          onTap: onTwistyTap,
                          rowHeight: _ocptResourcesRowHeight,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                resource.label.isEmpty ? tr.budgetPosteUnnamed : resource.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              if (resource.notes.isNotEmpty)
                                Text(
                                  resource.notes,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: _ocptResourcesDossierColumnWidth,
                  child: _OcptResourcesResourceStatusPill(groupKind: resource.groupKind, status: resource.status),
                ),
                _ocptResourcesAmountCell(context, figures.promisedCents, currencyCode),
                _ocptResourcesAmountCell(context, figures.receivedCents, currencyCode),
                _ocptResourcesAmountCell(context, figures.outstandingCents, currencyCode),
                SizedBox(
                  width: _ocptResourcesMenuColumnWidth,
                  child: !hasMenu
                      ? null
                      : PopupMenuButton<String>(
                          tooltip: "",
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (value) => switch (value) {
                            "edit" => onEditRequested?.call(),
                            "receipt" => onReceiptRequested?.call(),
                            "receiptUndo" => onReceiptUndoRequested?.call(),
                            "delete" => onDeletionRequested?.call(),
                            _ => null,
                          },
                          itemBuilder: (context) => [
                            if (onEditRequested != null)
                              PopupMenuItem<String>(value: "edit", child: Text(tr.budgetFinancingEditAction)),
                            if (onReceiptRequested != null)
                              PopupMenuItem<String>(
                                value: "receipt",
                                child: Text(tr.budgetFinancingRecordReceiptAction),
                              ),
                            if (onReceiptUndoRequested != null)
                              PopupMenuItem<String>(
                                value: "receiptUndo",
                                child: Text(tr.budgetFinancingUndoReceiptAction),
                              ),
                            if (onDeletionRequested != null)
                              PopupMenuItem<String>(value: "delete", child: Text(tr.budgetCommittedDeleteAction)),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One revenue row: mirrors [_OcptResourcesResourceRow], its own `⋮` menu offering `Edit` /
/// `Record a receipt` / `Move up` / `Move down` / `Delete` instead.
class _OcptResourcesRevenueRow extends StatelessWidget {
  /// The revenue this row draws.
  final OcptBudgetRevenue revenue;

  /// This revenue's own figures.
  final _OcptRowFigures figures;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this revenue is the currently selected one.
  final bool isSelected;

  /// Whether this revenue has at least one receipt to expand onto.
  final bool isExpandable;

  /// Whether this revenue is currently expanded.
  final bool isExpanded;

  /// Called when this row's own twisty is clicked, or null while [isExpandable] is false.
  final VoidCallback? onTwistyTap;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Called when this row's own `⋮` menu asks to edit it, or null while withheld.
  final VoidCallback? onEditRequested;

  /// Called when this row's own `⋮` menu asks to record a receipt against it, or null while
  /// withheld.
  final VoidCallback? onReceiptRequested;

  /// Called when this row's own `⋮` menu asks to move it up, or null while withheld (including
  /// while already first).
  final VoidCallback? onMoveUpRequested;

  /// Called when this row's own `⋮` menu asks to move it down, or null while withheld (including
  /// while already last).
  final VoidCallback? onMoveDownRequested;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptResourcesRevenueRow({
    required this.revenue,
    required this.figures,
    required this.currencyCode,
    required this.isSelected,
    required this.isExpandable,
    required this.isExpanded,
    required this.onTwistyTap,
    required this.onTap,
    required this.onEditRequested,
    required this.onReceiptRequested,
    required this.onMoveUpRequested,
    required this.onMoveDownRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final hasMenu =
        onEditRequested != null ||
        onReceiptRequested != null ||
        onMoveUpRequested != null ||
        onMoveDownRequested != null ||
        onDeletionRequested != null;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha) : Colors.transparent,
        child: SizedBox(
          height: _ocptResourcesRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ocptTableRowHorizontalPadding),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: _ocptResourcesIndentStep, right: 8),
                    child: Row(
                      children: [
                        _OcptResourcesTwisty(
                          isExpandable: isExpandable,
                          isExpanded: isExpanded,
                          onTap: onTwistyTap,
                          rowHeight: _ocptResourcesRowHeight,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                revenue.label.isEmpty ? tr.budgetPosteUnnamed : revenue.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              if (revenue.notes.isNotEmpty)
                                Text(
                                  revenue.notes,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: _ocptResourcesDossierColumnWidth,
                  child: _OcptResourcesRevenueStatusPill(status: revenue.status),
                ),
                _ocptResourcesAmountCell(context, figures.promisedCents, currencyCode),
                _ocptResourcesAmountCell(context, figures.receivedCents, currencyCode),
                _ocptResourcesAmountCell(context, figures.outstandingCents, currencyCode),
                SizedBox(
                  width: _ocptResourcesMenuColumnWidth,
                  child: !hasMenu
                      ? null
                      : PopupMenuButton<String>(
                          tooltip: "",
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (value) => switch (value) {
                            "edit" => onEditRequested?.call(),
                            "receipt" => onReceiptRequested?.call(),
                            "up" => onMoveUpRequested?.call(),
                            "down" => onMoveDownRequested?.call(),
                            "delete" => onDeletionRequested?.call(),
                            _ => null,
                          },
                          itemBuilder: (context) => [
                            if (onEditRequested != null)
                              PopupMenuItem<String>(value: "edit", child: Text(tr.budgetFinancingEditAction)),
                            if (onReceiptRequested != null)
                              PopupMenuItem<String>(
                                value: "receipt",
                                child: Text(tr.budgetFinancingRecordReceiptAction),
                              ),
                            if (onMoveUpRequested != null)
                              PopupMenuItem<String>(value: "up", child: Text(tr.budgetPosteMoveUpAction)),
                            if (onMoveDownRequested != null)
                              PopupMenuItem<String>(value: "down", child: Text(tr.budgetPosteMoveDownAction)),
                            if (onDeletionRequested != null)
                              PopupMenuItem<String>(value: "delete", child: Text(tr.budgetCommittedDeleteAction)),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A receipt sub-row: a dot, a `Rentré` badge, the entry's own date and wording, its amount printed
/// in the `Rentré` column alone — the other money cells left blank, no `Dossier` cell, no menu.
class _OcptResourcesReceiptRow extends StatelessWidget {
  /// The journal entry this row draws.
  final OcptBudgetEntry entry;

  /// The project's own default VAT rate, in basis points, or null while it declares none — what
  /// [entry]'s own credit is read tax-inclusive against.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this receipt is the currently selected one.
  final bool isSelected;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptResourcesReceiptRow({
    required this.entry,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final dateText = DateFormat.yMd().format(entry.date);
    final label = entry.label.isEmpty ? dateText : "$dateText · ${entry.label}";
    // Read exactly the way the `Rentré` column above it is — tax-inclusive, through the journal's
    // own reading rather than off `creditCents` raw — so a sub-row can never disagree with the
    // total it sits under, and an entry whose rate is unknown prints the same em dash everywhere.
    final creditCents = ocptBudgetEntryCreditCentsOf(
      entry,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha) : Colors.transparent,
        child: SizedBox(
          height: _ocptResourcesReceiptRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ocptTableRowHorizontalPadding),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: _ocptResourcesTwistyWidth + _ocptResourcesIndentStep * 2,
                      right: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: _ocptResourcesDotDiameter,
                          height: _ocptResourcesDotDiameter,
                          decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(ocptRadiusSmall),
                          ),
                          child: Text(
                            tr.budgetFinancingColumnReceived,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: _ocptResourcesDossierColumnWidth),
                _ocptResourcesAmountCell(context, null, currencyCode, showBlank: true),
                SizedBox(
                  width: _ocptResourcesAmountColumnWidth,
                  child: Text(
                    creditCents == null
                        ? ocptBudgetEmptyValue
                        : ocptBudgetAmountLabel(creditCents, currencyCode),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                _ocptResourcesAmountCell(context, null, currencyCode, showBlank: true),
                const SizedBox(width: _ocptResourcesMenuColumnWidth),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The total row: `Total · N familles`, the three totals, and — in the `Dossier` column, while the
/// project holds any in-kind resource at all — the quiet `dont {amount} valorisés` caption.
class _OcptResourcesTotalRow extends StatelessWidget {
  /// How many family rows are actually drawn.
  final int familyCount;

  /// The grand total across every drawn family.
  final _OcptRowFigures aggregates;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the project holds any in-kind resource at all.
  final bool hasInKind;

  /// The in-kind total, read only while [hasInKind].
  final int valuedCents;

  /// Class constructor
  const _OcptResourcesTotalRow({
    required this.familyCount,
    required this.aggregates,
    required this.currencyCode,
    required this.hasInKind,
    required this.valuedCents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final boldStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: _ocptResourcesTotalRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ocptTableRowHorizontalPadding),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tr.budgetFinancingTotalRowLabel(familyCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: boldStyle,
                ),
              ),
              SizedBox(
                width: _ocptResourcesDossierColumnWidth,
                child: !hasInKind
                    ? null
                    : Text(
                        tr.budgetFinancingValuedCaption(ocptBudgetAmountLabel(valuedCents, currencyCode)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
              ),
              _ocptResourcesAmountCell(context, aggregates.promisedCents, currencyCode, style: boldStyle),
              _ocptResourcesAmountCell(context, aggregates.receivedCents, currencyCode, style: boldStyle),
              _ocptResourcesAmountCell(context, aggregates.outstandingCents, currencyCode, style: boldStyle),
              const SizedBox(width: _ocptResourcesMenuColumnWidth),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of `OcptBudgetResourceStatus`'s own three badges, for a resource row's own `Dossier` cell —
/// mirrors `OcptBudgetCostTracking`'s own status pills: a bordered outline while merely in play,
/// growing into a solid fill once held on paper.
class _OcptResourcesResourceStatusPill extends StatelessWidget {
  /// The group the resource this pill belongs to sits in — what its [status] is called depends on
  /// it.
  final OcptBudgetResourceGroupKind groupKind;

  /// The status this pill paints.
  final OcptBudgetResourceStatus status;

  /// Class constructor
  const _OcptResourcesResourceStatusPill({required this.groupKind, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final accent = ocptBudgetResourceStatusAccentColor(theme.colorScheme, status);
    final isSolid = status == OcptBudgetResourceStatus.confirmed;
    final alpha = status.index / (OcptBudgetResourceStatus.values.length - 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSolid ? accent : accent.withValues(alpha: alpha),
        border: status == OcptBudgetResourceStatus.pending
            ? Border.all(color: accent.withValues(alpha: 0.6))
            : null,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        ocptBudgetResourceStatusLabel(tr, groupKind, status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isSolid ? theme.colorScheme.onPrimary : accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One of `OcptBudgetRevenueStatus`'s own three badges — mirrors
/// [_OcptResourcesResourceStatusPill], generic over a different enum.
class _OcptResourcesRevenueStatusPill extends StatelessWidget {
  /// The status this pill paints.
  final OcptBudgetRevenueStatus status;

  /// Class constructor
  const _OcptResourcesRevenueStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final accent = ocptBudgetRevenueStatusAccentColor(theme.colorScheme, status);
    final isSolid = status == OcptBudgetRevenueStatus.invoiced;
    final alpha = status.index / (OcptBudgetRevenueStatus.values.length - 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSolid ? accent : accent.withValues(alpha: alpha),
        border: status == OcptBudgetRevenueStatus.expected
            ? Border.all(color: accent.withValues(alpha: 0.6))
            : null,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        ocptBudgetRevenueStatusLabel(tr, status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isSolid ? theme.colorScheme.onPrimary : accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The coverage band, under everything: `Le film coûte` and the quote's own total on the left, a
/// two-tone bar and a sentence in the middle, and an action back to the expenses document on the
/// right.
///
/// **Draws only while [OcptBudgetResourcesCoverage.needs] holds something** — `OcptBudgetFinancing`
/// itself withholds this widget entirely while the quote is empty, the same reading the cash
/// projection card already follows.
class _OcptResourcesCoverageBand extends StatelessWidget {
  /// What the band reads — never computed here, always `ocptBudgetResourcesCoverageOf`'s own
  /// answer.
  final OcptBudgetResourcesCoverage coverage;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when the band's own action is clicked.
  final VoidCallback onExpensesRequested;

  /// Class constructor
  const _OcptResourcesCoverageBand({
    required this.coverage,
    required this.currencyCode,
    required this.onExpensesRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final needs = coverage.needs;
    final needsAmount = ocptBudgetAmountLabel(needs.amountCents, currencyCode);
    final needsText = needs.isComplete
        ? needsAmount
        : tr.budgetDashboardBalanceCoverageReadOut(needsAmount, needs.coveredLineCount, needs.lineCount);

    final receivedFraction = needs.amountCents <= 0
        ? (coverage.received.amountCents > 0 ? 1.0 : 0.0)
        : (coverage.received.amountCents / needs.amountCents).clamp(0.0, 1.0);
    final plannedFraction = needs.amountCents <= 0
        ? (coverage.plannedCents > 0 ? 1.0 : 0.0)
        : (coverage.plannedCents / needs.amountCents).clamp(0.0, 1.0);

    final receivedAmount = ocptBudgetAmountLabel(coverage.received.amountCents, currencyCode);
    final promisedAmount = ocptBudgetAmountLabel(coverage.promisedCents, currencyCode);
    final suffixColor = coverage.isCovered ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.error;
    final suffixText = coverage.isCovered
        ? tr.budgetFinancingCoverageCoveredReadOut
        : tr.budgetFinancingCoverageMissingReadOut(ocptBudgetAmountLabel(coverage.missingCents, currencyCode));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: _ocptResourcesCoverageNeedsColumnWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr.budgetFinancingCoverageTitle.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(needsText, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(_ocptResourcesCoverageBarHeight / 2),
                        child: SizedBox(
                          height: _ocptResourcesCoverageBarHeight,
                          child: ColoredBox(color: theme.colorScheme.surfaceContainerHigh),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(_ocptResourcesCoverageBarHeight / 2),
                        child: FractionallySizedBox(
                          widthFactor: plannedFraction,
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: _ocptResourcesCoverageBarHeight,
                            child: ColoredBox(color: theme.colorScheme.primary.withValues(alpha: 0.35)),
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(_ocptResourcesCoverageBarHeight / 2),
                        child: FractionallySizedBox(
                          widthFactor: receivedFraction,
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: _ocptResourcesCoverageBarHeight,
                            child: ColoredBox(color: theme.colorScheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodySmall,
                      children: [
                        TextSpan(text: tr.budgetFinancingCoverageReadOut(receivedAmount, promisedAmount)),
                        const TextSpan(text: " · "),
                        TextSpan(
                          text: suffixText,
                          style: TextStyle(
                            color: suffixColor,
                            fontWeight: coverage.isCovered ? null : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            OutlinedButton(
              onPressed: onExpensesRequested,
              child: Text(tr.budgetFinancingCoverageExpensesAction),
            ),
          ],
        ),
      ),
    );
  }
}
