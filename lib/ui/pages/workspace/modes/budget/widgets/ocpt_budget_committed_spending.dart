// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The width, in logical pixels, under which the two columns stack instead of sitting side by
/// side — see the class doc comment.
const double _ocptCommittedWrapWidth = 900;

/// The `Due date` column's own fixed width, in logical pixels.
const double _ocptCommittedDueDateColumnWidth = 92;

/// The `Poste` column's own fixed width, in logical pixels.
const double _ocptCommittedPosteColumnWidth = 160;

/// The `Status` column's own fixed width, in logical pixels.
const double _ocptCommittedStatusColumnWidth = 132;

/// The `Amount` column's own fixed width, in logical pixels.
const double _ocptCommittedAmountColumnWidth = 108;

/// The trailing `⋮` menu column's own fixed width, in logical pixels — matches every other table
/// of this mode's own menu column.
const double _ocptCommittedMenuColumnWidth = 36;

/// Every commitment row's own fixed height, in logical pixels.
/// The narrowest the commitments table is drawn at before it starts scrolling sideways, in
/// logical pixels: its five fixed columns (528) plus the row inset (24) plus a floor of 240 for
/// the wording, which is the one column that has nothing but an `Expanded` to size it.
///
/// Same reasoning as `OcptBudgetCashJournal`'s own floor, and the same geometry causes it: the
/// centre pane loses roughly 580 px the moment the right dock opens, and a `Row` of fixed columns
/// then drops its `Expanded` to zero and clips the rest — losing the wording altogether, and
/// silently, since a release build paints no overflow band.
const double _ocptCommittedMinTableWidth = 792;

const double _ocptCommittedRowHeight = 44;

/// The header row's own fixed height, in logical pixels.
const double _ocptCommittedHeaderRowHeight = 36;

/// The height of one projection step's own bar, in logical pixels — mirrors
/// `OcptBudgetDashboard`'s own `_ocptDashboardBarHeight`.
const double _ocptCommittedProjectionBarHeight = 6;

/// How many of `OcptBudgetCommitmentStatus`'s own four values [_OcptCommittedStatusBadge] paints —
/// its own fill grows heavier step by step, `OcptBudgetCommitmentStatus.declared` alone drawn
/// solid.
const List<double> _ocptCommittedStatusFillAlphas = [0, 0.12, 0.2, 1];

/// The budget mode's committed-spending view: the outstanding commitments next to the cash
/// projection they build — the layout the validated mockup lays this view out as, **two columns
/// side by side, the commitments table taking roughly two thirds and the cash projection one
/// third, wrapping onto one another once the centre narrows past [_ocptCommittedWrapWidth]** rather
/// than crushing either column unreadable.
///
/// A composite panel (`docs/architecture/foundations.md`'s own idiom): takes [isReadOnly] rather
/// than a null callback per affordance, and withholds — never disables — every one of its own
/// writing affordances under it: the `+ Commitment` action, a row's own click (which opens the
/// commitment dialog to edit it) and its own `⋮` menu's `Settle`/`Undo settlement`/`Delete` entries.
///
/// **A settled commitment stays in the list**, wearing its own distinct badge
/// (`_OcptCommittedSettledBadge`) in place of its own four-value status one, and reading muted
/// rather than in the ordinary body colour — set apart from the outstanding ones because it is
/// history worth keeping, not a record that vanished the moment it was paid. It counts towards
/// neither the outstanding total nor the projection: `ocptBudgetCommittedCentsByPosteId` and
/// `ocptBudgetProjectionOf` already exclude it (their own doc comments), which is why this view
/// never re-derives that exclusion itself.
///
/// Empty state: a project carrying no commitment at all shows [OcptWorkspaceEmptyMode] **where the
/// table would be, under a heading band that stays drawn** — `OcptBudgetCashJournal`'s own reading,
/// and for its reason: `+ Commitment` lives in that band, and a list nobody has written in yet is
/// exactly when somebody reaches for it. The projection beside it needs no such care: with nothing
/// outstanding it already shows the balance and stops there.
class OcptBudgetCommittedSpending extends StatelessWidget {
  /// Every live commitment, in the due-date order `OcptBudgetJournalService.loadCommitments` gives
  /// them — never reordered here.
  final List<OcptBudgetCommitment> commitments;

  /// Every live poste of the project, used to resolve a commitment's own poste name.
  final List<OcptBudgetPoste> postes;

  /// The cash journal's own balance — `OcptBudgetCashTotals.balanceCents` — the figure the
  /// projection opens at.
  final int openingBalanceCents;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The project's default VAT rate, in basis points, or null while nobody has recorded one.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the mode shows a project version being previewed read-only — see the class doc
  /// comment.
  final bool isReadOnly;

  /// Called when the heading's own `+ Commitment` action is clicked, or null while [isReadOnly].
  final VoidCallback? onCommitmentCreationRequested;

  /// Called with a commitment when its row is clicked, opening the commitment dialog on it, or null
  /// while [isReadOnly].
  final ValueChanged<OcptBudgetCommitment>? onCommitmentTapped;

  /// Called with a commitment when its row's own `⋮` menu asks to record its payment (only offered
  /// while it isn't settled yet), or null while [isReadOnly]. Opens `OcptBudgetEntryDialog`
  /// pre-filled from the commitment.
  final ValueChanged<OcptBudgetCommitment>? onCommitmentSettleRequested;

  /// Called with a commitment's id when its row's own `⋮` menu asks to undo its settlement (only
  /// offered while it is settled), or null while [isReadOnly]. Clears the link alone — the journal
  /// entry it named stays exactly where it is.
  final ValueChanged<String>? onCommitmentUnsettleRequested;

  /// Called with a commitment's id when its row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onCommitmentDeletionRequested;

  /// Class constructor
  const OcptBudgetCommittedSpending({
    super.key,
    required this.commitments,
    required this.postes,
    required this.openingBalanceCents,
    required this.isSimplified,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.isReadOnly,
    required this.onCommitmentCreationRequested,
    required this.onCommitmentTapped,
    required this.onCommitmentSettleRequested,
    required this.onCommitmentUnsettleRequested,
    required this.onCommitmentDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final commitmentsColumn = _OcptCommittedCommitmentsColumn(
      commitments: commitments,
      postes: postes,
      isSimplified: isSimplified,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      currencyCode: currencyCode,
      isReadOnly: isReadOnly,
      onCommitmentCreationRequested: isReadOnly ? null : onCommitmentCreationRequested,
      onCommitmentTapped: isReadOnly ? null : onCommitmentTapped,
      onCommitmentSettleRequested: isReadOnly ? null : onCommitmentSettleRequested,
      onCommitmentUnsettleRequested: isReadOnly ? null : onCommitmentUnsettleRequested,
      onCommitmentDeletionRequested: isReadOnly ? null : onCommitmentDeletionRequested,
    );
    final projectionColumn = _OcptCommittedProjectionColumn(
      openingBalanceCents: openingBalanceCents,
      commitments: commitments,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      currencyCode: currencyCode,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _ocptCommittedWrapWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: commitmentsColumn),
              const SizedBox(width: 24),
              Expanded(child: projectionColumn),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: commitmentsColumn),
            const SizedBox(height: 24),
            Expanded(child: projectionColumn),
          ],
        );
      },
    );
  }
}

/// The left column: the heading band, then the commitments table.
class _OcptCommittedCommitmentsColumn extends StatelessWidget {
  /// See [OcptBudgetCommittedSpending]'s own fields of the same name.
  final List<OcptBudgetCommitment> commitments;
  final List<OcptBudgetPoste> postes;
  final bool isSimplified;
  final int? defaultVatRateBasisPoints;
  final String currencyCode;
  final bool isReadOnly;
  final VoidCallback? onCommitmentCreationRequested;
  final ValueChanged<OcptBudgetCommitment>? onCommitmentTapped;
  final ValueChanged<OcptBudgetCommitment>? onCommitmentSettleRequested;
  final ValueChanged<String>? onCommitmentUnsettleRequested;
  final ValueChanged<String>? onCommitmentDeletionRequested;

  /// Class constructor
  const _OcptCommittedCommitmentsColumn({
    required this.commitments,
    required this.postes,
    required this.isSimplified,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.isReadOnly,
    required this.onCommitmentCreationRequested,
    required this.onCommitmentTapped,
    required this.onCommitmentSettleRequested,
    required this.onCommitmentUnsettleRequested,
    required this.onCommitmentDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final outstanding = _outstandingTotalOf();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OcptCommittedHeadingBand(
          outstanding: outstanding,
          currencyCode: currencyCode,
          onCommitmentCreationRequested: onCommitmentCreationRequested,
        ),
        const SizedBox(height: 12),
        if (commitments.isEmpty)
          Expanded(
            child: OcptWorkspaceEmptyMode(
              icon: Icons.request_quote_outlined,
              // See `OcptBudgetCashJournal`'s own empty state for why the simplified reading
              // gets a sentence of its own rather than the trade word.
              message: isSimplified
                  ? Tr.of(context).budgetCommittedSimpleEmptyHint
                  : Tr.of(context).budgetCommittedEmptyHint,
            ),
          )
        else
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // The header and the rows scroll **together**, for the reason
                // `OcptBudgetCashJournal` gives: they share one set of fixed column widths.
                child: SizedBox(
                  width: math.max(constraints.maxWidth, _ocptCommittedMinTableWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ocptTableRowHorizontalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _OcptCommittedHeaderRow(),
                        Expanded(
                          child: ListView.builder(
                            itemCount: commitments.length,
                            itemBuilder: (context, index) => _OcptCommittedRow(
                              commitment: commitments[index],
                              poste: _posteById(commitments[index].posteId),
                              isSimplified: isSimplified,
                              defaultVatRateBasisPoints: defaultVatRateBasisPoints,
                              currencyCode: currencyCode,
                              onTap: onCommitmentTapped == null ? null : () => onCommitmentTapped?.call(commitments[index]),
                              onSettleRequested: onCommitmentSettleRequested == null
                                  ? null
                                  : () => onCommitmentSettleRequested?.call(commitments[index]),
                              onUnsettleRequested: onCommitmentUnsettleRequested == null
                                  ? null
                                  : () => onCommitmentUnsettleRequested?.call(commitments[index].id),
                              onDeletionRequested: onCommitmentDeletionRequested == null
                                  ? null
                                  : () => onCommitmentDeletionRequested?.call(commitments[index].id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The outstanding total, tax-inclusive, over every **unsettled** commitment — the sum of
  /// `ocptBudgetCommittedCentsByPosteId`'s own per-poste reading, which already excludes a settled
  /// commitment outright (its own doc comment), so this column never re-derives that exclusion.
  OcptBudgetCoveredTotal _outstandingTotalOf() {
    final committedByPoste = ocptBudgetCommittedCentsByPosteId(
      commitments,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );

    var amountCents = 0;
    var coveredLineCount = 0;
    var lineCount = 0;
    for (final total in committedByPoste.values) {
      amountCents += total.amountCents;
      coveredLineCount += total.coveredLineCount;
      lineCount += total.lineCount;
    }

    return OcptBudgetCoveredTotal(
      amountCents: amountCents,
      coveredLineCount: coveredLineCount,
      lineCount: lineCount,
    );
  }

  /// [postes]' own entry naming [posteId], or null while it names no live poste.
  OcptBudgetPoste? _posteById(String posteId) {
    for (final poste in postes) {
      if (poste.id == posteId) {
        return poste;
      }
    }

    return null;
  }
}

/// The commitments column's own heading: a title and a muted sentence explaining what a commitment
/// is, the outstanding total pushed right, then the `+ Commitment` action.
class _OcptCommittedHeadingBand extends StatelessWidget {
  /// The outstanding total, tax-inclusive, and how many of the outstanding commitments it covers.
  final OcptBudgetCoveredTotal outstanding;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when `+ Commitment` is clicked, or null while withheld.
  final VoidCallback? onCommitmentCreationRequested;

  /// Class constructor
  const _OcptCommittedHeadingBand({
    required this.outstanding,
    required this.currencyCode,
    required this.onCommitmentCreationRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final coverageText = outstanding.isComplete
        ? null
        : tr.budgetCommittedCoverageReadOut(outstanding.coveredLineCount, outstanding.lineCount);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr.budgetCommittedSectionTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                tr.budgetCommittedExplanationHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr.budgetCommittedOutstandingLabel.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            Text(
              ocptBudgetAmountLabel(outstanding.amountCents, currencyCode),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (coverageText != null)
              Text(
                coverageText,
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(width: 16),
        if (onCommitmentCreationRequested != null)
          FilledButton.icon(
            onPressed: onCommitmentCreationRequested,
            icon: const Icon(Icons.add, size: 16),
            label: Text(tr.budgetCommittedCreationAction),
          ),
      ],
    );
  }
}

/// The commitments table's own header row: `Due date`, `Label`, `Poste`, `Status`, `Amount`, then a
/// blank cell over the `⋮` menu column.
class _OcptCommittedHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptCommittedHeaderRow();

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
        height: _ocptCommittedHeaderRowHeight,
        child: Row(
          children: [
            SizedBox(
              width: _ocptCommittedDueDateColumnWidth,
              child: Text(tr.budgetCommittedColumnDueDate.toUpperCase(), style: labelStyle),
            ),
            Expanded(child: Text(tr.budgetCashJournalColumnLabel.toUpperCase(), style: labelStyle)),
            SizedBox(
              width: _ocptCommittedPosteColumnWidth,
              child: Text(tr.budgetCostTrackingColumnPoste.toUpperCase(), style: labelStyle),
            ),
            SizedBox(
              width: _ocptCommittedStatusColumnWidth,
              child: Text(tr.budgetCommittedColumnStatus.toUpperCase(), style: labelStyle),
            ),
            SizedBox(
              width: _ocptCommittedAmountColumnWidth,
              child: Text(
                tr.budgetCommittedColumnAmount.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            const SizedBox(width: _ocptCommittedMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}

/// One commitment row: due date, label, poste, status badge, amount, then its own `⋮` menu.
class _OcptCommittedRow extends StatelessWidget {
  /// The commitment this widget draws.
  final OcptBudgetCommitment commitment;

  /// The poste this commitment prices, or null while it names no live poste (should not happen: a
  /// commitment's own poste is required, but a dangling reference reads as such rather than
  /// crashing).
  final OcptBudgetPoste? poste;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when this row is clicked, or null while withheld.
  final VoidCallback? onTap;

  /// Called when this row's own `⋮` menu asks to record its payment, or null while withheld or
  /// already settled.
  final VoidCallback? onSettleRequested;

  /// Called when this row's own `⋮` menu asks to undo its settlement, or null while withheld or not
  /// settled.
  final VoidCallback? onUnsettleRequested;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptCommittedRow({
    required this.commitment,
    required this.poste,
    required this.isSimplified,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.onTap,
    required this.onSettleRequested,
    required this.onUnsettleRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dueDate = commitment.dueDate;
    final poste = this.poste;
    final isSettled = commitment.isSettled;
    final mutedColor = isSettled ? theme.colorScheme.onSurfaceVariant : null;
    final cashCents = ocptBudgetCommitmentCashCentsOf(
      commitment,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final hasMenu = onSettleRequested != null || onUnsettleRequested != null || onDeletionRequested != null;

    return InkWell(
      onTap: onTap,
      mouseCursor: onTap == null ? null : ocptClickableCursor,
      child: SizedBox(
        height: _ocptCommittedRowHeight,
        child: Row(
          children: [
            SizedBox(
              width: _ocptCommittedDueDateColumnWidth,
              child: Text(
                dueDate == null ? tr.budgetCommittedNoDueDateLabel : DateFormat.yMMMd(locale).format(dueDate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: dueDate == null ? theme.colorScheme.onSurfaceVariant : mutedColor,
                  fontStyle: dueDate == null ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  commitment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
                ),
              ),
            ),
            SizedBox(
              width: _ocptCommittedPosteColumnWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  poste == null
                      ? ocptBudgetEmptyValue
                      : ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
                ),
              ),
            ),
            SizedBox(
              width: _ocptCommittedStatusColumnWidth,
              child: isSettled
                  ? const _OcptCommittedSettledBadge()
                  : _OcptCommittedStatusBadge(status: commitment.status),
            ),
            SizedBox(
              width: _ocptCommittedAmountColumnWidth,
              child: Text(
                cashCents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(cashCents, currencyCode),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
              ),
            ),
            SizedBox(
              width: _ocptCommittedMenuColumnWidth,
              child: !hasMenu
                  ? null
                  : PopupMenuButton<String>(
                      tooltip: "",
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (value) => switch (value) {
                        "settle" => onSettleRequested?.call(),
                        "unsettle" => onUnsettleRequested?.call(),
                        "delete" => onDeletionRequested?.call(),
                        _ => null,
                      },
                      itemBuilder: (context) => [
                        if (!isSettled && onSettleRequested != null)
                          PopupMenuItem<String>(value: "settle", child: Text(tr.budgetCommittedSettleAction)),
                        if (isSettled && onUnsettleRequested != null)
                          PopupMenuItem<String>(
                            value: "unsettle",
                            child: Text(tr.budgetCommittedUnsettleAction),
                          ),
                        if (onDeletionRequested != null)
                          PopupMenuItem<String>(value: "delete", child: Text(tr.budgetCommittedDeleteAction)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of `OcptBudgetCommitmentStatus`'s own four badges, its own fill growing heavier — see
/// [_ocptCommittedStatusFillAlphas] — from a mere outline (a quote accepted) to a solid pill
/// (declared).
class _OcptCommittedStatusBadge extends StatelessWidget {
  /// The status this badge paints.
  final OcptBudgetCommitmentStatus status;

  /// Class constructor
  const _OcptCommittedStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final accent = ocptBudgetCommitmentStatusAccentColor(theme.colorScheme, status);
    final alpha = _ocptCommittedStatusFillAlphas[status.index];
    final isSolid = alpha >= 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSolid ? accent : accent.withValues(alpha: alpha),
        border: alpha == 0 ? Border.all(color: accent.withValues(alpha: 0.6)) : null,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        ocptBudgetCommitmentStatusLabel(tr, status),
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

/// The badge a **settled** commitment wears in place of [_OcptCommittedStatusBadge] — visually
/// distinct (its own icon, its own neutral tone) so a paid commitment never reads as merely one more
/// step of the ordinary four.
class _OcptCommittedSettledBadge extends StatelessWidget {
  /// Class constructor
  const _OcptCommittedSettledBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            tr.budgetCommittedStatusSettledLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The right column: the cash projection built from every unsettled commitment,
/// `lib/utils/ocpt_budget_projection.dart`'s own reading, opened at the cash journal's own balance.
class _OcptCommittedProjectionColumn extends StatelessWidget {
  /// The cash journal's own balance — the figure the projection opens at.
  final int openingBalanceCents;

  /// Every live commitment — the projection itself skips the settled ones, see
  /// `ocptBudgetProjectionOf`'s own doc comment.
  final List<OcptBudgetCommitment> commitments;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptCommittedProjectionColumn({
    required this.openingBalanceCents,
    required this.commitments,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final projection = ocptBudgetProjectionOf(
      openingBalanceCents: openingBalanceCents,
      commitments: commitments,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr.budgetCommittedProjectionTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          tr.budgetCommittedProjectionHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        // No commitment at all is outstanding: the projection shows the balance and nothing else,
        // rather than an empty frame — see the class doc comment.
        if (projection.commitmentCount == 0)
          _OcptCommittedProjectionBalanceOnly(
            balanceCents: projection.openingBalanceCents,
            currencyCode: currencyCode,
          )
        else ...[
          Expanded(
            child: projection.steps.isEmpty
                ? Center(
                    child: Text(
                      tr.budgetCommittedProjectionNoStepsHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : _OcptCommittedProjectionSteps(steps: projection.steps, currencyCode: currencyCode),
          ),
          const Divider(),
          _OcptCommittedProjectionFooter(projection: projection, currencyCode: currencyCode),
        ],
      ],
    );
  }
}

/// The projection's own list of steps, each bar scaled against the largest absolute
/// [OcptBudgetProjectionStep.balanceAfterCents] **in this very list** — never a fixed divisor,
/// which would draw the same production's projection differently for no reason but the size of its
/// budget.
class _OcptCommittedProjectionSteps extends StatelessWidget {
  /// The steps to draw, in [OcptBudgetProjection.steps]' own order.
  final List<OcptBudgetProjectionStep> steps;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptCommittedProjectionSteps({required this.steps, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final maxAbsBalanceCents = steps.fold(0, (max, step) {
      final absValue = step.balanceAfterCents.abs();
      return absValue > max ? absValue : max;
    });

    return ListView.builder(
      itemCount: steps.length,
      itemBuilder: (context, index) => _OcptCommittedProjectionStepRow(
        step: steps[index],
        maxAbsBalanceCents: maxAbsBalanceCents,
        currencyCode: currencyCode,
      ),
    );
  }
}

/// One projection step: its own due date, a bar scaled against [maxAbsBalanceCents], and the
/// balance left once it has fallen due — reading visibly differently, from the theme, the moment
/// that balance goes negative.
class _OcptCommittedProjectionStepRow extends StatelessWidget {
  /// The step this row draws.
  final OcptBudgetProjectionStep step;

  /// The largest absolute [OcptBudgetProjectionStep.balanceAfterCents] of the whole list this
  /// step's own bar is scaled against.
  final int maxAbsBalanceCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptCommittedProjectionStepRow({
    required this.step,
    required this.maxAbsBalanceCents,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dueDate = step.dueDate;
    final isNegative = step.balanceAfterCents < 0;
    final ratio = maxAbsBalanceCents <= 0
        ? 0.0
        : (step.balanceAfterCents.abs() / maxAbsBalanceCents).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
        horizontal: ocptTableRowHorizontalPadding,
      ),
      child: Row(
        children: [
          SizedBox(
            width: _ocptCommittedDueDateColumnWidth,
            child: Text(
              dueDate == null ? tr.budgetCommittedNoDueDateLabel : DateFormat.yMMMd(locale).format(dueDate),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: dueDate == null ? theme.colorScheme.onSurfaceVariant : null,
                fontStyle: dueDate == null ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_ocptCommittedProjectionBarHeight / 2),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: _ocptCommittedProjectionBarHeight,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation(
                  isNegative ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _ocptCommittedAmountColumnWidth,
            child: Text(
              ocptBudgetAmountLabel(step.balanceAfterCents, currencyCode),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isNegative ? theme.colorScheme.error : null,
                fontWeight: isNegative ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The projection's own footer: the balance once every outstanding commitment has fallen due, and a
/// sentence beneath it — the coverage read-out while a commitment could not be read tax-inclusive,
/// the plain explanatory sentence otherwise.
class _OcptCommittedProjectionFooter extends StatelessWidget {
  /// The projection this footer summarises.
  final OcptBudgetProjection projection;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptCommittedProjectionFooter({required this.projection, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isNegative = projection.finalBalanceCents < 0;
    final isComplete = projection.coveredCommitmentCount == projection.commitmentCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr.budgetCommittedProjectionFinalBalanceLabel,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              ocptBudgetAmountLabel(projection.finalBalanceCents, currencyCode),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isNegative ? theme.colorScheme.error : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isComplete
              ? tr.budgetCommittedProjectionFooterHint
              : tr.budgetCommittedProjectionCoverageReadOut(
                  projection.coveredCommitmentCount,
                  projection.commitmentCount,
                ),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The projection's own reading while no commitment at all is outstanding: just the balance, rather
/// than an empty frame with a table and a footer that would have nothing to say.
class _OcptCommittedProjectionBalanceOnly extends StatelessWidget {
  /// The balance to show — the projection's own [OcptBudgetProjection.openingBalanceCents],
  /// unchanged since nothing is left to take out of it.
  final int balanceCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptCommittedProjectionBalanceOnly({required this.balanceCents, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isNegative = balanceCents < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr.budgetCommittedProjectionFinalBalanceLabel.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            ocptBudgetAmountLabel(balanceCents, currencyCode),
            style: theme.textTheme.titleMedium?.copyWith(color: isNegative ? theme.colorScheme.error : null),
          ),
        ],
      ),
    );
  }
}
