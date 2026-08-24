// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The "what feeds this budget" card: three rows, each a title, a one-line reading and a click that
/// only ever *reports* upward, through [onBreakdownFeedRequested]/[onScheduleFeedRequested]/
/// [onCateringFeedRequested] — this widget never navigates on its own, whichever page draws it.
///
/// **Each callback is nullable, and a null one withholds its own row whole** — the app's standing
/// "withheld, not disabled" rule, applied here to a row rather than a whole control: the
/// catering-and-travel pass draws this very card at its own top, and a click through to itself would
/// be a link to the page the reader is already standing on, so it passes null for
/// [onCateringFeedRequested] rather than drawing a row that does nothing.
///
/// **The unpriced-elements count read by [_OcptFeedCardRow]'s own breakdown row is deliberately not
/// a third alert.** A dozen elements still waiting to be priced during preparation is the normal
/// state of a production still building its breakdown, true for months on end — this card's own
/// place for that reading, not a standing warning about it.
class OcptBudgetFeedCard extends StatelessWidget {
  /// How many live elements a live quote line already prices.
  final int breakdownPricedElementCount;

  /// How many live elements no live line prices yet.
  final int breakdownUnpricedElementCount;

  /// How many shooting days the schedule holds.
  final int shootingDayCount;

  /// How many meals the schedule's own presences produce.
  final int mealCount;

  /// How many heads the buffet serves, from the schedule's own presences.
  final int buffetCount;

  /// Called when the breakdown row is clicked, or null while the row is withheld.
  final VoidCallback? onBreakdownFeedRequested;

  /// Called when the schedule row is clicked, or null while the row is withheld.
  final VoidCallback? onScheduleFeedRequested;

  /// Called when the catering row is clicked, or null while the row is withheld.
  final VoidCallback? onCateringFeedRequested;

  /// Class constructor
  const OcptBudgetFeedCard({
    super.key,
    required this.breakdownPricedElementCount,
    required this.breakdownUnpricedElementCount,
    required this.shootingDayCount,
    required this.mealCount,
    required this.buffetCount,
    required this.onBreakdownFeedRequested,
    required this.onScheduleFeedRequested,
    required this.onCateringFeedRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final elementCount = breakdownPricedElementCount + breakdownUnpricedElementCount;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr.budgetDashboardFeedSectionTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (onBreakdownFeedRequested != null)
              _OcptFeedCardRow(
                title: tr.budgetDashboardFeedBreakdownTitle,
                readOut: tr.budgetDashboardFeedBreakdownReadOut(breakdownPricedElementCount, elementCount),
                onTap: onBreakdownFeedRequested!,
              ),
            if (onScheduleFeedRequested != null)
              _OcptFeedCardRow(
                title: tr.budgetDashboardFeedScheduleTitle,
                readOut: tr.budgetDashboardFeedScheduleReadOut(shootingDayCount),
                onTap: onScheduleFeedRequested!,
              ),
            if (onCateringFeedRequested != null)
              _OcptFeedCardRow(
                title: tr.budgetDashboardFeedCateringTitle,
                readOut: tr.budgetDashboardFeedCateringReadOut(mealCount, buffetCount),
                onTap: onCateringFeedRequested!,
              ),
          ],
        ),
      ),
    );
  }
}

/// One row of [OcptBudgetFeedCard]: a title, a one-line reading, and a `›` chevron hinting the whole
/// row is a click through to wherever [readOut] was typed.
class _OcptFeedCardRow extends StatelessWidget {
  /// The row's own title.
  final String title;

  /// The row's own one-line reading.
  final String readOut;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptFeedCardRow({required this.title, required this.readOut, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: ocptTableRowHorizontalPadding,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Text(
                readOut,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
