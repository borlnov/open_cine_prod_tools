// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_poste_strain.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_scaffold.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_off_line_banner.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The commitment variant: breadcrumb poste › line (when promoted from one) › `Commitment`, the
/// status/due-date hint, the `Estimé — Engagé — Payé` stepper, and `Pay`/`Edit`/`Delete`.
class OcptBudgetFicheCommitment extends StatelessWidget {
  /// The fiche this part belongs to: the catalogues it reads and the callbacks it asks.
  final OcptBudgetFiche fiche;

  /// The commitment this variant draws.
  final OcptBudgetCommitment commitment;

  /// Class constructor
  const OcptBudgetFicheCommitment({super.key, required this.fiche, required this.commitment});

  /// Build the budget fiche commitment as an [OcptBudgetFicheScaffold].
  @override
  Widget build(BuildContext context) {
    final entries = fiche.entries;
    final taxBasis = fiche.taxBasis;
    final defaultVatRateBasisPoints = fiche.defaultVatRateBasisPoints;
    final isSimplified = fiche.isSimplified;
    final isReadOnly = fiche.isReadOnly;
    final onCommitmentSettleRequested = fiche.onCommitmentSettleRequested;
    final onCommitmentEditRequested = fiche.onCommitmentEditRequested;
    final onCommitmentDeletionRequested = fiche.onCommitmentDeletionRequested;
    final onCommitmentPromoteToQuoteRequested = fiche.onCommitmentPromoteToQuoteRequested;
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();

    final poste = fiche.posteById(commitment.posteId);
    final line = commitment.lineId == null ? null : fiche.lineById(commitment.lineId!);
    final cashCents = ocptBudgetCommitmentCashCentsOf(
      commitment,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final isSettled = ocptBudgetCommitmentIsSettledOf(
      commitment,
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    // Mirrors `OcptBudgetFicheLine`'s own reading: `Payé` only ever states a figure once this
    // commitment is settled, matching what a single, exact-amount payment already read before a
    // commitment could be paid in instalments.
    final paidCents = isSettled
        ? ocptBudgetCommitmentPaidCentsOf(
            commitment,
            entries,
            projectVatRateBasisPoints: defaultVatRateBasisPoints,
          ).amountCents
        : null;
    final quotedLineCents = line == null ? null : ocptBudgetLineTotalCents(line);
    // What this commitment still owes — the `Pay` action and the outstanding block both read this,
    // never [cashCents]' own full figure, so a commitment paid in part offers back only what is
    // actually left, exactly as the promoted quote line's own fiche already does.
    final outstandingCents = ocptBudgetCommitmentOutstandingCentsOf(
      commitment,
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );

    final title = commitment.label.isEmpty ? tr.budgetPosteUnnamed : commitment.label;
    final dueDateText = commitment.dueDate == null
        ? tr.budgetCommittedNoDueDateLabel
        : DateFormat.yMMMd(locale).format(commitment.dueDate!);

    Widget? offLineBanner;
    if (ocptBudgetCommitmentIsOffLine(commitment)) {
      var bannerMessage = tr.budgetFicheCommitmentOffLineBannerText;
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
          bannerMessage = tr.budgetFicheCommitmentOffLineBannerOverQuoteText(
            fiche.amountLabelOf(varianceCents),
          );
        }
      }
      // A commitment always names a poste, so it offers only `Add to the quote` — no `Move
      // off-quote`, unlike an off-line debit entry's own banner.
      offLineBanner = OcptBudgetOffLineBanner(
        message: bannerMessage,
        promoteLabel: tr.budgetFichePromoteToQuoteAction,
        moveOffQuoteLabel: null,
        onPromoteToQuoteRequested: isReadOnly ? null : onCommitmentPromoteToQuoteRequested,
        onMoveOffQuoteRequested: null,
      );
    }

    return OcptBudgetFicheScaffold(
      breadcrumb: [
        if (poste != null)
          "${poste.code} ${ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified)}",
        if (line != null) (line.label.isEmpty ? tr.budgetLineUnnamed : line.label),
        tr.budgetFicheKindCommitmentLabel,
      ],
      title: title,
      amountText: fiche.amountLabelOf(cashCents),
      hint: tr.budgetFicheCommitmentHint(
        ocptBudgetCommitmentStatusLabel(tr, commitment.status),
        dueDateText,
      ),
      stepLabels: [
        tr.budgetFicheStepEstimatedLabel,
        tr.budgetInspectorFigureCommitted,
        tr.budgetInspectorFigurePaid,
      ],
      reachedCount: isSettled ? 3 : 2,
      figures: [
        (tr.budgetFicheStepEstimatedLabel, fiche.amountLabelOf(quotedLineCents)),
        (tr.budgetInspectorFigureCommitted, fiche.amountLabelOf(cashCents)),
        (tr.budgetInspectorFigurePaid, fiche.amountLabelOf(paidCents)),
      ],
      outstandingLabel: tr.budgetCommittedOutstandingLabel,
      outstandingValue: isSettled ? null : fiche.amountLabelOf(outstandingCents),
      banner: offLineBanner,
      primary: isReadOnly || isSettled || onCommitmentSettleRequested == null
          ? null
          : OcptBudgetFicheAction(
              label: tr.budgetFichePayAction(fiche.amountLabelOf(outstandingCents)),
              onTap: () => onCommitmentSettleRequested.call(commitment),
            ),
      secondaries: [
        if (!isReadOnly && onCommitmentEditRequested != null)
          OcptBudgetFicheAction(
            label: tr.budgetFinancingEditAction,
            onTap: () => onCommitmentEditRequested.call(commitment),
          ),
        if (!isReadOnly && onCommitmentDeletionRequested != null)
          OcptBudgetFicheAction(
            label: tr.budgetCommittedDeleteAction,
            onTap: () => onCommitmentDeletionRequested.call(commitment.id),
          ),
      ],
    );
  }
}
