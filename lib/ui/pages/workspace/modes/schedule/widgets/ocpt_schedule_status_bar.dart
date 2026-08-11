// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';

/// The schedule mode's status band: `N alerts · N episodes · N days · N shots placed · N left to
/// place`, plus the selected day's own estimated end in the trailing slot — mirroring
/// `OcptBreakdownStatusBar`'s own shape.
///
/// [alertCount] leads the summary and is, with [dayCount], one of the band's entries that never
/// drop on a narrow window: a count of problems the plan raises is exactly the kind of thing that
/// must not silently disappear the moment the window narrows, and it reads as an ordinary counter
/// — the same understated `labelSmall` every other one uses — rather than a shouted warning,
/// [Tr.scheduleStatsAlerts]'s own `=0` case being what keeps a healthy plan reading as "no alerts"
/// instead of an ambiguous "0". The hard/soft split the alerts panel's own summary carries is
/// deliberately left out of this one line: a compound "N alerts, M blocking" would cost this
/// already-narrow band more space than the split is worth here, where the panel itself is one click
/// away.
///
/// [episodeCount] sits second, right after the alerts — the schedule is the only mode reading
/// every episode of the project at once (it shows no episode selector at all, see
/// `OcptWorkspaceShell`'s own doc comment), which is exactly why its own band is where the series'
/// size belongs. It is null on a single-episode project, which draws no counter for it at all,
/// exactly as that project names no episode anywhere else — `nonDroppableCount` is 2 then, as it
/// always was. **When [episodeCount] is non-null, `nonDroppableCount` becomes 3**: it sits between
/// the never-dropped [alertCount] and [dayCount], and leaving it droppable would let a narrow
/// window silently swallow the counter this class doc comment just said belongs beside the alerts.
class OcptScheduleStatusBar extends StatelessWidget {
  /// The number of alerts the plan currently raises, across every rule and every day — see the
  /// class doc comment for why this leads the summary and never drops.
  final int alertCount;

  /// The number of live episodes in the project, or null on a single-episode project — see the
  /// class doc comment.
  final int? episodeCount;

  /// The number of live shooting days.
  final int dayCount;

  /// The number of shots placed somewhere in the schedule.
  final int placedShotCount;

  /// The number of shots that still have no live block placing them.
  final int shotsLeftToPlaceCount;

  /// Whether a day is selected at all, which [selectedDayEndMinute] alone cannot say: a day holding
  /// no block yet has no end either (`ocptComputeShootingDayTimelines` returns a null one for an
  /// empty day), and telling the user nothing is selected when they have just created a day and are
  /// looking at it is simply false.
  final bool isDaySelected;

  /// The selected day's own computed end minute, or null while no day is selected or the selected
  /// day holds nothing yet.
  final int? selectedDayEndMinute;

  /// Class constructor
  const OcptScheduleStatusBar({
    super.key,
    required this.alertCount,
    required this.episodeCount,
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
    final episodeCount = this.episodeCount;
    final selectedDayEndMinute = this.selectedDayEndMinute;
    final endText = switch (selectedDayEndMinute) {
      final int endMinute => tr.scheduleStatsEstimatedEnd(ocptFormatDayMinute(endMinute)),
      null when isDaySelected => tr.scheduleStatsNothingPlannedYet,
      null => tr.scheduleStatsNoDaySelected,
    };

    return OcptWorkspaceStatusBar(
      counters: [
        tr.scheduleStatsAlerts(alertCount),
        if (episodeCount != null) tr.scheduleStatsEpisodes(episodeCount),
        tr.scheduleStatsDays(dayCount),
        tr.scheduleStatsShotsPlaced(placedShotCount),
        tr.scheduleStatsShotsLeftToPlace(shotsLeftToPlaceCount),
      ],
      nonDroppableCount: episodeCount != null ? 3 : 2,
      trailingText: endText,
      trailing: Text(endText, style: theme.textTheme.labelSmall),
    );
  }
}
