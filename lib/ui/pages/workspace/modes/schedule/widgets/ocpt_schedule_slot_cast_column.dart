// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_people_subsection_title.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_person_card.dart';

/// The `Comédiens` half of a slot card: the slot's own convoked roles wrapped at [cardWidth] each,
/// then the `+ Cast` footer, under a title that is a plain read-out — the only fold on the card is
/// the people section's own, over the three kinds of person at once.
class OcptScheduleSlotCastColumn extends StatelessWidget {
  /// The slot's own cast convocations, in `sortKey` order.
  final List<OcptShootingSlotCastMember> cast;

  /// The whole cast, in display order — what the `+ Cast` picker offers once the roles [cast]
  /// already convokes are left out of it.
  final List<OcptRole> roles;

  /// The whole cast, keyed by id — what a cast row's own role is read off.
  final Map<String, OcptRole> roleById;

  /// The whole address book, keyed by id — what a cast row's own actor is read off.
  final Map<String, OcptPerson> personById;

  /// The width every cast card of this half claims.
  final double cardWidth;

  /// Called with the id of the role picked by the `+ Cast` footer, or null while withheld.
  final ValueChanged<String>? onCastRoleAdded;

  /// Called with a cast convocation's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onCastRoleRemoved;

  /// Class constructor
  const OcptScheduleSlotCastColumn({
    super.key,
    required this.cast,
    required this.roles,
    required this.roleById,
    required this.personById,
    required this.cardWidth,
    required this.onCastRoleAdded,
    required this.onCastRoleRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OcptScheduleSlotPeopleSubsectionTitle(
          title: tr.scheduleSlotCastColumnTitle,
          count: cast.length,
        ),
        const SizedBox(height: 7),
        if (cast.isEmpty)
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
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final member in cast)
                  SizedBox(
                    width: cardWidth,
                    child: _CastRoleRow(
                      key: ValueKey(member.id),
                      member: member,
                      role: roleById[member.roleId],
                      person: roleById[member.roleId]?.personId == null
                          ? null
                          : personById[roleById[member.roleId]!.personId],
                      onRemoved: onCastRoleRemoved == null
                          ? null
                          : () => onCastRoleRemoved!(member.id),
                    ),
                  ),
              ],
            ),
          ),
        if (onCastRoleAdded != null)
          PopupMenuButton<String>(
            tooltip: "",
            onSelected: onCastRoleAdded,
            // Never empty: a menu with no entry does not open at all, which reads as a dead button.
            itemBuilder: (context) {
              final offerableRoles = [
                for (final role in roles)
                  if (!cast.any((member) => member.roleId == role.id)) role,
              ];

              return [
                if (offerableRoles.isEmpty)
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Text(
                      roles.isEmpty
                          ? tr.scheduleCastPickerNoRoleHint
                          : tr.scheduleCastPickerAllConvokedHint,
                    ),
                  ),
                for (final role in offerableRoles)
                  PopupMenuItem<String>(value: role.id, child: Text(role.name)),
              ];
            },
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

/// One cast card of the `Comédiens` column, its layout shared with the crew cards (see
/// [OcptScheduleSlotPersonCard]): the role's own name and remove control on the first line, the
/// cast actor's own name underneath.
class _CastRoleRow extends StatelessWidget {
  /// The cast convocation this row shows.
  final OcptShootingSlotCastMember member;

  /// The role [member] convokes, or null while not yet loaded.
  final OcptRole? role;

  /// The person cast in [role], or null while uncast (or not yet loaded).
  final OcptPerson? person;

  /// Called when this row's remove control is clicked, or null while withheld.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _CastRoleRow({
    super.key,
    required this.member,
    required this.role,
    required this.person,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return OcptScheduleSlotPersonCard(
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
        ],
      ),
    );
  }
}
