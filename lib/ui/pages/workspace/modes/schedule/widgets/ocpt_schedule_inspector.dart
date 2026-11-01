// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timelines.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_sun_times.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_events_list.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_shot_status_control.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';

/// The right dock's own `Inspector` tab content, in order of precedence: the selected **block**'s
/// read-out, else the selected **shot**'s own, else the selected **day**'s own, else a plain hint.
/// A block is the more specific thing, and the block and shot selections can never both be set
/// (`OcptScheduleBloc` keeps them mutually exclusive); a shot is what the user just clicked in the
/// left dock, so it wins over a day it says nothing about.
///
/// Every writing affordance ([onDayStatusChanged], [onCrewNoteChanged], [onWeatherNoteChanged],
/// [onEventAdded] and the rest of the events section's own callbacks, [onShotStatusChanged],
/// [onBlockDurationChanged], [onBlockCrewNoteChanged], [onBlockNotesChanged]) is a nullable
/// callback, withheld while a project version is being previewed. Reading — every other line —
/// stays.
///
/// The day inspector's own events section is [OcptScheduleDayEventsList] under an
/// `_OcptScheduleInspectorSection`, after the sun times and before the weather note — the very same
/// widget the day view's own bordered band builds, so the two surfaces can never read a day's
/// events apart. It is drawn under the same condition as that band: [events] non-empty, or
/// [onEventAdded] non-null (the inspector may be written to).
class OcptScheduleInspector extends StatelessWidget {
  /// The selected day, or null while none is selected.
  final OcptShootingDay? day;

  /// The selected day's own live slots, in `sortKey` order.
  final List<OcptShootingSlot> slots;

  /// The whole location catalogue, keyed by id.
  final Map<String, OcptLocation> locationById;

  /// The whole set catalogue, keyed by id.
  final Map<String, OcptSet> setById;

  /// The selected day's own computed timetable, or null while it has nothing placed yet.
  final OcptShootingDayTimelines? timeline;

  /// The selected day's own earliest arrival — the minimum **resolved** start over its live slots
  /// (`OcptScheduleState.dayArrivalMinute`) — or null while it has no live slot at all.
  final int? dayArrivalMinute;

  /// The selected day's own computed sun times, or null while its first slot has no location with
  /// coordinates.
  final OcptSunTimes? sunTimes;

  /// The selected day's own crew note, as currently held (a pending edit, or its stored value).
  final String crewNoteValue;

  /// The selected day's own weather note, as currently held.
  final String weatherNoteValue;

  /// The selected day's own live events, already ordered by hour — handed to
  /// [OcptScheduleDayEventsList], the day view's own section built from the very same widget.
  final List<OcptShootingDayEvent> events;

  /// Resolves an event's id to its own label, as currently held (a pending edit, or its stored
  /// value).
  final String Function(String eventId) eventLabelValueOf;

  /// Resolves an event's id to its own notes, as currently held (a pending edit, or its stored
  /// value).
  final String Function(String eventId) eventNotesValueOf;

  /// Called when the events section's own `+ Event` footer is clicked, or null while withheld.
  final VoidCallback? onEventAdded;

  /// Called with an event's id and its own new minute once its hour field commits, or null while
  /// withheld.
  final void Function(String eventId, int minute)? onEventMinuteChanged;

  /// Called with an event's id and its raw label text on every keystroke, or null while withheld.
  final void Function(String eventId, String rawValue)? onEventLabelChanged;

  /// Called with an event's id and its raw note text on every keystroke, or null while withheld.
  final void Function(String eventId, String rawValue)? onEventNotesChanged;

  /// Called with an event's id when its own remove control is clicked, or null while withheld —
  /// only ever asks, the mode owning the confirmation.
  final ValueChanged<String>? onEventDeletionRequested;

  /// Called with the status just picked, or null while withheld.
  final ValueChanged<OcptShootingDayStatus>? onDayStatusChanged;

  /// Called with the crew note's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onCrewNoteChanged;

  /// Called with the weather note's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onWeatherNoteChanged;

  /// The selected shot, or null while none is selected — the inspector shows this ahead of [day]'s
  /// own read-out, but behind [block]'s (see the class doc comment's own precedence).
  final OcptShot? shot;

  /// [shot]'s own sequence, as the left dock heads it — null while [shot] is null.
  final String? shotSequenceLabel;

  /// The day numbers [shot] is currently placed on, in ascending order — empty while it isn't
  /// placed anywhere yet. Ignored while [shot] is null.
  final List<int> shotPlacedDayNumbers;

  /// The selected block, or null while none is selected — the inspector then shows [shot]'s own
  /// read-out instead, or, with neither selected, [day]'s.
  final OcptShootingDayBlock? block;

  /// The shot [block] names, when [block]'s own kind is [OcptShootingBlockKind.shot].
  final OcptShot? blockShot;

  /// The label of the slot [block] sits in, or null while it sits in none.
  final String? blockSlotLabel;

  /// [block]'s own computed timeline entry, or null while the day has no timeline yet.
  final OcptShootingTimelineEntry? blockEntry;

  /// Called with the status just picked for [blockShot], or null while withheld.
  final ValueChanged<OcptShotStatus>? onShotStatusChanged;

  /// Called with the new duration in minutes once the selected block's own `Duration` field
  /// commits, or null while withheld.
  final ValueChanged<int>? onBlockDurationChanged;

  /// The selected block's own crew note — the one that **prints**, unlike [blockNotesValue] — as
  /// currently held (a pending edit, or its stored value).
  final String blockCrewNoteValue;

  /// Called with the crew note's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onBlockCrewNoteChanged;

  /// The selected block's own private notes, as currently held (a pending edit, or its stored
  /// value).
  final String blockNotesValue;

  /// Called with the notes' raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onBlockNotesChanged;

  /// Whether the mode is read-only (a project version being previewed) — kept alongside the
  /// individual nullable callbacks above only for the one composite panel's own `isReadOnly` flag
  /// this widget itself needs nowhere else.
  final bool isReadOnly;

  /// Class constructor
  const OcptScheduleInspector({
    super.key,
    required this.day,
    required this.slots,
    required this.locationById,
    required this.setById,
    required this.timeline,
    required this.dayArrivalMinute,
    required this.sunTimes,
    required this.crewNoteValue,
    required this.weatherNoteValue,
    required this.events,
    required this.eventLabelValueOf,
    required this.eventNotesValueOf,
    required this.onEventAdded,
    required this.onEventMinuteChanged,
    required this.onEventLabelChanged,
    required this.onEventNotesChanged,
    required this.onEventDeletionRequested,
    required this.onDayStatusChanged,
    required this.onCrewNoteChanged,
    required this.onWeatherNoteChanged,
    required this.shot,
    required this.shotSequenceLabel,
    required this.shotPlacedDayNumbers,
    required this.block,
    required this.blockShot,
    required this.blockSlotLabel,
    required this.blockEntry,
    required this.onShotStatusChanged,
    required this.onBlockDurationChanged,
    required this.blockCrewNoteValue,
    required this.onBlockCrewNoteChanged,
    required this.blockNotesValue,
    required this.onBlockNotesChanged,
    required this.isReadOnly,
  });

  /// Build the schedule inspector as a [ListView].
  @override
  Widget build(BuildContext context) {
    final block = this.block;
    final shot = this.shot;
    final day = this.day;
    if (block == null && shot == null && day == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            Tr.of(context).scheduleInspectorEmptyHint,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // One list at one place in the tree whichever kind is selected: a list of its own per kind
    // would be a new element each time, and the scroll position would go back to the top on every
    // switch of selection.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (block != null)
          _OcptScheduleBlockInspector(
            block: block,
            blockShot: blockShot,
            blockSlotLabel: blockSlotLabel,
            blockEntry: blockEntry,
            onShotStatusChanged: onShotStatusChanged,
            onBlockDurationChanged: onBlockDurationChanged,
            blockCrewNoteValue: blockCrewNoteValue,
            onBlockCrewNoteChanged: onBlockCrewNoteChanged,
            blockNotesValue: blockNotesValue,
            onBlockNotesChanged: onBlockNotesChanged,
          )
        else if (shot != null)
          _OcptScheduleShotInspector(
            shot: shot,
            shotSequenceLabel: shotSequenceLabel,
            shotPlacedDayNumbers: shotPlacedDayNumbers,
            onShotStatusChanged: onShotStatusChanged,
          )
        else
          _OcptScheduleDayInspector(
            day: day!,
            slots: slots,
            locationById: locationById,
            setById: setById,
            timeline: timeline,
            dayArrivalMinute: dayArrivalMinute,
            sunTimes: sunTimes,
            crewNoteValue: crewNoteValue,
            weatherNoteValue: weatherNoteValue,
            events: events,
            eventLabelValueOf: eventLabelValueOf,
            eventNotesValueOf: eventNotesValueOf,
            onEventAdded: onEventAdded,
            onEventMinuteChanged: onEventMinuteChanged,
            onEventLabelChanged: onEventLabelChanged,
            onEventNotesChanged: onEventNotesChanged,
            onEventDeletionRequested: onEventDeletionRequested,
            onDayStatusChanged: onDayStatusChanged,
            onCrewNoteChanged: onCrewNoteChanged,
            onWeatherNoteChanged: onWeatherNoteChanged,
          ),
      ],
    );
  }
}

/// The day inspector: date, status, locations, sets, slots, the arrival → the estimated end,
/// the sun times and the UTC offset they were computed with, its own events, weather note, crew
/// note.
class _OcptScheduleDayInspector extends StatelessWidget {
  /// The selected day.
  final OcptShootingDay day;

  /// The day's live slots, in `sortKey` order.
  final List<OcptShootingSlot> slots;

  /// The whole location catalogue, keyed by id.
  final Map<String, OcptLocation> locationById;

  /// The whole set catalogue, keyed by id.
  final Map<String, OcptSet> setById;

  /// The day's computed timetable, or null while nothing is placed.
  final OcptShootingDayTimelines? timeline;

  /// The day's earliest arrival, or null while it has no live slot.
  final int? dayArrivalMinute;

  /// The day's computed sun times, or null while unknown.
  final OcptSunTimes? sunTimes;

  /// The day's crew note, as currently held.
  final String crewNoteValue;

  /// The day's weather note, as currently held.
  final String weatherNoteValue;

  /// The day's live events, ordered by hour.
  final List<OcptShootingDayEvent> events;

  /// Resolves an event's id to its label as currently held.
  final String Function(String eventId) eventLabelValueOf;

  /// Resolves an event's id to its notes as currently held.
  final String Function(String eventId) eventNotesValueOf;

  /// Called when the `+ Event` footer is clicked, or null while withheld.
  final VoidCallback? onEventAdded;

  /// Called with an event's id and its new minute, or null while withheld.
  final void Function(String eventId, int minute)? onEventMinuteChanged;

  /// Called with an event's id and its raw label text, or null while withheld.
  final void Function(String eventId, String rawValue)? onEventLabelChanged;

  /// Called with an event's id and its raw note text, or null while withheld.
  final void Function(String eventId, String rawValue)? onEventNotesChanged;

  /// Called with an event's id when its remove control is clicked, or null while withheld.
  final ValueChanged<String>? onEventDeletionRequested;

  /// Called with the status just picked, or null while withheld.
  final ValueChanged<OcptShootingDayStatus>? onDayStatusChanged;

  /// Called with the crew note's raw text, or null while withheld.
  final ValueChanged<String>? onCrewNoteChanged;

  /// Called with the weather note's raw text, or null while withheld.
  final ValueChanged<String>? onWeatherNoteChanged;

  /// Class constructor
  const _OcptScheduleDayInspector({
    required this.day,
    required this.slots,
    required this.locationById,
    required this.setById,
    required this.timeline,
    required this.dayArrivalMinute,
    required this.sunTimes,
    required this.crewNoteValue,
    required this.weatherNoteValue,
    required this.events,
    required this.eventLabelValueOf,
    required this.eventNotesValueOf,
    required this.onEventAdded,
    required this.onEventMinuteChanged,
    required this.onEventLabelChanged,
    required this.onEventNotesChanged,
    required this.onEventDeletionRequested,
    required this.onDayStatusChanged,
    required this.onCrewNoteChanged,
    required this.onWeatherNoteChanged,
  });

  /// Build the schedule day inspector as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final dateLabel = DateFormat.yMMMEd(
      Localizations.localeOf(context).toString(),
    ).format(day.date);
    final locationNames = {
      for (final slot in slots)
        if (slot.locationId != null) locationById[slot.locationId]?.name,
    }.whereType<String>().toList();
    final setNames = {
      for (final slot in slots)
        if (slot.setId != null) setById[slot.setId]?.name,
    }.whereType<String>().toList();
    final slotRangeLabels = {
      for (final slot in slots)
        slot.id: ocptScheduleDayMinuteRangeLabel(
          timeline?.bySlotId[slot.id]?.startMinute,
          timeline?.bySlotId[slot.id]?.endMinute,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr.scheduleInspectorDayTitle(ocptScheduleDayTagLabel(tr, day.dayNumber)),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 2),
        Text(dateLabel, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorStatusLabel,
          child: onDayStatusChanged == null
              ? Text(ocptShootingDayStatusLabel(tr, day.status), style: theme.textTheme.bodySmall)
              : PopupMenuButton<OcptShootingDayStatus>(
                  tooltip: "",
                  onSelected: onDayStatusChanged,
                  itemBuilder: (context) => [
                    for (final status in OcptShootingDayStatus.values)
                      PopupMenuItem<OcptShootingDayStatus>(
                        value: status,
                        child: Text(ocptShootingDayStatusLabel(tr, status)),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ocptShootingDayStatusLabel(tr, day.status),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ocptShootingDayStatusColor(context, day.status),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorLocationsLabel,
          child: Text(
            locationNames.isEmpty ? tr.scheduleDayNoLocation : locationNames.join(" → "),
            style: theme.textTheme.bodySmall,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorSetsLabel,
          child: Text(
            setNames.isEmpty ? tr.scheduleInspectorNoSets : setNames.join(", "),
            style: theme.textTheme.bodySmall,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorSlotsLabel,
          child: slots.isEmpty
              ? Text(tr.scheduleInspectorNoSlots, style: theme.textTheme.bodySmall)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final slot in slots)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          "${slot.label.isEmpty ? tr.scheduleInspectorUnnamedSlot : slot.label} · "
                          "${slotRangeLabels[slot.id]}",
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorArrivalToEndLabel,
          child: Text(
            ocptScheduleDayMinuteRangeLabel(dayArrivalMinute, timeline?.dayEndMinute),
            style: theme.textTheme.bodySmall,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorSunLabel,
          child: Text(ocptScheduleSunTimesLine(tr, sunTimes), style: theme.textTheme.bodySmall),
        ),
        if (events.isNotEmpty || onEventAdded != null)
          _OcptScheduleInspectorSection(
            label: tr.scheduleDayEventsSectionTitle,
            child: OcptScheduleDayEventsList(
              events: events,
              eventLabelValueOf: eventLabelValueOf,
              eventNotesValueOf: eventNotesValueOf,
              onEventAdded: onEventAdded,
              onEventMinuteChanged: onEventMinuteChanged,
              onEventLabelChanged: onEventLabelChanged,
              onEventNotesChanged: onEventNotesChanged,
              onEventDeletionRequested: onEventDeletionRequested,
            ),
          ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorWeatherLabel,
          child: _OcptScheduleNoteField(
            ownerId: day.id,
            value: weatherNoteValue,
            onChanged: onWeatherNoteChanged,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorCrewNoteLabel,
          child: _OcptScheduleNoteField(
            ownerId: day.id,
            value: crewNoteValue,
            onChanged: onCrewNoteChanged,
          ),
        ),
      ],
    );
  }
}

/// The block inspector: kind, (for a shot) its own code/size/characters and status control, the
/// computed start/end/duration, its own slot, its crew note (the one that prints) and its
/// private notes (the one that never does).
class _OcptScheduleBlockInspector extends StatelessWidget {
  /// The selected block.
  final OcptShootingDayBlock block;

  /// The shot [block] names, when it is a shot block.
  final OcptShot? blockShot;

  /// The label of the slot [block] sits in, or null while it sits in none.
  final String? blockSlotLabel;

  /// [block]'s computed timeline entry, or null while the day has no timeline yet.
  final OcptShootingTimelineEntry? blockEntry;

  /// Called with the status just picked for [blockShot], or null while withheld.
  final ValueChanged<OcptShotStatus>? onShotStatusChanged;

  /// Called with the new duration in minutes, or null while withheld.
  final ValueChanged<int>? onBlockDurationChanged;

  /// The block's crew note, as currently held.
  final String blockCrewNoteValue;

  /// Called with the crew note's raw text, or null while withheld.
  final ValueChanged<String>? onBlockCrewNoteChanged;

  /// The block's private notes, as currently held.
  final String blockNotesValue;

  /// Called with the notes' raw text, or null while withheld.
  final ValueChanged<String>? onBlockNotesChanged;

  /// Class constructor
  const _OcptScheduleBlockInspector({
    required this.block,
    required this.blockShot,
    required this.blockSlotLabel,
    required this.blockEntry,
    required this.onShotStatusChanged,
    required this.onBlockDurationChanged,
    required this.blockCrewNoteValue,
    required this.onBlockCrewNoteChanged,
    required this.blockNotesValue,
    required this.onBlockNotesChanged,
  });

  /// Build the schedule block inspector as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final blockShot = this.blockShot;
    final entry = blockEntry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(ocptShootingBlockKindLabel(tr, block.kind), style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        if (block.kind == OcptShootingBlockKind.shot && blockShot != null) ...[
          _OcptScheduleInspectorSection(
            label: tr.scheduleInspectorShotLabel,
            child: Text(
              "${blockShot.code} · ${blockShot.shotSize}",
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (blockShot.characters.isNotEmpty)
            _OcptScheduleInspectorSection(
              label: tr.scheduleInspectorCharactersLabel,
              child: Text(blockShot.characters.join(", "), style: theme.textTheme.bodySmall),
            ),
          _OcptScheduleInspectorSection(
            label: tr.scheduleInspectorShotStatusLabel,
            child: OcptScheduleShotStatusControl(
              status: blockShot.status,
              onChanged: onShotStatusChanged,
            ),
          ),
        ] else if (block.label.isNotEmpty)
          _OcptScheduleInspectorSection(
            label: tr.scheduleInspectorLabelLabel,
            child: Text(block.label, style: theme.textTheme.bodySmall),
          ),
        if (blockSlotLabel != null)
          _OcptScheduleInspectorSection(
            label: tr.scheduleInspectorSlotLabel,
            child: Text(blockSlotLabel!, style: theme.textTheme.bodySmall),
          ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorTimeLabel,
          child: Text(
            entry == null
                ? "—"
                : "${ocptScheduleDayMinuteRangeLabel(entry.startMinute, entry.endMinute)} · "
                      "${ocptFormatMinuteDuration(entry.durationMinutes)}",
            style: theme.textTheme.bodySmall,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorDurationLabel,
          child: entry == null
              ? Text("—", style: theme.textTheme.bodySmall)
              : _OcptScheduleBlockDurationField(
                  blockId: block.id,
                  durationMinutes: entry.durationMinutes,
                  onChanged: onBlockDurationChanged,
                ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorBlockCrewNoteLabel,
          child: _OcptScheduleNoteField(
            ownerId: block.id,
            value: blockCrewNoteValue,
            onChanged: onBlockCrewNoteChanged,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorNotesLabel,
          child: _OcptScheduleNoteField(
            ownerId: block.id,
            value: blockNotesValue,
            onChanged: onBlockNotesChanged,
          ),
        ),
      ],
    );
  }
}

/// The shot inspector: the top title is the very label a shot block itself wears
/// ([ocptShootingBlockKindLabel] of [OcptShootingBlockKind.shot]), then its own code/size, its
/// sequence, its characters (when it has any), its estimated duration, where it is placed, and
/// its status control — the same one [_OcptScheduleBlockInspector] uses.
class _OcptScheduleShotInspector extends StatelessWidget {
  /// The selected shot.
  final OcptShot shot;

  /// [shot]'s sequence, as the left dock heads it.
  final String? shotSequenceLabel;

  /// The day numbers [shot] is placed on, in ascending order.
  final List<int> shotPlacedDayNumbers;

  /// Called with the status just picked, or null while withheld.
  final ValueChanged<OcptShotStatus>? onShotStatusChanged;

  /// Class constructor
  const _OcptScheduleShotInspector({
    required this.shot,
    required this.shotSequenceLabel,
    required this.shotPlacedDayNumbers,
    required this.onShotStatusChanged,
  });

  /// Build the schedule shot inspector as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ocptShootingBlockKindLabel(tr, OcptShootingBlockKind.shot),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorShotLabel,
          child: Text("${shot.code} · ${shot.shotSize}", style: theme.textTheme.bodySmall),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorSequenceLabel,
          child: Text(shotSequenceLabel ?? "", style: theme.textTheme.bodySmall),
        ),
        if (shot.characters.isNotEmpty)
          _OcptScheduleInspectorSection(
            label: tr.scheduleInspectorCharactersLabel,
            child: Text(shot.characters.join(", "), style: theme.textTheme.bodySmall),
          ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorEstimatedDurationLabel,
          child: Text(
            ocptFormatShotDuration(shot.estimatedDurationMs),
            style: theme.textTheme.bodySmall,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorPlacementLabel,
          child: Text(
            shotPlacedDayNumbers.isEmpty
                ? tr.scheduleInspectorShotNotPlanned
                : shotPlacedDayNumbers.map((n) => ocptScheduleDayTagLabel(tr, n)).join(", "),
            style: theme.textTheme.bodySmall,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorShotStatusLabel,
          child: OcptScheduleShotStatusControl(status: shot.status, onChanged: onShotStatusChanged),
        ),
      ],
    );
  }
}

/// One labelled section of the inspector: an upper-case label over its content, mirroring the
/// mock's own `PAT → fin` / `Soleil` / `Météo` band.
class _OcptScheduleInspectorSection extends StatelessWidget {
  /// The section's own label.
  final String label;

  /// The section's own content.
  final Widget child;

  /// Class constructor
  const _OcptScheduleInspectorSection({required this.label, required this.child});

  /// Build the schedule inspector section as a [Padding].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          child,
        ],
      ),
    );
  }
}

/// A dense, multi-line text field for a note (a day's own weather or crew note, a block's own
/// notes), following the same controller-sync idiom as `OcptBreakdownHeader`'s own search field:
/// [value] is the field's current authoritative value, and the internal controller is only reset
/// to it when [ownerId] changes (the inspector now shows a different day or block) or when [value]
/// genuinely differs from what the controller already holds, so the caret never jumps mid-typing.
///
/// Reads as plain, selectable text with no field chrome at all while [onChanged] is null (a
/// project version being previewed read-only).
class _OcptScheduleNoteField extends StatefulWidget {
  /// The id of the day or block this field belongs to.
  final String ownerId;

  /// The field's current authoritative value.
  final String value;

  /// Called with the field's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const _OcptScheduleNoteField({
    required this.ownerId,
    required this.value,
    required this.onChanged,
  });

  /// Create the [_OcptScheduleNoteFieldState] holding the state of the schedule note field.
  @override
  State<_OcptScheduleNoteField> createState() => _OcptScheduleNoteFieldState();
}

/// The state of [_OcptScheduleNoteField]: owns the controller the class doc comment explains.
class _OcptScheduleNoteFieldState extends State<_OcptScheduleNoteField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  /// The [_OcptScheduleNoteField.ownerId] the controller was last synced against.
  late String _trackedOwnerId = widget.ownerId;

  /// Show the new note when the owner or its value differs from the text in the field.
  @override
  void didUpdateWidget(covariant _OcptScheduleNoteField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.ownerId != _trackedOwnerId || widget.value != _controller.text) {
      _controller.text = widget.value;
      _trackedOwnerId = widget.ownerId;
    }
  }

  /// Build the schedule note field as a [TextField].
  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    if (onChanged == null) {
      return SelectableText(
        widget.value.isEmpty ? "—" : widget.value,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return TextField(
      controller: _controller,
      onChanged: onChanged,
      maxLines: null,
      minLines: 2,
      style: Theme.of(context).textTheme.bodySmall,
      decoration: const InputDecoration(isDense: true),
    );
  }

  /// Dispose [_controller].
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// A field editing the selected block's own resolved duration, typed freely — `12` is a legal
/// figure here, which is the whole point of this field against the timetable row's own `±`
/// stepper (`_OcptScheduleDurationStepper`, `ocpt_schedule_timetable.dart`), which only ever moves
/// in steps of five.
///
/// Follows [_OcptScheduleNoteField]'s own controller-sync idiom ([blockId] resets the controller,
/// never mid-typing) and `OcptScheduleMinuteField`'s own commit-on-submit-or-focus-loss idiom,
/// guarded by [_OcptScheduleBlockDurationFieldState._lastReportedDurationMinutes] against the
/// double commit a submission's own focus loss would otherwise cause.
///
/// [durationMinutes] is the block's own **resolved** duration — the same figure the timetable's own
/// row prints (a shot block with no `durationMinutes` column of its own falls back to its shot's
/// own estimate) — so the field shows what a fresh edit is about to overwrite. A negative or
/// unparseable figure, or an empty submission, reverts the field to [durationMinutes]: there is no
/// "clear it back to the shot's own estimate" operation to dispatch, [durationMinutes] already
/// being that estimate whenever nothing overrides it.
///
/// Reads as plain text — [durationMinutes] formatted through [ocptFormatMinuteDuration] — with no
/// field chrome at all while [onChanged] is null (a project version being previewed read-only).
class _OcptScheduleBlockDurationField extends StatefulWidget {
  /// The id of the block this field belongs to.
  final String blockId;

  /// The block's own currently resolved duration, in minutes.
  final int durationMinutes;

  /// Called with the minutes just parsed once the field commits, or null while withheld.
  final ValueChanged<int>? onChanged;

  /// Class constructor
  const _OcptScheduleBlockDurationField({
    required this.blockId,
    required this.durationMinutes,
    required this.onChanged,
  });

  /// Create the [_OcptScheduleBlockDurationFieldState] holding the state of the schedule block
  /// duration field.
  @override
  State<_OcptScheduleBlockDurationField> createState() => _OcptScheduleBlockDurationFieldState();
}

/// The state of [_OcptScheduleBlockDurationField]: owns the controller and the focus-loss commit
/// the class doc comment explains.
class _OcptScheduleBlockDurationFieldState extends State<_OcptScheduleBlockDurationField> {
  /// The field's own text controller, seeded from
  /// [_OcptScheduleBlockDurationField.durationMinutes].
  late final TextEditingController _controller = TextEditingController(
    text: "${widget.durationMinutes}",
  );

  /// The field's own focus node, committing the moment it loses focus.
  final FocusNode _focusNode = FocusNode();

  /// The [_OcptScheduleBlockDurationField.blockId] the controller was last synced against.
  late String _trackedBlockId = widget.blockId;

  /// The value this field last reported — see `OcptScheduleMinuteField`'s own doc comment on why
  /// this, rather than [_OcptScheduleBlockDurationField.durationMinutes] itself, is what a fresh
  /// commit is compared against: a submission takes the focus off the field, which would otherwise
  /// commit the very same edit twice.
  late int _lastReportedDurationMinutes = widget.durationMinutes;

  /// Register [_onFocusChanged] as a listener of [_focusNode].
  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  /// Show the new duration in the field when the block or its duration changes and the field is not
  /// focused.
  @override
  void didUpdateWidget(covariant _OcptScheduleBlockDurationField oldWidget) {
    super.didUpdateWidget(oldWidget);

    final blockChanged = widget.blockId != _trackedBlockId;
    if (blockChanged || oldWidget.durationMinutes != widget.durationMinutes) {
      _trackedBlockId = widget.blockId;
      _lastReportedDurationMinutes = widget.durationMinutes;
      if (!_focusNode.hasFocus) {
        _controller.text = "${widget.durationMinutes}";
      }
    }
  }

  /// Build the schedule block duration field as a [SizedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onChanged = widget.onChanged;

    if (onChanged == null) {
      return Text(
        ocptFormatMinuteDuration(widget.durationMinutes),
        style: theme.textTheme.bodySmall,
      );
    }

    return SizedBox(
      width: 76,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onSubmitted: (_) => _commit(),
        keyboardType: TextInputType.number,
        style: theme.textTheme.bodySmall,
        decoration: const InputDecoration(isDense: true, suffixText: "min"),
      ),
    );
  }

  /// Commit the field's current text once it loses focus, mirroring `OcptScheduleMinuteField`'s
  /// own flush-on-focus-lost idiom.
  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  /// Parse the field's current text and report it, or revert the field to
  /// [_OcptScheduleBlockDurationField.durationMinutes]'s own formatted reading when the text is
  /// empty, unparseable or negative.
  void _commit() {
    final onChanged = widget.onChanged;
    if (onChanged == null) {
      return;
    }

    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed < 0) {
      _controller.text = "${widget.durationMinutes}";
      return;
    }

    _controller.text = "$parsed";
    if (parsed != _lastReportedDurationMinutes) {
      _lastReportedDurationMinutes = parsed;
      onChanged(parsed);
    }
  }

  /// Detach [_onFocusChanged] from [_focusNode], then dispose [_focusNode] and [_controller].
  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }
}
