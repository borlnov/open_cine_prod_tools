// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_entry.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_day_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_inspector.dart';

/// The `Inspector` tab's own content: the selected block's read-out, else the selected shot's own,
/// else the selected day's — see [OcptScheduleInspector]'s own doc comment for why that order. It
/// is wired to the mode's state and to [OcptScheduleDayBloc].
///
/// It watches the day bloc itself, since a typed field shows its pending edit: a keystroke redraws
/// this view and what else reads the day bloc, and nothing around them. Deleting an event is only
/// *asked*, through [onEventDeletionRequested]: the mode owns the confirmation dialog.
class OcptScheduleInspectorView extends StatelessWidget {
  /// The mode's state, which the selection, the plan and the catalogues are read from.
  final OcptScheduleState state;

  /// Called with the id of the day event the user asked to delete.
  final ValueChanged<String> onEventDeletionRequested;

  /// Class constructor
  const OcptScheduleInspectorView({
    super.key,
    required this.state,
    required this.onEventDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptScheduleBloc>();
    final dayBloc = context.read<OcptScheduleDayBloc>();
    final dayState = context.watch<OcptScheduleDayBloc>().state;
    final isReadOnly = state.isPreviewingVersion;
    final block = state.selectedBlock;
    final blockShot = block?.shotId == null ? null : state.shotById(block!.shotId!);
    String? blockSlotLabel;
    if (block?.slotId != null) {
      for (final slot in state.selectedDaySlots) {
        if (slot.id == block!.slotId) {
          blockSlotLabel = slot.label;
          break;
        }
      }
    }
    OcptShootingTimelineEntry? blockEntry;
    if (block != null) {
      final entries =
          state.timelinesOfDay(state.selectedDayId ?? "")?.entries ??
          const <OcptShootingTimelineEntry>[];
      for (final entry in entries) {
        if (entry.blockId == block.id) {
          blockEntry = entry;
          break;
        }
      }
    }

    final shot = state.selectedShot;
    final shotSequenceLabel = shot == null ? null : _sequenceLabelOfShot(context, shot);
    final shotPlacedDayNumbers = shot == null
        ? const <int>[]
        : state.placedDayNumbersByShotId[shot.id] ?? const [];

    // The two selections are mutually exclusive (`OcptScheduleBloc` keeps them so), so exactly one
    // of `blockShot`/`shot` is ever non-null: this is what feeds the status control either
    // read-out shows.
    final effectiveShot = blockShot ?? shot;

    final day = state.selectedDay;

    return OcptScheduleInspector(
      day: day,
      slots: state.selectedDaySlots,
      locationById: state.locationById,
      setById: state.setById,
      timeline: state.selectedDayId == null ? null : state.timelinesOfDay(state.selectedDayId!),
      dayArrivalMinute: state.selectedDayId == null
          ? null
          : state.dayArrivalMinute(state.selectedDayId!),
      sunTimes: state.selectedDayId == null ? null : state.sunTimesOfDay(state.selectedDayId!),
      crewNoteValue: day == null
          ? ""
          : dayState.fieldValueOf(day.id, OcptScheduleField.dayCrewNote, day.crewNote),
      weatherNoteValue: day == null
          ? ""
          : dayState.fieldValueOf(day.id, OcptScheduleField.dayWeatherNote, day.weatherNote),
      events: state.selectedDayEvents,
      eventLabelValueOf: (eventId) => dayState.fieldValueOf(
        eventId,
        OcptScheduleField.dayEventLabel,
        state.selectedDayEventOf(eventId)?.label ?? "",
      ),
      eventNotesValueOf: (eventId) => dayState.fieldValueOf(
        eventId,
        OcptScheduleField.dayEventNotes,
        state.selectedDayEventOf(eventId)?.notes ?? "",
      ),
      onEventAdded: isReadOnly || day == null
          ? null
          : () => dayBloc.add(
              OcptScheduleDayEventCreatedEvent(
                dayId: day.id,
                minute: state.newEventMinuteOf(day.id),
              ),
            ),
      onEventMinuteChanged: isReadOnly
          ? null
          : (eventId, minute) => dayBloc.add(
              OcptScheduleDayEventMinuteChangedEvent(eventId: eventId, minute: minute),
            ),
      onEventLabelChanged: isReadOnly
          ? null
          : (eventId, rawValue) => dayBloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: eventId,
                field: OcptScheduleField.dayEventLabel,
                rawValue: rawValue,
              ),
            ),
      onEventNotesChanged: isReadOnly
          ? null
          : (eventId, rawValue) => dayBloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: eventId,
                field: OcptScheduleField.dayEventNotes,
                rawValue: rawValue,
              ),
            ),
      onEventDeletionRequested: isReadOnly ? null : onEventDeletionRequested,
      onDayStatusChanged: isReadOnly || day == null
          ? null
          : (status) => bloc.add(OcptScheduleDayStatusChangedEvent(dayId: day.id, status: status)),
      onCrewNoteChanged: isReadOnly || day == null
          ? null
          : (rawValue) => dayBloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: day.id,
                field: OcptScheduleField.dayCrewNote,
                rawValue: rawValue,
              ),
            ),
      onWeatherNoteChanged: isReadOnly || day == null
          ? null
          : (rawValue) => dayBloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: day.id,
                field: OcptScheduleField.dayWeatherNote,
                rawValue: rawValue,
              ),
            ),
      shot: shot,
      shotSequenceLabel: shotSequenceLabel,
      shotPlacedDayNumbers: shotPlacedDayNumbers,
      block: block,
      blockShot: blockShot,
      blockSlotLabel: blockSlotLabel,
      blockEntry: blockEntry,
      onShotStatusChanged: isReadOnly || effectiveShot == null
          ? null
          : (status) => dayBloc.add(
              OcptScheduleShotStatusChangedEvent(shotId: effectiveShot.id, status: status),
            ),
      onBlockDurationChanged: isReadOnly || block == null
          ? null
          : (durationMinutes) => dayBloc.add(
              OcptScheduleBlockDurationChangedEvent(
                blockId: block.id,
                durationMinutes: durationMinutes,
              ),
            ),
      blockCrewNoteValue: block == null
          ? ""
          : dayState.fieldValueOf(block.id, OcptScheduleField.blockCrewNote, block.crewNote),
      onBlockCrewNoteChanged: isReadOnly || block == null
          ? null
          : (rawValue) => dayBloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: block.id,
                field: OcptScheduleField.blockCrewNote,
                rawValue: rawValue,
              ),
            ),
      blockNotesValue: block == null
          ? ""
          : dayState.fieldValueOf(block.id, OcptScheduleField.blockNotes, block.notes),
      onBlockNotesChanged: isReadOnly || block == null
          ? null
          : (rawValue) => dayBloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: block.id,
                field: OcptScheduleField.blockNotes,
                rawValue: rawValue,
              ),
            ),
      isReadOnly: isReadOnly,
    );
  }

  /// [shot]'s own sequence label, exactly as the left dock heads that sequence's own section of the
  /// unplaced-shots list (`Tr.scheduleUnplacedSequenceLabel`/`Tr.scheduleUnplacedOrphanGroupLabel`
  /// plus the heading) — resolved here, out of [OcptScheduleState.shotListSnapshots], rather than
  /// by the inspector itself, so a widget never has to search the snapshot on its own. Null while
  /// [shot]'s own sequence isn't found there (its episode's shot list hasn't loaded yet).
  String? _sequenceLabelOfShot(BuildContext context, OcptShot shot) {
    final tr = Tr.of(context);

    for (final shotListSnapshot in state.shotListSnapshots) {
      for (final sequence in shotListSnapshot.sequences) {
        if (!sequence.shots.any((candidate) => candidate.id == shot.id)) {
          continue;
        }

        if (sequence is OcptSceneShotSequence) {
          final tag = tr.scheduleUnplacedSequenceLabel(sequence.displaySceneNumber);
          return sequence.heading.isEmpty ? tag : "$tag  ${sequence.heading}";
        }

        return tr.scheduleUnplacedOrphanGroupLabel;
      }
    }

    return null;
  }
}
