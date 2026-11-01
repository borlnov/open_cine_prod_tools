// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_match_suggestion.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_match.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_attachment_answers.dart';

/// Get the ranked lettrage candidates for the movement typed so far: empty while [offersLettrage]
/// is
/// false or while [amountText] and [wording] do not yet make a saveable draft (a positive amount
/// and a non-blank wording).
List<OcptBudgetMatchSuggestion> ocptBudgetNewLettrageSuggestionsOf({
  required bool offersLettrage,
  required String amountText,
  required String wording,
  required bool isDebit,
  required DateTime date,
  required List<OcptBudgetCommitment> commitments,
  required List<OcptBudgetEntry> entries,
  required List<OcptBudgetAllowance> allowances,
  required List<OcptBudgetResource> resources,
  required List<OcptBudgetRevenue> revenues,
  required Map<String, OcptBudgetCoveredTotal> receivedByResourceId,
  required Map<String, OcptBudgetCoveredTotal> receivedByRevenueId,
  required int? projectVatRateBasisPoints,
}) {
  if (!offersLettrage) {
    return const [];
  }

  final amountCents = ocptCostCentsOf(amountText);
  final trimmedWording = wording.trim();
  if (amountCents == null || amountCents <= 0 || trimmedWording.isEmpty) {
    return const [];
  }

  return ocptBudgetMatchSuggestionsOf(
    isDebit: isDebit,
    draftAmountCents: amountCents,
    draftDate: date,
    draftWording: trimmedWording,
    commitments: commitments,
    entries: entries,
    allowances: allowances,
    resources: resources,
    revenues: revenues,
    receivedByResourceId: receivedByResourceId,
    receivedByRevenueId: receivedByRevenueId,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  );
}

/// Get the journal entry fields of the movement typed, according to [gesture] and to what step 2
/// collected in [answers].
OcptBudgetEntryFormFields ocptBudgetNewMovementFieldsOf({
  required OcptBudgetGesture gesture,
  required OcptBudgetNewAttachmentAnswers answers,
  required DateTime date,
  required String wording,
  required bool isDebit,
  required int amountCents,
  required bool isTaxInclusive,
  required String vatRateText,
  required String? pickedReceiptPath,
  required bool isReceiptDetached,
}) => OcptBudgetEntryFormFields(
  date: date,
  label: wording.trim(),
  posteId:
      gesture == OcptBudgetGesture.recordExpense || gesture == OcptBudgetGesture.recordOtherMovement
      ? answers.posteId
      : null,
  resourceId:
      gesture == OcptBudgetGesture.recordFinancingReceipt ||
          gesture == OcptBudgetGesture.repayContribution
      ? (answers.pendingNewResource == null ? answers.resourceId : null)
      : null,
  // `recordTakingReceipt` carries a revenue only when a contextual `Receive` opened the wizard
  // pre-filled from an existing taking; opened from `+ New` it names none and mints one below.
  revenueId: gesture == OcptBudgetGesture.recordTakingReceipt ? answers.revenueId : null,
  shareId: gesture == OcptBudgetGesture.payParticipantShare
      ? (answers.pendingNewShare == null ? answers.shareId : null)
      : null,
  personId: gesture == OcptBudgetGesture.reimbursePerson ? answers.personId : null,
  newResource:
      gesture == OcptBudgetGesture.recordFinancingReceipt ||
          gesture == OcptBudgetGesture.repayContribution
      ? answers.pendingNewResource
      : null,
  // The one-shot shortcut: `Le film a rapporté de l'argent` opened from `+ New` mints its own
  // taking from the very amount and label the reader typed once — fully received, since the
  // money is already in — rather than making them pick a taking and retype its amount.
  newRevenue: gesture == OcptBudgetGesture.recordTakingReceipt && answers.revenueId == null
      ? OcptBudgetRevenueFormFields(
          date: date,
          label: wording.trim(),
          amountCents: amountCents,
          status: OcptBudgetRevenueStatus.confirmed,
          notes: "",
        )
      : null,
  newShare: gesture == OcptBudgetGesture.payParticipantShare ? answers.pendingNewShare : null,
  isDebit: isDebit,
  amountCents: amountCents,
  isTaxInclusive: isTaxInclusive,
  vatRateBasisPoints: ocptVatRateBasisPointsOf(vatRateText),
  voucherNumber: null,
  pickedReceiptPath: pickedReceiptPath,
  isReceiptDetached: isReceiptDetached,
);
