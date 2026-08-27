// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_family.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// The poste's own proportion bar's fixed width, in logical pixels — fixed, not [Expanded], so two
/// postes stay comparable when the bar later appears in a list
/// (`docs/plans/budget-capture-wizard.md`'s "The other corrections").
const double _ocptBudgetPosteProportionBarWidth = 160;

/// The poste's own proportion bar's own height, in logical pixels — matches
/// `OcptBudgetFinancing`'s own two-tone coverage bar.
const double _ocptBudgetPosteProportionBarHeight = 8;

/// One primary or secondary action the fiche offers, resolved by whichever `_build…` method built
/// the variant currently on screen.
class _OcptBudgetFicheAction {
  /// The button's own label.
  final String label;

  /// Called when the button is pressed.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptBudgetFicheAction({required this.label, required this.onTap});
}

/// The right dock's own `Inspector` tab, once and for all: a single panel, polymorphic on
/// [selection], drawing whatever `OcptBudgetSelection` variant is currently selected —
/// `docs/architecture/budget.md`'s "The right dock belongs to the view, not to the mode".
///
/// Every variant draws the same grammar, top to bottom: a breadcrumb up to the document, the
/// object's own name and amount, an optional hint (and, for a resource or a taking, a status badge
/// beside it), a small stepper of its states, the figures that make it up, the outstanding amount in
/// large type, one primary action and at most two secondary ones. The table says where things
/// stand; this fiche says where they come from and what to do next.
///
/// **The poste's and the quote line's own editable fields move here** (M4's tree draws every quote
/// line, commitment and entry as a row of its own, so this panel stops listing them): a poste keeps
/// its label, code, simple label and typed estimate to complete; a quote line keeps its label,
/// quantity, unit, unit price, tax choice, VAT override and notes.
///
/// A composite panel (`docs/architecture/foundations.md`'s own idiom): [isReadOnly] withholds every
/// writing affordance — every callback simply arrives null under a previewed version, this widget
/// never disabling one instead.
///
/// This widget resolves the object [selection] names off the whole catalogues it is handed
/// ([postes], [commitments], [entries], [resources], [revenues]) rather than being handed the object
/// pre-resolved, exactly as `OcptBudgetCostTracking` already resolves its own rows off `selection`
/// and the same catalogues — the mode hands in what it has on state, this panel finds its own
/// subject and its own ancestors (a line's own poste, a commitment's own line) in it.
class OcptBudgetFiche extends StatelessWidget {
  /// What is currently selected, or null while nothing is — the tab then shows a plain hint.
  final OcptBudgetSelection? selection;

  /// Every live poste of the project, each carrying its own lines.
  final List<OcptBudgetPoste> postes;

  /// Every live commitment of the project.
  final List<OcptBudgetCommitment> commitments;

  /// Every live journal entry of the project.
  final List<OcptBudgetEntry> entries;

  /// Every live financing resource of the project.
  final List<OcptBudgetResource> resources;

  /// Every live taking of the project.
  final List<OcptBudgetRevenue> revenues;

  /// Which basis every amount is currently read in — the quote's own toggle, read by the poste and
  /// the quote-line variants alone: every other variant reads money that has moved, always
  /// tax-inclusive (`docs/architecture/budget.md`).
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the header's simplified/detailed switch currently reads simplified — a poste's own
  /// displayed name.
  final bool isSimplified;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// A live element's own name, keyed by its id — resolves a quote line's own `elementId` into its
  /// own quiet hint line.
  final Map<String, String> elementNameByElementId;

  /// Every live voucher, keyed by the `budget_entries` row it evidences — an entry's own hint reads
  /// whether one is attached.
  final Map<String, OcptAssetRef> receiptsByEntryId;

  /// What has actually come in against each financing resource, keyed by its own id — a resource
  /// with no key here has received nothing at all (`ocptBudgetReceivedByResourceId`'s own doc
  /// comment).
  final Map<String, OcptBudgetCoveredTotal> receivedByResourceId;

  /// What has actually come in against each taking, keyed by its own id — mirrors
  /// [receivedByResourceId].
  final Map<String, OcptBudgetCoveredTotal> receivedByRevenueId;

  /// A poste's or a line's current value for `field` — a pending edit, or its own stored value.
  final String Function(String targetId, OcptBudgetField field, String storedValue) fieldValueOf;

  /// Called with a poste's or a line's id, which field and the raw text just typed, or null while
  /// [isReadOnly].
  final void Function(String targetId, OcptBudgetField field, String rawValue)? onFieldChanged;

  /// Called with the poste's id when its own `Derive again` action is clicked, or null while
  /// [isReadOnly]. Not an irreversible action, so the mode answers this by dispatching straight
  /// away, with no `OcptConfirmDialog`.
  final ValueChanged<String>? onPosteEstimateToCompleteDerivedRequested;

  /// Called with a line's id and the including/excluding-tax choice just picked, or null while
  /// [isReadOnly].
  final void Function(String lineId, {required bool isTaxInclusive})? onLineTaxInclusiveChanged;

  /// Called with a line's id when its own `Inherit` action is clicked, or null while [isReadOnly].
  final ValueChanged<String>? onLineVatRateInheritedRequested;

  /// Called with a line's id when `Commit this line…` is clicked, or null while [isReadOnly].
  final ValueChanged<String>? onLineCommitRequested;

  /// Called with a line's id when its own promoted, unsettled commitment is to be paid — opens the
  /// entry dialog pre-filled from that commitment, or null while [isReadOnly].
  final ValueChanged<String>? onLineSettleRequested;

  /// Called with a line's id when `Show the commitment` is clicked — never withheld under
  /// [isReadOnly], since it only moves the reader to a view they may open by hand. Offered from the
  /// promoted-and-unsettled branch alone: a settled commitment has nowhere left to be shown, `À
  /// venir` holding unsettled commitments only.
  final ValueChanged<String>? onLineShowCommitmentRequested;

  /// Called with a line's id when `Cancel the commitment` is clicked, or null while [isReadOnly] or
  /// there is nothing to cancel.
  final ValueChanged<String>? onLineUncommitRequested;

  /// Called with a line's id when its own `Delete` action is clicked, or null while [isReadOnly].
  final ValueChanged<String>? onLineDeletionRequested;

  /// Called with a commitment when its own `Pay` action is clicked, or null while [isReadOnly] or
  /// it is already settled.
  final ValueChanged<OcptBudgetCommitment>? onCommitmentSettleRequested;

  /// Called with a commitment when its own `Edit` action is clicked, or null while [isReadOnly].
  final ValueChanged<OcptBudgetCommitment>? onCommitmentEditRequested;

  /// Called with a commitment's id when its own `Delete` action is clicked, or null while
  /// [isReadOnly].
  final ValueChanged<String>? onCommitmentDeletionRequested;

  /// Called with an entry when its own `Edit` action is clicked, or null while [isReadOnly].
  final ValueChanged<OcptBudgetEntry>? onEntryEditRequested;

  /// Called with an entry's id when its own `Delete` action is clicked, or null while [isReadOnly].
  final ValueChanged<String>? onEntryDeletionRequested;

  /// Called with a resource when its own `Receive` action is clicked, or null while [isReadOnly].
  final ValueChanged<OcptBudgetResource>? onResourceReceiptRequested;

  /// Called with a resource when its own `Edit` action is clicked, or null while [isReadOnly].
  final ValueChanged<OcptBudgetResource>? onResourceEditRequested;

  /// Called with a resource's id when its own `Delete` action is clicked, or null while
  /// [isReadOnly].
  final ValueChanged<String>? onResourceDeletionRequested;

  /// Called with a taking when its own `Receive` action is clicked, or null while [isReadOnly].
  final ValueChanged<OcptBudgetRevenue>? onRevenueReceiptRequested;

  /// Called with a taking when its own `Edit` action is clicked, or null while [isReadOnly].
  final ValueChanged<OcptBudgetRevenue>? onRevenueEditRequested;

  /// Called with a taking's id when its own `Delete` action is clicked, or null while [isReadOnly].
  final ValueChanged<String>? onRevenueDeletionRequested;

  /// Class constructor
  const OcptBudgetFiche({
    super.key,
    required this.selection,
    required this.postes,
    required this.commitments,
    required this.entries,
    required this.resources,
    required this.revenues,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.isSimplified,
    required this.isReadOnly,
    required this.elementNameByElementId,
    required this.receiptsByEntryId,
    required this.receivedByResourceId,
    required this.receivedByRevenueId,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onPosteEstimateToCompleteDerivedRequested,
    required this.onLineTaxInclusiveChanged,
    required this.onLineVatRateInheritedRequested,
    required this.onLineCommitRequested,
    required this.onLineSettleRequested,
    required this.onLineShowCommitmentRequested,
    required this.onLineUncommitRequested,
    required this.onLineDeletionRequested,
    required this.onCommitmentSettleRequested,
    required this.onCommitmentEditRequested,
    required this.onCommitmentDeletionRequested,
    required this.onEntryEditRequested,
    required this.onEntryDeletionRequested,
    required this.onResourceReceiptRequested,
    required this.onResourceEditRequested,
    required this.onResourceDeletionRequested,
    required this.onRevenueReceiptRequested,
    required this.onRevenueEditRequested,
    required this.onRevenueDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final selection = this.selection;
    if (selection == null) {
      return _emptyState(context);
    }

    return switch (selection) {
      OcptBudgetPosteSelection(:final posteId) => _buildPoste(context, posteId),
      OcptBudgetLineSelection(:final lineId) => _buildLine(context, lineId),
      OcptBudgetCommitmentSelection(:final commitmentId) => _buildCommitment(context, commitmentId),
      OcptBudgetEntrySelection(:final entryId) => _buildEntry(context, entryId),
      OcptBudgetResourceSelection(:final resourceId) => _buildResource(context, resourceId),
      OcptBudgetRevenueSelection(:final revenueId) => _buildRevenue(context, revenueId),
      // M6 wires the resources tree's own receipt sub-rows; nothing dispatches this selection
      // before then, so this reads exactly like an entry's own fiche until it does.
      OcptBudgetReceiptSelection(:final receiptId) => _buildReceipt(context, receiptId),
    };
  }

  /// The plain hint shown while nothing is selected, or the selected object has disappeared from a
  /// freshly loaded snapshot.
  Widget _emptyState(BuildContext context) =>
      OcptWorkspaceEmptyMode(icon: Icons.receipt_long_outlined, message: Tr.of(context).budgetFicheEmptyHint);

  // ---------------------------------------------------------------------------------------------
  // Ancestor lookups — every variant resolves its own subject and, when it has one, its own poste.
  // ---------------------------------------------------------------------------------------------

  /// [postes]' own entry naming [posteId], or null while no live poste carries that id.
  OcptBudgetPoste? _posteById(String posteId) => postes.firstWhereOrNull((poste) => poste.id == posteId);

  /// The poste [lineId]'s own quote line belongs to, or null while no live poste carries it.
  OcptBudgetPoste? _posteOfLine(String lineId) =>
      postes.firstWhereOrNull((poste) => poste.lines.any((line) => line.id == lineId));

  /// [lineId]'s own live quote line, or null.
  OcptBudgetLine? _lineById(String lineId) {
    for (final poste in postes) {
      final line = poste.lines.firstWhereOrNull((line) => line.id == lineId);
      if (line != null) {
        return line;
      }
    }
    return null;
  }

  /// [amountCents] formatted in [currencyCode], or [ocptBudgetEmptyValue] while it is null.
  String _amount(int? amountCents) =>
      amountCents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(amountCents, currencyCode);

  // ---------------------------------------------------------------------------------------------
  // Poste
  // ---------------------------------------------------------------------------------------------

  /// The poste variant: breadcrumb through the document, the quote/committed/paid/estimate to
  /// complete/final cost/final-cost variance figures (M1's own utils), the remaining amount as its
  /// own outstanding, and its editable fields — label, code, simple label, the typed estimate to
  /// complete and its `Derive again` action.
  Widget _buildPoste(BuildContext context, String posteId) {
    final poste = _posteById(posteId);
    if (poste == null) {
      return _emptyState(context);
    }
    final tr = Tr.of(context);

    final quoted = ocptBudgetTotalOf(
      poste.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final paidCents = _paidCentsOf(poste.id);
    final committedCents = _committedCentsOf(poste.id);
    final estimateToCompleteCents = ocptBudgetEstimateToCompleteCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paidCents,
      committedCents: committedCents,
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
    );

    return _OcptBudgetFicheScaffold(
      breadcrumb: [tr.budgetHeaderExpensesSegmentLabel],
      title: ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified),
      amountText: _amount(quoted.amountCents),
      // A poste is an aggregate, not a single debt working through a lifecycle of its own — the
      // three-step chain the line, commitment and entry variants below draw would light every step
      // in hard code the moment a poste exists at all. The poste variant alone draws no stepper —
      // `proportionBar` fills the very same slot instead, `docs/plans/budget-capture-wizard.md`'s "A
      // poste's fiche lies".
      stepLabels: const [],
      reachedCount: 0,
      proportionBar: _OcptBudgetPosteProportionBar(
        quotedAmountCents: quoted.amountCents,
        paidCents: paidCents,
        committedCents: committedCents,
      ),
      figures: [
        (tr.budgetInspectorFigureQuote, _amount(quoted.amountCents)),
        (tr.budgetInspectorFigureCommitted, _amount(committedCents)),
        (tr.budgetInspectorFigurePaid, _amount(paidCents)),
        (tr.budgetInspectorPosteEstimateToCompleteFieldLabel, _amount(estimateToCompleteCents)),
        (tr.budgetCostTrackingColumnFinalCost, _amount(finalCostCents)),
        (tr.budgetCostTrackingColumnVariance, _amount(finalCostVarianceCents)),
      ],
      outstandingLabel: tr.budgetInspectorFigureRemaining,
      outstandingValue: _amount(remainingCents),
      details: _posteEditableFields(context, poste),
      // The poste's own `Add`/`From breakdown` actions are gone: a fresh quote line is now typed
      // through the capture wizard's own `addQuoteLine`/`addQuoteLinesFromBreakdown` gestures,
      // reached from the header's own `+ Nouveau` button.
      primary: null,
      secondaries: const [],
    );
  }

  /// The poste's own editable fields: label, code, simple label and the typed estimate to complete,
  /// with its `Derive again` action.
  Widget _posteEditableFields(BuildContext context, OcptBudgetPoste poste) {
    final tr = Tr.of(context);
    final quoted = ocptBudgetTotalOf(
      poste.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final paidCents = _paidCentsOf(poste.id);
    final committedCents = _committedCentsOf(poste.id);
    final derivedEstimateToCompleteCents = ocptBudgetEstimateToCompleteCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paidCents,
      committedCents: committedCents,
      typedEstimateToCompleteCents: null,
    );
    final currencySymbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inlineField(
          targetId: poste.id,
          field: OcptBudgetField.posteLabel,
          label: tr.budgetInspectorPosteLabelFieldLabel,
          storedValue: poste.label,
        ),
        const SizedBox(height: 8),
        _inlineField(
          targetId: poste.id,
          field: OcptBudgetField.posteCode,
          label: tr.budgetInspectorPosteCodeFieldLabel,
          storedValue: poste.code,
        ),
        const SizedBox(height: 8),
        _inlineField(
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
              child: _OcptBudgetInlineField(
                label: tr.budgetInspectorPosteEstimateToCompleteFieldLabel,
                value: fieldValueOf(
                  poste.id,
                  OcptBudgetField.posteEstimateToComplete,
                  ocptCostTextOf(poste.estimateToCompleteCents),
                ),
                hintText: tr.budgetInspectorPosteEstimateToCompleteHint(
                  ocptBudgetAmountLabel(derivedEstimateToCompleteCents, currencyCode),
                ),
                suffixText: currencySymbol,
                onChanged: onFieldChanged == null
                    ? null
                    : (value) => onFieldChanged?.call(poste.id, OcptBudgetField.posteEstimateToComplete, value),
              ),
            ),
            if (!isReadOnly && onPosteEstimateToCompleteDerivedRequested != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: TextButton(
                  onPressed: () => onPosteEstimateToCompleteDerivedRequested?.call(poste.id),
                  child: Text(tr.budgetInspectorPosteEstimateToCompleteDeriveAction),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Quote line
  // ---------------------------------------------------------------------------------------------

  /// The quote-line variant: breadcrumb poste › line, the quantity × unit price hint (and the
  /// breakdown element it prices, when it prices one), the `Estimé — Engagé — Payé` stepper, and one
  /// of the line's own two mutually exclusive states — `docs/architecture/budget.md`'s "A quote line
  /// can be promoted into a commitment, and the line stays".
  Widget _buildLine(BuildContext context, String lineId) {
    final poste = _posteOfLine(lineId);
    final line = poste == null ? null : _lineById(lineId);
    if (poste == null || line == null) {
      return _emptyState(context);
    }
    final tr = Tr.of(context);

    final lineTotalCents = ocptBudgetLineTotalCents(line);
    final commitment = commitments.firstWhereOrNull((commitment) => commitment.lineId == lineId);
    final isPromoted = commitment != null;
    final isSettled =
        commitment != null &&
        ocptBudgetCommitmentIsSettledOf(commitment, entries, projectVatRateBasisPoints: defaultVatRateBasisPoints);
    final committedCents = commitment == null
        ? null
        : ocptBudgetCommitmentCashCentsOf(commitment, projectVatRateBasisPoints: defaultVatRateBasisPoints);
    // `Payé` only ever reads once this line's own commitment is settled — matching what a single,
    // exact-amount payment already read before commitments could be paid in instalments: a
    // commitment still owed something, even partly paid, states nothing here yet.
    final paidCents = commitment == null || !isSettled
        ? null
        : ocptBudgetCommitmentPaidCentsOf(commitment, entries, projectVatRateBasisPoints: defaultVatRateBasisPoints)
              .amountCents;

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
      outstandingValue = _amount(lineTotalCents);
    } else if (!isSettled) {
      outstandingLabel = tr.budgetCommittedOutstandingLabel;
      outstandingValue = _amount(committedCents);
    } else {
      outstandingLabel = tr.budgetCommittedOutstandingLabel;
      outstandingValue = null;
    }

    _OcptBudgetFicheAction? primary;
    final secondaries = <_OcptBudgetFicheAction>[];
    if (isReadOnly) {
      primary = null;
    } else if (!isPromoted) {
      primary = onLineCommitRequested == null
          ? null
          : _OcptBudgetFicheAction(
              label: tr.budgetLineCommitAction,
              onTap: () => onLineCommitRequested?.call(lineId),
            );
      if (onLineDeletionRequested != null) {
        secondaries.add(
          _OcptBudgetFicheAction(
            label: tr.budgetLineDeleteAction,
            onTap: () => onLineDeletionRequested?.call(lineId),
          ),
        );
      }
    } else if (!isSettled) {
      primary = onLineSettleRequested == null
          ? null
          : _OcptBudgetFicheAction(
              label: tr.budgetFichePayAction(_amount(committedCents)),
              onTap: () => onLineSettleRequested?.call(lineId),
            );
      if (onLineShowCommitmentRequested != null) {
        secondaries.add(
          _OcptBudgetFicheAction(
            label: tr.budgetLineShowCommitmentAction,
            onTap: () => onLineShowCommitmentRequested?.call(lineId),
          ),
        );
      }
      if (onLineUncommitRequested != null) {
        secondaries.add(
          _OcptBudgetFicheAction(
            label: tr.budgetLineUncommitAction,
            onTap: () => onLineUncommitRequested?.call(lineId),
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
          _OcptBudgetFicheAction(
            label: tr.budgetLineDeleteAction,
            onTap: () => onLineDeletionRequested?.call(lineId),
          ),
        );
      }
    }

    return _OcptBudgetFicheScaffold(
      breadcrumb: [
        "${poste.code} ${ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified)}",
        if (line.label.isEmpty) tr.budgetLineUnnamed else line.label,
      ],
      title: line.label.isEmpty ? tr.budgetLineUnnamed : line.label,
      amountText: _amount(lineTotalCents),
      hint: hintLines.join("\n"),
      stepLabels: [
        tr.budgetFicheStepEstimatedLabel,
        tr.budgetInspectorFigureCommitted,
        tr.budgetInspectorFigurePaid,
      ],
      reachedCount: isSettled ? 3 : (isPromoted ? 2 : 1),
      figures: [
        (tr.budgetFicheStepEstimatedLabel, _amount(lineTotalCents)),
        (tr.budgetInspectorFigureCommitted, _amount(committedCents)),
        (tr.budgetInspectorFigurePaid, _amount(paidCents)),
      ],
      outstandingLabel: outstandingLabel,
      outstandingValue: outstandingValue,
      details: _lineEditableFields(context, line),
      primary: primary,
      secondaries: secondaries,
    );
  }

  /// The quote line's own editable fields: label, quantity, unit, unit price (with the
  /// including/excluding-tax choice) and VAT (with its `Inherit` action) and notes.
  Widget _lineEditableFields(BuildContext context, OcptBudgetLine line) {
    final tr = Tr.of(context);
    final currencySymbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
    final effectiveRate = ocptEffectiveVatRateOf(
      lineVatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final onFieldChanged = this.onFieldChanged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inlineField(
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
              child: _inlineField(
                targetId: line.id,
                field: OcptBudgetField.lineQuantity,
                label: tr.budgetLineQuantityFieldLabel,
                storedValue: ocptBudgetQuantityLabel(line.quantityMilli),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _inlineField(
                targetId: line.id,
                field: OcptBudgetField.lineUnit,
                label: tr.budgetLineUnitFieldLabel,
                storedValue: line.unit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _OcptBudgetInlineField(
          label: tr.budgetLineUnitPriceFieldLabel,
          value: fieldValueOf(line.id, OcptBudgetField.lineUnitAmount, ocptCostTextOf(line.unitPrice.amountCents)),
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
              child: _OcptBudgetInlineField(
                label: tr.budgetLineVatRateFieldLabel,
                value: fieldValueOf(
                  line.id,
                  OcptBudgetField.lineVatRateOverride,
                  ocptVatRatePercentTextOf(line.unitPrice.vatRateBasisPoints),
                ),
                hintText: effectiveRate.basisPoints == null
                    ? null
                    : tr.budgetLineVatRateInheritedHint(ocptVatRatePercentTextOf(effectiveRate.basisPoints)),
                suffixText: tr.budgetLineVatRateSuffix,
                onChanged: onFieldChanged == null
                    ? null
                    : (value) => onFieldChanged.call(line.id, OcptBudgetField.lineVatRateOverride, value),
              ),
            ),
            if (!isReadOnly && onLineVatRateInheritedRequested != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: TextButton(
                  onPressed: () => onLineVatRateInheritedRequested?.call(line.id),
                  child: Text(tr.budgetLineVatRateInheritAction),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _inlineField(
          targetId: line.id,
          field: OcptBudgetField.lineNotes,
          label: tr.budgetLineNotesFieldLabel,
          storedValue: line.notes,
          multiline: true,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Commitment
  // ---------------------------------------------------------------------------------------------

  /// The commitment variant: breadcrumb poste › line (when promoted from one) › `Commitment`, the
  /// status/due-date hint, the `Estimé — Engagé — Payé` stepper, and `Pay`/`Edit`/`Delete`.
  Widget _buildCommitment(BuildContext context, String commitmentId) {
    final commitment = commitments.firstWhereOrNull((commitment) => commitment.id == commitmentId);
    if (commitment == null) {
      return _emptyState(context);
    }
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();

    final poste = _posteById(commitment.posteId);
    final line = commitment.lineId == null ? null : _lineById(commitment.lineId!);
    final cashCents = ocptBudgetCommitmentCashCentsOf(
      commitment,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final isSettled = ocptBudgetCommitmentIsSettledOf(
      commitment,
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    // Mirrors `_buildLine`'s own reading: `Payé` only ever states a figure once this commitment is
    // settled, matching what a single, exact-amount payment already read before a commitment could
    // be paid in instalments.
    final paidCents = isSettled
        ? ocptBudgetCommitmentPaidCentsOf(commitment, entries, projectVatRateBasisPoints: defaultVatRateBasisPoints)
              .amountCents
        : null;
    final quotedLineCents = line == null ? null : ocptBudgetLineTotalCents(line);

    final title = commitment.label.isEmpty ? tr.budgetPosteUnnamed : commitment.label;
    final dueDateText = commitment.dueDate == null
        ? tr.budgetCommittedNoDueDateLabel
        : DateFormat.yMMMd(locale).format(commitment.dueDate!);

    return _OcptBudgetFicheScaffold(
      breadcrumb: [
        if (poste != null) "${poste.code} ${ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified)}",
        if (line != null) (line.label.isEmpty ? tr.budgetLineUnnamed : line.label),
        tr.budgetFicheKindCommitmentLabel,
      ],
      title: title,
      amountText: _amount(cashCents),
      hint: tr.budgetFicheCommitmentHint(ocptBudgetCommitmentStatusLabel(tr, commitment.status), dueDateText),
      stepLabels: [
        tr.budgetFicheStepEstimatedLabel,
        tr.budgetInspectorFigureCommitted,
        tr.budgetInspectorFigurePaid,
      ],
      reachedCount: isSettled ? 3 : 2,
      figures: [
        (tr.budgetFicheStepEstimatedLabel, _amount(quotedLineCents)),
        (tr.budgetInspectorFigureCommitted, _amount(cashCents)),
        (tr.budgetInspectorFigurePaid, _amount(paidCents)),
      ],
      // `cashCents`, not the commitment's own outstanding figure, here and in the `Pay` action
      // below: this fiche still offers the commitment's own total, unchanged from before — only
      // [isSettled] itself is now derived from the ledger rather than read off a stored link.
      outstandingLabel: tr.budgetCommittedOutstandingLabel,
      outstandingValue: isSettled ? null : _amount(cashCents),
      primary: isReadOnly || isSettled || onCommitmentSettleRequested == null
          ? null
          : _OcptBudgetFicheAction(
              label: tr.budgetFichePayAction(_amount(cashCents)),
              onTap: () => onCommitmentSettleRequested?.call(commitment),
            ),
      secondaries: [
        if (!isReadOnly && onCommitmentEditRequested != null)
          _OcptBudgetFicheAction(
            label: tr.budgetFinancingEditAction,
            onTap: () => onCommitmentEditRequested?.call(commitment),
          ),
        if (!isReadOnly && onCommitmentDeletionRequested != null)
          _OcptBudgetFicheAction(
            label: tr.budgetCommittedDeleteAction,
            onTap: () => onCommitmentDeletionRequested?.call(commitment.id),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Entry
  // ---------------------------------------------------------------------------------------------

  /// The entry variant: breadcrumb through its own poste (when it names one), the date/voucher hint
  /// and its own receipt marker, the stepper with `Payé` reached, and `Edit`/`Delete`.
  Widget _buildEntry(BuildContext context, String entryId) {
    final entry = entries.firstWhereOrNull((entry) => entry.id == entryId);
    if (entry == null) {
      return _emptyState(context);
    }
    return _entryFiche(context, entry);
  }

  /// Shared by [_buildEntry] and [_buildReceipt]: the entry's own fiche, [stepLabelsOverride] and
  /// [reachedCountOverride] the only things that differ between the two readings of the very same
  /// row.
  Widget _entryFiche(
    BuildContext context,
    OcptBudgetEntry entry, {
    List<String>? stepLabelsOverride,
    int? reachedCountOverride,
    List<String>? breadcrumbOverride,
  }) {
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();
    final poste = entry.posteId == null ? null : _posteById(entry.posteId!);
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

    return _OcptBudgetFicheScaffold(
      breadcrumb:
          breadcrumbOverride ??
          [
            if (poste != null) "${poste.code} ${ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified)}",
            tr.budgetFicheKindEntryLabel,
          ],
      title: title,
      amountText: _amount(amountCents),
      hint: hintLines.join("\n"),
      stepLabels: stepLabelsOverride ?? [tr.budgetFicheStepEstimatedLabel, tr.budgetInspectorFigureCommitted, tr.budgetInspectorFigurePaid],
      reachedCount: reachedCountOverride ?? 3,
      figures: [
        (
          isDebit ? tr.budgetCashJournalColumnDebit : tr.budgetCashJournalColumnCredit,
          _amount(amountCents),
        ),
        (
          tr.budgetLineTaxInclusiveOption,
          entry.isTaxInclusive ? tr.budgetLineTaxInclusiveOption : tr.budgetLineTaxExclusiveOption,
        ),
        (tr.budgetLineVatRateFieldLabel, ocptVatRatePercentTextOf(effectiveRate.basisPoints)),
      ],
      primary: isReadOnly || onEntryEditRequested == null
          ? null
          : _OcptBudgetFicheAction(
              label: tr.budgetFinancingEditAction,
              onTap: () => onEntryEditRequested?.call(entry),
            ),
      secondaries: [
        if (!isReadOnly && onEntryDeletionRequested != null)
          _OcptBudgetFicheAction(
            label: tr.budgetEntryDeleteAction,
            onTap: () => onEntryDeletionRequested?.call(entry.id),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Resource
  // ---------------------------------------------------------------------------------------------

  /// The resource variant: breadcrumb through the resources document and its own group, the
  /// `Dossier` status badge, the `Promis — Rentré` stepper, `Promised`/`Received` figures and
  /// `Receive`/`Edit`/`Delete` — `docs/architecture/budget.md`'s "An in-kind contribution is valued,
  /// not collected": a valued in-kind resource no entry names yet reads the em dash for both
  /// `Received` and `Outstanding`.
  Widget _buildResource(BuildContext context, String resourceId) {
    final resource = resources.firstWhereOrNull((resource) => resource.id == resourceId);
    if (resource == null) {
      return _emptyState(context);
    }
    final tr = Tr.of(context);

    final received = receivedByResourceId[resource.id];
    final hasEntry = received != null;
    final receivedCents = received?.amountCents ?? 0;
    final isInKind = resource.groupKind == OcptBudgetResourceGroupKind.inKind;
    final readsAsUncollected = isInKind && !hasEntry;
    final outstandingCents = ocptBudgetResourceOutstandingCents(
      amountCents: resource.amountCents,
      receivedCents: receivedCents,
    );
    final canReceive =
        !isReadOnly && !isInKind && outstandingCents > 0 && onResourceReceiptRequested != null;

    return _OcptBudgetFicheScaffold(
      breadcrumb: [
        tr.budgetHeaderResourcesSegmentLabel,
        ocptBudgetResourceGroupKindLabel(tr, resource.groupKind),
      ],
      title: resource.label.isEmpty ? tr.budgetPosteUnnamed : resource.label,
      amountText: _amount(resource.amountCents),
      hint: resource.notes.isEmpty ? null : resource.notes,
      badge: ocptBudgetResourceStatusLabel(tr, resource.groupKind, resource.status),
      badgeColor: ocptBudgetResourceStatusAccentColor(Theme.of(context).colorScheme, resource.status),
      stepLabels: [tr.budgetFicheStepPromisedLabel, tr.budgetFinancingColumnReceived],
      reachedCount: hasEntry && receivedCents > 0 ? 2 : 1,
      figures: [
        (tr.budgetFicheStepPromisedLabel, _amount(resource.amountCents)),
        (tr.budgetFinancingColumnReceived, readsAsUncollected ? null : _amount(receivedCents)),
      ],
      outstandingLabel: tr.budgetFinancingColumnOutstanding,
      outstandingValue: readsAsUncollected ? null : _amount(outstandingCents),
      primary: canReceive
          ? _OcptBudgetFicheAction(
              label: tr.budgetFicheReceiveAction(_amount(outstandingCents < 0 ? 0 : outstandingCents)),
              onTap: () => onResourceReceiptRequested?.call(resource),
            )
          : null,
      secondaries: [
        if (!isReadOnly && onResourceEditRequested != null)
          _OcptBudgetFicheAction(
            label: tr.budgetFinancingEditAction,
            onTap: () => onResourceEditRequested?.call(resource),
          ),
        if (!isReadOnly && onResourceDeletionRequested != null)
          _OcptBudgetFicheAction(
            label: tr.budgetCommittedDeleteAction,
            onTap: () => onResourceDeletionRequested?.call(resource.id),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Revenue (taking)
  // ---------------------------------------------------------------------------------------------

  /// The taking variant — mirrors [_buildResource] with no `Dossier` group and no in-kind reading.
  Widget _buildRevenue(BuildContext context, String revenueId) {
    final revenue = revenues.firstWhereOrNull((revenue) => revenue.id == revenueId);
    if (revenue == null) {
      return _emptyState(context);
    }
    final tr = Tr.of(context);

    final received = receivedByRevenueId[revenue.id];
    final hasEntry = received != null;
    final receivedCents = received?.amountCents ?? 0;
    final outstandingCents = ocptBudgetResourceOutstandingCents(
      amountCents: revenue.amountCents,
      receivedCents: receivedCents,
    );
    final canReceive = !isReadOnly && outstandingCents > 0 && onRevenueReceiptRequested != null;

    return _OcptBudgetFicheScaffold(
      breadcrumb: [
        tr.budgetHeaderResourcesSegmentLabel,
        ocptBudgetResourceFamilyLabel(tr, OcptBudgetResourceFamily.takings),
      ],
      title: revenue.label.isEmpty ? tr.budgetPosteUnnamed : revenue.label,
      amountText: _amount(revenue.amountCents),
      hint: revenue.notes.isEmpty ? null : revenue.notes,
      badge: ocptBudgetRevenueStatusLabel(tr, revenue.status),
      badgeColor: ocptBudgetRevenueStatusAccentColor(Theme.of(context).colorScheme, revenue.status),
      stepLabels: [tr.budgetFicheStepPromisedLabel, tr.budgetFinancingColumnReceived],
      reachedCount: hasEntry && receivedCents > 0 ? 2 : 1,
      figures: [
        (tr.budgetFicheStepPromisedLabel, _amount(revenue.amountCents)),
        (tr.budgetFinancingColumnReceived, _amount(receivedCents)),
      ],
      outstandingLabel: tr.budgetFinancingColumnOutstanding,
      outstandingValue: _amount(outstandingCents),
      primary: canReceive
          ? _OcptBudgetFicheAction(
              label: tr.budgetFicheReceiveAction(_amount(outstandingCents < 0 ? 0 : outstandingCents)),
              onTap: () => onRevenueReceiptRequested?.call(revenue),
            )
          : null,
      secondaries: [
        if (!isReadOnly && onRevenueEditRequested != null)
          _OcptBudgetFicheAction(
            label: tr.budgetFinancingEditAction,
            onTap: () => onRevenueEditRequested?.call(revenue),
          ),
        if (!isReadOnly && onRevenueDeletionRequested != null)
          _OcptBudgetFicheAction(
            label: tr.budgetCommittedDeleteAction,
            onTap: () => onRevenueDeletionRequested?.call(revenue.id),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Receipt (M6 wires the selection itself; this reads the entry it names today)
  // ---------------------------------------------------------------------------------------------

  /// The receipt variant: the entry it names, read with a `Promis — Rentré` stepper and a
  /// breadcrumb through the resource or the taking it settles — nothing dispatches
  /// [OcptBudgetReceiptSelection] before M6 wires the resources tree's own receipt sub-rows, so this
  /// is answered rather than left to throw.
  Widget _buildReceipt(BuildContext context, String receiptId) {
    final entry = entries.firstWhereOrNull((entry) => entry.id == receiptId);
    if (entry == null) {
      return _emptyState(context);
    }
    final tr = Tr.of(context);
    final resource = entry.resourceId == null
        ? null
        : resources.firstWhereOrNull((resource) => resource.id == entry.resourceId);
    final revenue = entry.revenueId == null
        ? null
        : revenues.firstWhereOrNull((revenue) => revenue.id == entry.revenueId);
    final ancestorLabel = resource?.label ?? revenue?.label;

    return _entryFiche(
      context,
      entry,
      stepLabelsOverride: [tr.budgetFicheStepPromisedLabel, tr.budgetFinancingColumnReceived],
      reachedCountOverride: 2,
      breadcrumbOverride: [
        if (ancestorLabel != null && ancestorLabel.isNotEmpty) ancestorLabel,
        tr.budgetFicheKindEntryLabel,
      ],
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------------------------

  /// `posteId`'s own paid total, in cents, tax-inclusive — 0 while nothing is entered against it,
  /// read off [entries] directly since the fiche resolves its own poste rather than being handed
  /// one pre-resolved.
  int _paidCentsOf(String posteId) => ocptBudgetPaidCentsByPosteId(
    entries,
    projectVatRateBasisPoints: defaultVatRateBasisPoints,
  )[posteId]?.amountCents ?? 0;

  /// `posteId`'s own committed total, in cents, tax-inclusive — mirrors [_paidCentsOf].
  int _committedCentsOf(String posteId) => ocptBudgetCommittedCentsByPosteId(
    commitments,
    entries: entries,
    projectVatRateBasisPoints: defaultVatRateBasisPoints,
  )[posteId]?.amountCents ?? 0;

  /// One editable text field bound to [fieldValueOf]/[onFieldChanged].
  Widget _inlineField({
    required String targetId,
    required OcptBudgetField field,
    required String label,
    required String storedValue,
    String? hintText,
    bool multiline = false,
  }) {
    final onFieldChanged = this.onFieldChanged;
    return _OcptBudgetInlineField(
      label: label,
      value: fieldValueOf(targetId, field, storedValue),
      hintText: hintText,
      multiline: multiline,
      onChanged: onFieldChanged == null ? null : (value) => onFieldChanged(targetId, field, value),
    );
  }
}

/// The shared layout every variant of [OcptBudgetFiche] draws: breadcrumb, title and amount, an
/// optional hint (with an optional status badge beside it), an optional stepper, the figures row,
/// an optional outstanding block, an optional details section (the poste's or the line's own
/// editable fields), one primary action and up to two secondary ones.
class _OcptBudgetFicheScaffold extends StatelessWidget {
  /// The breadcrumb segments, from the outermost ancestor to the object itself.
  final List<String> breadcrumb;

  /// The object's own name.
  final String title;

  /// The object's own amount, already formatted (or [ocptBudgetEmptyValue]).
  final String amountText;

  /// A short hint under the title, or null.
  final String? hint;

  /// A status badge's own text, drawn beside [hint], or null — the resource/revenue `Dossier` fact.
  final String? badge;

  /// [badge]'s own accent colour.
  final Color? badgeColor;

  /// The stepper's own step labels — two or three words, or empty while this variant draws none
  /// (the poste variant, which draws [proportionBar] in this very slot instead).
  final List<String> stepLabels;

  /// How many of [stepLabels] are reached.
  final int reachedCount;

  /// The poste variant's own proportion bar, drawn in the very slot [stepLabels] would otherwise
  /// fill — null for every other variant, which keeps its stepper
  /// (`docs/plans/budget-capture-wizard.md`'s "The other corrections"). Never both at once: a poste
  /// carries no [stepLabels], and every other variant carries no [proportionBar].
  final Widget? proportionBar;

  /// The figures that make the amount up: a label paired with an already-formatted value, or null
  /// for [ocptBudgetEmptyValue].
  final List<(String label, String? value)> figures;

  /// The outstanding block's own label, or null while this variant draws none.
  final String? outstandingLabel;

  /// The outstanding block's own value, already formatted, or null for [ocptBudgetEmptyValue] —
  /// drawn only while [outstandingLabel] is not null.
  final String? outstandingValue;

  /// The poste's or the line's own editable fields, or null while this variant carries none.
  final Widget? details;

  /// The one primary action, or null while withheld or none applies.
  final _OcptBudgetFicheAction? primary;

  /// Up to two secondary actions.
  final List<_OcptBudgetFicheAction> secondaries;

  /// Class constructor
  const _OcptBudgetFicheScaffold({
    required this.breadcrumb,
    required this.title,
    required this.amountText,
    this.hint,
    this.badge,
    this.badgeColor,
    required this.stepLabels,
    required this.reachedCount,
    this.proportionBar,
    required this.figures,
    this.outstandingLabel,
    this.outstandingValue,
    this.details,
    required this.primary,
    required this.secondaries,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = this.details;
    final hint = this.hint;
    final badge = this.badge;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OcptBudgetFicheBreadcrumb(segments: breadcrumb),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amountText,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (hint != null || badge != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (hint != null)
                  Expanded(
                    child: Text(
                      hint,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (badge != null) ...[
                  if (hint != null) const SizedBox(width: 8),
                  _OcptBudgetFicheBadge(text: badge, color: badgeColor ?? theme.colorScheme.primary),
                ],
              ],
            ),
          ],
          if (details != null) ...[
            const SizedBox(height: 16),
            details,
          ],
          if (stepLabels.isNotEmpty || proportionBar != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    proportionBar ??
                        _OcptBudgetFicheStepper(stepLabels: stepLabels, reachedCount: reachedCount),
                    const SizedBox(height: 12),
                    _OcptBudgetFicheFiguresRow(figures: figures),
                  ],
                ),
              ),
            ),
          ] else if (figures.isNotEmpty) ...[
            const SizedBox(height: 16),
            _OcptBudgetFicheFiguresRow(figures: figures),
          ],
          if (outstandingLabel != null) ...[
            const SizedBox(height: 16),
            _OcptBudgetFicheOutstanding(
              label: outstandingLabel!,
              value: outstandingValue ?? ocptBudgetEmptyValue,
            ),
          ],
          if (primary != null || secondaries.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (primary != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: primary!.onTap, child: Text(primary!.label)),
              ),
            if (secondaries.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var index = 0; index < secondaries.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: secondaries[index].onTap,
                        child: Text(secondaries[index].label),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The fiche's own breadcrumb: `segments`, chevron-separated, muted — the way back up to the
/// document this object lives in.
class _OcptBudgetFicheBreadcrumb extends StatelessWidget {
  /// The breadcrumb's own segments, from the outermost ancestor to the object itself.
  final List<String> segments;

  /// Class constructor
  const _OcptBudgetFicheBreadcrumb({required this.segments});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < segments.length; index++) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 14, color: theme.colorScheme.onSurfaceVariant),
            ),
          Text(segments[index], maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ],
      ],
    );
  }
}

/// A small status badge — the resource/revenue `Dossier` fact, held apart from the money.
class _OcptBudgetFicheBadge extends StatelessWidget {
  /// The badge's own text.
  final String text;

  /// The badge's own accent colour.
  final Color color;

  /// Class constructor
  const _OcptBudgetFicheBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
    ),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

/// The small stepper of an object's own states: a dot per step, filled and connected up to
/// `reachedCount`, hollow past it, its own label under each dot — the current (last reached) one
/// bold.
class _OcptBudgetFicheStepper extends StatelessWidget {
  /// The stepper's own step labels, two or three words.
  final List<String> stepLabels;

  /// How many of [stepLabels] are reached, from the first.
  final int reachedCount;

  /// Class constructor
  const _OcptBudgetFicheStepper({required this.stepLabels, required this.reachedCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var index = 0; index < stepLabels.length; index++) ...[
              if (index > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: index <= reachedCount - 1 ? colors.primary : colors.outlineVariant,
                  ),
                ),
              Icon(
                index < reachedCount ? Icons.circle : Icons.circle_outlined,
                size: 12,
                color: index < reachedCount ? colors.primary : colors.outlineVariant,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var index = 0; index < stepLabels.length; index++)
              Expanded(
                child: Text(
                  stepLabels[index],
                  textAlign: index == 0
                      ? TextAlign.start
                      : (index == stepLabels.length - 1 ? TextAlign.end : TextAlign.center),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: index < reachedCount ? colors.onSurface : colors.onSurfaceVariant,
                    fontWeight: index == reachedCount - 1 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The poste variant's own proportion bar, drawn in [_OcptBudgetFicheStepper]'s own slot: the paid
/// amount, then the committed one, over a track of [_ocptBudgetPosteProportionBarWidth] — fixed
/// rather than [Expanded], so two postes stay comparable when the bar later appears in a list
/// (`docs/plans/budget-capture-wizard.md`'s "The other corrections").
///
/// **The track's own scale is the quote, until paid-plus-committed overruns it** — the moment it
/// does, the scale becomes that overrun total instead, so the whole bar still fits its own fixed
/// width, and the overrun's own length eats the end of the bar in [ColorScheme.error]. A tick marks
/// where the quote itself falls on that stretched scale — drawn only while there is an overrun to
/// place it against, since without one the quote sits exactly at the bar's own right edge, where a
/// tick would say nothing a reader could not already see.
class _OcptBudgetPosteProportionBar extends StatelessWidget {
  /// The poste's own quoted total, in cents — the track's own scale while nothing overruns it.
  final int quotedAmountCents;

  /// The poste's own paid total, in cents — the bar's own first segment.
  final int paidCents;

  /// The poste's own committed total, in cents — the bar's own second segment, drawn right after
  /// [paidCents].
  final int committedCents;

  /// Class constructor
  const _OcptBudgetPosteProportionBar({
    required this.quotedAmountCents,
    required this.paidCents,
    required this.committedCents,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(_ocptBudgetPosteProportionBarHeight / 2);
    // Never negative: a poste's own quote, paid and committed totals are all sums of non-negative
    // amounts (`docs/architecture/budget.md`'s "The money rule").
    final quoteCents = quotedAmountCents < 0 ? 0 : quotedAmountCents;
    final totalCents = paidCents + committedCents;
    final overrunCents = totalCents > quoteCents ? totalCents - quoteCents : 0;
    final scaleCents = overrunCents > 0 ? totalCents : quoteCents;

    final track = Container(
      width: _ocptBudgetPosteProportionBarWidth,
      height: _ocptBudgetPosteProportionBarHeight,
      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: radius),
    );

    if (scaleCents <= 0) {
      // Nothing quoted and nothing moved: the empty track alone, no segment and no tick to draw.
      return track;
    }

    double lengthOf(int cents) => _ocptBudgetPosteProportionBarWidth * cents / scaleCents;

    // The within-budget share of each segment — what still fits inside the quote once the other
    // has already claimed its own share of it — is what stays in the accent colour; whatever is
    // left over, [overrunCents], is what eats the end of the track in red.
    final withinBudgetPaidCents = paidCents < quoteCents ? paidCents : quoteCents;
    final remainingBudgetCents = quoteCents - withinBudgetPaidCents;
    final withinBudgetCommittedCents = committedCents < remainingBudgetCents
        ? committedCents
        : remainingBudgetCents;
    final tickPosition = lengthOf(quoteCents);

    return SizedBox(
      width: _ocptBudgetPosteProportionBarWidth,
      height: _ocptBudgetPosteProportionBarHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          track,
          ClipRRect(
            borderRadius: radius,
            child: Row(
              children: [
                Container(width: lengthOf(withinBudgetPaidCents), color: colors.primary),
                Container(
                  width: lengthOf(withinBudgetCommittedCents),
                  color: colors.primary.withValues(alpha: 0.45),
                ),
                if (overrunCents > 0) Container(width: lengthOf(overrunCents), color: colors.error),
              ],
            ),
          ),
          if (overrunCents > 0)
            Positioned(
              left: tickPosition - 1,
              top: -2,
              bottom: -2,
              child: Container(width: 2, color: colors.onSurface),
            ),
        ],
      ),
    );
  }
}

/// The figures that make the amount up: a `Wrap` of muted-label-over-value pairs, mirroring
/// `OcptBudgetCostTracking`'s own figure reading.
class _OcptBudgetFicheFiguresRow extends StatelessWidget {
  /// The figures to draw: a label paired with an already-formatted value, or null for
  /// [ocptBudgetEmptyValue].
  final List<(String label, String? value)> figures;

  /// Class constructor
  const _OcptBudgetFicheFiguresRow({required this.figures});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 20,
      runSpacing: 10,
      children: [
        for (final figure in figures)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                figure.$1.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              Text(figure.$2 ?? ocptBudgetEmptyValue, style: theme.textTheme.bodyMedium),
            ],
          ),
      ],
    );
  }
}

/// The outstanding amount, in large type — what the fiche's whole grammar builds up to.
class _OcptBudgetFicheOutstanding extends StatelessWidget {
  /// The block's own label.
  final String label;

  /// The block's own value, already formatted.
  final String value;

  /// Class constructor
  const _OcptBudgetFicheOutstanding({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// One editable field, mirroring `OcptResourcesSheetField`'s own controller idiom without depending
/// on that mode's widget — unchanged from `OcptBudgetPosteInspector`'s own private field widget.
class _OcptBudgetInlineField extends StatefulWidget {
  /// The field's label.
  final String label;

  /// The field's current authoritative value.
  final String value;

  /// The greyed placeholder shown while the field is empty, or null.
  final String? hintText;

  /// Chrome shown after the typed text, or null.
  final String? suffixText;

  /// Whether this field is written as several lines.
  final bool multiline;

  /// Called with the field's raw text on every keystroke, or null while it may not be written to.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const _OcptBudgetInlineField({
    required this.label,
    required this.value,
    this.hintText,
    this.suffixText,
    this.multiline = false,
    required this.onChanged,
  });

  @override
  State<_OcptBudgetInlineField> createState() => _OcptBudgetInlineFieldState();
}

/// The state of [_OcptBudgetInlineField]: owns the controller, kept in sync with the widget's own
/// authoritative value exactly as `OcptResourcesSheetField` keeps its own.
class _OcptBudgetInlineFieldState extends State<_OcptBudgetInlineField> {
  /// The field's own text editing controller.
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _OcptBudgetInlineField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          readOnly: widget.onChanged == null,
          onChanged: widget.onChanged,
          maxLines: widget.multiline ? null : 1,
          minLines: widget.multiline ? 3 : 1,
          style: theme.textTheme.bodySmall,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            suffixText: widget.suffixText,
          ),
        ),
      ],
    );
  }
}
