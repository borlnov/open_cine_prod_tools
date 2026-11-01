// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_match_suggestion.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_label_above.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_lettrage_strip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_asset_file_line.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';

/// Step 3 of the seven `cashMovement` gestures: the date, amount and tax basis, the wording, the
/// lettrage strip when a candidate exists, the VAT rate, the receipt and — for the free-form
/// movement alone — the direction.
///
/// Every controller belongs to the wizard's own state, which keeps them alive across steps; this
/// widget only draws them.
class OcptBudgetNewMovementForm extends StatelessWidget {
  /// The form the step validates against.
  final GlobalKey<FormState> formKey;

  /// The gesture in effect.
  final OcptBudgetGesture? gesture;

  /// The wording field's controller.
  final TextEditingController labelController;

  /// The amount field's controller.
  final TextEditingController amountController;

  /// The VAT rate field's controller.
  final TextEditingController vatRateController;

  /// The movement's date.
  final DateTime date;

  /// Whether the amount is tax inclusive.
  final bool isTaxInclusive;

  /// Whether the movement is a debit (money going out).
  final bool isDebit;

  /// The ranked lettrage candidates; the strip is drawn only while there is at least one.
  final List<OcptBudgetMatchSuggestion> suggestions;

  /// Which lettrage candidate is picked, by index into [suggestions], or null for `Aucun`.
  final int? selectedSuggestionIndex;

  /// Every live commitment, read by the lettrage strip.
  final List<OcptBudgetCommitment> commitments;

  /// Every live poste of the project, read by the lettrage strip.
  final List<OcptBudgetPoste> postes;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// Whether the mode's header currently reads simplified.
  final bool isSimplified;

  /// The receipt picked for the movement, or null.
  final String? pickedReceiptPath;

  /// Called when the wording or the amount changes, so the lettrage candidates are ranked again.
  final VoidCallback onDraftTextChanged;

  /// Called with the date picked.
  final ValueChanged<DateTime?> onDateChanged;

  /// Called with the tax basis picked.
  final ValueChanged<bool> onTaxInclusiveChanged;

  /// Called with the direction picked.
  final ValueChanged<bool> onDirectionChanged;

  /// Called with the lettrage candidate picked, or null for `Aucun`.
  final ValueChanged<int?> onSuggestionSelected;

  /// Called when the picked receipt is removed.
  final VoidCallback onReceiptRemoved;

  /// Called when the receipt picker is requested.
  final VoidCallback onReceiptPickRequested;

  /// Class constructor
  const OcptBudgetNewMovementForm({
    super.key,
    required this.formKey,
    required this.gesture,
    required this.labelController,
    required this.amountController,
    required this.vatRateController,
    required this.date,
    required this.isTaxInclusive,
    required this.isDebit,
    required this.suggestions,
    required this.selectedSuggestionIndex,
    required this.commitments,
    required this.postes,
    required this.currencyCode,
    required this.defaultVatRateBasisPoints,
    required this.isSimplified,
    required this.pickedReceiptPath,
    required this.onDraftTextChanged,
    required this.onDateChanged,
    required this.onTaxInclusiveChanged,
    required this.onDirectionChanged,
    required this.onSuggestionSelected,
    required this.onReceiptRemoved,
    required this.onReceiptPickRequested,
  });

  /// Build the budget new movement form as a [Form].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final currencySymbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OcptBudgetNewDateAmountBasisRow(
            currencySymbol: currencySymbol,
            amountController: amountController,
            date: date,
            isTaxInclusive: isTaxInclusive,
            onDraftTextChanged: onDraftTextChanged,
            onDateChanged: onDateChanged,
            onTaxInclusiveChanged: onTaxInclusiveChanged,
          ),
          const SizedBox(height: 12),
          OcptBudgetNewLabelAbove(
            label: tr.budgetEntryDialogLabelFieldLabel,
            child: TextFormField(
              key: const Key("ocptBudgetNewLabelField"),
              controller: labelController,
              autofocus: true,
              decoration: const InputDecoration(isDense: true),
              validator: (value) =>
                  (value ?? "").trim().isEmpty ? tr.budgetEntryDialogLabelRequiredError : null,
              onChanged: (_) => onDraftTextChanged(),
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            OcptBudgetNewLettrageStrip(
              suggestions: suggestions,
              selectedIndex: selectedSuggestionIndex,
              commitments: commitments,
              postes: postes,
              currencyCode: currencyCode,
              onSelected: onSuggestionSelected,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OcptBudgetNewVatField(
                  controller: vatRateController,
                  defaultVatRateBasisPoints: defaultVatRateBasisPoints,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OcptBudgetNewReceiptField(
                  pickedReceiptPath: pickedReceiptPath,
                  onRemoved: onReceiptRemoved,
                  onPickRequested: onReceiptPickRequested,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tr.budgetEntryDialogVoucherAutoHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (gesture == OcptBudgetGesture.recordOtherMovement) ...[
            const SizedBox(height: 12),
            _OcptBudgetNewDirectionField(
              isDebit: isDebit,
              isSimplified: isSimplified,
              onChanged: onDirectionChanged,
            ),
          ],
        ],
      ),
    );
  }
}

/// The first row of the movement form: the date, the amount and the tax basis.
class _OcptBudgetNewDateAmountBasisRow extends StatelessWidget {
  /// The symbol of the project's currency, shown as the amount's suffix.
  final String currencySymbol;

  /// The amount field's controller.
  final TextEditingController amountController;

  /// The movement's date.
  final DateTime date;

  /// Whether the amount is tax inclusive.
  final bool isTaxInclusive;

  /// Called when the amount changes.
  final VoidCallback onDraftTextChanged;

  /// Called with the date picked.
  final ValueChanged<DateTime?> onDateChanged;

  /// Called with the tax basis picked.
  final ValueChanged<bool> onTaxInclusiveChanged;

  /// Class constructor
  const _OcptBudgetNewDateAmountBasisRow({
    required this.currencySymbol,
    required this.amountController,
    required this.date,
    required this.isTaxInclusive,
    required this.onDraftTextChanged,
    required this.onDateChanged,
    required this.onTaxInclusiveChanged,
  });

  /// Build the budget new date amount basis row as a [Row].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: OcptPersonSheetDateField(
            label: tr.budgetEntryDialogDateFieldLabel,
            value: date,
            onChanged: onDateChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OcptBudgetNewLabelAbove(
            label: tr.budgetEntryDialogAmountFieldLabel,
            child: TextFormField(
              key: const Key("ocptBudgetNewAmountField"),
              controller: amountController,
              decoration: InputDecoration(isDense: true, suffixText: currencySymbol),
              validator: (value) => ocptCostCentsOf(value ?? "") == null
                  ? tr.budgetEntryDialogAmountInvalidError
                  : null,
              onChanged: (_) => onDraftTextChanged(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IntrinsicWidth(
          child: OcptBudgetNewLabelAbove(
            label: tr.budgetEntryDialogTaxBasisFieldLabel,
            child: OcptBudgetBinaryChoice(
              value: isTaxInclusive,
              trueLabel: tr.budgetLineTaxInclusiveOption,
              falseLabel: tr.budgetLineTaxExclusiveOption,
              onChanged: onTaxInclusiveChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// The free-form movement's direction field: paid or received, debit or credit.
class _OcptBudgetNewDirectionField extends StatelessWidget {
  /// Whether the movement is a debit (money going out).
  final bool isDebit;

  /// Whether the mode's header currently reads simplified.
  final bool isSimplified;

  /// Called with the direction picked.
  final ValueChanged<bool> onChanged;

  /// Class constructor
  const _OcptBudgetNewDirectionField({
    required this.isDebit,
    required this.isSimplified,
    required this.onChanged,
  });

  /// Build the budget new direction field as an [OcptBudgetNewLabelAbove].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptBudgetNewLabelAbove(
      label: tr.budgetEntryDialogDirectionFieldLabel,
      child: OcptBudgetBinaryChoice(
        value: isDebit,
        trueLabel: isSimplified ? tr.budgetEntryDialogPaidOption : tr.budgetEntryDialogDebitOption,
        falseLabel: isSimplified
            ? tr.budgetEntryDialogReceivedOption
            : tr.budgetEntryDialogCreditOption,
        onChanged: onChanged,
      ),
    );
  }
}

/// The movement's VAT rate field, hinting the project's default rate when there is one.
class _OcptBudgetNewVatField extends StatelessWidget {
  /// The VAT rate field's controller.
  final TextEditingController controller;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// Class constructor
  const _OcptBudgetNewVatField({required this.controller, required this.defaultVatRateBasisPoints});

  /// Build the budget new VAT field as an [OcptBudgetNewLabelAbove].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final defaultVatRateBasisPoints = this.defaultVatRateBasisPoints;
    final vatRateHint = defaultVatRateBasisPoints == null
        ? null
        : tr.budgetLineVatRateInheritedHint(ocptVatRatePercentTextOf(defaultVatRateBasisPoints));

    return OcptBudgetNewLabelAbove(
      label: tr.budgetLineVatRateFieldLabel,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          isDense: true,
          hintText: vatRateHint,
          suffixText: tr.budgetLineVatRateSuffix,
        ),
      ),
    );
  }
}

/// The movement's receipt field: the picked file or an empty hint, and the attach/replace button.
class _OcptBudgetNewReceiptField extends StatelessWidget {
  /// The receipt picked for the movement, or null.
  final String? pickedReceiptPath;

  /// Called when the picked receipt is removed.
  final VoidCallback onRemoved;

  /// Called when the receipt picker is requested.
  final VoidCallback onPickRequested;

  /// Class constructor
  const _OcptBudgetNewReceiptField({
    required this.pickedReceiptPath,
    required this.onRemoved,
    required this.onPickRequested,
  });

  /// Build the budget new receipt field as an [OcptBudgetNewLabelAbove].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final pickedReceiptPath = this.pickedReceiptPath;

    return OcptBudgetNewLabelAbove(
      label: tr.budgetEntryDialogReceiptFieldLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pickedReceiptPath != null)
            OcptAssetFileLine(
              asset: OcptAssetRef(
                id: "",
                kind: OcptAssetKind.receipt,
                path: pickedReceiptPath,
                label: "",
                addedAt: DateTime.now(),
                personId: null,
                locationId: null,
                elementId: null,
                validFrom: null,
                validUntil: null,
              ),
              onRemoved: onRemoved,
            )
          else
            Text(
              tr.budgetEntryDialogReceiptEmptyHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onPickRequested,
              child: Text(
                pickedReceiptPath == null
                    ? tr.budgetEntryDialogReceiptAttachAction
                    : tr.budgetEntryDialogReceiptReplaceAction,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
