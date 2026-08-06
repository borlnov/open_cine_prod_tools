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
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_group.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_groups_band.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_timetable.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// The day view: the mode's real working surface (`docs/plans/schedule-mode.md` §8) — the day's own
/// summary band, then [OcptScheduleGroupsBand] (M2'), then one [OcptScheduleSlotCard] per slot with
/// its own `+ Slot` footer. A day used to draw one shared [OcptScheduleTimetable] of its own beneath
/// every card; it no longer does (M2') — each card now draws its own, over that slot's own blocks
/// alone, so [blocks] and [timeline] here only ever feed the summary band's own totals and each
/// card's own slice of them.
///
/// Every writing affordance every one of its children exposes is threaded through as a nullable
/// callback, withheld while a project version is being previewed — this widget itself withholds
/// none on its own account, since it draws nothing that writes by itself.
class OcptScheduleDayView extends StatelessWidget {
  /// The day this view shows.
  final OcptShootingDay day;

  /// [day]'s own live slots, in `sortKey` order.
  final List<OcptShootingSlot> slots;

  /// [day]'s own live groups, in `sortKey` order — what [OcptScheduleGroupsBand] lists and what
  /// every slot card's own crew/cast group pickers offer.
  final List<OcptShootingDayGroup> groups;

  /// How many live crew and cast rows of [day] currently point at each group, keyed by id —
  /// `OcptScheduleState.groupMemberCountsOfDay`'s own read, handed straight to
  /// [OcptScheduleGroupsBand].
  final Map<String, int> groupMemberCounts;

  /// [day]'s own live blocks, across every slot, in `sortKey` order — read here for the summary
  /// band's own totals, and handed whole to every [OcptScheduleSlotCard], each of which filters
  /// them down to its own [OcptShootingSlot.id] before drawing its own [OcptScheduleTimetable].
  final List<OcptShootingDayBlock> blocks;

  /// [day]'s own computed timelines, one chain per slot, or null while it has no live slot to chain
  /// at all — read here only for the summary band's own [OcptShootingDayTimelines.dayEndMinute];
  /// each slot card reads its own [OcptShootingDayTimelines.bySlotId] entry instead.
  final OcptShootingDayTimelines? timeline;

  /// [day]'s own earliest arrival — the minimum crew/cast convocation arrival across every live
  /// slot, or the earliest slot start while nobody is convoked yet
  /// (`OcptScheduleState.dayArrivalMinute`) — or null while it has no live slot at all. Read here
  /// for the summary band's own arrival-to-end range and its own total duration.
  final int? dayArrivalMinute;

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

  /// Every real scene of the screenplay's shot list — what a **hold** row's own timetable sequence
  /// picker offers, handed straight to every [OcptScheduleSlotCard]. See
  /// `OcptScheduleTimetable.sequences`.
  final List<OcptSceneShotSequence> sequences;

  /// Resolves a slot's id to its own label, as currently held (a pending edit, or its stored
  /// value).
  final String Function(String slotId) slotLabelValueOf;

  /// Resolves a group's id to its own label, as currently held (a pending edit, or its stored
  /// value) — [OcptScheduleGroupsBand]'s own `labelValueOf`.
  final String Function(String groupId) groupLabelValueOf;

  /// Resolves a slot's id to its own computed convocations (ADR 0017), or null while none could be
  /// computed yet — what each slot card's own crew/cast read-outs are drawn from.
  final OcptSlotConvocations? Function(String slotId) slotConvocationsOf;

  /// Called when the `+ Slot` control is clicked, or null while withheld.
  final VoidCallback? onSlotAdded;

  /// Called with a slot's id and its raw label text on every keystroke, or null while withheld.
  final void Function(String slotId, String rawValue)? onSlotLabelChanged;

  /// Called with a slot's id and the location/set just picked, or null while withheld.
  final void Function(String slotId, String? locationId, String? setId)? onSlotPlaceChanged;

  /// Called with a slot's id and its own new start minute once committed, or null while withheld.
  final void Function(String slotId, int startMinute)? onSlotStartChanged;

  /// Called with a slot's id when its own `Delete this slot…` action is picked, or null while
  /// withheld.
  final ValueChanged<String>? onSlotDeletionRequested;

  /// Called with a group's id and its raw label text on every keystroke, or null while withheld —
  /// [OcptScheduleGroupsBand]'s own `onLabelChanged`.
  final void Function(String groupId, String rawValue)? onGroupLabelChanged;

  /// Called with a group's id and its own new lead time once committed, or null while withheld.
  final void Function(String groupId, int leadMinutes)? onGroupLeadChanged;

  /// Called when the groups band's own `+ Group` control is clicked, or null while withheld.
  final VoidCallback? onGroupAdded;

  /// Called with a group's id when its own delete control is clicked, or null while withheld.
  final ValueChanged<String>? onGroupDeletionRequested;

  /// Called with a slot's id and the id of the person picked by its own `+ Crew member` footer, or
  /// null while withheld.
  final void Function(String slotId, String personId)? onSlotCrewMemberAdded;

  /// Called with a crew assignment's id and the catalogue position just picked, or null while
  /// withheld.
  final void Function(String crewMemberId, String positionId)? onSlotCrewMemberPositionChanged;

  /// Called with a crew assignment's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onSlotCrewMemberRemoved;

  /// Called with a crew assignment's id and its own new lead time (null to clear it), or null while
  /// withheld.
  final void Function(String crewMemberId, int? leadMinutes)? onSlotCrewMemberLeadChanged;

  /// Called with a crew assignment's id and the group just picked (null for "no group"), or null
  /// while withheld.
  final void Function(String crewMemberId, String? groupId)? onSlotCrewMemberGroupChanged;

  /// Called with a slot's id and the id of the role picked by its own `+ Cast` footer, or null
  /// while withheld.
  final void Function(String slotId, String roleId)? onSlotCastRoleAdded;

  /// Called with a cast convocation's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onSlotCastRoleRemoved;

  /// Called with a cast convocation's id and its own new lead time (null to clear it), or null
  /// while withheld.
  final void Function(String castRoleId, int? leadMinutes)? onSlotCastRoleLeadChanged;

  /// Called with a cast convocation's id and the group just picked (null for "no group"), or null
  /// while withheld.
  final void Function(String castRoleId, String? groupId)? onSlotCastRoleGroupChanged;

  /// Called with a block's id when its row is clicked.
  final ValueChanged<String> onBlockSelected;

  /// Called with a block's id and its 0-based new position once a drag-to-reorder gesture ends
  /// within its own slot, or null while withheld.
  final void Function(String blockId, int newPosition)? onBlockReordered;

  /// Called with a block's id and its own new duration once a `±` control is tapped, or null while
  /// withheld.
  final void Function(String blockId, int durationMinutes)? onBlockDurationChanged;

  /// Called with a block's id and its own new anchor once the pin is toggled or the pinned minute
  /// is retyped, or null while withheld.
  final void Function(String blockId, int? anchorMinute)? onBlockAnchorChanged;

  /// Called with a shot block's own shot id and the status just picked, or null while withheld.
  final void Function(String shotId, OcptShotStatus status)? onShotStatusChanged;

  /// Called with a **hold** block's id and the scene just picked from its own timetable row's
  /// sequence picker, or null while withheld — see `OcptScheduleTimetable.onHoldSequenceChanged`.
  final void Function(String blockId, String? sceneId)? onBlockSequenceChanged;

  /// Called with a block's id when its own remove control is clicked, or null while withheld.
  final ValueChanged<String>? onBlockDeletionRequested;

  /// Called with a slot's id and the kind just picked from that slot card's own `+ Block` menu —
  /// the new block lands in **that** slot — or null while withheld.
  final void Function(String slotId, OcptShootingBlockKind kind)? onBlockAdded;

  /// Called with a slot's id when that slot card's own `+ Block` menu's `Shot` entry is picked, or
  /// null while withheld — see [OcptScheduleSlotCard.onShotBlockRequested].
  final void Function(String slotId)? onShotBlockRequested;

  /// Called with a block's id and the id of the slot it is moved to, dispatched by a cross-slot drag
  /// or by a row's own `Move to…` menu, or null while withheld — see
  /// [OcptScheduleTimetable.onBlockMovedToSlot].
  final void Function(String blockId, String targetSlotId)? onBlockMovedToSlot;

  /// Class constructor
  const OcptScheduleDayView({
    super.key,
    required this.day,
    required this.slots,
    required this.groups,
    required this.groupMemberCounts,
    required this.blocks,
    required this.timeline,
    required this.dayArrivalMinute,
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
    required this.sequences,
    required this.slotLabelValueOf,
    required this.groupLabelValueOf,
    required this.slotConvocationsOf,
    required this.onSlotAdded,
    required this.onSlotLabelChanged,
    required this.onSlotPlaceChanged,
    required this.onSlotStartChanged,
    required this.onSlotDeletionRequested,
    required this.onGroupLabelChanged,
    required this.onGroupLeadChanged,
    required this.onGroupAdded,
    required this.onGroupDeletionRequested,
    required this.onSlotCrewMemberAdded,
    required this.onSlotCrewMemberPositionChanged,
    required this.onSlotCrewMemberRemoved,
    required this.onSlotCrewMemberLeadChanged,
    required this.onSlotCrewMemberGroupChanged,
    required this.onSlotCastRoleAdded,
    required this.onSlotCastRoleRemoved,
    required this.onSlotCastRoleLeadChanged,
    required this.onSlotCastRoleGroupChanged,
    required this.onBlockSelected,
    required this.onBlockReordered,
    required this.onBlockDurationChanged,
    required this.onBlockAnchorChanged,
    required this.onShotStatusChanged,
    required this.onBlockSequenceChanged,
    required this.onBlockDeletionRequested,
    required this.onBlockAdded,
    required this.onShotBlockRequested,
    required this.onBlockMovedToSlot,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return ListView(
      children: [
        _buildSummaryBand(context),
        const SizedBox(height: 16),
        OcptScheduleGroupsBand(
          groups: groups,
          memberCountByGroupId: groupMemberCounts,
          labelValueOf: groupLabelValueOf,
          onLabelChanged: onGroupLabelChanged,
          onLeadChanged: onGroupLeadChanged,
          onGroupAdded: onGroupAdded,
          onGroupDeletionRequested: onGroupDeletionRequested,
        ),
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
              groups: groups,
              convocations: slotConvocationsOf(slot.id),
              labelValue: slotLabelValueOf(slot.id),
              onLabelChanged: onSlotLabelChanged == null
                  ? null
                  : (value) => onSlotLabelChanged!(slot.id, value),
              onPlaceChanged: onSlotPlaceChanged == null
                  ? null
                  : (locationId, setId) => onSlotPlaceChanged!(slot.id, locationId, setId),
              onStartChanged: onSlotStartChanged == null
                  ? null
                  : (startMinute) => onSlotStartChanged!(slot.id, startMinute),
              onDeletionRequested: onSlotDeletionRequested == null
                  ? null
                  : () => onSlotDeletionRequested!(slot.id),
              onCrewMemberAdded: onSlotCrewMemberAdded == null
                  ? null
                  : (personId) => onSlotCrewMemberAdded!(slot.id, personId),
              onCrewMemberPositionChanged: onSlotCrewMemberPositionChanged,
              onCrewMemberRemoved: onSlotCrewMemberRemoved,
              onCrewMemberLeadChanged: onSlotCrewMemberLeadChanged,
              onCrewMemberGroupChanged: onSlotCrewMemberGroupChanged,
              onCastRoleAdded: onSlotCastRoleAdded == null
                  ? null
                  : (roleId) => onSlotCastRoleAdded!(slot.id, roleId),
              onCastRoleRemoved: onSlotCastRoleRemoved,
              onCastRoleLeadChanged: onSlotCastRoleLeadChanged,
              onCastRoleGroupChanged: onSlotCastRoleGroupChanged,
              blocks: blocks,
              timeline: timeline?.bySlotId[slot.id],
              shotOf: shotOf,
              selectedBlockId: selectedBlockId,
              sequences: sequences,
              otherSlots: [
                for (final other in slots)
                  if (other.id != slot.id) (other.id, slotLabelValueOf(other.id)),
              ],
              onBlockSelected: onBlockSelected,
              onBlockReordered: onBlockReordered,
              onBlockDurationChanged: onBlockDurationChanged,
              onBlockAnchorChanged: onBlockAnchorChanged,
              onShotStatusChanged: onShotStatusChanged,
              onBlockSequenceChanged: onBlockSequenceChanged,
              onBlockDeletionRequested: onBlockDeletionRequested,
              onBlockAdded: onBlockAdded == null ? null : (kind) => onBlockAdded!(slot.id, kind),
              onShotBlockRequested: onShotBlockRequested == null
                  ? null
                  : () => onShotBlockRequested!(slot.id),
              onBlockMovedToSlot: onBlockMovedToSlot,
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
        if (day.crewNote.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(day.crewNote, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// The day's own summary band: arrival → estimated end, sun times, weather and the total (shot
  /// count and duration of presence).
  Widget _buildSummaryBand(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final shotBlocks = blocks.where((block) => block.kind == OcptShootingBlockKind.shot).length;
    final dayEndMinute = timeline?.dayEndMinute;
    final totalLabel = dayEndMinute == null || dayArrivalMinute == null
        ? tr.scheduleDayNoShotsPlaced
        : tr.scheduleDaySummaryTotal(shotBlocks, ocptFormatMinuteDuration(dayEndMinute - dayArrivalMinute!));

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
            tr.scheduleInspectorArrivalToEndLabel,
            ocptScheduleDayMinuteRangeLabel(dayArrivalMinute, dayEndMinute),
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
