// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_timetable.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// The day view: the mode's real working surface (`docs/plans/schedule-mode.md` §8) — the day's
/// own summary band, one [OcptScheduleSlotCard] per slot with its own `+ Slot` footer, then
/// [OcptScheduleTimetable].
///
/// Every writing affordance every one of its children exposes is threaded through as a nullable
/// callback, withheld while a project version is being previewed — this widget itself withholds
/// none on its own account, since it draws nothing that writes by itself.
class OcptScheduleDayView extends StatelessWidget {
  /// The day this view shows.
  final OcptShootingDay day;

  /// [day]'s own live slots, in `sortKey` order.
  final List<OcptShootingSlot> slots;

  /// [day]'s own live blocks — its timetable — in `sortKey` order.
  final List<OcptShootingDayBlock> blocks;

  /// [day]'s own computed timetable, or null while it has nothing placed yet.
  final OcptShootingDayTimelines? timeline;

  /// [day]'s own computed sun times, or null while its first slot has no location with
  /// coordinates.
  final OcptSunTimes? sunTimes;

  /// The whole location catalogue, keyed by id.
  final Map<String, OcptLocation> locationById;

  /// The whole set catalogue, keyed by id.
  final Map<String, OcptSet> setById;

  /// The whole location catalogue, in display order — what a slot card's own location picker
  /// offers.
  final List<OcptLocation> locations;

  /// The whole address book, keyed by id.
  final Map<String, OcptPerson> personById;

  /// The whole cast, keyed by id.
  final Map<String, OcptRole> roleById;

  /// The whole address book, in display order.
  final List<OcptPerson> people;

  /// The whole cast, in display order.
  final List<OcptRole> roles;

  /// Resolves a shot id to the shot it names.
  final OcptShot? Function(String shotId) shotOf;

  /// The id of the currently selected block, or null while none is.
  final String? selectedBlockId;

  /// Resolves a slot's id to its own label, as currently held (a pending edit, or its stored
  /// value).
  final String Function(String slotId) slotLabelValueOf;

  /// Called when the `+ Slot` control is clicked, or null while withheld.
  final VoidCallback? onSlotAdded;

  /// Called with a slot's id and its raw label text on every keystroke, or null while withheld.
  final void Function(String slotId, String rawValue)? onSlotLabelChanged;

  /// Called with a slot's id and the location/set just picked, or null while withheld.
  final void Function(String slotId, String? locationId, String? setId)? onSlotPlaceChanged;

  /// Called with a slot's id and its crew call/wrap band just committed, or null while withheld.
  final void Function(String slotId, int callMinute, int wrapMinute)? onSlotCrewTimesChanged;

  /// Called with a slot's id and its default PAT band just committed, or null while withheld.
  final void Function(String slotId, int? castCallMinute, int? castWrapMinute)? onSlotCastTimesChanged;

  /// Called with a slot's id when its own `Delete this slot…` action is picked, or null while
  /// withheld.
  final ValueChanged<String>? onSlotDeletionRequested;

  /// Called with a slot's id and the id of the person picked by its own `+ Crew member` footer, or
  /// null while withheld.
  final void Function(String slotId, String personId)? onSlotCrewMemberAdded;

  /// Called with a crew assignment's id and the catalogue position just picked, or null while
  /// withheld.
  final void Function(String crewMemberId, String positionId)? onSlotCrewMemberPositionChanged;

  /// Called with a crew assignment's id and its own call/wrap override just committed, or null
  /// while withheld.
  final void Function(String crewMemberId, int? callMinute, int? wrapMinute)?
  onSlotCrewMemberTimesChanged;

  /// Called with a crew assignment's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onSlotCrewMemberRemoved;

  /// Called with a slot's id and the id of the role picked by its own `+ Cast` footer, or null
  /// while withheld.
  final void Function(String slotId, String roleId)? onSlotCastRoleAdded;

  /// Called with a cast convocation's id and its own arrival/PAT overrides just committed, or null
  /// while withheld.
  final void Function(String castRoleId, int? arrivalMinute, int? castCallMinute, int? castWrapMinute)?
  onSlotCastRoleTimesChanged;

  /// Called with a cast convocation's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onSlotCastRoleRemoved;

  /// Called with a block's id when its row is clicked.
  final ValueChanged<String> onBlockSelected;

  /// Called with a block's id and its 0-based new position once a drag-to-reorder gesture ends, or
  /// null while withheld.
  final void Function(String blockId, int newPosition)? onBlockReordered;

  /// Called with a block's id and its own new duration once a `±` control is tapped, or null while
  /// withheld.
  final void Function(String blockId, int durationMinutes)? onBlockDurationChanged;

  /// Called with a block's id and its own new anchor once the pin is toggled or the pinned minute
  /// is retyped, or null while withheld.
  final void Function(String blockId, int? anchorMinute)? onBlockAnchorChanged;

  /// Called with a shot block's own shot id and the status just picked, or null while withheld.
  final void Function(String shotId, OcptShotStatus status)? onShotStatusChanged;

  /// Called with a block's id when its own remove control is clicked, or null while withheld.
  final ValueChanged<String>? onBlockDeletionRequested;

  /// Called with the kind just picked from the timetable's own `+ Block` menu, or null while
  /// withheld.
  final ValueChanged<OcptShootingBlockKind>? onBlockAdded;

  /// Class constructor
  const OcptScheduleDayView({
    super.key,
    required this.day,
    required this.slots,
    required this.blocks,
    required this.timeline,
    required this.sunTimes,
    required this.locationById,
    required this.setById,
    required this.locations,
    required this.personById,
    required this.roleById,
    required this.people,
    required this.roles,
    required this.shotOf,
    required this.selectedBlockId,
    required this.slotLabelValueOf,
    required this.onSlotAdded,
    required this.onSlotLabelChanged,
    required this.onSlotPlaceChanged,
    required this.onSlotCrewTimesChanged,
    required this.onSlotCastTimesChanged,
    required this.onSlotDeletionRequested,
    required this.onSlotCrewMemberAdded,
    required this.onSlotCrewMemberPositionChanged,
    required this.onSlotCrewMemberTimesChanged,
    required this.onSlotCrewMemberRemoved,
    required this.onSlotCastRoleAdded,
    required this.onSlotCastRoleTimesChanged,
    required this.onSlotCastRoleRemoved,
    required this.onBlockSelected,
    required this.onBlockReordered,
    required this.onBlockDurationChanged,
    required this.onBlockAnchorChanged,
    required this.onShotStatusChanged,
    required this.onBlockDeletionRequested,
    required this.onBlockAdded,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return ListView(
      children: [
        _buildSummaryBand(context),
        const SizedBox(height: 16),
        for (final slot in slots)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: OcptScheduleSlotCard(
              slot: slot,
              location: slot.locationId == null ? null : locationById[slot.locationId],
              set: slot.setId == null ? null : setById[slot.setId],
              locations: locations,
              personById: personById,
              roleById: roleById,
              people: people,
              roles: roles.where((role) => !slot.cast.any((cast) => cast.roleId == role.id)).toList(),
              labelValue: slotLabelValueOf(slot.id),
              onLabelChanged: onSlotLabelChanged == null
                  ? null
                  : (value) => onSlotLabelChanged!(slot.id, value),
              onPlaceChanged: onSlotPlaceChanged == null
                  ? null
                  : (locationId, setId) => onSlotPlaceChanged!(slot.id, locationId, setId),
              onCrewTimesChanged: onSlotCrewTimesChanged == null
                  ? null
                  : (call, wrap) => onSlotCrewTimesChanged!(slot.id, call, wrap),
              onCastTimesChanged: onSlotCastTimesChanged == null
                  ? null
                  : (call, wrap) => onSlotCastTimesChanged!(slot.id, call, wrap),
              onDeletionRequested: onSlotDeletionRequested == null
                  ? null
                  : () => onSlotDeletionRequested!(slot.id),
              onCrewMemberAdded: onSlotCrewMemberAdded == null
                  ? null
                  : (personId) => onSlotCrewMemberAdded!(slot.id, personId),
              onCrewMemberPositionChanged: onSlotCrewMemberPositionChanged,
              onCrewMemberTimesChanged: onSlotCrewMemberTimesChanged,
              onCrewMemberRemoved: onSlotCrewMemberRemoved,
              onCastRoleAdded: onSlotCastRoleAdded == null
                  ? null
                  : (roleId) => onSlotCastRoleAdded!(slot.id, roleId),
              onCastRoleTimesChanged: onSlotCastRoleTimesChanged,
              onCastRoleRemoved: onSlotCastRoleRemoved,
            ),
          ),
        if (onSlotAdded != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton.icon(
              onPressed: onSlotAdded,
              icon: const Icon(Icons.add, size: 16),
              label: Text(tr.scheduleAddSlotAction),
            ),
          ),
        Text(
          tr.scheduleTimetableTitle.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 7),
        OcptScheduleTimetable(
          blocks: blocks,
          timeline: timeline,
          shotOf: shotOf,
          selectedBlockId: selectedBlockId,
          onBlockSelected: onBlockSelected,
          onReordered: onBlockReordered,
          onDurationChanged: onBlockDurationChanged,
          onAnchorChanged: onBlockAnchorChanged,
          onShotStatusChanged: onShotStatusChanged,
          onDeletionRequested: onBlockDeletionRequested,
          onBlockAdded: onBlockAdded,
        ),
        if (day.crewNote.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(day.crewNote, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// The day's own summary band: call → estimated end, sun times, weather and the total (shot
  /// count and duration of presence).
  Widget _buildSummaryBand(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final firstCallMinute = slots.isEmpty ? null : slots.first.crewCallMinute;
    final shotBlocks = blocks.where((block) => block.kind == OcptShootingBlockKind.shot).length;
    final dayEndMinute = timeline?.dayEndMinute;
    final totalLabel = dayEndMinute == null || firstCallMinute == null
        ? tr.scheduleDayNoShotsPlaced
        : tr.scheduleDaySummaryTotal(shotBlocks, ocptFormatMinuteDuration(dayEndMinute - firstCallMinute));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Wrap(
        spacing: 26,
        runSpacing: 10,
        children: [
          _buildSummaryField(
            context,
            tr.scheduleInspectorPatToEndLabel,
            ocptScheduleDayMinuteRangeLabel(firstCallMinute, dayEndMinute),
          ),
          _buildSummaryField(context, tr.scheduleInspectorSunLabel, ocptScheduleSunTimesLine(tr, sunTimes)),
          _buildSummaryField(
            context,
            tr.scheduleInspectorWeatherLabel,
            day.weatherNote.isEmpty ? "—" : day.weatherNote,
          ),
          _buildSummaryField(context, tr.scheduleDaySummaryTotalLabel, totalLabel),
        ],
      ),
    );
  }

  /// One labelled field of the summary band.
  Widget _buildSummaryField(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 3),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
