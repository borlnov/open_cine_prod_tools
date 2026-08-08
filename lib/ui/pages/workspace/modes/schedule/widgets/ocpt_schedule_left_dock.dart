// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_alert_badge.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';

/// The schedule mode's left dock: the list of shooting days over the list of shots still to
/// place, grouped by sequence — mirroring
/// the mock's `bandeDays`/`unplacedGroups` (`design.html` lines 192-243).
///
/// Every writing affordance is a nullable callback, withheld while a project version is being
/// previewed: [onDayCreated] (the `+ New day` control above the list), [onDayDateChangeRequested],
/// [onDayDuplicationRequested] and [onDayDeletionRequested] (a day card's own `⋮` menu). Selecting a
/// day ([onDaySelected]) or an unplaced shot ([onShotSelected], which only brings that shot's own
/// read-out up in the inspector) only ever reads, so neither is ever withheld.
class OcptScheduleLeftDock extends StatelessWidget {
  /// The live days to list, in `dayNumber` order.
  final List<OcptShootingDay> days;

  /// The id of the currently selected day, or null while none is.
  final String? selectedDayId;

  /// The number of live blocks of each day, keyed by day id — a day with none has no entry.
  final Map<String, int> blockCountByDayId;

  /// Each day's own first slot's location, keyed by day id, or null while it has none.
  final Map<String, OcptLocation?> firstLocationByDayId;

  /// Resolves a day id to the alerts the plan raises about it (`OcptScheduleState.alertsOfDay`) —
  /// what each card's own [OcptScheduleDayAlertBadge] is drawn from, empty for a day raising none.
  final List<OcptScheduleAlert> Function(String dayId) alertsOfDay;

  /// Called with a day's id when its row (or, once selected, its own card) is clicked.
  final ValueChanged<String> onDaySelected;

  /// Called with the date just picked by the `+ New day` control, or null while the mode is
  /// read-only.
  final ValueChanged<DateTime>? onDayCreated;

  /// Called with a day's id and the date just picked, once its own `⋮` menu's `Change the
  /// date…` entry opened a date picker seeded on that day's own date — a correction, not a
  /// duplication, which is why it sits first in the menu — or null while the mode is read-only.
  final void Function(String dayId, DateTime date)? onDayDateChangeRequested;

  /// Called with a day's id and the date just picked, once its own `⋮` menu's `Duplicate this
  /// day…` entry opened a date picker, or null while the mode is read-only.
  final void Function(String dayId, DateTime date)? onDayDuplicationRequested;

  /// Called with a day's id when its own `⋮` menu's `Delete this day…` entry is picked — the mode
  /// itself asks the question through `OcptConfirmDialog` before dispatching the deletion — or
  /// null while the mode is read-only.
  final ValueChanged<String>? onDayDeletionRequested;

  /// The live shots still to place, grouped by sequence.
  final List<OcptScheduleUnplacedGroup> unplacedGroups;

  /// The id of the shot currently selected, or null while none is.
  final String? selectedShotId;

  /// Called with a shot's id when one of its rows is clicked, bringing that shot's own read-out up
  /// in the inspector. Never withheld — see the class doc comment.
  final ValueChanged<String> onShotSelected;

  /// Class constructor
  const OcptScheduleLeftDock({
    super.key,
    required this.days,
    required this.selectedDayId,
    required this.blockCountByDayId,
    required this.firstLocationByDayId,
    required this.alertsOfDay,
    required this.onDaySelected,
    required this.onDayCreated,
    required this.onDayDateChangeRequested,
    required this.onDayDuplicationRequested,
    required this.onDayDeletionRequested,
    required this.unplacedGroups,
    required this.selectedShotId,
    required this.onShotSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(tr.scheduleDaysPanelTitle, style: theme.textTheme.titleSmall),
              ),
              if (onDayCreated != null)
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: tr.scheduleNewDayAction,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _pickDateThen(context, onDayCreated!),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (days.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      tr.scheduleDaysEmptyHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final day in days)
                    _OcptScheduleDayCard(
                      day: day,
                      isSelected: day.id == selectedDayId,
                      blockCount: blockCountByDayId[day.id] ?? 0,
                      location: firstLocationByDayId[day.id],
                      alerts: alertsOfDay(day.id),
                      onSelected: () => onDaySelected(day.id),
                      onDateChangeRequested: onDayDateChangeRequested == null
                          ? null
                          : () => _pickDateThen(
                              context,
                              (date) => onDayDateChangeRequested!(day.id, date),
                              initialDate: day.date,
                            ),
                      onDuplicationRequested: onDayDuplicationRequested == null
                          ? null
                          : () => _pickDateThen(
                              context,
                              (date) => onDayDuplicationRequested!(day.id, date),
                            ),
                      onDeletionRequested: onDayDeletionRequested == null
                          ? null
                          : () => onDayDeletionRequested!(day.id),
                    ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr.scheduleUnplacedPanelTitle,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      Text(
                        unplacedGroups.isEmpty
                            ? tr.scheduleUnplacedAllPlaced
                            : tr.scheduleUnplacedCount(_totalUnplacedCount),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final group in unplacedGroups)
                  _OcptScheduleUnplacedGroupSection(
                    group: group,
                    selectedShotId: selectedShotId,
                    onShotSelected: onShotSelected,
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The total number of shots across every [unplacedGroups] entry.
  int get _totalUnplacedCount =>
      unplacedGroups.fold(0, (sum, group) => sum + group.shots.length);

  /// Opens the platform date picker seeded on [initialDate] (today when omitted), reporting the
  /// pick to [onPicked]. Does nothing when the picker is dismissed with no pick — mirrors
  /// `OcptPersonSheetDateField._pickDate`, the app's own convention for [showDatePicker]. The
  /// `firstDate`/`lastDate` bounds are anchored on today but widen to include [initialDate]
  /// itself — [showDatePicker] asserts the seed falls inside them, and a day being re-dated may
  /// already sit outside the usual one-year-back/five-years-ahead window.
  static Future<void> _pickDateThen(
    BuildContext context,
    ValueChanged<DateTime> onPicked, {
    DateTime? initialDate,
  }) async {
    final now = DateTime.now();
    final seed = initialDate ?? now;
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 5);
    final picked = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: seed.isBefore(firstDate) ? seed : firstDate,
      lastDate: seed.isAfter(lastDate) ? seed : lastDate,
    );

    if (picked != null) {
      onPicked(picked);
    }
  }
}

/// One day card of the left dock's own list: the day tag and date, its first location, its block
/// count and status, and a `⋮` menu.
class _OcptScheduleDayCard extends StatelessWidget {
  /// The day this card shows.
  final OcptShootingDay day;

  /// Whether this is the currently selected day.
  final bool isSelected;

  /// The number of live blocks of this day.
  final int blockCount;

  /// This day's own first slot's location, or null while it has none.
  final OcptLocation? location;

  /// The alerts the plan raises about this day, empty while it raises none.
  final List<OcptScheduleAlert> alerts;

  /// Called when this card is clicked.
  final VoidCallback onSelected;

  /// Called when the `⋮` menu's `Change the date…` entry is picked, or null while withheld.
  final VoidCallback? onDateChangeRequested;

  /// Called when the `⋮` menu's `Duplicate this day…` entry is picked, or null while withheld.
  final VoidCallback? onDuplicationRequested;

  /// Called when the `⋮` menu's `Delete this day…` entry is picked, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptScheduleDayCard({
    required this.day,
    required this.isSelected,
    required this.blockCount,
    required this.location,
    required this.alerts,
    required this.onSelected,
    required this.onDateChangeRequested,
    required this.onDuplicationRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final tint = ocptScheduleDayLocationTint(context, location);
    final dateLabel = DateFormat.yMMMEd(Localizations.localeOf(context).toString()).format(day.date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: InkWell(
        onTap: onSelected,
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            ),
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(ocptRadiusMedium),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                constraints: const BoxConstraints(minHeight: 26),
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ocptScheduleDayTagLabel(tr, day.dayNumber),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        OcptScheduleDayAlertBadge(alerts: alerts),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      location?.name ?? tr.scheduleDayNoLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr.scheduleDayBlockCount(blockCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          ocptShootingDayStatusLabel(tr, day.status),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: ocptShootingDayStatusColor(context, day.status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDateChangeRequested != null || onDuplicationRequested != null || onDeletionRequested != null)
                PopupMenuButton<VoidCallback>(
                  icon: const Icon(Icons.more_vert, size: 16),
                  tooltip: "",
                  padding: EdgeInsets.zero,
                  onSelected: (action) => action(),
                  itemBuilder: (context) => [
                    // A correction, so it opens first — kept apart from the deletion entry below
                    // so the two are never adjacent by accident.
                    if (onDateChangeRequested != null)
                      PopupMenuItem<VoidCallback>(
                        value: onDateChangeRequested,
                        child: Text(tr.scheduleChangeDayDateAction),
                      ),
                    if (onDuplicationRequested != null)
                      PopupMenuItem<VoidCallback>(
                        value: onDuplicationRequested,
                        child: Text(tr.scheduleDuplicateDayAction),
                      ),
                    if (onDeletionRequested != null)
                      PopupMenuItem<VoidCallback>(
                        value: onDeletionRequested,
                        child: Text(tr.scheduleDeleteDayAction),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One sequence's own section of the unplaced-shots list: its heading over its shots, each a
/// clickable row bringing that shot's own read-out up in the inspector.
class _OcptScheduleUnplacedGroupSection extends StatelessWidget {
  /// The group this section shows.
  final OcptScheduleUnplacedGroup group;

  /// The id of the shot currently selected, or null while none is.
  final String? selectedShotId;

  /// Called with a shot's id when one of its rows is clicked.
  final ValueChanged<String> onShotSelected;

  /// Class constructor
  const _OcptScheduleUnplacedGroupSection({
    required this.group,
    required this.selectedShotId,
    required this.onShotSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final heading = group.displaySceneNumber == null
        ? tr.scheduleUnplacedOrphanGroupLabel
        : tr.scheduleUnplacedSequenceLabel(group.displaySceneNumber!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                heading,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (group.heading != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.heading!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          for (final shot in group.shots)
            _OcptScheduleUnplacedShotRow(
              code: shot.code,
              shotSize: shot.shotSize,
              durationLabel: ocptFormatShotDuration(shot.estimatedDurationMs),
              isSelected: shot.id == selectedShotId,
              onTap: () => onShotSelected(shot.id),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// One shot row of the unplaced-shots list.
class _OcptScheduleUnplacedShotRow extends StatelessWidget {
  /// The shot's own display code.
  final String code;

  /// The shot's own shot size ("valeur de plan").
  final String shotSize;

  /// The shot's own formatted estimated duration.
  final String durationLabel;

  /// Whether this shot is the one currently selected.
  final bool isSelected;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptScheduleUnplacedShotRow({
    required this.code,
    required this.shotSize,
    required this.durationLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
                : theme.colorScheme.surfaceContainerHigh,
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(ocptRadiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Text(
                code,
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  shotSize,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                durationLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
