// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';

/// The mark a day wears wherever the schedule mode draws one, saying that the plan raises something
/// about **that** day: the left dock's own day cards, the three agenda presentations, and the day
/// view's own summary band.
///
/// The `Alerts` dock tab is where an alert is read in full; this badge is what tells a user, from
/// whichever surface they happen to be on, that there is something to go and read — a count in the
/// status bar answers "does this plan raise anything at all", never "which day".
///
/// **It only ever reads its own [alerts] list** (`OcptScheduleState.alertsOfDay`, off
/// `OcptSchedulePlanSnapshot.alertsByDayId`): the severity it paints and the kinds it names in its
/// tooltip are the alerts' own, never a second reading of the eleven rules — a badge that decided
/// for itself what "blocking" means is exactly how it and the panel would come to disagree. A day
/// raising nothing draws nothing at all (a zero badge would be noise on every untroubled day of a
/// forty-day shoot).
///
/// Its [onTap] is **nullable, and wired in exactly one place**: the day view's own summary band,
/// where it opens the `Alerts` dock tab. Everywhere else it is left null on purpose — a day card
/// selects its day, an agenda cell opens it, and a badge swallowing that tap would make the gesture
/// depend on hitting a 16-pixel square. The summary band is the one surface that is not itself a
/// selection target: the day it describes is already selected, so there is nothing there for the
/// badge to steal. Its tooltip names the kinds either way, which is the question a user asks of a
/// mark on a day ("what is wrong with it?") without leaving the surface they are reading. Opening a
/// dock tab writes nothing, so the badge still needs no `isReadOnly` handling and draws identically
/// under a version preview, exactly as the `Alerts` panel itself does.
class OcptScheduleDayAlertBadge extends StatelessWidget {
  /// The alerts this day raises, in `ocptComputeScheduleAlerts`' own order (hard before soft) —
  /// empty for a day the plan raises nothing about, which draws nothing at all.
  final List<OcptScheduleAlert> alerts;

  /// Whether to draw the compact form: the icon alone, sized for a month cell or a week column
  /// header, where a count would not fit beside a day tag. The tooltip is the same either way.
  final bool isCompact;

  /// Called when the badge is clicked, or null — the default — for the informative form every
  /// surface but the day view's own summary band draws (see the class doc comment).
  final VoidCallback? onTap;

  /// Class constructor
  const OcptScheduleDayAlertBadge({
    super.key,
    required this.alerts,
    this.isCompact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final hasHardAlert = alerts.any((alert) => alert.severity == OcptScheduleAlertSeverity.hard);
    // The two colours the rest of this mode already reserves for "broken" and "needs attention but
    // not broken", and the badge takes the graver of the two whenever a hard alert is among them: a
    // day carrying one blocking problem and five soft ones is a blocked day.
    final color = hasHardAlert ? theme.colorScheme.error : ocptWarningColor(context);
    final icon = hasHardAlert ? Icons.error_outline : Icons.warning_amber_rounded;
    final iconSize = isCompact ? 11.0 : 13.0;

    final badge = Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _ocptScheduleDayAlertBadgeAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          if (!isCompact) ...[
            const SizedBox(width: 3),
            Text(
              "${alerts.length}",
              style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: _tooltipOf(tr),
      child: onTap == null
          ? badge
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(ocptRadiusSmall),
              mouseCursor: ocptClickableCursor,
              child: badge,
            ),
    );
  }

  /// The tooltip: how many alerts this day raises, then the distinct kinds among them, each named
  /// once however many times it was raised — a day with six "role not convoked" alerts reads as one
  /// problem to go and look at, not as a wall of the same sentence.
  String _tooltipOf(Tr tr) {
    final kinds = <OcptScheduleAlertKind>{for (final alert in alerts) alert.kind};
    return tr.scheduleDayAlertsBadgeTooltip(
      alerts.length,
      [for (final kind in kinds) ocptScheduleAlertKindLabel(tr, kind)].join(", "),
    );
  }
}

/// How strongly the badge's own severity colour tints its background — enough to read as a marked
/// chip on a day card, light enough not to compete with the day tint beside it.
const double _ocptScheduleDayAlertBadgeAlpha = 0.16;
