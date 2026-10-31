// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_crew_position_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_crew_position_prefill.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_people_subsection_title.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_person_card.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_crew_position_picker_dialog.dart';

/// The `Équipe technique` half of a slot card's own body: [crew] grouped by department, each
/// department's own cards wrapped at [cardWidth], then the `+ Crew member` footer, under a title
/// that is a plain read-out — the one fold on the card belongs to the people section and answers
/// for the crew, the cast and the guests at once.
///
/// **This is where a crew row's picker learns what to promote and what to refuse** — each member's
/// own person's declared `person_positions` are joined against every other live crew row of [crew]
/// naming that same person, through `ocptCrewPositionPrefillOf` (`lib/models/rules/`): the
/// promoted list and the taken set travel down to the row rather than being recomputed inside its
/// own menu builder.
class OcptScheduleSlotCrewSection extends StatelessWidget {
  /// The slot's own crew assignments, in `sortKey` order.
  final List<OcptShootingSlotCrewMember> crew;

  /// The whole address book, keyed by id — what a crew row's own name is read off.
  final Map<String, OcptPerson> personById;

  /// The whole address book, in display order — what the `+ Crew member` picker offers.
  final List<OcptPerson> people;

  /// The width every crew card of this half claims.
  final double cardWidth;

  /// Called with the id of the person picked by the `+ Crew member` footer, or null while withheld.
  final ValueChanged<String>? onCrewMemberAdded;

  /// Called with a crew assignment's id and the position just picked, or null while withheld.
  final void Function(String crewMemberId, OcptCrewPositionRef position)?
  onCrewMemberPositionChanged;

  /// Called with a crew assignment's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCrewMemberRemoved;

  /// Class constructor
  const OcptScheduleSlotCrewSection({
    super.key,
    required this.crew,
    required this.personById,
    required this.people,
    required this.cardWidth,
    required this.onCrewMemberAdded,
    required this.onCrewMemberPositionChanged,
    required this.onCrewMemberRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final byDepartment = <OcptCrewDepartment?, List<OcptShootingSlotCrewMember>>{};
    for (final member in crew) {
      final department = ocptCrewPositionDepartmentOf(member.positionId);
      byDepartment.putIfAbsent(department, () => []).add(member);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OcptScheduleSlotPeopleSubsectionTitle(
          title: tr.scheduleSlotCrewColumnTitle,
          count: crew.length,
        ),
        const SizedBox(height: 7),
        if (crew.isEmpty)
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final member in byDepartment[department]!)
                        SizedBox(
                          width: cardWidth,
                          child: _CrewMemberEntry(
                            member: member,
                            crew: crew,
                            personById: personById,
                            onCrewMemberPositionChanged: onCrewMemberPositionChanged,
                            onCrewMemberRemoved: onCrewMemberRemoved,
                          ),
                        ),
                    ],
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
}

/// One crew card for [member], its picker's promoted and taken positions computed through
/// `ocptCrewPositionPrefillOf` so the row and the service that later refuses a duplicate can never
/// disagree.
///
/// It joins [member]'s own person's declared `person_positions` with every live crew row of [crew]
/// naming that same person on this slot — [member]'s own row included, so its current position
/// reads as taken rather than greyed.
class _CrewMemberEntry extends StatelessWidget {
  /// The crew assignment the card shows.
  final OcptShootingSlotCrewMember member;

  /// Every crew assignment of the slot, what the taken positions are joined from.
  final List<OcptShootingSlotCrewMember> crew;

  /// The whole address book, keyed by id.
  final Map<String, OcptPerson> personById;

  /// Called with a crew assignment's id and the position just picked, or null while withheld.
  final void Function(String crewMemberId, OcptCrewPositionRef position)?
  onCrewMemberPositionChanged;

  /// Called with a crew assignment's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCrewMemberRemoved;

  /// Class constructor
  const _CrewMemberEntry({
    required this.member,
    required this.crew,
    required this.personById,
    required this.onCrewMemberPositionChanged,
    required this.onCrewMemberRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final prefill = ocptCrewPositionPrefillOf(
      declaredPositions: [
        for (final position
            in personById[member.personId]?.positions ?? const <OcptPersonPosition>[])
          OcptCrewPositionRef(positionId: position.positionId, customLabel: position.customLabel),
      ],
      heldOnSlot: [
        for (final other in crew)
          if (other.personId == member.personId)
            OcptCrewPositionRef(positionId: other.positionId, customLabel: other.customLabel),
      ],
    );

    return _CrewMemberRow(
      key: ValueKey(member.id),
      member: member,
      person: personById[member.personId],
      promotedPositions: prefill.promotedPositions,
      takenPositions: prefill.takenPositions,
      onPositionChanged: onCrewMemberPositionChanged == null
          ? null
          : (position) => onCrewMemberPositionChanged!(member.id, position),
      onRemoved: onCrewMemberRemoved == null ? null : () => onCrewMemberRemoved!(member.id),
    );
  }
}

/// One crew card of the `Équipe technique` column, built exactly like the cast cards (see
/// [OcptScheduleSlotPersonCard]): the position picker and the remove control on the first line, the
/// person's own name underneath.
///
/// The picker promotes [promotedPositions] above the `ocptCrewPositions` catalogue and never
/// offers anything in [takenPositions] — the two lists [_CrewMemberEntry] hands down, join computed
/// once rather than per menu build.
class _CrewMemberRow extends StatelessWidget {
  /// The crew assignment this row shows.
  final OcptShootingSlotCrewMember member;

  /// The person [member] names, or null while not yet loaded.
  final OcptPerson? person;

  /// The person's declared positions not already held on this slot, in their declared order —
  /// shown at the top of the picker, above the catalogue, behind a divider.
  final List<OcptCrewPositionRef> promotedPositions;

  /// Every position this person already holds on this slot, [member]'s own included — never
  /// offered by the picker, catalogue entries among them.
  final Set<OcptCrewPositionRef> takenPositions;

  /// Called with the position just picked — a promoted one or a catalogue entry — or null while
  /// withheld.
  final ValueChanged<OcptCrewPositionRef>? onPositionChanged;

  /// Called when this row's remove control is clicked, or null while withheld.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _CrewMemberRow({
    super.key,
    required this.member,
    required this.person,
    required this.promotedPositions,
    required this.takenPositions,
    required this.onPositionChanged,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final positionLabel = member.positionId.isEmpty
        ? (member.customLabel.isEmpty ? tr.scheduleSlotCrewPositionPlaceholder : member.customLabel)
        : ocptCrewPositionLabel(tr, member.positionId);
    final personName = person?.displayName.isEmpty ?? true
        ? tr.resourcesUnnamedPerson
        : person!.displayName;

    return OcptScheduleSlotPersonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: onPositionChanged == null
                    ? Text(positionLabel, style: theme.textTheme.bodySmall)
                    : InkWell(
                        onTap: () => _openPicker(context),
                        mouseCursor: ocptClickableCursor,
                        borderRadius: BorderRadius.circular(ocptRadiusSmall),
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
        ],
      ),
    );
  }

  /// Opens the shared `OcptCrewPositionPickerDialog`, promoting [promotedPositions] and excluding
  /// [takenPositions] — no "Custom label…" entry: a crew row picks off the catalogue or off what
  /// the person already declared, never types a fresh free label here. Reports whatever was
  /// picked through [onPositionChanged]; a dismissed dialog leaves the assignment untouched.
  Future<void> _openPicker(BuildContext context) async {
    final result = await OcptCrewPositionPickerDialog.show(
      context,
      promoted: promotedPositions,
      excluded: takenPositions,
    );
    if (result?.position case final position?) {
      onPositionChanged?.call(position);
    }
  }
}
