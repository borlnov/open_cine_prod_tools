// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_creation_footer.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_feed_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';

/// The empty state drawn in place of the two-pane table while the project holds no poste — see
/// [OcptBudgetCostTracking]'s class doc comment. The creation footer is kept, exactly as it is
/// drawn today, so the way to create the first poste never disappears.
class OcptBudgetCostTrackingEmptyState extends StatelessWidget {
  /// How many breakdown elements carry a price.
  final int breakdownPricedElementCount;

  /// How many breakdown elements carry no price yet.
  final int breakdownUnpricedElementCount;

  /// How many shooting days the schedule holds.
  final int shootingDayCount;

  /// How many meals the catering counts.
  final int mealCount;

  /// How many buffets the catering counts.
  final int buffetCount;

  /// Called when the breakdown row of the feed card is clicked.
  final VoidCallback onBreakdownFeedRequested;

  /// Called when the schedule row of the feed card is clicked.
  final VoidCallback onScheduleFeedRequested;

  /// Called when the catering row of the feed card is clicked.
  final VoidCallback onCateringFeedRequested;

  /// Called when the creation footer is clicked, or null to withhold the footer.
  final VoidCallback? onPosteCreationRequested;

  /// Class constructor
  const OcptBudgetCostTrackingEmptyState({
    super.key,
    required this.breakdownPricedElementCount,
    required this.breakdownUnpricedElementCount,
    required this.shootingDayCount,
    required this.mealCount,
    required this.buffetCount,
    required this.onBreakdownFeedRequested,
    required this.onScheduleFeedRequested,
    required this.onCateringFeedRequested,
    required this.onPosteCreationRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onCreation = onPosteCreationRequested;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ocptBudgetCostTrackingEmptyStateMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OcptWorkspaceEmptyMode(
                    icon: Icons.payments_outlined,
                    message: tr.budgetDashboardEmptyHint,
                  ),
                  const SizedBox(height: 16),
                  OcptBudgetFeedCard(
                    breakdownPricedElementCount: breakdownPricedElementCount,
                    breakdownUnpricedElementCount: breakdownUnpricedElementCount,
                    shootingDayCount: shootingDayCount,
                    mealCount: mealCount,
                    buffetCount: buffetCount,
                    onBreakdownFeedRequested: onBreakdownFeedRequested,
                    onScheduleFeedRequested: onScheduleFeedRequested,
                    onCateringFeedRequested: onCateringFeedRequested,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onCreation != null) OcptBudgetCostTrackingCreationFooter(onTap: onCreation),
      ],
    );
  }
}
