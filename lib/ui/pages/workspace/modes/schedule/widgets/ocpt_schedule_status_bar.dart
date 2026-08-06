// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';

/// The schedule mode's status band: `N days · N shots placed · N left to place`, plus the selected
/// day's own estimated end in the trailing slot — mirroring `OcptBreakdownStatusBar`'s own shape.
class OcptScheduleStatusBar extends StatelessWidget {
  /// The number of live shooting days.
  final int dayCount;

  /// The number of shots placed somewhere in the schedule.
  final int placedShotCount;

  /// The number of shots that still have no live block placing them.
  final int shotsLeftToPlaceCount;

  /// Whether a day is selected at all, which [selectedDayEndMinute] alone cannot say: a day holding
  /// no block yet has no end either (`ocptComputeShootingDayTimeline` returns a null one for an
  /// empty day), and telling the user nothing is selected when they have just created a day and are
  /// looking at it is simply false.
  final bool isDaySelected;

  /// The selected day's own computed end minute, or null while no day is selected or the selected
  /// day holds nothing yet.
  final int? selectedDayEndMinute;

  /// Class constructor
  const OcptScheduleStatusBar({
    super.key,
    required this.dayCount,
    required this.placedShotCount,
    required this.shotsLeftToPlaceCount,
    required this.isDaySelected,
    required this.selectedDayEndMinute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final selectedDayEndMinute = this.selectedDayEndMinute;
    final endText = switch (selectedDayEndMinute) {
      final int endMinute => tr.scheduleStatsEstimatedEnd(ocptFormatDayMinute(endMinute)),
      null when isDaySelected => tr.scheduleStatsNothingPlannedYet,
      null => tr.scheduleStatsNoDaySelected,
    };

    return OcptWorkspaceStatusBar(
      counters: [
        tr.scheduleStatsDays(dayCount),
        tr.scheduleStatsShotsPlaced(placedShotCount),
        tr.scheduleStatsShotsLeftToPlace(shotsLeftToPlaceCount),
      ],
      nonDroppableCount: 1,
      trailingText: endText,
      trailing: Text(endText, style: theme.textTheme.labelSmall),
    );
  }
}
