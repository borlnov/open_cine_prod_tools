// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_alert_badge.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// The strip agenda: one card per shooting day, in order, each carrying its own placed shots as
/// chips (mock's `bandeDays`, `design.html` lines 129-168).
///
/// It is purely informative: a placement is made and unmade in the day view's own timetables,
/// where the block itself lives, not here. A card's own header click opens that day, selecting it
/// and switching the centre to the day view — the same "open this day" gesture the week and month
/// presentations' own header/cell click already answers — while a chip only ever selects the block
/// it names. Both only ever read, so neither [onDayOpenRequested] nor [onBlockSelected] is ever
/// withheld.
class OcptScheduleStripAgenda extends StatelessWidget {
  /// The live days to show, in `dayNumber` order.
  final List<OcptShootingDay> days;

  /// The id of the currently selected day, or null while none is.
  final String? selectedDayId;

  /// Each day's own first slot's location, keyed by day id, or null while it has none — what a
  /// card's own location line reads, whatever [dayTintOf] is currently painting it with.
  final Map<String, OcptLocation?> firstLocationByDayId;

  /// A day's own resolved tint, under whichever `OcptScheduleAgendaColorMode` is currently active —
  /// `ocptScheduleDayLocationTint`/`ocptScheduleDayEffectTint` applied by the caller, so this widget
  /// stays ignorant of which fact a day is coloured by.
  final Color Function(String dayId) dayTintOf;

  /// Each day's own live blocks, keyed by day id.
  final Map<String, List<OcptShootingDayBlock>> blocksByDayId;

  /// Resolves a shot id to the shot it names, or null while it isn't loaded.
  final OcptShot? Function(String shotId) shotOf;

  /// Resolves a day id to its own computed timetable, or null while it has nothing placed yet.
  final OcptShootingDayTimelines? Function(String dayId) timelineOf;

  /// Resolves a day id to its own earliest arrival — the minimum slot start over its live slots
  /// (`OcptScheduleState.dayArrivalMinute`) — or null while it has no live slot at all — what each
  /// card's own arrival-to-end range starts from.
  final int? Function(String dayId) arrivalMinuteOf;

  /// Resolves a day id to the alerts the plan raises about it (`OcptScheduleState.alertsOfDay`) —
  /// what each card's own [OcptScheduleDayAlertBadge] is drawn from, empty for a day raising none.
  final List<OcptScheduleAlert> Function(String dayId) alertsOfDay;

  /// Called with a day's id when its own header is clicked, selecting it and opening the day view.
  final ValueChanged<String> onDayOpenRequested;

  /// Called with a block's id and its own day's id when a chip's own code/label is clicked.
  final void Function(String blockId, String dayId) onBlockSelected;

  /// Class constructor
  const OcptScheduleStripAgenda({
    super.key,
    required this.days,
    required this.selectedDayId,
    required this.firstLocationByDayId,
    required this.dayTintOf,
    required this.blocksByDayId,
    required this.shotOf,
    required this.timelineOf,
    required this.arrivalMinuteOf,
    required this.alertsOfDay,
    required this.onDayOpenRequested,
    required this.onBlockSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Center(
        child: Text(
          Tr.of(context).scheduleAgendaEmptyHint,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      itemCount: days.length,
      separatorBuilder: (context, index) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final day = days[index];
        return _OcptScheduleStripDayCard(
          day: day,
          isSelected: day.id == selectedDayId,
          location: firstLocationByDayId[day.id],
          tint: dayTintOf(day.id),
          blocks: blocksByDayId[day.id] ?? const [],
          shotOf: shotOf,
          timeline: timelineOf(day.id),
          arrivalMinute: arrivalMinuteOf(day.id),
          alerts: alertsOfDay(day.id),
          onSelected: () => onDayOpenRequested(day.id),
          onBlockSelected: (blockId) => onBlockSelected(blockId, day.id),
        );
      },
    );
  }
}

/// One day card of the strip agenda.
class _OcptScheduleStripDayCard extends StatelessWidget {
  /// The day this card shows.
  final OcptShootingDay day;

  /// Whether this is the currently selected day.
  final bool isSelected;

  /// This day's own first slot's location, or null while it has none — read for the card's own
  /// location line regardless of what [tint] currently paints.
  final OcptLocation? location;

  /// This day's own resolved tint (`OcptScheduleStripAgenda.dayTintOf`, already applied).
  final Color tint;

  /// This day's own live blocks, in timetable order.
  final List<OcptShootingDayBlock> blocks;

  /// Resolves a shot id to the shot it names.
  final OcptShot? Function(String shotId) shotOf;

  /// This day's own computed timetable, or null while it has nothing placed.
  final OcptShootingDayTimelines? timeline;

  /// This day's own earliest arrival, or null while it has no live slot at all — see
  /// `OcptScheduleState.dayArrivalMinute`.
  final int? arrivalMinute;

  /// The alerts the plan raises about this day, empty while it raises none.
  final List<OcptScheduleAlert> alerts;

  /// Called when the card's own header is clicked.
  final VoidCallback onSelected;

  /// Called with a block's id when one of the card's own chips is clicked.
  final ValueChanged<String> onBlockSelected;

  /// Class constructor
  const _OcptScheduleStripDayCard({
    required this.day,
    required this.isSelected,
    required this.location,
    required this.tint,
    required this.blocks,
    required this.shotOf,
    required this.timeline,
    required this.arrivalMinute,
    required this.alerts,
    required this.onSelected,
    required this.onBlockSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final dateLabel = DateFormat.yMMMEd(Localizations.localeOf(context).toString()).format(day.date);
    final shotBlocks = blocks.where((block) => block.kind == OcptShootingBlockKind.shot).toList();
    final entryByBlockId = <String, OcptShootingTimelineEntry>{
      for (final entry in timeline?.entries ?? const <OcptShootingTimelineEntry>[]) entry.blockId: entry,
    };

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
        ),
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onSelected,
            mouseCursor: ocptClickableCursor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    constraints: const BoxConstraints(minHeight: 34),
                    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              ocptScheduleDayTagLabel(tr, day.dayNumber),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (alerts.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              OcptScheduleDayAlertBadge(alerts: alerts),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(dateLabel, style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location?.name ?? tr.scheduleDayNoLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ocptShootingDayStatusLabel(tr, day.status),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: ocptShootingDayStatusColor(context, day.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          tr.scheduleDayArrivalToEndLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ocptScheduleDayMinuteRangeLabel(arrivalMinute, timeline?.dayEndMinute),
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shotBlocks.isEmpty
                              ? tr.scheduleDayNoShotsPlaced
                              : tr.scheduleDayShotsPlacedCount(shotBlocks.length),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(29, 0, 13, 11),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final block in shotBlocks)
                  _OcptScheduleStripShotChip(
                    shot: shotOf(block.shotId ?? ""),
                    startMinute: entryByBlockId[block.id]?.startMinute,
                    onSelected: () => onBlockSelected(block.id),
                  ),
                if (shotBlocks.isEmpty)
                  Text(
                    tr.scheduleDayNoShotsPlacedHint,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One placed shot's own chip.
class _OcptScheduleStripShotChip extends StatelessWidget {
  /// The shot named by the block this chip shows, or null while it isn't loaded.
  final OcptShot? shot;

  /// This block's own computed start minute, or null while the day has no timeline yet.
  final int? startMinute;

  /// Called when the chip's own code/label is clicked.
  final VoidCallback onSelected;

  /// Class constructor
  const _OcptScheduleStripShotChip({
    required this.shot,
    required this.startMinute,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shot = this.shot;

    return InkWell(
      onTap: onSelected,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              shot?.code ?? "",
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            Text(
              shot?.shotSize ?? "",
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (startMinute != null) ...[
              const SizedBox(width: 6),
              Text(
                ocptFormatDayMinute(startMinute!),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
