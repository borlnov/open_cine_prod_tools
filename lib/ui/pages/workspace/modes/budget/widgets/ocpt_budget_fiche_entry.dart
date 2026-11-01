// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_poste_strain.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_scaffold.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_off_line_banner.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The entry variant: breadcrumb through its own poste (when it names one), the date/voucher hint
/// and its own receipt marker, the stepper with `Payé` reached, and `Edit`/`Delete`. Also drawn by
/// [OcptBudgetFicheReceipt]: [stepLabelsOverride], [reachedCountOverride] and [breadcrumbOverride]
/// the only things that differ between the two readings of the very same row.
class OcptBudgetFicheEntry extends StatelessWidget {
  /// The fiche this part belongs to: the catalogues it reads and the callbacks it asks.
  final OcptBudgetFiche fiche;

  /// The entry this variant draws.
  final OcptBudgetEntry entry;

  /// The stepper labels to draw in place of the entry's own, or null.
  final List<String>? stepLabelsOverride;

  /// How many stepper labels to draw as reached in place of the entry's own, or null.
  final int? reachedCountOverride;

  /// The breadcrumb segments to draw in place of the entry's own, or null.
  final List<String>? breadcrumbOverride;

  /// Class constructor
  const OcptBudgetFicheEntry({
    super.key,
    required this.fiche,
    required this.entry,
    this.stepLabelsOverride,
    this.reachedCountOverride,
    this.breadcrumbOverride,
  });

  /// Build the budget fiche entry as an [OcptBudgetFicheScaffold].
  @override
  Widget build(BuildContext context) {
    final commitments = fiche.commitments;
    final resources = fiche.resources;
    final revenues = fiche.revenues;
    final taxBasis = fiche.taxBasis;
    final defaultVatRateBasisPoints = fiche.defaultVatRateBasisPoints;
    final isSimplified = fiche.isSimplified;
    final isReadOnly = fiche.isReadOnly;
    final receiptsByEntryId = fiche.receiptsByEntryId;
    final onEntryEditRequested = fiche.onEntryEditRequested;
    final onEntryDeletionRequested = fiche.onEntryDeletionRequested;
    final onEntryPromoteToQuoteRequested = fiche.onEntryPromoteToQuoteRequested;
    final onEntryMoveOffQuoteRequested = fiche.onEntryMoveOffQuoteRequested;
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();
    final poste = entry.posteId == null ? null : fiche.posteById(entry.posteId!);
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

    final title = entry.label.isEmpty ? tr.budgetPosteUnnamed : entry.label;
    final dateText = DateFormat.yMMMd(locale).format(entry.date);
    final hintLines = [
      tr.budgetFicheEntryHint(dateText, entry.voucherNumber),
      if (receipt != null) tr.budgetCashJournalVoucherAttachedTooltip,
      if (settlesText != null) tr.budgetFicheEntrySettlesLabel(settlesText),
    ];

    Widget? offLineDebitBanner;
    if (ocptBudgetEntryIsOffLineDebit(entry)) {
      var bannerMessage = tr.budgetFicheEntryOffLineBannerText;
      if (poste != null) {
        final posteQuoted = ocptBudgetTotalOf(
          poste.lines,
          basis: taxBasis,
          projectVatRateBasisPoints: defaultVatRateBasisPoints,
        );
        final postePaidCents = fiche.paidCentsOf(poste.id);
        final posteCommittedCents = fiche.committedCentsOf(poste.id);
        final posteInKindCoveredCents = fiche.inKindCoveredCentsOf(poste.id);
        final posteStrain = ocptBudgetPosteStrainOf(
          quotedAmountCents: posteQuoted.amountCents,
          paidCents: postePaidCents,
          committedCents: posteCommittedCents,
          inKindCoveredCents: posteInKindCoveredCents,
        );
        if (posteStrain == OcptBudgetPosteStrain.over) {
          final varianceCents = ocptBudgetVarianceCents(
            quotedAmountCents: posteQuoted.amountCents,
            paidCents: postePaidCents,
            committedCents: posteCommittedCents,
            inKindCoveredCents: posteInKindCoveredCents,
          );
          bannerMessage = tr.budgetFicheEntryOffLineBannerOverQuoteText(
            fiche.amountLabelOf(varianceCents),
          );
        }
      }
      offLineDebitBanner = OcptBudgetOffLineBanner(
        message: bannerMessage,
        promoteLabel: tr.budgetFichePromoteToQuoteAction,
        moveOffQuoteLabel: tr.budgetFicheEntryMoveOffQuoteAction,
        onPromoteToQuoteRequested: isReadOnly ? null : onEntryPromoteToQuoteRequested,
        onMoveOffQuoteRequested: isReadOnly ? null : onEntryMoveOffQuoteRequested,
      );
    }

    return OcptBudgetFicheScaffold(
      breadcrumb:
          breadcrumbOverride ??
          [
            if (poste != null)
              "${poste.code} ${ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified)}",
            tr.budgetFicheKindEntryLabel,
          ],
      title: title,
      amountText: fiche.amountLabelOf(amountCents),
      hint: hintLines.join("\n"),
      stepLabels:
          stepLabelsOverride ??
          [
            tr.budgetFicheStepEstimatedLabel,
            tr.budgetInspectorFigureCommitted,
            tr.budgetInspectorFigurePaid,
          ],
      reachedCount: reachedCountOverride ?? 3,
      figures: [
        (
          isDebit ? tr.budgetCashJournalColumnDebit : tr.budgetCashJournalColumnCredit,
          fiche.amountLabelOf(amountCents),
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
          : OcptBudgetFicheAction(
              label: tr.budgetFinancingEditAction,
              onTap: () => onEntryEditRequested.call(entry),
            ),
      secondaries: [
        if (!isReadOnly && onEntryDeletionRequested != null)
          OcptBudgetFicheAction(
            label: tr.budgetEntryDeleteAction,
            onTap: () => onEntryDeletionRequested.call(entry.id),
          ),
      ],
    );
  }
}
