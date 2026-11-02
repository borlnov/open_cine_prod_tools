// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_account_proportion_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_scaffold.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_inline_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The poste variant: breadcrumb through the document, the quote/committed/paid/estimate to
/// complete/final cost/final-cost variance figures, the remaining amount as its
/// own outstanding, and its editable fields — label, code, simple label, the typed estimate to
/// complete and its `Derive again` action.
class OcptBudgetDetailPoste extends StatelessWidget {
  /// The detail panel this part belongs to: the catalogues it reads and the callbacks it asks.
  final OcptBudgetDetail detail;

  /// The poste this variant draws.
  final OcptBudgetPoste poste;

  /// Class constructor
  const OcptBudgetDetailPoste({super.key, required this.detail, required this.poste});

  /// Build the budget detail panel poste as an [OcptBudgetDetailScaffold].
  @override
  Widget build(BuildContext context) {
    final taxBasis = detail.taxBasis;
    final defaultVatRateBasisPoints = detail.defaultVatRateBasisPoints;
    final isSimplified = detail.isSimplified;
    final tr = Tr.of(context);

    final quoted = ocptBudgetTotalOf(
      poste.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final paidCents = detail.paidCentsOf(poste.id);
    final committedCents = detail.committedCentsOf(poste.id);
    final inKindCoveredCents = detail.inKindCoveredCentsOf(poste.id);
    final estimateToCompleteCents = ocptBudgetEstimateToCompleteCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paidCents,
      committedCents: committedCents,
      inKindCoveredCents: inKindCoveredCents,
      typedEstimateToCompleteCents: poste.estimateToCompleteCents,
    );
    final finalCostCents = ocptBudgetFinalCostCents(
      paidCents: paidCents,
      committedCents: committedCents,
      estimateToCompleteCents: estimateToCompleteCents,
    );
    final finalCostVarianceCents = ocptBudgetFinalCostVarianceCents(
      quotedAmountCents: quoted.amountCents,
      finalCostCents: finalCostCents,
    );
    final remainingCents = ocptBudgetRemainingCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paidCents,
      committedCents: committedCents,
      inKindCoveredCents: inKindCoveredCents,
    );

    return OcptBudgetDetailScaffold(
      breadcrumb: [tr.budgetHeaderExpensesSegmentLabel],
      title: ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified),
      amountText: detail.amountLabelOf(quoted.amountCents),
      // A poste is an aggregate, not a single debt working through a lifecycle of its own — the
      // three-step chain the line, commitment and entry variants below draw would light every step
      // in hard code the moment a poste exists at all. The poste variant alone draws no stepper —
      // `proportionBar` fills the very same slot instead, `docs/architecture/budget.md`.
      stepLabels: const [],
      reachedCount: 0,
      proportionBar: OcptBudgetPosteProportionBar(
        quotedAmountCents: quoted.amountCents,
        paidCents: paidCents,
        committedCents: committedCents,
      ),
      figures: [
        (tr.budgetInspectorFigureQuote, detail.amountLabelOf(quoted.amountCents)),
        (tr.budgetInspectorFigureCommitted, detail.amountLabelOf(committedCents)),
        (tr.budgetInspectorFigurePaid, detail.amountLabelOf(paidCents)),
        (
          tr.budgetInspectorPosteEstimateToCompleteFieldLabel,
          detail.amountLabelOf(estimateToCompleteCents),
        ),
        (tr.budgetCostTrackingColumnFinalCost, detail.amountLabelOf(finalCostCents)),
        (tr.budgetCostTrackingColumnVariance, detail.amountLabelOf(finalCostVarianceCents)),
      ],
      outstandingLabel: tr.budgetInspectorFigureRemaining,
      outstandingValue: detail.amountLabelOf(remainingCents),
      details: _OcptBudgetDetailPosteFields(detail: detail, poste: poste),
      // The poste's own `Add`/`From breakdown` actions are gone: a fresh quote line is now typed
      // through the capture wizard's own `addQuoteLine`/`addQuoteLinesFromBreakdown` gestures,
      // reached from the header's own `+ Nouveau` button.
      primary: null,
      secondaries: const [],
    );
  }
}

/// The poste's own editable fields: label, code, simple label and the typed estimate to complete,
/// with its `Derive again` action.
class _OcptBudgetDetailPosteFields extends StatelessWidget {
  /// The detail panel this part belongs to: the catalogues it reads and the callbacks it asks.
  final OcptBudgetDetail detail;

  /// The poste whose fields are drawn.
  final OcptBudgetPoste poste;

  /// Class constructor
  const _OcptBudgetDetailPosteFields({required this.detail, required this.poste});

  /// Build the budget detail panel poste fields as a [Column].
  @override
  Widget build(BuildContext context) {
    final postes = detail.postes;
    final taxBasis = detail.taxBasis;
    final defaultVatRateBasisPoints = detail.defaultVatRateBasisPoints;
    final currencyCode = detail.currencyCode;
    final isReadOnly = detail.isReadOnly;
    final fieldValueOf = detail.fieldValueOf;
    final onFieldChanged = detail.onFieldChanged;
    final onPosteEstimateToCompleteDerivedRequested =
        detail.onPosteEstimateToCompleteDerivedRequested;
    final tr = Tr.of(context);
    final quoted = ocptBudgetTotalOf(
      poste.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final paidCents = detail.paidCentsOf(poste.id);
    final committedCents = detail.committedCentsOf(poste.id);
    final derivedEstimateToCompleteCents = ocptBudgetEstimateToCompleteCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paidCents,
      committedCents: committedCents,
      inKindCoveredCents: detail.inKindCoveredCentsOf(poste.id),
      typedEstimateToCompleteCents: null,
    );
    final currencySymbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
    // Signalled, never blocked (`docs/architecture/budget.md`): an empty code is not a duplicate,
    // and the comparison trims both sides so two codes differing only by surrounding whitespace
    // still read as the same one.
    final trimmedCode = poste.code.trim();
    final hasDuplicateCode =
        trimmedCode.isNotEmpty &&
        postes.any((other) => other.id != poste.id && other.code.trim() == trimmedCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OcptBudgetDetailField(
          detail: detail,
          targetId: poste.id,
          field: OcptBudgetField.posteLabel,
          label: tr.budgetInspectorPosteLabelFieldLabel,
          storedValue: poste.label,
        ),
        const SizedBox(height: 8),
        OcptBudgetDetailField(
          detail: detail,
          targetId: poste.id,
          field: OcptBudgetField.posteCode,
          label: tr.budgetInspectorPosteCodeFieldLabel,
          storedValue: poste.code,
          errorText: hasDuplicateCode ? tr.budgetInspectorPosteCodeDuplicateError : null,
        ),
        const SizedBox(height: 8),
        OcptBudgetDetailField(
          detail: detail,
          targetId: poste.id,
          field: OcptBudgetField.posteSimpleLabel,
          label: tr.budgetInspectorPosteSimpleLabelFieldLabel,
          storedValue: poste.simpleLabel ?? "",
          hintText: poste.label,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OcptBudgetInlineField(
                label: tr.budgetInspectorPosteEstimateToCompleteFieldLabel,
                value: fieldValueOf(
                  poste.id,
                  OcptBudgetField.posteEstimateToComplete,
                  ocptCostTextOf(poste.estimateToCompleteCents),
                ),
                hintText: tr.budgetInspectorPosteEstimateToCompleteHint(
                  ocptBudgetAmountLabel(derivedEstimateToCompleteCents, currencyCode),
                ),
                helperText: tr.budgetInspectorPosteEstimateToCompleteHelper,
                suffixText: currencySymbol,
                onChanged: onFieldChanged == null
                    ? null
                    : (value) => onFieldChanged.call(
                        poste.id,
                        OcptBudgetField.posteEstimateToComplete,
                        value,
                      ),
              ),
            ),
            if (!isReadOnly && onPosteEstimateToCompleteDerivedRequested != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: TextButton(
                  onPressed: () => onPosteEstimateToCompleteDerivedRequested.call(poste.id),
                  child: Text(tr.budgetInspectorPosteEstimateToCompleteDeriveAction),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
