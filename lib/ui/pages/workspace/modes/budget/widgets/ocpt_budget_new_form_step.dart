// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_match_suggestion.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_allowance_form_body.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_commitment_form_body.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_line_form_body.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_breakdown_step.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_movement_form.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_resource_form_body.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_revenue_form_body.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_share_form_body.dart';

/// Step 3 — the money, or the form: the movement form for the seven `cashMovement` gestures, the
/// breakdown selector for `addQuoteLinesFromBreakdown`, and the embeddable form body of every
/// other gesture. Every draft and every controller belongs to the wizard's own state; this widget
/// only reports changes.
class OcptBudgetNewFormStep extends StatelessWidget {
  /// The gesture in effect, or null.
  final OcptBudgetGesture? gesture;

  /// The form step 3 validates against, whichever of its own bodies is currently drawn.
  final GlobalKey<FormState> formKey;

  /// Every live account of the project.
  final List<OcptBudgetAccount> accounts;

  /// Every live person of the project's address book.
  final List<OcptPerson> people;

  /// Every live mileage rate of the project.
  final List<OcptBudgetMileageRate> mileageRates;

  /// Every live commitment, read by the matching strip.
  final List<OcptBudgetCommitment> commitments;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// Whether the mode's header currently reads simplified.
  final bool isSimplified;

  /// The prefill of the `commitSpend` form body, or null.
  final OcptBudgetCommitmentFormFields? commitmentPrefill;

  /// Called with the line form's draft as it changes.
  final ValueChanged<OcptBudgetLineFormFields?> onLineDraftChanged;

  /// Called with the commitment form's draft as it changes.
  final ValueChanged<OcptBudgetCommitmentFormFields?> onCommitmentDraftChanged;

  /// Called with the commitment form's missing-fields hint as it changes.
  final ValueChanged<String?> onCommitmentMissingHintChanged;

  /// Called with the resource form's draft as it changes.
  final ValueChanged<OcptBudgetResourceFormFields?> onResourceDraftChanged;

  /// Called with the taking form's draft as it changes.
  final ValueChanged<OcptBudgetRevenueFormFields?> onRevenueDraftChanged;

  /// Called with the defrayal form's draft as it changes.
  final ValueChanged<OcptBudgetAllowanceFormFields?> onAllowanceDraftChanged;

  /// Called with the participant form's draft as it changes.
  final ValueChanged<OcptBudgetShareFormFields?> onShareDraftChanged;

  /// The movement form's wording field controller.
  final TextEditingController labelController;

  /// The movement form's amount field controller.
  final TextEditingController amountController;

  /// The movement form's VAT rate field controller.
  final TextEditingController vatRateController;

  /// The movement's date.
  final DateTime date;

  /// Whether the movement's amount is tax inclusive.
  final bool isTaxInclusive;

  /// Whether the movement is a debit.
  final bool isDebit;

  /// The matching candidates the movement form offers.
  final List<OcptBudgetMatchSuggestion> matchingSuggestions;

  /// The matching candidate picked, by index, or null for `Aucun`.
  final int? selectedSuggestionIndex;

  /// The receipt picked for the movement, or null.
  final String? pickedReceiptPath;

  /// Called when the movement's wording or amount changes.
  final VoidCallback onDraftTextChanged;

  /// Called with the movement's date picked.
  final ValueChanged<DateTime?> onDateChanged;

  /// Called with the tax basis picked.
  final ValueChanged<bool> onTaxInclusiveChanged;

  /// Called with the direction picked.
  final ValueChanged<bool> onDirectionChanged;

  /// Called with the matching candidate picked, or null for `Aucun`.
  final ValueChanged<int?> onSuggestionSelected;

  /// Called when the movement's picked receipt is removed.
  final VoidCallback onReceiptRemoved;

  /// Called when the receipt picker is requested.
  final VoidCallback onReceiptPickRequested;

  /// Every live breakdown element no live quote line prices yet.
  final List<OcptElement> unpricedElements;

  /// The breakdown selector's search text.
  final String breakdownQuery;

  /// The ids of the elements checked in the breakdown selector.
  final Set<String> breakdownSelectedIds;

  /// The breakdown selector's `File all under` account, or null.
  final String? breakdownBulkAccountId;

  /// The account a breakdown row will be filed under, or null.
  final String? Function(String elementId) breakdownAccountIdOf;

  /// The quantity controller of a breakdown element.
  final TextEditingController Function(OcptElement element) breakdownQuantityControllerOf;

  /// Called with the `File all under` account picked.
  final ValueChanged<String?> onBreakdownBulkAccountChanged;

  /// Called with the breakdown search text as it changes.
  final ValueChanged<String> onBreakdownQueryChanged;

  /// Called when a breakdown element is checked or unchecked.
  final void Function(OcptElement element, {required bool isChecked})
  onBreakdownElementCheckedChanged;

  /// Called when a breakdown row is given an account of its own.
  final void Function(String elementId, String? accountId) onBreakdownElementAccountChanged;

  /// Called when a breakdown row's quantity text changes.
  final void Function(String elementId, String value) onBreakdownQuantityChanged;

  /// Class constructor
  const OcptBudgetNewFormStep({
    super.key,
    required this.gesture,
    required this.formKey,
    required this.accounts,
    required this.people,
    required this.mileageRates,
    required this.commitments,
    required this.currencyCode,
    required this.defaultVatRateBasisPoints,
    required this.isSimplified,
    required this.commitmentPrefill,
    required this.onLineDraftChanged,
    required this.onCommitmentDraftChanged,
    required this.onCommitmentMissingHintChanged,
    required this.onResourceDraftChanged,
    required this.onRevenueDraftChanged,
    required this.onAllowanceDraftChanged,
    required this.onShareDraftChanged,
    required this.labelController,
    required this.amountController,
    required this.vatRateController,
    required this.date,
    required this.isTaxInclusive,
    required this.isDebit,
    required this.matchingSuggestions,
    required this.selectedSuggestionIndex,
    required this.pickedReceiptPath,
    required this.onDraftTextChanged,
    required this.onDateChanged,
    required this.onTaxInclusiveChanged,
    required this.onDirectionChanged,
    required this.onSuggestionSelected,
    required this.onReceiptRemoved,
    required this.onReceiptPickRequested,
    required this.unpricedElements,
    required this.breakdownQuery,
    required this.breakdownSelectedIds,
    required this.breakdownBulkAccountId,
    required this.breakdownAccountIdOf,
    required this.breakdownQuantityControllerOf,
    required this.onBreakdownBulkAccountChanged,
    required this.onBreakdownQueryChanged,
    required this.onBreakdownElementCheckedChanged,
    required this.onBreakdownElementAccountChanged,
    required this.onBreakdownQuantityChanged,
  });

  /// Build the budget new form step.
  @override
  Widget build(BuildContext context) {
    final gesture = this.gesture;
    if (gesture == null) {
      return const SizedBox.shrink();
    }

    if (ocptBudgetGestureNatureOf(gesture) != null) {
      return OcptBudgetNewMovementForm(
        formKey: formKey,
        gesture: gesture,
        labelController: labelController,
        amountController: amountController,
        vatRateController: vatRateController,
        date: date,
        isTaxInclusive: isTaxInclusive,
        isDebit: isDebit,
        suggestions: matchingSuggestions,
        selectedSuggestionIndex: selectedSuggestionIndex,
        commitments: commitments,
        accounts: accounts,
        currencyCode: currencyCode,
        defaultVatRateBasisPoints: defaultVatRateBasisPoints,
        isSimplified: isSimplified,
        pickedReceiptPath: pickedReceiptPath,
        onDraftTextChanged: onDraftTextChanged,
        onDateChanged: onDateChanged,
        onTaxInclusiveChanged: onTaxInclusiveChanged,
        onDirectionChanged: onDirectionChanged,
        onSuggestionSelected: onSuggestionSelected,
        onReceiptRemoved: onReceiptRemoved,
        onReceiptPickRequested: onReceiptPickRequested,
      );
    }

    return switch (gesture) {
      OcptBudgetGesture.addQuoteLine => OcptBudgetLineFormBody(
        currencyCode: currencyCode,
        formKey: formKey,
        onDraftChanged: onLineDraftChanged,
      ),
      OcptBudgetGesture.addQuoteLinesFromBreakdown => OcptBudgetNewBreakdownStep(
        unpricedElements: unpricedElements,
        query: breakdownQuery,
        selectedIds: breakdownSelectedIds,
        bulkAccountId: breakdownBulkAccountId,
        accounts: accounts,
        isSimplified: isSimplified,
        accountIdOf: breakdownAccountIdOf,
        quantityControllerOf: breakdownQuantityControllerOf,
        onBulkAccountChanged: onBreakdownBulkAccountChanged,
        onQueryChanged: onBreakdownQueryChanged,
        onElementCheckedChanged: onBreakdownElementCheckedChanged,
        onElementAccountChanged: onBreakdownElementAccountChanged,
        onQuantityChanged: onBreakdownQuantityChanged,
      ),
      OcptBudgetGesture.commitSpend => OcptBudgetCommitmentFormBody(
        existing: null,
        prefill: commitmentPrefill,
        accounts: accounts,
        currencyCode: currencyCode,
        defaultVatRateBasisPoints: defaultVatRateBasisPoints,
        isSimplified: isSimplified,
        formKey: formKey,
        onDraftChanged: onCommitmentDraftChanged,
        onMissingFieldsHintChanged: onCommitmentMissingHintChanged,
        // Step 2 has already asked the account (`accountAndLine`, or `commitmentPrefill`'s own
        // shortcut) — drawing the picker again here would ask the same question twice.
        accountAlreadyAnswered: true,
      ),
      OcptBudgetGesture.planSubsidy => OcptBudgetResourceFormBody(
        existing: null,
        groupKind: OcptBudgetResourceGroupKind.subsidy,
        people: people,
        currencyCode: currencyCode,
        accounts: accounts,
        isSimplified: isSimplified,
        formKey: formKey,
        onDraftChanged: onResourceDraftChanged,
      ),
      OcptBudgetGesture.planContribution => OcptBudgetResourceFormBody(
        existing: null,
        groupKind: OcptBudgetResourceGroupKind.cash,
        people: people,
        currencyCode: currencyCode,
        accounts: accounts,
        isSimplified: isSimplified,
        formKey: formKey,
        onDraftChanged: onResourceDraftChanged,
        // `planContribution` collapses cash and in-kind into one gesture — the picker is the one
        // question left for the wizard to ask, offering only the two.
        offerCashOrInKindChoice: true,
      ),
      OcptBudgetGesture.planTaking => OcptBudgetRevenueFormBody(
        existing: null,
        currencyCode: currencyCode,
        formKey: formKey,
        onDraftChanged: onRevenueDraftChanged,
      ),
      OcptBudgetGesture.defrayPerson => OcptBudgetAllowanceFormBody(
        existing: null,
        people: people,
        mileageRates: mileageRates,
        currencyCode: currencyCode,
        formKey: formKey,
        onDraftChanged: onAllowanceDraftChanged,
      ),
      OcptBudgetGesture.addSharingParticipant => OcptBudgetShareFormBody(
        existing: null,
        people: people,
        formKey: formKey,
        onDraftChanged: onShareDraftChanged,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
