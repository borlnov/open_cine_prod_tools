// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';

/// The right dock's own `Alerts` tab: every [OcptScheduleAlert] the nine rules of
/// `lib/utils/ocpt_schedule_alerts.dart` raise over the **whole shoot**, in the order that pure
/// function already returns them (hard before soft, then day order, then kind order — this widget
/// never re-sorts).
///
/// A card reads as the mock's own alert cards do: a severity-coloured title naming the kind of
/// problem ([ocptScheduleAlertKindLabel]), then a sentence naming the people, roles, positions,
/// locations, slots and days it concerns ([ocptScheduleAlertSentence]) — both pure functions this
/// widget only calls, never reimplements, so a rule can never read differently here than the
/// function that raised it meant. A card whose own [OcptScheduleAlert.dayId] is set additionally
/// carries a day control: clicking it selects that day and switches to the day view, the same "open
/// this day" gesture the agendas and the positions matrix already answer
/// ([onDayOpenRequested]) — [OcptScheduleRoleUncastAlert] alone carries none, a role's own casting
/// being a fact about the role rather than about any one day.
///
/// A hard alert's own title is painted in the theme's real `error` colour (the plan, as written,
/// cannot be shot the way it stands); a soft one in [ocptWarningColor] (worth a second look, not a
/// blocker) — the same two colours the rest of this mode already reserves for "broken" and "needs
/// attention but not broken" (`OcptSpecificColors`' own doc comment).
///
/// Entirely **read-only**, like `OcptScheduleConvocationsPanel` and `OcptSchedulePositionsMatrix`:
/// every figure on a card is computed by `OcptSchedulePlanSnapshot.alerts`, and the only callback
/// this widget takes ([onDayOpenRequested]) is a selection, which writes nothing to the project
/// database. It therefore takes no `isReadOnly` flag and draws identically whether the working copy
/// or a version preview is on screen.
class OcptScheduleAlertsPanel extends StatelessWidget {
  /// Every alert the whole shoot currently raises, in [ocptComputeScheduleAlerts]'s own order.
  final List<OcptScheduleAlert> alerts;

  /// The whole address book, keyed by id — what a card's own person id is resolved to a name
  /// through.
  final Map<String, OcptPerson> personById;

  /// The whole cast, keyed by id — what a card's own role id is resolved to a name through.
  final Map<String, OcptRole> roleById;

  /// The whole location catalogue, keyed by id — what a card's own location id is resolved to a
  /// name through.
  final Map<String, OcptLocation> locationById;

  /// Every live day of the whole shoot, keyed by id — what a card's own day control reads its tag
  /// and date off.
  final Map<String, OcptShootingDay> daysById;

  /// Every live slot of the whole shoot, keyed by id (not scoped to one day, unlike
  /// `OcptScheduleConvocationsPanel`'s own `slotById`: an alert card is read outside the context of
  /// any single selected day) — what a card's own slot ids are resolved to labels through.
  final Map<String, OcptShootingSlot> slotById;

  /// Every live block of the whole shoot, keyed by id — what a timeline-overrun card's own block id
  /// is resolved to a readable identity through.
  final Map<String, OcptShootingDayBlock> blockById;

  /// Resolves a shot id to the shot it names, or null while it isn't loaded — what a role-not-
  /// convoked card's own shot code, and a timeline-overrun card's own shot block, read through.
  final OcptShot? Function(String shotId) shotOf;

  /// Called with a card's own [OcptScheduleAlert.dayId] when its day control is clicked, selecting
  /// that day and opening the day view.
  final ValueChanged<String> onDayOpenRequested;

  /// Class constructor
  const OcptScheduleAlertsPanel({
    super.key,
    required this.alerts,
    required this.personById,
    required this.roleById,
    required this.locationById,
    required this.daysById,
    required this.slotById,
    required this.blockById,
    required this.shotOf,
    required this.onDayOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    if (alerts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr.scheduleAlertsEmptyHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final hardCount = alerts.where((alert) => alert.severity == OcptScheduleAlertSeverity.hard).length;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tr.scheduleAlertsSummary(alerts.length, hardCount),
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }

        final alert = alerts[index - 1];
        return _OcptScheduleAlertCard(
          severity: alert.severity,
          kindLabel: ocptScheduleAlertKindLabel(tr, alert.kind),
          sentence: ocptScheduleAlertSentence(
            tr,
            alert,
            personById: personById,
            roleById: roleById,
            locationById: locationById,
            slotById: slotById,
            blockById: blockById,
            shotOf: shotOf,
          ),
          day: alert.dayId == null ? null : daysById[alert.dayId],
          onDayOpenRequested: alert.dayId == null ? null : () => onDayOpenRequested(alert.dayId!),
        );
      },
    );
  }
}

/// One card of [OcptScheduleAlertsPanel]: the severity-coloured [kindLabel], [sentence] beneath it,
/// and — while [day] is non-null — a clickable control naming that day.
class _OcptScheduleAlertCard extends StatelessWidget {
  /// This card's own severity, painting [kindLabel].
  final OcptScheduleAlertSeverity severity;

  /// This card's own kind title, already localized.
  final String kindLabel;

  /// This card's own body sentence, already localized and fully resolved.
  final String sentence;

  /// The day this alert is about, or null for [OcptScheduleRoleUncastAlert] alone — see the panel's
  /// own class doc comment.
  final OcptShootingDay? day;

  /// Called when the day control is clicked, or null while [day] itself is null.
  final VoidCallback? onDayOpenRequested;

  /// Class constructor
  const _OcptScheduleAlertCard({
    required this.severity,
    required this.kindLabel,
    required this.sentence,
    required this.day,
    required this.onDayOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final severityColor = severity == OcptScheduleAlertSeverity.hard
        ? theme.colorScheme.error
        : ocptWarningColor(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kindLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                color: severityColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(sentence, style: theme.textTheme.bodySmall),
            if (day != null) ...[
              const SizedBox(height: 8),
              _OcptScheduleAlertDayControl(day: day!, onPressed: onDayOpenRequested, tr: tr),
            ],
          ],
        ),
      ),
    );
  }
}

/// The day control at the foot of a card: the day's own tag and date, clickable to select that day
/// and open the day view — the exact idiom `ocptShotPlacementLabel` already reads a placement's own
/// day off (day tag, then a short locale date, joined by " · ").
class _OcptScheduleAlertDayControl extends StatelessWidget {
  /// The day this control names.
  final OcptShootingDay day;

  /// Called when the control is clicked.
  final VoidCallback? onPressed;

  /// The already-resolved localizations, so the label can be built with no second [Tr.of] lookup.
  final Tr tr;

  /// Class constructor
  const _OcptScheduleAlertDayControl({required this.day, required this.onPressed, required this.tr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final label =
        "${ocptScheduleDayTagLabel(tr, day.dayNumber)} · ${DateFormat.MMMEd(locale).format(day.date)}";

    return InkWell(
      onTap: onPressed,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusLarge),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 12, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
