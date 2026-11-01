// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_commitment_payments.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_info_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_scaffold.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_inline_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The quote-line variant: breadcrumb poste › line, the quantity × unit price hint (and the
/// breakdown element it prices, when it prices one), the `Estimé — Engagé — Payé` stepper, and
/// one of the line's own two mutually exclusive states — `docs/architecture/budget.md`'s "A quote
/// line can be promoted into a commitment, and the line stays".
class OcptBudgetFicheLine extends StatelessWidget {
  /// The fiche this part belongs to: the catalogues it reads and the callbacks it asks.
  final OcptBudgetFiche fiche;

  /// The poste the line belongs to.
  final OcptBudgetPoste poste;

  /// The quote line this variant draws.
  final OcptBudgetLine line;

  /// Class constructor
  const OcptBudgetFicheLine({
    super.key,
    required this.fiche,
    required this.poste,
    required this.line,
  });

  @override
  Widget build(BuildContext context) {
    final commitments = fiche.commitments;
    final entries = fiche.entries;
    final resources = fiche.resources;
    final defaultVatRateBasisPoints = fiche.defaultVatRateBasisPoints;
    final currencyCode = fiche.currencyCode;
    final isSimplified = fiche.isSimplified;
    final isReadOnly = fiche.isReadOnly;
    final elementNameByElementId = fiche.elementNameByElementId;
    final onLineCommitRequested = fiche.onLineCommitRequested;
    final onLinePayDirectlyRequested = fiche.onLinePayDirectlyRequested;
    final onLineSettleRequested = fiche.onLineSettleRequested;
    final onLineShowCommitmentRequested = fiche.onLineShowCommitmentRequested;
    final onLineUncommitRequested = fiche.onLineUncommitRequested;
    final onLineDeletionRequested = fiche.onLineDeletionRequested;
    final onResourceEditRequested = fiche.onResourceEditRequested;
    final tr = Tr.of(context);

    final lineTotalCents = ocptBudgetLineTotalCents(line);
    final commitment = commitments.firstWhereOrNull((commitment) => commitment.lineId == line.id);
    final isPromoted = commitment != null;
    final isSettled =
        commitment != null &&
        ocptBudgetCommitmentIsSettledOf(
          commitment,
          entries,
          projectVatRateBasisPoints: defaultVatRateBasisPoints,
        );
    final committedCents = commitment == null
        ? null
        : ocptBudgetCommitmentCashCentsOf(
            commitment,
            projectVatRateBasisPoints: defaultVatRateBasisPoints,
          );
    // `Payé` only ever reads once this line's own commitment is settled — matching what a single,
    // exact-amount payment already read before commitments could be paid in instalments: a
    // commitment still owed something, even partly paid, states nothing here yet.
    final paidCents = commitment == null || !isSettled
        ? null
        : ocptBudgetCommitmentPaidCentsOf(
            commitment,
            entries,
            projectVatRateBasisPoints: defaultVatRateBasisPoints,
          ).amountCents;
    // What this commitment still owes — the `Pay` action and the outstanding block below both read
    // this, never [committedCents]' own full figure, so a partly-paid commitment offers back only
    // what is actually left to pay (`docs/architecture/budget.md`).
    final outstandingCents = commitment == null
        ? null
        : ocptBudgetCommitmentOutstandingCentsOf(
            commitment,
            entries,
            projectVatRateBasisPoints: defaultVatRateBasisPoints,
          );
    // Every entry that has paid this commitment, oldest first — a commitment settled in
    // instalments draws each one, `docs/architecture/budget.md`.
    final payments = commitment == null
        ? const <OcptBudgetEntry>[]
        : (entries.where((entry) => entry.commitmentId == commitment.id).toList()
            ..sort((a, b) => a.date.compareTo(b.date)));

    final elementName = line.elementId == null ? null : elementNameByElementId[line.elementId];
    final quantityText = ocptBudgetQuantityLabel(line.quantityMilli);
    final unitPriceText = ocptBudgetAmountLabel(line.unitPrice.amountCents, currencyCode);
    final hintLines = [
      "$quantityText ${line.unit} × $unitPriceText",
      if (elementName != null) tr.budgetLineFromElementReadOut(elementName),
    ];

    final String outstandingLabel;
    final String? outstandingValue;
    if (!isPromoted) {
      outstandingLabel = tr.budgetFicheLineStillToCommitLabel;
      outstandingValue = fiche.amountLabelOf(lineTotalCents);
    } else if (!isSettled) {
      outstandingLabel = tr.budgetCommittedOutstandingLabel;
      outstandingValue = fiche.amountLabelOf(outstandingCents);
    } else {
      outstandingLabel = tr.budgetCommittedOutstandingLabel;
      outstandingValue = null;
    }

    // A counterpart line ([OcptBudgetLine.inKindResourceId] not null) is neither paid, committed
    // nor deleted from the quote — its whole lifecycle is the contribution's
    // (`docs/architecture/budget.md`) — so this branch runs before, and instead of, every other
    // one below: no primary, no secondary, only a calm note naming the contribution it is covered
    // in kind by.
    final isInKindCounterpart = line.inKindResourceId != null;
    OcptBudgetFicheAction? primary;
    final secondaries = <OcptBudgetFicheAction>[];
    Widget? banner;
    if (isInKindCounterpart) {
      // A counterpart line is edited only through the contribution it balances — its whole
      // lifecycle is the resource's — so its own fields read read-only here (no `details`, no
      // stepper) and its sole action opens that contribution (`docs/architecture/budget.md`).
      final contribution = resources.firstWhereOrNull(
        (resource) => resource.id == line.inKindResourceId,
      );
      final contributionLabel = contribution == null || contribution.label.isEmpty
          ? tr.budgetPosteUnnamed
          : contribution.label;
      banner = OcptBudgetFicheInfoBanner(
        message: tr.budgetFicheInKindCounterpartHint(contributionLabel),
      );
      primary = (isReadOnly || contribution == null || onResourceEditRequested == null)
          ? null
          : OcptBudgetFicheAction(
              label: tr.budgetFicheEditInKindContributionAction,
              onTap: () => onResourceEditRequested.call(contribution),
            );
    } else if (isReadOnly) {
      primary = null;
    } else if (!isPromoted) {
      // Pay is the primary gesture, not commit: a production quotes then pays, the commitment made
      // for it transparently. Commit stays on as a secondary, for a cost acted before it is paid.
      primary = onLinePayDirectlyRequested == null
          ? null
          : OcptBudgetFicheAction(
              label: tr.budgetFichePayAction(fiche.amountLabelOf(lineTotalCents)),
              onTap: () => onLinePayDirectlyRequested.call(line.id),
            );
      if (onLineCommitRequested != null) {
        secondaries.add(
          OcptBudgetFicheAction(
            label: tr.budgetLineCommitAction,
            onTap: () => onLineCommitRequested.call(line.id),
          ),
        );
      }
      if (onLineDeletionRequested != null) {
        secondaries.add(
          OcptBudgetFicheAction(
            label: tr.budgetLineDeleteAction,
            onTap: () => onLineDeletionRequested.call(line.id),
          ),
        );
      }
    } else if (!isSettled) {
      primary = onLineSettleRequested == null
          ? null
          : OcptBudgetFicheAction(
              label: tr.budgetFichePayAction(fiche.amountLabelOf(outstandingCents)),
              onTap: () => onLineSettleRequested.call(line.id),
            );
      if (onLineShowCommitmentRequested != null) {
        secondaries.add(
          OcptBudgetFicheAction(
            label: tr.budgetLineShowCommitmentAction,
            onTap: () => onLineShowCommitmentRequested.call(line.id),
          ),
        );
      }
      if (onLineUncommitRequested != null) {
        secondaries.add(
          OcptBudgetFicheAction(
            label: tr.budgetLineUncommitAction,
            onTap: () => onLineUncommitRequested.call(line.id),
          ),
        );
      }
    } else {
      primary = null;
      // No `Show the commitment` here, unlike the unsettled branch above: it would open the
      // cash-flow page's own `À venir` section, which holds unsettled commitments only — a
      // settled one has nowhere left on that page to be shown.
      if (onLineDeletionRequested != null) {
        secondaries.add(
          OcptBudgetFicheAction(
            label: tr.budgetLineDeleteAction,
            onTap: () => onLineDeletionRequested.call(line.id),
          ),
        );
      }
    }

    return OcptBudgetFicheScaffold(
      breadcrumb: [
        "${poste.code} ${ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified)}",
        if (line.label.isEmpty) tr.budgetLineUnnamed else line.label,
      ],
      title: line.label.isEmpty ? tr.budgetLineUnnamed : line.label,
      amountText: fiche.amountLabelOf(lineTotalCents),
      hint: hintLines.join("\n"),
      stepLabels: isInKindCounterpart
          ? const []
          : [
              tr.budgetFicheStepEstimatedLabel,
              tr.budgetInspectorFigureCommitted,
              tr.budgetInspectorFigurePaid,
            ],
      reachedCount: isInKindCounterpart ? 0 : (isSettled ? 3 : (isPromoted ? 2 : 1)),
      figures: isInKindCounterpart
          ? [(tr.budgetResourceDialogValuedAtFieldLabel, fiche.amountLabelOf(lineTotalCents))]
          : [
              (tr.budgetFicheStepEstimatedLabel, fiche.amountLabelOf(lineTotalCents)),
              (tr.budgetInspectorFigureCommitted, fiche.amountLabelOf(committedCents)),
              (tr.budgetInspectorFigurePaid, fiche.amountLabelOf(paidCents)),
            ],
      outstandingLabel: isInKindCounterpart ? null : outstandingLabel,
      outstandingValue: isInKindCounterpart ? null : outstandingValue,
      details: isInKindCounterpart ? null : _OcptBudgetFicheLineFields(fiche: fiche, line: line),
      banner: banner,
      paymentsSection: payments.isEmpty
          ? null
          : OcptBudgetCommitmentPayments(
              payments: payments,
              defaultVatRateBasisPoints: defaultVatRateBasisPoints,
              currencyCode: currencyCode,
            ),
      primary: primary,
      secondaries: secondaries,
    );
  }
}

/// The quote line's own editable fields: label, quantity, unit, unit price (with the
/// including/excluding-tax choice) and VAT (with its `Inherit` action) and notes.
class _OcptBudgetFicheLineFields extends StatelessWidget {
  /// The fiche this part belongs to: the catalogues it reads and the callbacks it asks.
  final OcptBudgetFiche fiche;

  /// The line whose fields are drawn.
  final OcptBudgetLine line;

  /// Class constructor
  const _OcptBudgetFicheLineFields({required this.fiche, required this.line});

  @override
  Widget build(BuildContext context) {
    final defaultVatRateBasisPoints = fiche.defaultVatRateBasisPoints;
    final currencyCode = fiche.currencyCode;
    final isReadOnly = fiche.isReadOnly;
    final fieldValueOf = fiche.fieldValueOf;
    final onFieldChanged = fiche.onFieldChanged;
    final onLineTaxInclusiveChanged = fiche.onLineTaxInclusiveChanged;
    final onLineVatRateInheritedRequested = fiche.onLineVatRateInheritedRequested;
    final tr = Tr.of(context);
    final currencySymbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
    final effectiveRate = ocptEffectiveVatRateOf(
      lineVatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OcptBudgetFicheField(
          fiche: fiche,
          targetId: line.id,
          field: OcptBudgetField.lineLabel,
          label: tr.budgetLineLabelFieldLabel,
          storedValue: line.label,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OcptBudgetFicheField(
                fiche: fiche,
                targetId: line.id,
                field: OcptBudgetField.lineQuantity,
                label: tr.budgetLineQuantityFieldLabel,
                storedValue: ocptBudgetQuantityLabel(line.quantityMilli),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OcptBudgetFicheField(
                fiche: fiche,
                targetId: line.id,
                field: OcptBudgetField.lineUnit,
                label: tr.budgetLineUnitFieldLabel,
                storedValue: line.unit,
                hintText: tr.budgetLineUnitFieldHint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OcptBudgetInlineField(
          label: tr.budgetLineUnitPriceFieldLabel,
          value: fieldValueOf(
            line.id,
            OcptBudgetField.lineUnitAmount,
            ocptCostTextOf(line.unitPrice.amountCents),
          ),
          suffixText: currencySymbol,
          onChanged: onFieldChanged == null
              ? null
              : (value) => onFieldChanged.call(line.id, OcptBudgetField.lineUnitAmount, value),
        ),
        const SizedBox(height: 8),
        OcptBudgetBinaryChoice(
          value: line.unitPrice.isTaxInclusive,
          trueLabel: tr.budgetLineTaxInclusiveOption,
          falseLabel: tr.budgetLineTaxExclusiveOption,
          onChanged: isReadOnly
              ? null
              : (value) => onLineTaxInclusiveChanged?.call(line.id, isTaxInclusive: value),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OcptBudgetInlineField(
                label: tr.budgetLineVatRateFieldLabel,
                value: fieldValueOf(
                  line.id,
                  OcptBudgetField.lineVatRateOverride,
                  ocptVatRatePercentTextOf(line.unitPrice.vatRateBasisPoints),
                ),
                hintText: effectiveRate.basisPoints == null
                    ? null
                    : tr.budgetLineVatRateInheritedHint(
                        ocptVatRatePercentTextOf(effectiveRate.basisPoints),
                      ),
                suffixText: tr.budgetLineVatRateSuffix,
                onChanged: onFieldChanged == null
                    ? null
                    : (value) =>
                          onFieldChanged.call(line.id, OcptBudgetField.lineVatRateOverride, value),
              ),
            ),
            if (!isReadOnly && onLineVatRateInheritedRequested != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: TextButton(
                  onPressed: () => onLineVatRateInheritedRequested.call(line.id),
                  child: Text(tr.budgetLineVatRateInheritAction),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        OcptBudgetFicheField(
          fiche: fiche,
          targetId: line.id,
          field: OcptBudgetField.lineNotes,
          label: tr.budgetLineNotesFieldLabel,
          storedValue: line.notes,
          multiline: true,
        ),
      ],
    );
  }
}
