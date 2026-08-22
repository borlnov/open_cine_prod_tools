// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_shares.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The width, in logical pixels, under which the two columns stack instead of sitting side by
/// side — mirrors `OcptBudgetRegie`'s own `_ocptRegieWrapWidth`.
const double _ocptSharingWrapWidth = 1000;

/// The `Status` column's own fixed width, in logical pixels — matches `OcptBudgetFinancing`'s own
/// status column.
const double _ocptSharingStatusColumnWidth = 132;

/// The `Received`/`Share`/`Due`/`Paid`/`Reinvested` columns' own fixed width, in logical pixels —
/// matches `OcptBudgetFinancing`'s own amount columns.
const double _ocptSharingAmountColumnWidth = 108;

/// The `Share` column's own fixed width, in logical pixels — narrower than an amount column, a
/// percentage never running as wide as a currency figure.
const double _ocptSharingPercentColumnWidth = 72;

/// The `Repaying the contributions` card's own `Contributed`/`Repaid`/`Owed` columns' own fixed
/// width, in logical pixels — narrower than [_ocptSharingAmountColumnWidth], the card carrying
/// three of them side by side rather than one.
const double _ocptSharingRepaymentAmountColumnWidth = 84;

/// The trailing `⋮` menu column's own fixed width, in logical pixels — matches every other table
/// of this mode's own menu column.
const double _ocptSharingMenuColumnWidth = 36;

/// The date format the `Takings received` card's own rows print their date in — mirrors
/// `OcptBudgetCommittedSpending`'s own due-date reading.
final DateFormat _ocptSharingDateFormat = DateFormat.yMd();

/// The budget mode's revenue sharing view: two columns side by side, wrapping onto one another
/// once the centre narrows past [_ocptSharingWrapWidth] — the layout the validated mockup lays
/// this view out as, mirroring `OcptBudgetRegie`'s own two-column reading.
///
/// **Every card sizes to its own content and hugs the top of its own column — never stretched to
/// fill the view's own height.** This is `OcptBudgetFinancing`'s own house style (its group cards
/// size to their content, the page simply carrying empty space below them), so each column here is
/// a plain, content-sized `Column` of cards, and it is *that* — not a card's own body — which sits
/// inside the scroll view: [_OcptSharingLeftColumn]/[_OcptSharingDistributionColumn] carry no
/// `Expanded` of their own, and neither does a card's own list of rows, which is a plain `Column`
/// rather than a `ListView`. Wide, each column scrolls on its own (`SingleChildScrollView`,
/// side by side in a `Row`); narrow, one scroll view carries both columns in sequence.
///
/// **Left column**: `Takings received` (one row per live [revenues]) above `Repaying the
/// contributions` ([sharingPot]'s own four-line read-out, the order that card exists to make
/// legible — the reimbursable contributions come before any sharing at all). **Right column**:
/// `Distribution`, one row per [shareSplits] — what is left is split by the agreed shares, and each
/// participant may reinvest theirs in the next production.
///
/// **No inspector**, mirroring `OcptBudgetFinancing`'s own class doc comment for the very same
/// reason: neither a taking nor a participant carries a line of its own the right dock's existing
/// `Inspector` tab, built entirely around a poste's own quote lines, could show. A row's own click
/// only ever selects it ([onRevenueSelected]/[onShareSelected]), read and written exactly as
/// `OcptBudgetState.selectedResourceId` already is; a row's own fields are read and written through
/// `OcptBudgetRevenueDialog`/`OcptBudgetShareDialog` instead, reached from the row's own `⋮` menu.
///
/// **The sum of the shares is stated, never policed.** Where [ocptBudgetSharesPermilleTotal] is not
/// `1000`, the `Distribution` table says so in a line of its own, rather than refusing the write or
/// silently rescaling every participant's own figure: a plan still being negotiated legitimately
/// does not add up yet, and it is the participants' own business to settle, not this app's to
/// arbitrate. `OcptBudgetShareDialog`'s own class doc comment repeats the same argument for why its
/// own `Share` field carries no validator against the other rows' own total.
///
/// A composite panel (`docs/architecture/foundations.md`'s own idiom): takes [isReadOnly] rather
/// than a null callback per affordance, and withholds — never disables — every one of its own
/// writing affordances under it: both `+ Add` footers and every row's own `⋮` menu entries.
class OcptBudgetSharing extends StatelessWidget {
  /// Every live taking, in `sortKey` order.
  final List<OcptBudgetRevenue> revenues;

  /// Every live share, in `sortKey` order.
  final List<OcptBudgetShare> shares;

  /// What has actually come in against each taking, keyed by its own id — read raw, rather than
  /// through a `?? 0` reading, so a taking whose received figure differs from its own
  /// [OcptBudgetRevenue.amountCents] can print the expected amount as a quiet second line.
  final Map<String, OcptBudgetCoveredTotal> receivedByRevenueId;

  /// What there is to share, and what stands between the takings and it.
  final OcptBudgetSharingPot sharingPot;

  /// `resources`' own reimbursable ones, grouped by lender — `ocptBudgetRepaymentLinesOf`
  /// (`lib/utils/ocpt_budget_shares.dart`). The `Repaying the contributions` card's own detail: who
  /// is owed what, one line per lender, rather than only [sharingPot]'s own three aggregate
  /// figures.
  final List<OcptBudgetRepaymentLine> repaymentLines;

  /// The split of [sharingPot] across [shares], in the order they are handed in.
  final List<OcptBudgetShareSplit> shareSplits;

  /// Every live person of the project's address book — resolves a share's own
  /// [OcptBudgetShare.personId] into a display name, printed as a quiet second line under its own
  /// `Participant` cell.
  final List<OcptPerson> people;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The id of the currently selected taking, or null while none is.
  final String? selectedRevenueId;

  /// The id of the currently selected share, or null while none is.
  final String? selectedShareId;

  /// Whether the mode shows a project version being previewed read-only — see the class doc
  /// comment.
  final bool isReadOnly;

  /// Called when the `Takings received` card's own `+ Add` footer is clicked, or null while
  /// [isReadOnly].
  final VoidCallback? onRevenueCreationRequested;

  /// Called with a taking's id when its row is clicked — selects it, and only that.
  final ValueChanged<String> onRevenueSelected;

  /// Called with a taking when its row's own `⋮` menu asks to edit it, or null while [isReadOnly].
  /// Opens `OcptBudgetRevenueDialog` on it.
  final ValueChanged<OcptBudgetRevenue>? onRevenueEditRequested;

  /// Called with a taking when its row's own `⋮` menu asks to record a receipt against it, or null
  /// while [isReadOnly]. Opens `OcptBudgetEntryDialog` pre-filled from it, as a credit.
  final ValueChanged<OcptBudgetRevenue>? onRevenueReceiptRequested;

  /// Called with a taking's id and a direction when its row's own `⋮` menu asks to move it, or
  /// null while [isReadOnly]. `moveUp` is named, never positional, mirroring
  /// `OcptBudgetCostTracking.onPosteReorderRequested`.
  final void Function(String revenueId, {required bool moveUp})? onRevenueReorderRequested;

  /// Called with a taking's id when its row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onRevenueDeletionRequested;

  /// Called when the `Distribution` table's own `+ Add` footer is clicked, or null while
  /// [isReadOnly].
  final VoidCallback? onShareCreationRequested;

  /// Called with a share's id when its row is clicked — selects it, and only that.
  final ValueChanged<String> onShareSelected;

  /// Called with a share when its row's own `⋮` menu asks to edit it, or null while [isReadOnly].
  /// Opens `OcptBudgetShareDialog` on it.
  final ValueChanged<OcptBudgetShare>? onShareEditRequested;

  /// Called with a share when its row's own `⋮` menu asks to record a payout against it, or null
  /// while [isReadOnly]. Opens `OcptBudgetEntryDialog` pre-filled from it, as a debit.
  final ValueChanged<OcptBudgetShare>? onSharePayoutRequested;

  /// Called with a share's id and a direction when its row's own `⋮` menu asks to move it, or null
  /// while [isReadOnly]. Mirrors [onRevenueReorderRequested].
  final void Function(String shareId, {required bool moveUp})? onShareReorderRequested;

  /// Called with a share's id when its row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. Mirrors [onRevenueDeletionRequested].
  final ValueChanged<String>? onShareDeletionRequested;

  /// Class constructor
  const OcptBudgetSharing({
    super.key,
    required this.revenues,
    required this.shares,
    required this.receivedByRevenueId,
    required this.sharingPot,
    required this.repaymentLines,
    required this.shareSplits,
    required this.people,
    required this.currencyCode,
    required this.selectedRevenueId,
    required this.selectedShareId,
    required this.isReadOnly,
    required this.onRevenueCreationRequested,
    required this.onRevenueSelected,
    required this.onRevenueEditRequested,
    required this.onRevenueReceiptRequested,
    required this.onRevenueReorderRequested,
    required this.onRevenueDeletionRequested,
    required this.onShareCreationRequested,
    required this.onShareSelected,
    required this.onShareEditRequested,
    required this.onSharePayoutRequested,
    required this.onShareReorderRequested,
    required this.onShareDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    final leftColumn = _OcptSharingLeftColumn(
      revenues: revenues,
      receivedByRevenueId: receivedByRevenueId,
      sharingPot: sharingPot,
      repaymentLines: repaymentLines,
      people: people,
      currencyCode: currencyCode,
      selectedRevenueId: selectedRevenueId,
      isReadOnly: isReadOnly,
      onRevenueCreationRequested: onRevenueCreationRequested,
      onRevenueSelected: onRevenueSelected,
      onRevenueEditRequested: onRevenueEditRequested,
      onRevenueReceiptRequested: onRevenueReceiptRequested,
      onRevenueReorderRequested: onRevenueReorderRequested,
      onRevenueDeletionRequested: onRevenueDeletionRequested,
    );
    final rightColumn = _OcptSharingDistributionColumn(
      shares: shares,
      shareSplits: shareSplits,
      sharingPot: sharingPot,
      people: people,
      currencyCode: currencyCode,
      selectedShareId: selectedShareId,
      isReadOnly: isReadOnly,
      onShareCreationRequested: onShareCreationRequested,
      onShareSelected: onShareSelected,
      onShareEditRequested: onShareEditRequested,
      onSharePayoutRequested: onSharePayoutRequested,
      onShareReorderRequested: onShareReorderRequested,
      onShareDeletionRequested: onShareDeletionRequested,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr.budgetSharingCaption,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= _ocptSharingWrapWidth) {
                // Each column scrolls on its own, top-aligned: the cards inside size to their own
                // content, exactly as `OcptBudgetFinancing`'s own group cards do — see the class
                // doc comment for why this reads as one column stretching full height was the
                // defect a screenshot against the validated mockup caught.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SingleChildScrollView(child: leftColumn)),
                    const SizedBox(width: 16),
                    Expanded(child: SingleChildScrollView(child: rightColumn)),
                  ],
                );
              }

              // Narrow: one scroll view holding both columns in sequence, rather than splitting
              // the height between two, each independently scrolling.
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [leftColumn, const SizedBox(height: 16), rightColumn],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The left column: `Takings received` above `Repaying the contributions`.
class _OcptSharingLeftColumn extends StatelessWidget {
  /// See [OcptBudgetSharing]'s own fields of the same name.
  final List<OcptBudgetRevenue> revenues;
  final Map<String, OcptBudgetCoveredTotal> receivedByRevenueId;
  final OcptBudgetSharingPot sharingPot;
  final List<OcptBudgetRepaymentLine> repaymentLines;
  final List<OcptPerson> people;
  final String currencyCode;
  final String? selectedRevenueId;
  final bool isReadOnly;
  final VoidCallback? onRevenueCreationRequested;
  final ValueChanged<String> onRevenueSelected;
  final ValueChanged<OcptBudgetRevenue>? onRevenueEditRequested;
  final ValueChanged<OcptBudgetRevenue>? onRevenueReceiptRequested;
  final void Function(String revenueId, {required bool moveUp})? onRevenueReorderRequested;
  final ValueChanged<String>? onRevenueDeletionRequested;

  /// Class constructor
  const _OcptSharingLeftColumn({
    required this.revenues,
    required this.receivedByRevenueId,
    required this.sharingPot,
    required this.repaymentLines,
    required this.people,
    required this.currencyCode,
    required this.selectedRevenueId,
    required this.isReadOnly,
    required this.onRevenueCreationRequested,
    required this.onRevenueSelected,
    required this.onRevenueEditRequested,
    required this.onRevenueReceiptRequested,
    required this.onRevenueReorderRequested,
    required this.onRevenueDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final received = ocptBudgetRevenuesReceivedTotalOf(
      revenues: revenues,
      receivedByRevenueId: receivedByRevenueId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr.budgetSharingTakingsReceivedTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (revenues.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        tr.budgetSharingTakingsEmptyHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (final (index, revenue) in revenues.indexed)
                    _OcptSharingRevenueRow(
                      revenue: revenue,
                      received: receivedByRevenueId[revenue.id],
                      currencyCode: currencyCode,
                      isSelected: revenue.id == selectedRevenueId,
                      onTap: () => onRevenueSelected(revenue.id),
                      onEditRequested: isReadOnly || onRevenueEditRequested == null
                          ? null
                          : () => onRevenueEditRequested?.call(revenue),
                      onReceiptRequested: isReadOnly || onRevenueReceiptRequested == null
                          ? null
                          : () => onRevenueReceiptRequested?.call(revenue),
                      onMoveUpRequested: isReadOnly || onRevenueReorderRequested == null || index == 0
                          ? null
                          : () => onRevenueReorderRequested?.call(revenue.id, moveUp: true),
                      onMoveDownRequested:
                          isReadOnly || onRevenueReorderRequested == null || index == revenues.length - 1
                          ? null
                          : () => onRevenueReorderRequested?.call(revenue.id, moveUp: false),
                      onDeletionRequested: isReadOnly || onRevenueDeletionRequested == null
                          ? null
                          : () => onRevenueDeletionRequested?.call(revenue.id),
                    ),
                const Divider(height: 1),
                _OcptSharingTotalRow(
                  label: tr.budgetCostTrackingTotalRowLabel,
                  valueText: ocptBudgetAmountLabel(received.amountCents, currencyCode),
                  caption: received.isComplete
                      ? null
                      : tr.budgetSharingTakingsCoverageReadOut(
                          ocptBudgetAmountLabel(received.amountCents, currencyCode),
                          received.coveredLineCount,
                          received.lineCount,
                        ),
                ),
                if (!isReadOnly && onRevenueCreationRequested != null)
                  _OcptSharingCreationFooter(
                    label: tr.budgetSharingRevenueCreationAction,
                    onTap: onRevenueCreationRequested!,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(tr.budgetSharingRepayingTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (repaymentLines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      tr.budgetSharingRepaymentEmptyHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  const _OcptSharingRepaymentHeaderRow(),
                  for (final line in repaymentLines)
                    _OcptSharingRepaymentLenderRow(
                      line: line,
                      person: line.personId == null
                          ? null
                          : people.where((person) => person.id == line.personId).firstOrNull,
                      currencyCode: currencyCode,
                    ),
                ],
                const SizedBox(height: 4),
                const Divider(height: 1),
                const SizedBox(height: 4),
                _OcptSharingPotLine(
                  label: tr.budgetSharingReimbursableTotalLabel,
                  valueText: ocptBudgetAmountLabel(sharingPot.reimbursableCents, currencyCode),
                ),
                _OcptSharingPotLine(
                  label: tr.budgetSharingRepaidLabel,
                  valueText: ocptBudgetAmountLabel(sharingPot.repaid.amountCents, currencyCode),
                ),
                _OcptSharingPotLine(
                  label: tr.budgetSharingOutstandingRepaymentLabel,
                  valueText: ocptBudgetAmountLabel(sharingPot.outstandingRepaymentCents, currencyCode),
                ),
                const SizedBox(height: 4),
                const Divider(height: 1),
                const SizedBox(height: 4),
                _OcptSharingPotLine(
                  label: tr.budgetSharingLeftToShareLabel,
                  valueText: ocptBudgetAmountLabel(sharingPot.shareableCents, currencyCode),
                  isEmphasized: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One line of the `Repaying the contributions` card: a muted label, a value — the last one
/// ([isEmphasized]) bolder and in the accent colour, the point of the card being to make it stand
/// out from the three that lead up to it.
class _OcptSharingPotLine extends StatelessWidget {
  /// The line's own label.
  final String label;

  /// The line's own value.
  final String valueText;

  /// Whether this is the card's own final, emphasized line.
  final bool isEmphasized;

  /// Class constructor
  const _OcptSharingPotLine({required this.label, required this.valueText, this.isEmphasized = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: isEmphasized
                  ? theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)
                  : theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            valueText,
            style: isEmphasized
                ? theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  )
                : theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The column header naming a lender row's own three amount columns — `Contributed`, `Repaid`,
/// `Owed` — sitting once above the `Repaying the contributions` card's own list of lender lines,
/// `_OcptFinancingColumnHeaderRow`'s own idiom (`ocpt_budget_financing.dart`) read over this card's
/// narrower, three-column shape.
class _OcptSharingRepaymentHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptSharingRepaymentHeaderRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(tr.budgetSharingRepaymentColumnLender.toUpperCase(), style: labelStyle),
          ),
          SizedBox(
            width: _ocptSharingRepaymentAmountColumnWidth,
            child: Text(
              tr.budgetSharingRepaymentColumnContributed.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: _ocptSharingRepaymentAmountColumnWidth,
            child: Text(
              tr.budgetSharingRepaymentColumnRepaid.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: _ocptSharingRepaymentAmountColumnWidth,
            child: Text(
              tr.budgetSharingRepaymentColumnOutstanding.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// One lender's own line in the `Repaying the contributions` card — `ocptBudgetRepaymentLinesOf`'s
/// own reading (`lib/utils/ocpt_budget_shares.dart`): who they are, what they contributed in total,
/// what has already gone back to them and what is still owed, the last one printed in the error
/// colour while positive — this is precisely the detail the product owner asked for: three loans of
/// 100 € from the same person read as one line owed 300 €, not three figures buried in the plan's
/// own aggregate.
class _OcptSharingRepaymentLenderRow extends StatelessWidget {
  /// The line this row draws.
  final OcptBudgetRepaymentLine line;

  /// The person [line]'s own `personId` names, or null while it groups by its own [line].label
  /// instead, or while the person it once named has since been removed from the address book.
  final OcptPerson? person;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptSharingRepaymentLenderRow({
    required this.line,
    required this.person,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final person = this.person;
    final displayLabel = person != null
        ? person.displayName
        : (line.label.isEmpty ? tr.budgetPosteUnnamed : line.label);
    final isOutstanding = line.outstandingCents > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: _ocptSharingRepaymentAmountColumnWidth,
            child: Text(
              ocptBudgetAmountLabel(line.contributedCents, currencyCode),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: _ocptSharingRepaymentAmountColumnWidth,
            child: Text(
              ocptBudgetAmountLabel(line.repaid.amountCents, currencyCode),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: _ocptSharingRepaymentAmountColumnWidth,
            child: Text(
              ocptBudgetAmountLabel(line.outstandingCents, currencyCode),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isOutstanding ? theme.colorScheme.error : null,
                fontWeight: isOutstanding ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One taking row: its date, its label, its status pill, its received amount — a quiet second line
/// naming the expected amount whenever it differs from what was actually received — then its own
/// `⋮` menu.
class _OcptSharingRevenueRow extends StatelessWidget {
  /// The revenue this row draws.
  final OcptBudgetRevenue revenue;

  /// What has actually come in against [revenue], or null while no entry names it at all.
  final OcptBudgetCoveredTotal? received;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this revenue is the currently selected one.
  final bool isSelected;

  /// Called when this row is clicked — selects it, and only that.
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
  const _OcptSharingRevenueRow({
    required this.revenue,
    required this.received,
    required this.currencyCode,
    required this.isSelected,
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

    final receivedCents = received?.amountCents;
    // The expected amount prints as a quiet second line only where it actually differs from what
    // was received — an announced prize and a cashed one are told apart, but a row nobody has been
    // paid against yet (received null) says nothing more than its own expected figure once, on its
    // main line.
    final showsExpectedCaption = receivedCents != null && receivedCents != revenue.amountCents;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: _ocptSharingAmountColumnWidth,
                child: Text(
                  _ocptSharingDateFormat.format(revenue.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    revenue.label.isEmpty ? tr.budgetPosteUnnamed : revenue.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              SizedBox(
                width: _ocptSharingStatusColumnWidth,
                child: _OcptSharingRevenueStatusPill(status: revenue.status),
              ),
              SizedBox(
                width: _ocptSharingAmountColumnWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      receivedCents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(receivedCents, currencyCode),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (showsExpectedCaption)
                      Text(
                        ocptBudgetAmountLabel(revenue.amountCents, currencyCode),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: _ocptSharingMenuColumnWidth,
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
    );
  }
}

/// One of `OcptBudgetRevenueStatus`'s own three badges — mirrors `OcptBudgetFinancing`'s own
/// `_OcptFinancingStatusPill`, generic over a different enum.
class _OcptSharingRevenueStatusPill extends StatelessWidget {
  /// The status this pill paints.
  final OcptBudgetRevenueStatus status;

  /// Class constructor
  const _OcptSharingRevenueStatusPill({required this.status});

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

/// The right column: `Distribution`, a table over [shareSplits].
class _OcptSharingDistributionColumn extends StatelessWidget {
  /// See [OcptBudgetSharing]'s own fields of the same name.
  final List<OcptBudgetShare> shares;
  final List<OcptBudgetShareSplit> shareSplits;
  final OcptBudgetSharingPot sharingPot;
  final List<OcptPerson> people;
  final String currencyCode;
  final String? selectedShareId;
  final bool isReadOnly;
  final VoidCallback? onShareCreationRequested;
  final ValueChanged<String> onShareSelected;
  final ValueChanged<OcptBudgetShare>? onShareEditRequested;
  final ValueChanged<OcptBudgetShare>? onSharePayoutRequested;
  final void Function(String shareId, {required bool moveUp})? onShareReorderRequested;
  final ValueChanged<String>? onShareDeletionRequested;

  /// Class constructor
  const _OcptSharingDistributionColumn({
    required this.shares,
    required this.shareSplits,
    required this.sharingPot,
    required this.people,
    required this.currencyCode,
    required this.selectedShareId,
    required this.isReadOnly,
    required this.onShareCreationRequested,
    required this.onShareSelected,
    required this.onShareEditRequested,
    required this.onSharePayoutRequested,
    required this.onShareReorderRequested,
    required this.onShareDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final personById = {for (final person in people) person.id: person};
    final sharesPermilleTotal = ocptBudgetSharesPermilleTotal(shares);
    final showsMismatch = shares.isNotEmpty && sharesPermilleTotal != 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr.budgetSharingDistributionTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _OcptSharingDistributionHeaderRow(),
                const Divider(height: 1),
                if (shareSplits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        tr.budgetSharingDistributionEmptyHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (final (index, split) in shareSplits.indexed)
                    _OcptSharingShareRow(
                      split: split,
                      person: split.share.personId == null ? null : personById[split.share.personId],
                      currencyCode: currencyCode,
                      isSelected: split.share.id == selectedShareId,
                      onTap: () => onShareSelected(split.share.id),
                      onEditRequested: isReadOnly || onShareEditRequested == null
                          ? null
                          : () => onShareEditRequested?.call(split.share),
                      onPayoutRequested: isReadOnly || onSharePayoutRequested == null
                          ? null
                          : () => onSharePayoutRequested?.call(split.share),
                      onMoveUpRequested: isReadOnly || onShareReorderRequested == null || index == 0
                          ? null
                          : () => onShareReorderRequested?.call(split.share.id, moveUp: true),
                      onMoveDownRequested:
                          isReadOnly || onShareReorderRequested == null || index == shareSplits.length - 1
                          ? null
                          : () => onShareReorderRequested?.call(split.share.id, moveUp: false),
                      onDeletionRequested: isReadOnly || onShareDeletionRequested == null
                          ? null
                          : () => onShareDeletionRequested?.call(split.share.id),
                    ),
                const Divider(height: 1),
                _OcptSharingTotalRow(
                  label: tr.budgetSharingReinvestedTotalLabel,
                  valueText: ocptBudgetAmountLabel(
                    ocptBudgetReinvestedTotalCents(shareSplits),
                    currencyCode,
                  ),
                ),
                if (showsMismatch)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      tr.budgetSharingSharesMismatchReadOut(
                        ocptBudgetAmountLabel(ocptBudgetDueTotalCents(shareSplits), currencyCode),
                        ocptBudgetAmountLabel(sharingPot.shareableCents, currencyCode),
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                if (!isReadOnly && onShareCreationRequested != null)
                  _OcptSharingCreationFooter(
                    label: tr.budgetSharingShareCreationAction,
                    onTap: onShareCreationRequested!,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The `Distribution` table's own header row: `Participant`, `Share`, `Due`, `Paid`, `Reinvested`.
class _OcptSharingDistributionHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptSharingDistributionHeaderRow();

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(tr.budgetSharingParticipantColumnLabel.toUpperCase(), style: labelStyle)),
          SizedBox(
            width: _ocptSharingPercentColumnWidth,
            child: Text(
              tr.budgetSharingShareColumnLabel.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: _ocptSharingAmountColumnWidth,
            child: Text(
              tr.budgetSharingDueColumnLabel.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: _ocptSharingAmountColumnWidth,
            child: Text(
              tr.budgetSharingPaidColumnLabel.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: _ocptSharingAmountColumnWidth,
            child: Text(
              tr.budgetSharingReinvestedColumnLabel.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          const SizedBox(width: _ocptSharingMenuColumnWidth),
        ],
      ),
    );
  }
}

/// One participant's row: its own label (with the linked person's name underneath, when it names
/// one), its share as a percentage, what it is due, what has been paid, and what it reinvests.
class _OcptSharingShareRow extends StatelessWidget {
  /// The split this row draws.
  final OcptBudgetShareSplit split;

  /// The person [split]'s own [OcptBudgetShare.personId] names, or null while it names nobody.
  final OcptPerson? person;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this share is the currently selected one.
  final bool isSelected;

  /// Called when this row is clicked — selects it, and only that.
  final VoidCallback onTap;

  /// Called when this row's own `⋮` menu asks to edit it, or null while withheld.
  final VoidCallback? onEditRequested;

  /// Called when this row's own `⋮` menu asks to record a payout against it, or null while
  /// withheld.
  final VoidCallback? onPayoutRequested;

  /// Called when this row's own `⋮` menu asks to move it up, or null while withheld.
  final VoidCallback? onMoveUpRequested;

  /// Called when this row's own `⋮` menu asks to move it down, or null while withheld.
  final VoidCallback? onMoveDownRequested;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptSharingShareRow({
    required this.split,
    required this.person,
    required this.currencyCode,
    required this.isSelected,
    required this.onTap,
    required this.onEditRequested,
    required this.onPayoutRequested,
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
        onPayoutRequested != null ||
        onMoveUpRequested != null ||
        onMoveDownRequested != null ||
        onDeletionRequested != null;
    final share = split.share;
    final isReinvestedNonZero = split.reinvestedCents != 0;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        share.label.isEmpty ? tr.budgetPosteUnnamed : share.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (person != null)
                        Text(
                          person!.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: _ocptSharingPercentColumnWidth,
                child: Text(
                  ocptBudgetSharePercentLabel(share.sharePermille),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: _ocptSharingAmountColumnWidth,
                child: Text(
                  ocptBudgetAmountLabel(split.dueCents, currencyCode),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: _ocptSharingAmountColumnWidth,
                child: Text(
                  ocptBudgetAmountLabel(split.paid.amountCents, currencyCode),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: _ocptSharingAmountColumnWidth,
                child: Text(
                  ocptBudgetAmountLabel(split.reinvestedCents, currencyCode),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isReinvestedNonZero ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isReinvestedNonZero ? FontWeight.w600 : null,
                  ),
                ),
              ),
              SizedBox(
                width: _ocptSharingMenuColumnWidth,
                child: !hasMenu
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: "",
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (value) => switch (value) {
                          "edit" => onEditRequested?.call(),
                          "payout" => onPayoutRequested?.call(),
                          "up" => onMoveUpRequested?.call(),
                          "down" => onMoveDownRequested?.call(),
                          "delete" => onDeletionRequested?.call(),
                          _ => null,
                        },
                        itemBuilder: (context) => [
                          if (onEditRequested != null)
                            PopupMenuItem<String>(value: "edit", child: Text(tr.budgetFinancingEditAction)),
                          if (onPayoutRequested != null)
                            PopupMenuItem<String>(
                              value: "payout",
                              child: Text(tr.budgetSharingRecordPayoutAction),
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
    );
  }
}

/// One bold total row, right-aligned, its own quiet coverage caption underneath while [caption] is
/// given — shared by both columns' own footers.
class _OcptSharingTotalRow extends StatelessWidget {
  /// The row's own label.
  final String label;

  /// The row's own value.
  final String valueText;

  /// A quiet caption underneath, or null while the figure is already complete.
  final String? caption;

  /// Class constructor
  const _OcptSharingTotalRow({required this.label, required this.valueText, this.caption});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boldStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: boldStyle)),
              Text(valueText, style: boldStyle),
            ],
          ),
          if (caption != null)
            Text(
              caption!,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// The `+ Add` footer shared by both columns — mirrors `OcptBudgetCostTracking`'s own
/// `_OcptCostTrackingCreationFooter`, generic over its own label.
class _OcptSharingCreationFooter extends StatelessWidget {
  /// The footer's own label.
  final String label;

  /// Called when the footer is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptSharingCreationFooter({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
