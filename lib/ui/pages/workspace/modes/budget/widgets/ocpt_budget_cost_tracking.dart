// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';

/// The `N°` column's own fixed width, in logical pixels — detailed header only.
const double _ocptCostTrackingNumberColumnWidth = 44;

/// The `Quote`, `Paid`, `Committed`, `Remaining`, `Variance` and `Consumed` columns' own fixed
/// width, in logical pixels.
const double _ocptCostTrackingAmountColumnWidth = 108;

/// The trailing `⋮` menu column's own fixed width, in logical pixels.
const double _ocptCostTrackingMenuColumnWidth = 36;

/// The narrowest the `Poste` column is ever drawn, in logical pixels — past this, the scrolling
/// pane (the amount columns) scrolls horizontally under the pinned identity pane rather than
/// crushing the poste names, mirroring `OcptBreakdownRecapTable`'s own
/// `_ocptRecapElementColumnMinWidth`.
const double _ocptCostTrackingPosteColumnMinWidth = 220;

/// Every poste row's own fixed height, in logical pixels — tall enough for the `Quote` cell's own
/// two stacked lines (the headline figure, then the other tax basis and, when a poste's lines all
/// share one, the rate underneath it).
///
/// The table draws as two independently laid-out panes side by side — the pinned `N°`/`Poste`
/// columns, the scrolling amount columns — each its own plain `Column`, sharing no `RenderObject`
/// with the other. A row sized to its own content, the ordinary Flutter way, would let a poste
/// whose lines carry a priced second basis (a taller `Quote` cell) sit a few pixels taller than a
/// neighbour with none — and since the `Quote` cell lives in the *scrolling* pane while the poste
/// name lives in the *pinned* one, the two panes would drift out of step by exactly that many
/// pixels, row after row. Claiming this one named height, whatever a particular row actually holds,
/// is what keeps a poste's own name level with its own figures with neither `IntrinsicHeight` nor a
/// `ScrollController` shared between the panes' two `SingleChildScrollView`s.
const double _ocptCostTrackingRowHeight = 48;

/// The header row's own fixed height, in logical pixels — see [_ocptCostTrackingRowHeight]'s own
/// doc comment for why the two panes need every row, the header included, to claim a named height
/// rather than size to its own single-line content.
const double _ocptCostTrackingHeaderRowHeight = 36;

/// The total row's own fixed height, in logical pixels — tall enough for
/// `tr.budgetCostTrackingCoverageReadOut`'s own two lines, printed here in place of the plain
/// amount while the excluding-tax total does not yet cover every poste; see
/// [_ocptCostTrackingRowHeight]'s own doc comment for why a named height, not the tallest cell's
/// own, is what keeps this row's two panes aligned.
const double _ocptCostTrackingTotalRowHeight = 48;

/// The budget mode's cost-tracking view: one row per poste, a total row, then a `+ Poste`
/// creation footer — this mode's own working surface.
///
/// **The `N°` and `Poste` columns are pinned**, drawn in their own pane at the left edge that
/// never moves; only the six amount columns and the trailing `⋮` menu, in a second pane to their
/// right, scroll horizontally once the centre dock narrows past
/// [_ocptCostTrackingPosteColumnMinWidth] — a poste nobody can name is worse than a figure nobody
/// can read yet, so a row's own identity survives the scroll even when its own numbers no longer
/// fit. The two panes share one vertical scroll, so the whole table still moves together, and, row
/// for row, the exact same height ([_ocptCostTrackingRowHeight]'s own doc comment argues why).
///
/// A composite panel (`docs/architecture/foundations.md`'s own idiom): takes [isReadOnly] rather
/// than a null callback per affordance, and hands its own three writing affordances — the creation
/// footer, a row's own `⋮` menu, the reorder it opens onto — the null callbacks that withholds them
/// under a version preview, so a control added later here can't be gated in one place and
/// forgotten in the other.
///
/// [isSimplified] switches every poste's own displayed name between [OcptBudgetPoste.simpleLabel]
/// (falling back to [OcptBudgetPoste.label] when null) and [OcptBudgetPoste.label] itself, and
/// hides the `N°` column — a display switch over the same data, never a second read.
///
/// [paidCentsOf] and [committedCentsOf] read the cash journal's own per-poste totals
/// (`OcptBudgetState.paidCentsOf`/`committedCentsOf`, backed by
/// `lib/utils/ocpt_budget_journal.dart`/`ocpt_budget_projection.dart`): a poste with no entry or
/// commitment against it answers **0**, honestly, rather than a stand-in for an unknown figure —
/// the journal exists and is kept, so "nothing has moved" is a fact this table can state outright.
/// `Paid`, `Committed`, `Remaining` and `Variance` therefore always print a real amount. `Consumed`
/// is the one column that still prints [ocptBudgetEmptyValue]: it is a ratio, and
/// [ocptBudgetConsumedRatioOf] answers null for a poste carrying no quote at all, where a
/// percentage would be a division by zero rather than a figure.
///
/// **A row's own `Rename` menu entry selects it and opens the `Inspector` tab rather than editing
/// its name in place.** This app has no precedent for renaming a record inline inside a plain list
/// — the two inline-answer exceptions the confirm-dialog rule already carries (the `Versions` dock
/// panel, the project dictionary dialog) exist because a list of rows there has no other way of
/// saying *which* row is being talked about, which is not this table's problem: every row already
/// opens straight onto its own poste's fields the moment it is clicked. A poste's own `Label` and
/// `Code` fields living in its inspector, exactly where a person's or an element's own name field
/// lives in the resources mode's sheets, is the reading this table follows instead.
class OcptBudgetCostTracking extends StatelessWidget {
  /// Every live poste, in display order.
  final List<OcptBudgetPoste> postes;

  /// The id of the currently selected poste, or null while none is.
  final String? selectedPosteId;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// Which basis the header's excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null while nobody has recorded one.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// A poste's own paid total, in cents, tax-inclusive — see the class doc comment.
  final int Function(String posteId) paidCentsOf;

  /// A poste's own committed total, in cents, tax-inclusive — see the class doc comment.
  final int Function(String posteId) committedCentsOf;

  /// Whether the mode shows a project version being previewed read-only — see the class doc
  /// comment.
  final bool isReadOnly;

  /// Called with a poste's id when its row is clicked, opening the `Inspector` tab on it.
  final ValueChanged<String> onPosteSelected;

  /// Called when the footer's `+ Poste` action is clicked, or null while [isReadOnly].
  final VoidCallback? onPosteCreationRequested;

  /// Called with a poste's id and whether it moves up (`true`) or down (`false`), from a row's own
  /// `⋮` menu, or null while [isReadOnly]. `moveUp` is named, never positional, so a call site
  /// reads which direction it means rather than a bare `true`/`false`.
  final void Function(String posteId, {required bool moveUp})? onPosteReorderRequested;

  /// Called with a poste's id when a row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onPosteDeletionRequested;

  /// Class constructor
  const OcptBudgetCostTracking({
    super.key,
    required this.postes,
    required this.selectedPosteId,
    required this.isSimplified,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.paidCentsOf,
    required this.committedCentsOf,
    required this.isReadOnly,
    required this.onPosteSelected,
    required this.onPosteCreationRequested,
    required this.onPosteReorderRequested,
    required this.onPosteDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final allLines = [for (final poste in postes) ...poste.lines];
    final total = ocptBudgetTotalOf(
      allLines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final coveredPosteCount = _coveredPosteCountOf();

    return LayoutBuilder(
      builder: (context, constraints) {
        final identityFixedWidth = isSimplified ? 0.0 : _ocptCostTrackingNumberColumnWidth;
        // Quote, Paid, Committed, Remaining, Variance, Consumed — six amount columns.
        final amountsWidth = 6 * _ocptCostTrackingAmountColumnWidth + _ocptCostTrackingMenuColumnWidth;
        final posteWidth = (constraints.maxWidth - identityFixedWidth - amountsWidth).clamp(
          _ocptCostTrackingPosteColumnMinWidth,
          double.infinity,
        );
        final pinnedWidth = identityFixedWidth + posteWidth;
        final showFooter = !isReadOnly && onPosteCreationRequested != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: pinnedWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _OcptCostTrackingIdentityHeaderCell(
                            isSimplified: isSimplified,
                            posteWidth: posteWidth,
                          ),
                          for (final poste in postes)
                            _OcptCostTrackingIdentityRow(
                              poste: poste,
                              isSelected: poste.id == selectedPosteId,
                              isSimplified: isSimplified,
                              posteWidth: posteWidth,
                              onTap: () => onPosteSelected(poste.id),
                            ),
                          _OcptCostTrackingIdentityTotalRow(
                            isSimplified: isSimplified,
                            posteWidth: posteWidth,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: amountsWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _OcptCostTrackingAmountsHeaderRow(),
                              for (final poste in postes)
                                _OcptCostTrackingAmountsRow(
                                  poste: poste,
                                  isSelected: poste.id == selectedPosteId,
                                  taxBasis: taxBasis,
                                  defaultVatRateBasisPoints: defaultVatRateBasisPoints,
                                  currencyCode: currencyCode,
                                  paidCents: paidCentsOf(poste.id),
                                  committedCents: committedCentsOf(poste.id),
                                  onTap: () => onPosteSelected(poste.id),
                                  onRenameRequested: isReadOnly
                                      ? null
                                      : () => onPosteSelected(poste.id),
                                  onMoveUpRequested: isReadOnly
                                      ? null
                                      : () => onPosteReorderRequested?.call(poste.id, moveUp: true),
                                  onMoveDownRequested: isReadOnly
                                      ? null
                                      : () =>
                                            onPosteReorderRequested?.call(poste.id, moveUp: false),
                                  onDeletionRequested: isReadOnly
                                      ? null
                                      : () => onPosteDeletionRequested?.call(poste.id),
                                ),
                              _OcptCostTrackingAmountsTotalRow(
                                total: total,
                                currencyCode: currencyCode,
                                posteCount: postes.length,
                                coveredPosteCount: coveredPosteCount,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showFooter) _OcptCostTrackingCreationFooter(onTap: onPosteCreationRequested!),
          ],
        );
      },
    );
  }

  /// How many postes count as covered under [taxBasis] — "every one of its own lines does"
  /// (`docs/architecture/budget.md`) — what the total row's own coverage read-out counts
  /// against `postes.length`.
  int _coveredPosteCountOf() {
    var count = 0;
    for (final poste in postes) {
      final posteTotal = ocptBudgetTotalOf(
        poste.lines,
        basis: taxBasis,
        projectVatRateBasisPoints: defaultVatRateBasisPoints,
      );
      if (posteTotal.isComplete) {
        count++;
      }
    }
    return count;
  }
}

/// The pinned pane's own header cell: the `N°` and `Poste` column headings.
class _OcptCostTrackingIdentityHeaderCell extends StatelessWidget {
  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double posteWidth;

  /// Class constructor
  const _OcptCostTrackingIdentityHeaderCell({required this.isSimplified, required this.posteWidth});

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
        height: _ocptCostTrackingHeaderRowHeight,
        child: Row(
          children: [
            if (!isSimplified)
              SizedBox(
                width: _ocptCostTrackingNumberColumnWidth,
                child: Text(
                  tr.budgetCostTrackingColumnNumber.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
              ),
            SizedBox(
              width: posteWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(tr.budgetCostTrackingColumnPoste.toUpperCase(), style: labelStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The scrolling pane's own header row: the six amount column headings, then a blank cell over the
/// `⋮` menu column.
class _OcptCostTrackingAmountsHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptCostTrackingAmountsHeaderRow();

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
        height: _ocptCostTrackingHeaderRowHeight,
        child: Row(
          children: [
            _headerCell(tr.budgetCostTrackingColumnQuote, labelStyle),
            _headerCell(tr.budgetCostTrackingColumnPaid, labelStyle),
            _headerCell(tr.budgetCostTrackingColumnCommitted, labelStyle),
            _headerCell(tr.budgetCostTrackingColumnRemaining, labelStyle),
            _headerCell(tr.budgetCostTrackingColumnVariance, labelStyle),
            _headerCell(tr.budgetCostTrackingColumnConsumed, labelStyle),
            const SizedBox(width: _ocptCostTrackingMenuColumnWidth),
          ],
        ),
      ),
    );
  }

  /// One amount column's own header cell, right-aligned like the figures underneath it.
  Widget _headerCell(String label, TextStyle? style) => SizedBox(
    width: _ocptCostTrackingAmountColumnWidth,
    child: Text(
      label.toUpperCase(),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    ),
  );
}

/// The pinned pane's own row: one poste's `N°` and `Poste` cells.
///
/// **This row is one half of the poste's own row** — [_OcptCostTrackingAmountsRow] draws the
/// other, in the scrolling pane, for the very same [poste]. The two share [isSelected], so they
/// paint the very same background, and each carries its own tap target calling the very same
/// [onTap], so a click on either half selects the poste: together they read as one row to the
/// user even though they are two separate widgets with no `RenderObject` in common.
class _OcptCostTrackingIdentityRow extends StatelessWidget {
  /// The poste this row shows.
  final OcptBudgetPoste poste;

  /// Whether this poste is the currently selected one.
  final bool isSelected;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double posteWidth;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptCostTrackingIdentityRow({
    required this.poste,
    required this.isSelected,
    required this.isSimplified,
    required this.posteWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final label = ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          height: _ocptCostTrackingRowHeight,
          child: Row(
            children: [
              if (!isSimplified)
                SizedBox(
                  width: _ocptCostTrackingNumberColumnWidth,
                  child: Text(
                    poste.code,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              SizedBox(
                width: posteWidth,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Text(
                    label.isEmpty ? tr.budgetPosteUnnamed : label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: label.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The scrolling pane's own row: one poste's six amount cells and its own `⋮` menu — see
/// [_OcptCostTrackingIdentityRow]'s own doc comment for why it shares [isSelected] and [onTap]
/// with the pinned half of the very same row.
class _OcptCostTrackingAmountsRow extends StatelessWidget {
  /// The poste this row shows.
  final OcptBudgetPoste poste;

  /// Whether this poste is the currently selected one.
  final bool isSelected;

  /// Which basis the header's excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// This poste's own paid total, in cents.
  final int paidCents;

  /// This poste's own committed total, in cents.
  final int committedCents;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Called when the row's own `⋮` menu asks to rename this poste, or null while withheld.
  final VoidCallback? onRenameRequested;

  /// Called when the row's own `⋮` menu asks to move this poste up, or null while withheld.
  final VoidCallback? onMoveUpRequested;

  /// Called when the row's own `⋮` menu asks to move this poste down, or null while withheld.
  final VoidCallback? onMoveDownRequested;

  /// Called when the row's own `⋮` menu asks to delete this poste, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptCostTrackingAmountsRow({
    required this.poste,
    required this.isSelected,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.paidCents,
    required this.committedCents,
    required this.onTap,
    required this.onRenameRequested,
    required this.onMoveUpRequested,
    required this.onMoveDownRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final quoted = ocptBudgetTotalOf(
      poste.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final secondaryBasis = taxBasis == OcptBudgetTaxBasis.includingTax
        ? OcptBudgetTaxBasis.excludingTax
        : OcptBudgetTaxBasis.includingTax;
    final secondary = ocptBudgetTotalOf(
      poste.lines,
      basis: secondaryBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final uniformRate = ocptBudgetPosteUniformVatRateOf(
      poste.lines,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          height: _ocptCostTrackingRowHeight,
          child: Row(
            children: [
              SizedBox(
                width: _ocptCostTrackingAmountColumnWidth,
                child: _OcptCostTrackingQuoteCell(
                  primaryCents: quoted.amountCents,
                  secondaryCents: secondary.coveredLineCount == 0 ? null : secondary.amountCents,
                  uniformRate: uniformRate,
                  currencyCode: currencyCode,
                ),
              ),
              _amountCell(context, ocptBudgetAmountLabel(paidCents, currencyCode)),
              _amountCell(context, ocptBudgetAmountLabel(committedCents, currencyCode)),
              _amountCell(
                context,
                ocptBudgetAmountLabel(
                  ocptBudgetRemainingCents(
                    quotedAmountCents: quoted.amountCents,
                    paidCents: paidCents,
                    committedCents: committedCents,
                  ),
                  currencyCode,
                ),
              ),
              _amountCell(
                context,
                ocptBudgetAmountLabel(
                  ocptBudgetVarianceCents(
                    quotedAmountCents: quoted.amountCents,
                    paidCents: paidCents,
                    committedCents: committedCents,
                  ),
                  currencyCode,
                ),
              ),
              _amountCell(context, _consumedTextOf(quoted.amountCents)),
              SizedBox(
                width: _ocptCostTrackingMenuColumnWidth,
                child: (onRenameRequested == null &&
                        onMoveUpRequested == null &&
                        onMoveDownRequested == null &&
                        onDeletionRequested == null)
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: "",
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (value) => switch (value) {
                          "rename" => onRenameRequested?.call(),
                          "up" => onMoveUpRequested?.call(),
                          "down" => onMoveDownRequested?.call(),
                          "delete" => onDeletionRequested?.call(),
                          _ => null,
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: "rename",
                            child: Text(tr.budgetPosteRenameAction),
                          ),
                          PopupMenuItem<String>(value: "up", child: Text(tr.budgetPosteMoveUpAction)),
                          PopupMenuItem<String>(
                            value: "down",
                            child: Text(tr.budgetPosteMoveDownAction),
                          ),
                          PopupMenuItem<String>(
                            value: "delete",
                            child: Text(tr.budgetPosteDeleteAction),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One amount cell, right-aligned, reading [ocptBudgetEmptyValue] while [text] is null — only the
  /// `Consumed` column ever hands this null, see [_consumedTextOf]'s own doc comment.
  Widget _amountCell(BuildContext context, String? text) => SizedBox(
    width: _ocptCostTrackingAmountColumnWidth,
    child: Text(
      text ?? ocptBudgetEmptyValue,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );

  /// The `Consumed` column's own percentage text, or [ocptBudgetEmptyValue] while
  /// [ocptBudgetConsumedRatioOf] answers null (a poste carrying no quote at all).
  String _consumedTextOf(int quotedAmountCents) {
    final ratio = ocptBudgetConsumedRatioOf(
      quotedAmountCents: quotedAmountCents,
      paidCents: paidCents,
      committedCents: committedCents,
    );
    if (ratio == null) {
      return ocptBudgetEmptyValue;
    }

    return "${(ratio * 100).round()} %";
  }
}

/// The `Quote` column's own cell: the primary figure, then, in small type, the other basis' own
/// figure and — only when the poste's lines all share one — the rate it reads under.
class _OcptCostTrackingQuoteCell extends StatelessWidget {
  /// The amount shown as the headline figure, in the header's own selected basis.
  final int primaryCents;

  /// The amount shown underneath, in the other basis, or null while no line of this poste covers
  /// it at all — "it carries nothing" (`docs/architecture/budget.md`).
  final int? secondaryCents;

  /// The one rate every line of this poste shares, or null while they don't (or none is known) —
  /// see `ocptBudgetPosteUniformVatRateOf`'s own doc comment.
  final OcptBudgetEffectiveVatRate? uniformRate;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptCostTrackingQuoteCell({
    required this.primaryCents,
    required this.secondaryCents,
    required this.uniformRate,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryCents = this.secondaryCents;
    final uniformRate = this.uniformRate;

    final secondaryText = secondaryCents == null
        ? null
        : uniformRate == null
        ? ocptBudgetAmountLabel(secondaryCents, currencyCode)
        : "${ocptBudgetAmountLabel(secondaryCents, currencyCode)} · "
              "${ocptVatRatePercentTextOf(uniformRate.basisPoints)} %";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ocptBudgetAmountLabel(primaryCents, currencyCode),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        if (secondaryText != null)
          Text(
            secondaryText,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: uniformRate?.isOverridden == true
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// The pinned pane's own total row: just the `Total` label, spanning the `N°`/`Poste` cells' own
/// width so it lines up with [_OcptCostTrackingAmountsTotalRow], the other half of the very same
/// row, in the scrolling pane.
class _OcptCostTrackingIdentityTotalRow extends StatelessWidget {
  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double posteWidth;

  /// Class constructor
  const _OcptCostTrackingIdentityTotalRow({required this.isSimplified, required this.posteWidth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: _ocptCostTrackingTotalRowHeight,
        child: Row(
          children: [
            if (!isSimplified) const SizedBox(width: _ocptCostTrackingNumberColumnWidth),
            SizedBox(
              width: posteWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  tr.budgetCostTrackingTotalRowLabel,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The scrolling pane's own total row: the grand `Quote` total (with its own coverage read-out).
/// The five money-that-moved columns are left blank here: summing `paidCentsOf`/`committedCentsOf`
/// across every poste is not the same reduction those two per-poste maps answer (an entry naming
/// no poste moves cash without pricing any one poste's total), so a grand `Paid`/`Committed`
/// total is not drawn until a view actually reads the journal as a whole. See
/// [_OcptCostTrackingIdentityTotalRow]'s own doc comment for the pinned half of the very same row.
class _OcptCostTrackingAmountsTotalRow extends StatelessWidget {
  /// The grand total, in the header's own selected basis, and how many lines it covers.
  final OcptBudgetCoveredTotal total;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The total number of live postes.
  final int posteCount;

  /// How many of them count as covered — every one of their own lines is.
  final int coveredPosteCount;

  /// Class constructor
  const _OcptCostTrackingAmountsTotalRow({
    required this.total,
    required this.currencyCode,
    required this.posteCount,
    required this.coveredPosteCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final amountText = ocptBudgetAmountLabel(total.amountCents, currencyCode);
    final coverageText = total.isComplete
        ? null
        : tr.budgetCostTrackingCoverageReadOut(amountText, coveredPosteCount, posteCount);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: _ocptCostTrackingTotalRowHeight,
        child: Row(
          children: [
            SizedBox(
              width: _ocptCostTrackingAmountColumnWidth,
              child: Text(
                coverageText ?? amountText,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            for (var i = 0; i < 5; i++)
              SizedBox(
                width: _ocptCostTrackingAmountColumnWidth,
                child: Text(
                  ocptBudgetEmptyValue,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(width: _ocptCostTrackingMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}

/// The table's own `+ Poste` creation footer, drawn below the table rather than as one of its own
/// scrolling rows — left-aligned like the pinned pane above it, and, unlike it, never scrolled
/// away by either the table's own vertical or horizontal scroll.
class _OcptCostTrackingCreationFooter extends StatelessWidget {
  /// Called when this footer is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptCostTrackingCreationFooter({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              tr.budgetPosteCreationAction,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
