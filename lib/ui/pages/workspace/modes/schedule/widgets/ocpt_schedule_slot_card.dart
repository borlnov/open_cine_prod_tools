// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_group.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_lead_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_timetable.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// The value the "no location" entry of the location picker menu carries, distinct from every
/// location id — a [PopupMenuButton] cannot carry a null value for an entry that must still be
/// selectable.
const String _noLocationOption = "";

/// The value the "no group" entry of a crew or cast row's own group picker menu carries, distinct
/// from every group id — the same convention as [_noLocationOption], for the same reason.
const String _noGroupOption = "";

/// One slot's own card in the day view: its label, its location and set, its own **start**
/// minute — the one clock left on a slot (§2.4 of
/// `docs/plans/schedule-slots-and-computed-convocations.md`) — then the two columns
/// `docs/plans/schedule-mode.md` §8 and Benoit's own M1 decision #1 ask for — `Équipe technique`,
/// grouped by department, and `Comédiens` — each ending on its own `+ Crew member`/`+ Cast` footer
/// opening a person or role picker right there on the card, with no duplicate list anywhere in the
/// right dock — and, below both, this slot's **own** [OcptScheduleTimetable] (M2'): a day used to
/// carry one timetable shared by every slot; now each card draws its own, over its own [blocks]
/// alone, chained by its own [timeline].
///
/// **A crew or cast row's own arrival and PAT band are read-outs, never fields**: they are
/// [convocations]' own computed answer (ADR 0017) for that row, and moving a block is what changes
/// them — there is nothing to type into for either band. The one editable clock on the whole card
/// is the slot's own start ([onStartChanged]); what a row *does* edit is its own **cause**: a lead
/// time ([OcptScheduleLeadField]) and a group picked from [groups] — a row with no lead time of its
/// own reads its group's, already folded into its own [convocations] entry, so the row shows it
/// muted and in italics rather than blank (see [OcptScheduleLeadField]'s own doc comment).
///
/// Every writing affordance is a nullable callback, withheld while a project version is being
/// previewed (`isReadOnly`): the label field, the location/set pickers, the start field, every
/// crew/cast row's own position picker, lead field, group picker and remove control, both `+`
/// footers, and every writing affordance of the timetable itself, its own hold row's sequence
/// picker included (see [OcptScheduleTimetable]'s own doc comment). Nothing here reads a
/// `pendingFieldEdits` map itself — [labelValue] is already resolved by the caller, exactly as
/// every other mode's own sheet fields are.
class OcptScheduleSlotCard extends StatelessWidget {
  /// The slot this card shows.
  final OcptShootingSlot slot;

  /// [slot]'s own location, or null while none is chosen.
  final OcptLocation? location;

  /// [slot]'s own set, or null while none is chosen.
  final OcptSet? set;

  /// The whole location catalogue (with their sets) — what the location/set pickers offer.
  final List<OcptLocation> locations;

  /// The whole address book, keyed by id — what a crew row's own name is read off.
  final Map<String, OcptPerson> personById;

  /// The whole cast, keyed by id — what a cast row's own name is read off.
  final Map<String, OcptRole> roleById;

  /// The whole address book, in display order — what the `+ Crew member` picker offers.
  final List<OcptPerson> people;

  /// The whole cast, in display order — what the `+ Cast` picker offers, already excluding the
  /// roles [slot] already convokes.
  final List<OcptRole> roles;

  /// [slot]'s own day's live groups, in `sortKey` order — what a crew or cast row's own group
  /// picker offers.
  final List<OcptShootingDayGroup> groups;

  /// [slot]'s own computed convocations (ADR 0017), or null while none could be computed yet —
  /// what every crew and cast row's own read-out is drawn from.
  final OcptSlotConvocations? convocations;

  /// [slot]'s own label, as currently held (a pending edit, or its stored value).
  final String labelValue;

  /// Called with the label's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onLabelChanged;

  /// Called with the location and set just picked, or null while withheld.
  final void Function(String? locationId, String? setId)? onPlaceChanged;

  /// Called with the slot's own new start minute once committed, or null while withheld.
  final ValueChanged<int>? onStartChanged;

  /// Called when the `Delete this slot…` action is picked, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Called with the id of the person picked by the `+ Crew member` footer, or null while withheld.
  final ValueChanged<String>? onCrewMemberAdded;

  /// Called with a crew assignment's id and the catalogue position just picked, or null while
  /// withheld.
  final void Function(String crewMemberId, String positionId)? onCrewMemberPositionChanged;

  /// Called with a crew assignment's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCrewMemberRemoved;

  /// Called with a crew assignment's id and its own new lead time (null to clear it back to
  /// reading its group's), once its row's own [OcptScheduleLeadField] commits, or null while
  /// withheld.
  final void Function(String crewMemberId, int? leadMinutes)? onCrewMemberLeadChanged;

  /// Called with a crew assignment's id and the group just picked (null for "no group"), or null
  /// while withheld.
  final void Function(String crewMemberId, String? groupId)? onCrewMemberGroupChanged;

  /// Called with the id of the role picked by the `+ Cast` footer, or null while withheld.
  final ValueChanged<String>? onCastRoleAdded;

  /// Called with a cast convocation's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCastRoleRemoved;

  /// Called with a cast convocation's id and its own new lead time (null to clear it back to
  /// reading its group's), once its row's own [OcptScheduleLeadField] commits, or null while
  /// withheld.
  final void Function(String castRoleId, int? leadMinutes)? onCastRoleLeadChanged;

  /// Called with a cast convocation's id and the group just picked (null for "no group"), or null
  /// while withheld.
  final void Function(String castRoleId, String? groupId)? onCastRoleGroupChanged;

  /// [slot]'s own **day**'s live blocks, across every slot, in `sortKey` order — this card filters
  /// them down to [slot]'s own before handing them to its own [OcptScheduleTimetable], so a caller
  /// never has to pre-slice the day's blocks itself.
  final List<OcptShootingDayBlock> blocks;

  /// [slot]'s own computed timeline, or null while it has nothing placed yet.
  final OcptShootingSlotTimeline? timeline;

  /// Resolves a shot id to the shot it names.
  final OcptShot? Function(String shotId) shotOf;

  /// The id of the currently selected block, or null while none is.
  final String? selectedBlockId;

  /// Every real scene of the screenplay's shot list — what a **hold** row's own timetable sequence
  /// picker offers. See [OcptScheduleTimetable.sequences].
  final List<OcptSceneShotSequence> sequences;

  /// The day's own other live slots, by id and by raw label — see
  /// [OcptScheduleTimetable.otherSlots].
  final List<(String, String)> otherSlots;

  /// Called with a block's id when its row is clicked.
  final ValueChanged<String> onBlockSelected;

  /// Called with a block's id and its 0-based new position once a drag-to-reorder gesture ends
  /// within this slot, or null while withheld.
  final void Function(String blockId, int newPosition)? onBlockReordered;

  /// Called with a block's id and its own new duration once a `±` control is tapped, or null while
  /// withheld.
  final void Function(String blockId, int durationMinutes)? onBlockDurationChanged;

  /// Called with a block's id and its own new anchor once the pin is toggled, or null while
  /// withheld.
  final void Function(String blockId, int? anchorMinute)? onBlockAnchorChanged;

  /// Called with a shot block's own shot id and the status just picked, or null while withheld.
  final void Function(String shotId, OcptShotStatus status)? onShotStatusChanged;

  /// Called with a **hold** block's id and the scene just picked from its own timetable row's
  /// sequence picker, or null while withheld — see [OcptScheduleTimetable.onHoldSequenceChanged].
  final void Function(String blockId, String? sceneId)? onBlockSequenceChanged;

  /// Called with a block's id when its own remove control is clicked, or null while withheld.
  final ValueChanged<String>? onBlockDeletionRequested;

  /// Called with the kind just picked from the timetable's own `+ Block` menu — the new block lands
  /// in **this** slot — or null while withheld.
  final ValueChanged<OcptShootingBlockKind>? onBlockAdded;

  /// Called when the timetable's own `+ Block` menu's `Shot` entry is picked, or null while
  /// withheld — see [OcptScheduleTimetable.onShotBlockRequested].
  final VoidCallback? onShotBlockRequested;

  /// Called with a block's id and the id of the slot it is moved to, or null while withheld — see
  /// [OcptScheduleTimetable.onBlockMovedToSlot].
  final void Function(String blockId, String targetSlotId)? onBlockMovedToSlot;

  /// Class constructor
  const OcptScheduleSlotCard({
    super.key,
    required this.slot,
    required this.location,
    required this.set,
    required this.locations,
    required this.personById,
    required this.roleById,
    required this.people,
    required this.roles,
    required this.groups,
    required this.convocations,
    required this.labelValue,
    required this.onLabelChanged,
    required this.onPlaceChanged,
    required this.onStartChanged,
    required this.onDeletionRequested,
    required this.onCrewMemberAdded,
    required this.onCrewMemberPositionChanged,
    required this.onCrewMemberRemoved,
    required this.onCrewMemberLeadChanged,
    required this.onCrewMemberGroupChanged,
    required this.onCastRoleAdded,
    required this.onCastRoleRemoved,
    required this.onCastRoleLeadChanged,
    required this.onCastRoleGroupChanged,
    required this.blocks,
    required this.timeline,
    required this.shotOf,
    required this.selectedBlockId,
    required this.sequences,
    required this.otherSlots,
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
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final tint = ocptScheduleDayLocationTint(context, location);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: theme.colorScheme.surfaceContainer,
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  constraints: const BoxConstraints(minHeight: 30),
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 11),
                Expanded(child: _buildHeaderFields(context)),
                const SizedBox(width: 11),
                _buildTimesColumn(context),
                if (onDeletionRequested != null)
                  PopupMenuButton<VoidCallback>(
                    icon: const Icon(Icons.more_vert, size: 16),
                    tooltip: "",
                    padding: EdgeInsets.zero,
                    onSelected: (action) => action(),
                    itemBuilder: (context) => [
                      PopupMenuItem<VoidCallback>(
                        value: onDeletionRequested,
                        child: Text(tr.scheduleDeleteSlotAction),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            child: Wrap(
              spacing: 22,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: 320,
                  child: _buildCrewColumn(context),
                ),
                SizedBox(
                  width: 230,
                  child: _buildCastColumn(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 11),
            child: _buildTimetable(context),
          ),
        ],
      ),
    );
  }

  /// This slot's own timetable, below its crew and cast columns — see the class doc comment.
  Widget _buildTimetable(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.scheduleTimetableTitle.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 7),
        OcptScheduleTimetable(
          slotId: slot.id,
          blocks: [
            for (final block in blocks)
              if (block.slotId == slot.id) block,
          ],
          timeline: timeline,
          shotOf: shotOf,
          selectedBlockId: selectedBlockId,
          sequences: sequences,
          otherSlots: otherSlots,
          onBlockSelected: onBlockSelected,
          onReordered: onBlockReordered,
          onDurationChanged: onBlockDurationChanged,
          onAnchorChanged: onBlockAnchorChanged,
          onShotStatusChanged: onShotStatusChanged,
          onHoldSequenceChanged: onBlockSequenceChanged,
          onDeletionRequested: onBlockDeletionRequested,
          onBlockAdded: onBlockAdded,
          onShotBlockRequested: onShotBlockRequested,
          onBlockMovedToSlot: onBlockMovedToSlot,
        ),
      ],
    );
  }

  /// The header's own label field and location/set pickers.
  Widget _buildHeaderFields(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onLabelChanged = this.onLabelChanged;
    final onPlaceChanged = this.onPlaceChanged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: onLabelChanged == null
              ? Text(
                  labelValue.isEmpty ? tr.scheduleInspectorUnnamedSlot : labelValue,
                  style: theme.textTheme.titleSmall,
                )
              : _OcptScheduleSlotLabelField(
                  key: ValueKey(slot.id),
                  value: labelValue,
                  hintText: tr.scheduleInspectorUnnamedSlot,
                  onChanged: onLabelChanged,
                ),
        ),
        const SizedBox(height: 6),
        // Every entry of this row is flexible and every name ellipsizes: the card narrows with the
        // centre whenever the inspector opens, and a location and a set named at full length would
        // otherwise push straight through the times column beside them.
        Row(
          children: [
            Flexible(
              child: onPlaceChanged == null
                  ? _buildPlaceName(context, location?.name ?? tr.scheduleDayNoLocation)
                  : PopupMenuButton<String>(
                      tooltip: "",
                      onSelected: (value) => onPlaceChanged(
                        value == _noLocationOption ? null : value,
                        null,
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: _noLocationOption,
                          child: Text(tr.scheduleDayNoLocation),
                        ),
                        const PopupMenuDivider(),
                        for (final candidate in locations)
                          PopupMenuItem<String>(value: candidate.id, child: Text(candidate.name)),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: _buildPlaceName(
                              context,
                              location?.name ?? tr.scheduleDayNoLocation,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 16),
                        ],
                      ),
                    ),
            ),
            if (location != null) ...[
              const SizedBox(width: 6),
              Text("·", style: theme.textTheme.bodySmall),
              const SizedBox(width: 6),
              Flexible(
                child: onPlaceChanged == null
                    ? _buildPlaceName(context, set?.name ?? tr.scheduleInspectorNoSets)
                    : PopupMenuButton<String>(
                        tooltip: "",
                        onSelected: (value) =>
                            onPlaceChanged(location!.id, value == _noLocationOption ? null : value),
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: _noLocationOption,
                            child: Text(tr.scheduleInspectorNoSets),
                          ),
                          const PopupMenuDivider(),
                          for (final candidate in location!.sets)
                            PopupMenuItem<String>(value: candidate.id, child: Text(candidate.name)),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: _buildPlaceName(
                                context,
                                set?.name ?? tr.scheduleInspectorNoSets,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ),
                      ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// One name of the header's own location · set line, ellipsized on a single line.
  Widget _buildPlaceName(BuildContext context, String name) => Text(
    name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodySmall,
  );

  /// The header's own start field — the one clock a slot still carries, right-aligned.
  Widget _buildTimesColumn(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("${tr.scheduleSlotCrewBandLabel} ", style: theme.textTheme.labelSmall),
        OcptScheduleMinuteField(
          minute: slot.startMinute,
          isClearable: false,
          emptyHint: "—",
          onChanged: onStartChanged == null
              ? null
              : (value) => onStartChanged!(value ?? slot.startMinute),
        ),
      ],
    );
  }

  /// The `Équipe technique` column: [slot]'s own crew rows grouped by department, then the
  /// `+ Crew member` footer.
  Widget _buildCrewColumn(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final byDepartment = <OcptCrewDepartment?, List<OcptShootingSlotCrewMember>>{};
    for (final member in slot.crew) {
      final department = ocptCrewPositionDepartmentOf(member.positionId);
      byDepartment.putIfAbsent(department, () => []).add(member);
    }
    final convocationById = {
      for (final convocation in convocations?.crew ?? const <OcptCrewConvocation>[])
        convocation.id: convocation,
    };
    final groupById = {for (final group in groups) group.id: group};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.scheduleSlotCrewColumnTitle.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 7),
        if (slot.crew.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              tr.scheduleSlotCrewEmptyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          for (final department in byDepartment.keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    department == null
                        ? tr.scheduleSlotUnassignedDepartmentLabel
                        : ocptCrewDepartmentLabel(tr, department),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  for (final member in byDepartment[department]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _OcptScheduleCrewMemberRow(
                        key: ValueKey(member.id),
                        member: member,
                        person: personById[member.personId],
                        convocation: convocationById[member.id],
                        groups: groups,
                        groupById: groupById,
                        onPositionChanged: onCrewMemberPositionChanged == null
                            ? null
                            : (positionId) => onCrewMemberPositionChanged!(member.id, positionId),
                        onRemoved: onCrewMemberRemoved == null
                            ? null
                            : () => onCrewMemberRemoved!(member.id),
                        onLeadChanged: onCrewMemberLeadChanged == null
                            ? null
                            : (leadMinutes) => onCrewMemberLeadChanged!(member.id, leadMinutes),
                        onGroupChanged: onCrewMemberGroupChanged == null
                            ? null
                            : (groupId) => onCrewMemberGroupChanged!(member.id, groupId),
                      ),
                    ),
                ],
              ),
            ),
        if (onCrewMemberAdded != null)
          PopupMenuButton<String>(
            tooltip: "",
            onSelected: onCrewMemberAdded,
            itemBuilder: (context) => [
              for (final person in people)
                PopupMenuItem<String>(
                  value: person.id,
                  child: Text(
                    person.displayName.isEmpty ? tr.resourcesUnnamedPerson : person.displayName,
                  ),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 14),
                const SizedBox(width: 4),
                Text(tr.scheduleAddCrewMemberAction, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }

  /// The `Comédiens` column: [slot]'s own convoked roles, then the `+ Cast` footer.
  Widget _buildCastColumn(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final convocationById = {
      for (final convocation in convocations?.cast ?? const <OcptCastConvocation>[])
        convocation.id: convocation,
    };
    final groupById = {for (final group in groups) group.id: group};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.scheduleSlotCastColumnTitle.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 7),
        if (slot.cast.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              tr.scheduleSlotCastEmptyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          for (final member in slot.cast)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _OcptScheduleCastRoleRow(
                key: ValueKey(member.id),
                member: member,
                role: roleById[member.roleId],
                person: roleById[member.roleId]?.personId == null
                    ? null
                    : personById[roleById[member.roleId]!.personId],
                convocation: convocationById[member.id],
                groups: groups,
                groupById: groupById,
                onRemoved: onCastRoleRemoved == null ? null : () => onCastRoleRemoved!(member.id),
                onLeadChanged: onCastRoleLeadChanged == null
                    ? null
                    : (leadMinutes) => onCastRoleLeadChanged!(member.id, leadMinutes),
                onGroupChanged: onCastRoleGroupChanged == null
                    ? null
                    : (groupId) => onCastRoleGroupChanged!(member.id, groupId),
              ),
            ),
        if (onCastRoleAdded != null)
          PopupMenuButton<String>(
            tooltip: "",
            onSelected: onCastRoleAdded,
            itemBuilder: (context) => [
              for (final role in roles)
                PopupMenuItem<String>(value: role.id, child: Text(role.name)),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 14),
                const SizedBox(width: 4),
                Text(tr.scheduleAddCastAction, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }
}

/// One crew card of [OcptScheduleSlotCard]'s own `Équipe technique` column, built exactly like
/// [_OcptScheduleCastRoleRow]'s own card (see [_buildSlotPersonCard]): the position picker and the
/// remove control on the first line, the person's own name underneath, then its own computed
/// arrival/PAT band read-out (see [_buildConvocationTimesRow]) and, on their own line, its own
/// **cause** — a lead time and a group picker (see [_buildLeadAndGroupRow]).
class _OcptScheduleCrewMemberRow extends StatelessWidget {
  /// The crew assignment this row shows.
  final OcptShootingSlotCrewMember member;

  /// The person [member] names, or null while not yet loaded.
  final OcptPerson? person;

  /// This row's own computed convocation, or null while it hasn't been computed yet — what its
  /// arrival/PAT band read-out, and its lead field's own inherited figure, are drawn from.
  final OcptCrewConvocation? convocation;

  /// The day's own live groups — what this row's own group picker offers.
  final List<OcptShootingDayGroup> groups;

  /// [groups], keyed by id — what this row's own currently picked group is looked up in.
  final Map<String, OcptShootingDayGroup> groupById;

  /// Called with the catalogue position just picked, or null while withheld.
  final ValueChanged<String>? onPositionChanged;

  /// Called when this row's remove control is clicked, or null while withheld.
  final VoidCallback? onRemoved;

  /// Called with this row's own new lead time (null to clear it back to reading its group's), or
  /// null while withheld.
  final ValueChanged<int?>? onLeadChanged;

  /// Called with the group just picked (null for "no group"), or null while withheld.
  final ValueChanged<String?>? onGroupChanged;

  /// Class constructor
  const _OcptScheduleCrewMemberRow({
    super.key,
    required this.member,
    required this.person,
    required this.convocation,
    required this.groups,
    required this.groupById,
    required this.onPositionChanged,
    required this.onRemoved,
    required this.onLeadChanged,
    required this.onGroupChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final positionLabel = member.positionId.isEmpty
        ? (member.customLabel.isEmpty ? tr.resourcesPositionScopePlaceholder : member.customLabel)
        : ocptCrewPositionLabel(tr, member.positionId);
    final personName = person?.displayName.isEmpty ?? true
        ? tr.resourcesUnnamedPerson
        : person!.displayName;

    return _buildSlotPersonCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: onPositionChanged == null
                    ? Text(positionLabel, style: theme.textTheme.bodySmall)
                    : PopupMenuButton<String>(
                        tooltip: "",
                        onSelected: onPositionChanged,
                        itemBuilder: (context) => [
                          for (final position in ocptCrewPositions)
                            PopupMenuItem<String>(
                              value: position.id,
                              child: Text(ocptCrewPositionLabel(tr, position.id)),
                            ),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                positionLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 14),
                          ],
                        ),
                      ),
              ),
              if (onRemoved != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  visualDensity: VisualDensity.compact,
                  tooltip: tr.scheduleRemoveCrewMemberTooltip,
                  onPressed: onRemoved,
                ),
            ],
          ),
          Text(
            personName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          _buildConvocationTimesRow(
            context,
            tr,
            theme,
            arrivalMinute: convocation?.arrivalMinute,
            patStartMinute: convocation?.patStartMinute,
            patEndMinute: convocation?.patEndMinute,
          ),
          const SizedBox(height: 3),
          _buildLeadAndGroupRow(
            context,
            tr,
            theme,
            leadMinutes: member.leadMinutes,
            inheritedLeadMinutes: convocation?.leadMinutes,
            onLeadChanged: onLeadChanged,
            currentGroupId: member.groupId,
            groups: groups,
            groupById: groupById,
            onGroupChanged: onGroupChanged,
          ),
        ],
      ),
    );
  }
}

/// One cast card of [OcptScheduleSlotCard]'s own `Comédiens` column, its layout shared with
/// [_OcptScheduleCrewMemberRow]'s own card (see [_buildSlotPersonCard]): the role's own name and
/// remove control on the first line, the cast actor's own name underneath, then its computed
/// arrival/PAT band read-out (see [_buildConvocationTimesRow]) and, on their own line, its own
/// **cause** — a lead time and a group picker (see [_buildLeadAndGroupRow]).
class _OcptScheduleCastRoleRow extends StatelessWidget {
  /// The cast convocation this row shows.
  final OcptShootingSlotCastMember member;

  /// The role [member] convokes, or null while not yet loaded.
  final OcptRole? role;

  /// The person cast in [role], or null while uncast (or not yet loaded).
  final OcptPerson? person;

  /// This row's own computed convocation, or null while it hasn't been computed yet — what its
  /// arrival/PAT read-out, and its lead field's own inherited figure, are drawn from.
  final OcptCastConvocation? convocation;

  /// The day's own live groups — what this row's own group picker offers.
  final List<OcptShootingDayGroup> groups;

  /// [groups], keyed by id — what this row's own currently picked group is looked up in.
  final Map<String, OcptShootingDayGroup> groupById;

  /// Called when this row's remove control is clicked, or null while withheld.
  final VoidCallback? onRemoved;

  /// Called with this row's own new lead time (null to clear it back to reading its group's), or
  /// null while withheld.
  final ValueChanged<int?>? onLeadChanged;

  /// Called with the group just picked (null for "no group"), or null while withheld.
  final ValueChanged<String?>? onGroupChanged;

  /// Class constructor
  const _OcptScheduleCastRoleRow({
    super.key,
    required this.member,
    required this.role,
    required this.person,
    required this.convocation,
    required this.groups,
    required this.groupById,
    required this.onRemoved,
    required this.onLeadChanged,
    required this.onGroupChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return _buildSlotPersonCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  role?.name ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (onRemoved != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  visualDensity: VisualDensity.compact,
                  tooltip: tr.scheduleRemoveCastTooltip,
                  onPressed: onRemoved,
                ),
            ],
          ),
          Text(
            person == null ? tr.scheduleSlotCastUncastHint : person!.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: person == null ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          _buildConvocationTimesRow(
            context,
            tr,
            theme,
            arrivalMinute: convocation?.arrivalMinute,
            patStartMinute: convocation?.patStartMinute,
            patEndMinute: convocation?.patEndMinute,
          ),
          const SizedBox(height: 3),
          _buildLeadAndGroupRow(
            context,
            tr,
            theme,
            leadMinutes: member.leadMinutes,
            inheritedLeadMinutes: convocation?.leadMinutes,
            onLeadChanged: onLeadChanged,
            currentGroupId: member.groupId,
            groups: groups,
            groupById: groupById,
            onGroupChanged: onGroupChanged,
          ),
        ],
      ),
    );
  }
}

/// The slot card's own single-line label field, following the same controller-sync idiom as
/// `OcptScheduleInspector`'s own note field: [value] is the field's current authoritative value,
/// and the internal controller is only reset to it when it genuinely differs from what the
/// controller already holds, so the caret never jumps mid-typing.
class _OcptScheduleSlotLabelField extends StatefulWidget {
  /// The field's current authoritative value.
  final String value;

  /// The hint shown while [value] is empty.
  final String hintText;

  /// Called with the field's raw text on every keystroke.
  final ValueChanged<String> onChanged;

  /// Class constructor
  const _OcptScheduleSlotLabelField({
    super.key,
    required this.value,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<_OcptScheduleSlotLabelField> createState() => _OcptScheduleSlotLabelFieldState();
}

/// The state of [_OcptScheduleSlotLabelField]: owns the controller the class doc comment explains.
class _OcptScheduleSlotLabelFieldState extends State<_OcptScheduleSlotLabelField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _OcptScheduleSlotLabelField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: widget.onChanged,
    style: Theme.of(context).textTheme.titleSmall,
    decoration: InputDecoration(isDense: true, hintText: widget.hintText),
  );
}

/// The bordered card shell shared by [_OcptScheduleCrewMemberRow] and [_OcptScheduleCastRoleRow]:
/// the one place their common border, radius and padding are declared, so the two kinds of card
/// cannot drift from one another.
Widget _buildSlotPersonCard(BuildContext context, {required Widget child}) {
  final theme = Theme.of(context);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: theme.colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
    ),
    child: child,
  );
}

/// A crew or cast card's own computed arrival + PAT band read-out, shared by
/// [_OcptScheduleCrewMemberRow] and [_OcptScheduleCastRoleRow]: three permanently read-only
/// [OcptScheduleMinuteField]s (`onChanged: null`, ADR 0017 — there is nothing here to type into),
/// wrapped over as many lines as the card's own width allows.
Widget _buildConvocationTimesRow(
  BuildContext context,
  Tr tr,
  ThemeData theme, {
  required int? arrivalMinute,
  required int? patStartMinute,
  required int? patEndMinute,
}) => Wrap(
  crossAxisAlignment: WrapCrossAlignment.center,
  spacing: 4,
  runSpacing: 2,
  children: [
    Text("${tr.scheduleSlotArrivalLabel} ", style: theme.textTheme.labelSmall),
    OcptScheduleMinuteField(minute: arrivalMinute, isClearable: false, emptyHint: "—", onChanged: null),
    Text("${tr.scheduleSlotPatBandLabel} ", style: theme.textTheme.labelSmall),
    OcptScheduleMinuteField(
      minute: patStartMinute,
      isClearable: false,
      emptyHint: "—",
      onChanged: null,
    ),
    Text(" – ", style: theme.textTheme.labelSmall),
    OcptScheduleMinuteField(minute: patEndMinute, isClearable: false, emptyHint: "—", onChanged: null),
  ],
);

/// A crew or cast card's own lead time + group line, shared by [_OcptScheduleCrewMemberRow] and
/// [_OcptScheduleCastRoleRow]: the row's own **cause** behind [_buildConvocationTimesRow]'s computed
/// read-out (ADR 0017) — an [OcptScheduleLeadField] then [_buildGroupPicker], on their own line
/// under the times.
Widget _buildLeadAndGroupRow(
  BuildContext context,
  Tr tr,
  ThemeData theme, {
  required int? leadMinutes,
  required int? inheritedLeadMinutes,
  required ValueChanged<int?>? onLeadChanged,
  required String? currentGroupId,
  required List<OcptShootingDayGroup> groups,
  required Map<String, OcptShootingDayGroup> groupById,
  required ValueChanged<String?>? onGroupChanged,
}) => Wrap(
  crossAxisAlignment: WrapCrossAlignment.center,
  spacing: 4,
  runSpacing: 2,
  children: [
    Text("${tr.scheduleLeadTimeLabel} ", style: theme.textTheme.labelSmall),
    OcptScheduleLeadField(
      leadMinutes: leadMinutes,
      inheritedLeadMinutes: inheritedLeadMinutes,
      isClearable: true,
      onChanged: onLeadChanged,
    ),
    const SizedBox(width: 6),
    _buildGroupPicker(
      context,
      tr,
      theme,
      currentGroupId: currentGroupId,
      groups: groups,
      groupById: groupById,
      onChanged: onGroupChanged,
    ),
  ],
);

/// A crew or cast row's own group picker, shared by [_OcptScheduleCrewMemberRow] and
/// [_OcptScheduleCastRoleRow]: [currentGroupId]'s own label (or [_noGroupOption]'s "no group" one),
/// opening onto every one of [groups] plus that same "no group" entry when [onChanged] is given, or
/// plain read-only text while it is withheld.
Widget _buildGroupPicker(
  BuildContext context,
  Tr tr,
  ThemeData theme, {
  required String? currentGroupId,
  required List<OcptShootingDayGroup> groups,
  required Map<String, OcptShootingDayGroup> groupById,
  required ValueChanged<String?>? onChanged,
}) {
  final currentLabel = currentGroupId == null
      ? tr.scheduleGroupNoGroupOption
      : _groupLabelOf(tr, groupById[currentGroupId]);
  final labelStyle = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

  if (onChanged == null) {
    return Text(currentLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle);
  }

  return PopupMenuButton<String>(
    tooltip: "",
    onSelected: (value) => onChanged(value == _noGroupOption ? null : value),
    itemBuilder: (context) => [
      PopupMenuItem<String>(value: _noGroupOption, child: Text(tr.scheduleGroupNoGroupOption)),
      const PopupMenuDivider(),
      for (final group in groups)
        PopupMenuItem<String>(value: group.id, child: Text(_groupLabelOf(tr, group))),
    ],
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(currentLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle)),
        const Icon(Icons.arrow_drop_down, size: 14),
      ],
    ),
  );
}

/// [group]'s own label, or `tr.scheduleGroupUnnamed` while it is empty, or an em dash while
/// [group] itself is null (a group id the day's own live [OcptScheduleSlotCard.groups] no longer
/// carries — a stale read between a deletion and the fresh snapshot landing).
String _groupLabelOf(Tr tr, OcptShootingDayGroup? group) {
  if (group == null) {
    return "—";
  }
  return group.label.isEmpty ? tr.scheduleGroupUnnamed : group.label;
}
