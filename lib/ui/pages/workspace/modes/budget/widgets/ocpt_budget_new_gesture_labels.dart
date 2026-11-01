// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_family.dart';

/// [gesture]'s own bold answer label — the fifteen answers, one per `OcptBudgetGesture`.
String ocptBudgetGestureAnswerLabel(Tr tr, OcptBudgetGesture gesture) => switch (gesture) {
  OcptBudgetGesture.addQuoteLine => tr.budgetNewGestureAddQuoteLineLabel,
  OcptBudgetGesture.addQuoteLinesFromBreakdown =>
    tr.budgetNewGestureAddQuoteLinesFromBreakdownLabel,
  OcptBudgetGesture.commitSpend => tr.budgetNewGestureCommitSpendLabel,
  OcptBudgetGesture.recordExpense => tr.budgetNewGestureRecordExpenseLabel,
  OcptBudgetGesture.recordFinancingReceipt => tr.budgetNewGestureRecordFinancingReceiptLabel,
  OcptBudgetGesture.recordTakingReceipt => tr.budgetNewGestureRecordTakingReceiptLabel,
  OcptBudgetGesture.reimbursePerson => tr.budgetNewGestureReimbursePersonLabel,
  OcptBudgetGesture.payParticipantShare => tr.budgetNewGesturePayParticipantShareLabel,
  OcptBudgetGesture.repayContribution => tr.budgetNewGestureRepayContributionLabel,
  OcptBudgetGesture.recordOtherMovement => tr.budgetNewGestureRecordOtherMovementLabel,
  OcptBudgetGesture.planSubsidy => tr.budgetNewGesturePlanSubsidyLabel,
  OcptBudgetGesture.planContribution => tr.budgetNewGesturePlanContributionLabel,
  OcptBudgetGesture.planTaking => tr.budgetNewGesturePlanTakingLabel,
  OcptBudgetGesture.defrayPerson => tr.budgetNewGestureDefrayPersonLabel,
  OcptBudgetGesture.addSharingParticipant => tr.budgetNewGestureAddSharingParticipantLabel,
};

/// [gesture]'s own muted hint — one sentence, every answer carrying its own, not just the complex
/// ones.
String ocptBudgetGestureHint(Tr tr, OcptBudgetGesture gesture) => switch (gesture) {
  OcptBudgetGesture.addQuoteLine => tr.budgetNewGestureAddQuoteLineHint,
  OcptBudgetGesture.addQuoteLinesFromBreakdown => tr.budgetNewGestureAddQuoteLinesFromBreakdownHint,
  OcptBudgetGesture.commitSpend => tr.budgetNewGestureCommitSpendHint,
  OcptBudgetGesture.recordExpense => tr.budgetNewGestureRecordExpenseHint,
  OcptBudgetGesture.recordFinancingReceipt => tr.budgetNewGestureRecordFinancingReceiptHint,
  OcptBudgetGesture.recordTakingReceipt => tr.budgetNewGestureRecordTakingReceiptHint,
  OcptBudgetGesture.reimbursePerson => tr.budgetNewGestureReimbursePersonHint,
  OcptBudgetGesture.payParticipantShare => tr.budgetNewGesturePayParticipantShareHint,
  OcptBudgetGesture.repayContribution => tr.budgetNewGestureRepayContributionHint,
  OcptBudgetGesture.recordOtherMovement => tr.budgetNewGestureRecordOtherMovementHint,
  OcptBudgetGesture.planSubsidy => tr.budgetNewGesturePlanSubsidyHint,
  OcptBudgetGesture.planContribution => tr.budgetNewGesturePlanContributionHint,
  OcptBudgetGesture.planTaking => tr.budgetNewGesturePlanTakingHint,
  OcptBudgetGesture.defrayPerson => tr.budgetNewGestureDefrayPersonHint,
  OcptBudgetGesture.addSharingParticipant => tr.budgetNewGestureAddSharingParticipantHint,
};

/// [family]'s own heading — the five documents, in the design's own order.
String ocptBudgetGestureFamilyLabel(Tr tr, OcptBudgetGestureFamily family) => switch (family) {
  OcptBudgetGestureFamily.quote => tr.budgetNewFamilyQuoteLabel,
  OcptBudgetGestureFamily.cashMovement => tr.budgetNewFamilyCashMovementLabel,
  OcptBudgetGestureFamily.financingPlan => tr.budgetNewFamilyFinancingPlanLabel,
  OcptBudgetGestureFamily.allowances => tr.budgetNewFamilyAllowancesLabel,
  OcptBudgetGestureFamily.revenueSharing => tr.budgetNewFamilyRevenueSharingLabel,
};

/// [family]'s own subtitle — the one line stating its tense, telling `J'ai encaissé un financement`
/// apart from `Inscrire une subvention attendue`.
String ocptBudgetGestureFamilySubtitle(Tr tr, OcptBudgetGestureFamily family) => switch (family) {
  OcptBudgetGestureFamily.quote => tr.budgetNewFamilyQuoteSubtitle,
  OcptBudgetGestureFamily.cashMovement => tr.budgetNewFamilyCashMovementSubtitle,
  OcptBudgetGestureFamily.financingPlan => tr.budgetNewFamilyFinancingPlanSubtitle,
  OcptBudgetGestureFamily.allowances => tr.budgetNewFamilyAllowancesSubtitle,
  OcptBudgetGestureFamily.revenueSharing => tr.budgetNewFamilyRevenueSharingSubtitle,
};
