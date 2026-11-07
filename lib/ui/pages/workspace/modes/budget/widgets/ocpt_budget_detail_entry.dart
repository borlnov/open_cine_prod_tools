// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_account_strain.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_scaffold.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_off_line_banner.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The entry variant: breadcrumb through its own account (when it names one), the date/voucher hint
/// and its own receipt marker, the stepper with `Payé` reached, and `Edit`/`Delete`. Also drawn by
/// [OcptBudgetDetailReceipt]: [stepLabelsOverride], [reachedCountOverride] and [breadcrumbOverride]
/// the only things that differ between the two readings of the very same row.
class OcptBudgetDetailEntry extends StatelessWidget {
  /// The detail panel this part belongs to: the catalogues it reads and the callbacks it asks.
  final OcptBudgetDetail detail;

  /// The entry this variant draws.
  final OcptBudgetEntry entry;

  /// The stepper labels to draw in place of the entry's own, or null.
  final List<String>? stepLabelsOverride;

  /// How many stepper labels to draw as reached in place of the entry's own, or null.
  final int? reachedCountOverride;

  /// The breadcrumb segments to draw in place of the entry's own, or null.
  final List<String>? breadcrumbOverride;

  /// Class constructor
  const OcptBudgetDetailEntry({
    super.key,
    required this.detail,
    required this.entry,
    this.stepLabelsOverride,
    this.reachedCountOverride,
    this.breadcrumbOverride,
  });

  /// Build the budget detail panel entry as an [OcptBudgetDetailScaffold].
  @override
  Widget build(BuildContext context) {
    final commitments = detail.commitments;
    final resources = detail.resources;
    final revenues = detail.revenues;
    final taxBasis = detail.taxBasis;
    final defaultVatRateBasisPoints = detail.defaultVatRateBasisPoints;
    final isSimplified = detail.isSimplified;
    final isReadOnly = detail.isReadOnly;
    final receiptsByEntryId = detail.receiptsByEntryId;
    final onEntryEditRequested = detail.onEntryEditRequested;
    final onEntryDeletionRequested = detail.onEntryDeletionRequested;
    final onEntryPromoteToQuoteRequested = detail.onEntryPromoteToQuoteRequested;
    final onEntryMoveOffQuoteRequested = detail.onEntryMoveOffQuoteRequested;
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();
    final account = entry.accountId == null ? null : detail.accountById(entry.accountId!);
    final isDebit = entry.debitCents > 0;
    final amountCents = isDebit
        ? ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: defaultVatRateBasisPoints)
        : ocptBudgetEntryCreditCentsOf(entry, projectVatRateBasisPoints: defaultVatRateBasisPoints);
    final effectiveRate = ocptEffectiveVatRateOf(
      lineVatRateBasisPoints: entry.vatRateBasisPoints,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final receipt = receiptsByEntryId[entry.id];

    final settlingCommitment = entry.commitmentId == null
        ? null
        : commitments.firstWhereOrNull((commitment) => commitment.id == entry.commitmentId);
    final settlingResource = entry.resourceId == null
        ? null
        : resources.firstWhereOrNull((resource) => resource.id == entry.resourceId);
    final settlingRevenue = entry.revenueId == null
        ? null
        : revenues.firstWhereOrNull((revenue) => revenue.id == entry.revenueId);
    final settlesText = settlingCommitment != null
        ? settlingCommitment.label
        : settlingResource != null
        ? settlingResource.label
        : settlingRevenue?.label;

    final title = entry.label.isEmpty ? tr.budgetAccountUnnamed : entry.label;
    final dateText = DateFormat.yMMMd(locale).format(entry.date);
    final hintLines = [
      tr.budgetDetailEntryHint(dateText, entry.voucherNumber),
      if (receipt != null) tr.budgetCashJournalVoucherAttachedTooltip,
      if (settlesText != null) tr.budgetDetailEntrySettlesLabel(settlesText),
    ];

    Widget? offLineDebitBanner;
    if (ocptBudgetEntryIsOffLineDebit(entry)) {
      var bannerMessage = tr.budgetDetailEntryOffLineBannerText;
      if (account != null) {
        final accountQuoted = ocptBudgetTotalOf(
          account.lines,
          basis: taxBasis,
          projectVatRateBasisPoints: defaultVatRateBasisPoints,
        );
        final accountPaidCents = detail.paidCentsOf(account.id);
        final accountCommittedCents = detail.committedCentsOf(account.id);
        final accountInKindCoveredCents = detail.inKindCoveredCentsOf(account.id);
        final accountStrain = ocptBudgetAccountStrainOf(
          quotedAmountCents: accountQuoted.amountCents,
          paidCents: accountPaidCents,
          committedCents: accountCommittedCents,
          inKindCoveredCents: accountInKindCoveredCents,
        );
        if (accountStrain == OcptBudgetAccountStrain.over) {
          final varianceCents = ocptBudgetVarianceCents(
            quotedAmountCents: accountQuoted.amountCents,
            paidCents: accountPaidCents,
            committedCents: accountCommittedCents,
            inKindCoveredCents: accountInKindCoveredCents,
          );
          bannerMessage = tr.budgetDetailEntryOffLineBannerOverQuoteText(
            detail.amountLabelOf(varianceCents),
          );
        }
      }
      offLineDebitBanner = OcptBudgetOffLineBanner(
        message: bannerMessage,
        promoteLabel: tr.budgetDetailPromoteToQuoteAction,
        moveOffQuoteLabel: tr.budgetDetailEntryMoveOffQuoteAction,
        onPromoteToQuoteRequested: isReadOnly ? null : onEntryPromoteToQuoteRequested,
        onMoveOffQuoteRequested: isReadOnly ? null : onEntryMoveOffQuoteRequested,
      );
    }

    return OcptBudgetDetailScaffold(
      breadcrumb:
          breadcrumbOverride ??
          [
            if (account != null)
              "${account.code} "
                  "${ocptBudgetAccountDisplayLabel(account, isSimplified: isSimplified)}",
            tr.budgetDetailKindEntryLabel,
          ],
      title: title,
      amountText: detail.amountLabelOf(amountCents),
      hint: hintLines.join("\n"),
      stepLabels:
          stepLabelsOverride ??
          [
            tr.budgetDetailStepEstimatedLabel,
            tr.budgetInspectorFigureCommitted,
            tr.budgetInspectorFigurePaid,
          ],
      reachedCount: reachedCountOverride ?? 3,
      figures: [
        (
          isDebit ? tr.budgetCashJournalColumnDebit : tr.budgetCashJournalColumnCredit,
          detail.amountLabelOf(amountCents),
        ),
        (
          tr.budgetLineTaxInclusiveOption,
          entry.isTaxInclusive ? tr.budgetLineTaxInclusiveOption : tr.budgetLineTaxExclusiveOption,
        ),
        (tr.budgetLineVatRateFieldLabel, ocptVatRatePercentTextOf(effectiveRate.basisPoints)),
      ],
      banner: offLineDebitBanner,
      primary: isReadOnly || onEntryEditRequested == null
          ? null
          : OcptBudgetDetailAction(
              label: tr.budgetFinancingEditAction,
              onTap: () => onEntryEditRequested.call(entry),
            ),
      secondaries: [
        if (!isReadOnly && onEntryDeletionRequested != null)
          OcptBudgetDetailAction(
            label: tr.budgetEntryDeleteAction,
            onTap: () => onEntryDeletionRequested.call(entry.id),
          ),
      ],
    );
  }
}
