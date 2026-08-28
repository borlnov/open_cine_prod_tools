// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';

void main() {
  group("ocptBudgetGestureFlowsOf classifies gestures by the direction money moves", () {
    test("everything the expenses filter offers makes money go out", () {
      const spends = {
        OcptBudgetGesture.addQuoteLine,
        OcptBudgetGesture.addQuoteLinesFromBreakdown,
        OcptBudgetGesture.commitSpend,
        OcptBudgetGesture.recordExpense,
        OcptBudgetGesture.reimbursePerson,
        OcptBudgetGesture.payParticipantShare,
        OcptBudgetGesture.repayContribution,
      };
      for (final gesture in spends) {
        expect(
          ocptBudgetGestureFlowsOf(gesture),
          contains(OcptBudgetGestureFlow.spends),
          reason: "$gesture should count as spending",
        );
      }
    });

    test("everything the resources filter offers brings money in", () {
      const brings = {
        OcptBudgetGesture.planSubsidy,
        OcptBudgetGesture.planContribution,
        OcptBudgetGesture.planTaking,
        OcptBudgetGesture.recordFinancingReceipt,
        OcptBudgetGesture.recordTakingReceipt,
      };
      for (final gesture in brings) {
        expect(
          ocptBudgetGestureFlowsOf(gesture),
          contains(OcptBudgetGestureFlow.brings),
          reason: "$gesture should count as bringing in",
        );
      }
    });

    test("Autre mouvement flows both ways, so it shows on expenses and resources alike", () {
      expect(
        ocptBudgetGestureFlowsOf(OcptBudgetGesture.recordOtherMovement),
        {OcptBudgetGestureFlow.spends, OcptBudgetGestureFlow.brings},
      );
    });

    test("a defrayal and a sharing participant have no direction — their own view files them", () {
      expect(ocptBudgetGestureFlowsOf(OcptBudgetGesture.defrayPerson), isEmpty);
      expect(ocptBudgetGestureFlowsOf(OcptBudgetGesture.addSharingParticipant), isEmpty);
    });
  });
}
