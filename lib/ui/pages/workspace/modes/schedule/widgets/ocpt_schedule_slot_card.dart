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
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';

/// The value the "no location" entry of the location picker menu carries, distinct from every
/// location id — a [PopupMenuButton] cannot carry a null value for an entry that must still be
/// selectable.
const String _noLocationOption = "";

/// One slot's own card in the day view: its label, its location and set, its crew call/wrap band
/// and its default PAT band, then the two columns `docs/plans/schedule-mode.md` §8 and Benoit's own
/// M1 decision #1 ask for — `Équipe technique`, grouped by department, and `Comédiens` — each
/// ending on its own `+ Crew member`/`+ Cast` footer opening a person or role picker right there on
/// the card, with no duplicate list anywhere in the right dock.
///
/// Every writing affordance is a nullable callback, withheld while a project version is being
/// previewed (`isReadOnly`): the label field, the location/set pickers, the two time bands, every
/// crew/cast row's own controls and both `+` footers. Nothing here reads a `pendingFieldEdits` map
/// itself — [labelValue] is already resolved by the caller, exactly as every other mode's own
/// sheet fields are.
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

  /// [slot]'s own label, as currently held (a pending edit, or its stored value).
  final String labelValue;

  /// Called with the label's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onLabelChanged;

  /// Called with the location and set just picked, or null while withheld.
  final void Function(String? locationId, String? setId)? onPlaceChanged;

  /// Called with the crew call/wrap band just committed, or null while withheld.
  final void Function(int callMinute, int wrapMinute)? onCrewTimesChanged;

  /// Called with the default PAT band just committed, or null while withheld.
  final void Function(int? castCallMinute, int? castWrapMinute)? onCastTimesChanged;

  /// Called when the `Delete this slot…` action is picked, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Called with the id of the person picked by the `+ Crew member` footer, or null while withheld.
  final ValueChanged<String>? onCrewMemberAdded;

  /// Called with a crew assignment's id and the catalogue position just picked, or null while
  /// withheld.
  final void Function(String crewMemberId, String positionId)? onCrewMemberPositionChanged;

  /// Called with a crew assignment's id and its own call/wrap override just committed, or null
  /// while withheld.
  final void Function(String crewMemberId, int? callMinute, int? wrapMinute)? onCrewMemberTimesChanged;

  /// Called with a crew assignment's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCrewMemberRemoved;

  /// Called with the id of the role picked by the `+ Cast` footer, or null while withheld.
  final ValueChanged<String>? onCastRoleAdded;

  /// Called with a cast convocation's id and its own arrival/PAT overrides just committed, or null
  /// while withheld.
  final void Function(String castRoleId, int? arrivalMinute, int? castCallMinute, int? castWrapMinute)?
  onCastRoleTimesChanged;

  /// Called with a cast convocation's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCastRoleRemoved;

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
    required this.labelValue,
    required this.onLabelChanged,
    required this.onPlaceChanged,
    required this.onCrewTimesChanged,
    required this.onCastTimesChanged,
    required this.onDeletionRequested,
    required this.onCrewMemberAdded,
    required this.onCrewMemberPositionChanged,
    required this.onCrewMemberTimesChanged,
    required this.onCrewMemberRemoved,
    required this.onCastRoleAdded,
    required this.onCastRoleTimesChanged,
    required this.onCastRoleRemoved,
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
        ],
      ),
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

  /// The header's own crew call/wrap band and default PAT band, right-aligned.
  Widget _buildTimesColumn(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onCrewTimesChanged = this.onCrewTimesChanged;
    final onCastTimesChanged = this.onCastTimesChanged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${tr.scheduleSlotCrewBandLabel} ", style: theme.textTheme.labelSmall),
            OcptScheduleMinuteField(
              minute: slot.crewCallMinute,
              isClearable: false,
              emptyHint: "—",
              onChanged: onCrewTimesChanged == null
                  ? null
                  : (value) => onCrewTimesChanged(value ?? slot.crewCallMinute, slot.crewWrapMinute),
            ),
            Text(" – ", style: theme.textTheme.labelSmall),
            OcptScheduleMinuteField(
              minute: slot.crewWrapMinute,
              isClearable: false,
              emptyHint: "—",
              onChanged: onCrewTimesChanged == null
                  ? null
                  : (value) => onCrewTimesChanged(slot.crewCallMinute, value ?? slot.crewWrapMinute),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${tr.scheduleSlotPatBandLabel} ", style: theme.textTheme.labelSmall),
            OcptScheduleMinuteField(
              minute: slot.castCallMinute,
              isClearable: true,
              emptyHint: "—",
              onChanged: onCastTimesChanged == null
                  ? null
                  : (value) => onCastTimesChanged(value, slot.castWrapMinute),
            ),
            Text(" – ", style: theme.textTheme.labelSmall),
            OcptScheduleMinuteField(
              minute: slot.castWrapMinute,
              isClearable: true,
              emptyHint: "—",
              onChanged: onCastTimesChanged == null
                  ? null
                  : (value) => onCastTimesChanged(slot.castCallMinute, value),
            ),
          ],
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
                    _OcptScheduleCrewMemberRow(
                      key: ValueKey(member.id),
                      member: member,
                      person: personById[member.personId],
                      onPositionChanged: onCrewMemberPositionChanged == null
                          ? null
                          : (positionId) => onCrewMemberPositionChanged!(member.id, positionId),
                      onTimesChanged: onCrewMemberTimesChanged == null
                          ? null
                          : (call, wrap) => onCrewMemberTimesChanged!(member.id, call, wrap),
                      onRemoved: onCrewMemberRemoved == null
                          ? null
                          : () => onCrewMemberRemoved!(member.id),
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
            _OcptScheduleCastRoleRow(
              key: ValueKey(member.id),
              member: member,
              role: roleById[member.roleId],
              person: roleById[member.roleId]?.personId == null
                  ? null
                  : personById[roleById[member.roleId]!.personId],
              onTimesChanged: onCastRoleTimesChanged == null
                  ? null
                  : (arrival, call, wrap) => onCastRoleTimesChanged!(member.id, arrival, call, wrap),
              onRemoved: onCastRoleRemoved == null ? null : () => onCastRoleRemoved!(member.id),
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

/// One crew row of [OcptScheduleSlotCard]'s own `Équipe technique` column: the position picker,
/// the person's own name, its own call/wrap override and a remove control.
class _OcptScheduleCrewMemberRow extends StatelessWidget {
  /// The crew assignment this row shows.
  final OcptShootingSlotCrewMember member;

  /// The person [member] names, or null while not yet loaded.
  final OcptPerson? person;

  /// Called with the catalogue position just picked, or null while withheld.
  final ValueChanged<String>? onPositionChanged;

  /// Called with this row's own call/wrap override just committed, or null while withheld.
  final void Function(int? callMinute, int? wrapMinute)? onTimesChanged;

  /// Called when this row's remove control is clicked, or null while withheld.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptScheduleCrewMemberRow({
    super.key,
    required this.member,
    required this.person,
    required this.onPositionChanged,
    required this.onTimesChanged,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onTimesChanged = this.onTimesChanged;
    final positionLabel = member.positionId.isEmpty
        ? (member.customLabel.isEmpty ? tr.resourcesPositionScopePlaceholder : member.customLabel)
        : ocptCrewPositionLabel(tr, member.positionId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
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
          Expanded(
            child: Text(
              person?.displayName.isEmpty ?? true
                  ? tr.resourcesUnnamedPerson
                  : person!.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          OcptScheduleMinuteField(
            minute: member.callMinute,
            isClearable: true,
            emptyHint: "—",
            onChanged: onTimesChanged == null ? null : (value) => onTimesChanged(value, member.wrapMinute),
          ),
          const SizedBox(width: 4),
          OcptScheduleMinuteField(
            minute: member.wrapMinute,
            isClearable: true,
            emptyHint: "—",
            onChanged: onTimesChanged == null ? null : (value) => onTimesChanged(member.callMinute, value),
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
    );
  }
}

/// One cast row of [OcptScheduleSlotCard]'s own `Comédiens` column: the role's own name and cast
/// actor, its arrival time, its own PAT override and a remove control.
class _OcptScheduleCastRoleRow extends StatelessWidget {
  /// The cast convocation this row shows.
  final OcptShootingSlotCastMember member;

  /// The role [member] convokes, or null while not yet loaded.
  final OcptRole? role;

  /// The person cast in [role], or null while uncast (or not yet loaded).
  final OcptPerson? person;

  /// Called with this row's own arrival/PAT overrides just committed, or null while withheld.
  final void Function(int? arrivalMinute, int? castCallMinute, int? castWrapMinute)? onTimesChanged;

  /// Called when this row's remove control is clicked, or null while withheld.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptScheduleCastRoleRow({
    super.key,
    required this.member,
    required this.role,
    required this.person,
    required this.onTimesChanged,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onTimesChanged = this.onTimesChanged;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
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
            person == null
                ? tr.scheduleSlotCastUncastHint
                : person!.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: person == null ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              Text("${tr.scheduleSlotArrivalLabel} ", style: theme.textTheme.labelSmall),
              OcptScheduleMinuteField(
                minute: member.arrivalMinute,
                isClearable: true,
                emptyHint: "—",
                onChanged: onTimesChanged == null
                    ? null
                    : (value) => onTimesChanged(value, member.castCallMinute, member.castWrapMinute),
              ),
              const SizedBox(width: 4),
              Text("${tr.scheduleSlotPatBandLabel} ", style: theme.textTheme.labelSmall),
              OcptScheduleMinuteField(
                minute: member.castCallMinute,
                isClearable: true,
                emptyHint: "—",
                onChanged: onTimesChanged == null
                    ? null
                    : (value) => onTimesChanged(member.arrivalMinute, value, member.castWrapMinute),
              ),
              Text(" – ", style: theme.textTheme.labelSmall),
              OcptScheduleMinuteField(
                minute: member.castWrapMinute,
                isClearable: true,
                emptyHint: "—",
                onChanged: onTimesChanged == null
                    ? null
                    : (value) => onTimesChanged(member.arrivalMinute, member.castCallMinute, value),
              ),
            ],
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
