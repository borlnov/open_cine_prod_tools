// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_day_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_view.dart';

/// The schedule's day centre view: the selected day's own summary band and its slot cards, each
/// with its own timetable — an [OcptScheduleDayView] wired to the mode bloc and to
/// [OcptScheduleDayBloc] — or a plain hint while no day is selected yet.
///
/// It watches the day bloc itself, since a typed field shows its pending edit: a keystroke redraws
/// this view and what else reads the day bloc, and nothing around them. Everything irreversible the
/// day view offers is only *asked*, through the `on…Requested` callbacks below: the mode owns the
/// confirmation dialogs, and the shot picker it opens.
class OcptScheduleDayCentreView extends StatelessWidget {
  /// The mode's state, which the selected day, its plan and the catalogues are read from.
  final OcptScheduleState state;

  /// Called with the id of the slot the user asked to delete.
  final ValueChanged<String> onSlotDeletionRequested;

  /// Called with the id of the block the user asked to delete.
  final ValueChanged<String> onBlockDeletionRequested;

  /// Called with the id of the day event the user asked to delete.
  final ValueChanged<String> onEventDeletionRequested;

  /// Called with the id of the slot the user asked to place a shot on.
  final ValueChanged<String> onShotBlockRequested;

  /// Class constructor
  const OcptScheduleDayCentreView({
    super.key,
    required this.state,
    required this.onSlotDeletionRequested,
    required this.onBlockDeletionRequested,
    required this.onEventDeletionRequested,
    required this.onShotBlockRequested,
  });

  @override
  Widget build(BuildContext context) {
    final day = state.selectedDay;
    if (day == null) {
      return Center(
        child: Text(
          Tr.of(context).scheduleInspectorEmptyHint,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    final bloc = context.read<OcptScheduleBloc>();
    final dayBloc = context.read<OcptScheduleDayBloc>();
    final dayState = context.watch<OcptScheduleDayBloc>().state;
    final isReadOnly = state.isPreviewingVersion;

    return OcptScheduleDayView(
      day: day,
      slots: state.selectedDaySlots,
      blocks: state.selectedDayBlocks,
      timeline: state.timelinesOfDay(day.id),
      dayArrivalMinute: state.dayArrivalMinute(day.id),
      sunTimes: state.sunTimesOfDay(day.id),
      alerts: state.alertsOfDay(day.id),
      locationById: state.locationById,
      setById: state.setById,
      locations: state.locations,
      personById: state.personById,
      roleById: state.roleById,
      roleCandidateById: state.roleCandidateById,
      people: state.people,
      roles: state.roles,
      shotOf: state.shotById,
      selectedBlockId: state.selectedBlockId,
      sequences: state.sceneSequences,
      slotLabelValueOf: (slotId) {
        final slot = state.selectedDaySlots.firstWhere((candidate) => candidate.id == slotId);
        return dayState.fieldValueOf(slotId, OcptScheduleField.slotLabel, slot.label);
      },
      slotNotesValueOf: (slotId) {
        final slot = state.selectedDaySlots.firstWhere((candidate) => candidate.id == slotId);
        return dayState.fieldValueOf(slotId, OcptScheduleField.slotNotes, slot.notes);
      },
      onSlotAdded: isReadOnly
          ? null
          : () => dayBloc.add(OcptScheduleSlotCreatedEvent(dayId: day.id)),
      onSlotLabelChanged: isReadOnly
          ? null
          : (slotId, rawValue) => dayBloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: slotId,
                field: OcptScheduleField.slotLabel,
                rawValue: rawValue,
              ),
            ),
      onSlotNotesChanged: isReadOnly
          ? null
          : (slotId, rawValue) => dayBloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: slotId,
                field: OcptScheduleField.slotNotes,
                rawValue: rawValue,
              ),
            ),
      onSlotPlaceChanged: isReadOnly
          ? null
          : (slotId, locationId, setId) => dayBloc.add(
              OcptScheduleSlotPlaceChangedEvent(
                slotId: slotId,
                locationId: locationId,
                setId: setId,
              ),
            ),
      onSlotAnchorChanged: isReadOnly
          ? null
          : (slotId, edge, minute, sourceSlotId) => dayBloc.add(
              OcptScheduleSlotAnchorChangedEvent(
                slotId: slotId,
                edge: edge,
                minute: minute,
                sourceSlotId: sourceSlotId,
              ),
            ),
      onSlotMoved: isReadOnly
          ? null
          : (slotId, newPosition) => dayBloc.add(
              OcptScheduleSlotReorderedEvent(
                dayId: day.id,
                slotId: slotId,
                newPosition: newPosition,
              ),
            ),
      onSlotDeletionRequested: isReadOnly ? null : onSlotDeletionRequested,
      onSlotCrewMemberAdded: isReadOnly
          ? null
          : (slotId, personId) => dayBloc.add(
              OcptScheduleSlotCrewMemberAddedEvent(slotId: slotId, personId: personId),
            ),
      onSlotCrewMemberPositionChanged: isReadOnly
          ? null
          : (crewMemberId, position) => dayBloc.add(
              OcptScheduleSlotCrewMemberPositionChangedEvent(
                crewMemberId: crewMemberId,
                positionId: position.positionId,
                customLabel: position.customLabel,
              ),
            ),
      onSlotCrewMemberRemoved: isReadOnly
          ? null
          : (crewMemberId) =>
                dayBloc.add(OcptScheduleSlotCrewMemberRemovedEvent(crewMemberId: crewMemberId)),
      onSlotCastRoleAdded: isReadOnly
          ? null
          : (slotId, roleId) =>
                dayBloc.add(OcptScheduleSlotCastRoleAddedEvent(slotId: slotId, roleId: roleId)),
      onSlotCastRoleRemoved: isReadOnly
          ? null
          : (castRoleId) =>
                dayBloc.add(OcptScheduleSlotCastRoleRemovedEvent(castRoleId: castRoleId)),
      onSlotGuestAdded: isReadOnly
          ? null
          : (slotId, personId) =>
                dayBloc.add(OcptScheduleSlotGuestAddedEvent(slotId: slotId, personId: personId)),
      onSlotGuestRemoved: isReadOnly
          ? null
          : (guestId) => dayBloc.add(OcptScheduleSlotGuestRemovedEvent(guestId: guestId)),
      slotGuestReasonValueOf: (guestId) => dayState.fieldValueOf(
        guestId,
        OcptScheduleField.guestReason,
        state.selectedDayGuestOf(guestId)?.reason ?? "",
      ),
      onSlotGuestReasonChanged: isReadOnly
          ? null
          : (guestId, rawValue) => dayBloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: guestId,
                field: OcptScheduleField.guestReason,
                rawValue: rawValue,
              ),
            ),
      slotGuestNotesValueOf: (guestId) => dayState.fieldValueOf(
        guestId,
        OcptScheduleField.guestNotes,
        state.selectedDayGuestOf(guestId)?.notes ?? "",
      ),
      onSlotGuestNotesChanged: isReadOnly
          ? null
          : (guestId, rawValue) => dayBloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: guestId,
                field: OcptScheduleField.guestNotes,
                rawValue: rawValue,
              ),
            ),
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
      onEventAdded: isReadOnly
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
      onBlockSelected: (blockId) =>
          bloc.add(OcptScheduleBlockSelectedEvent(blockId: blockId, dayId: day.id)),
      onBlockReordered: isReadOnly
          ? null
          : (blockId, newPosition) => dayBloc.add(
              OcptScheduleBlockReorderedEvent(blockId: blockId, newPosition: newPosition),
            ),
      onBlockDurationChanged: isReadOnly
          ? null
          : (blockId, durationMinutes) => dayBloc.add(
              OcptScheduleBlockDurationChangedEvent(
                blockId: blockId,
                durationMinutes: durationMinutes,
              ),
            ),
      onBlockAnchorChanged: isReadOnly
          ? null
          : (blockId, anchorMinute) => dayBloc.add(
              OcptScheduleBlockAnchorChangedEvent(blockId: blockId, anchorMinute: anchorMinute),
            ),
      onShotStatusChanged: isReadOnly
          ? null
          : (shotId, status) =>
                dayBloc.add(OcptScheduleShotStatusChangedEvent(shotId: shotId, status: status)),
      onBlockSequenceChanged: isReadOnly
          ? null
          : (blockId, sceneId) => dayBloc.add(
              OcptScheduleBlockSequenceChangedEvent(blockId: blockId, sceneId: sceneId),
            ),
      onBlockCandidateAdded: isReadOnly
          ? null
          : (blockId, roleCandidateId) => dayBloc.add(
              OcptScheduleBlockCandidateAddedEvent(
                blockId: blockId,
                roleCandidateId: roleCandidateId,
              ),
            ),
      onBlockCandidateRemoved: isReadOnly
          ? null
          : (blockCandidateId) => dayBloc.add(
              OcptScheduleBlockCandidateRemovedEvent(blockCandidateId: blockCandidateId),
            ),
      onBlockDeletionRequested: isReadOnly ? null : onBlockDeletionRequested,
      onBlockAdded: isReadOnly
          ? null
          : (slotId, kind) =>
                dayBloc.add(OcptScheduleBlockCreatedEvent(slotId: slotId, kind: kind)),
      onShotBlockRequested: isReadOnly ? null : onShotBlockRequested,
      onBlockMovedToSlot: isReadOnly
          ? null
          : (blockId, targetSlotId) => dayBloc.add(
              OcptScheduleBlockMovedToSlotEvent(blockId: blockId, targetSlotId: targetSlotId),
            ),
      // Never withheld under a version preview: selecting a dock tab writes nothing, and an alert
      // is exactly what a reader of a previewed plan is looking for.
      onAlertsOpenRequested: () => bloc.add(
        const OcptScheduleRightDockTabSelectedEvent(tab: OcptScheduleRightDockTab.alerts),
      ),
    );
  }
}
