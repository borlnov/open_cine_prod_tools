// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_avatar.dart';

/// The separator joining the names of the other roles a cast member holds, in
/// [_OcptRoleEntry]'s own muted line.
const _otherRolesSeparator = ", ";

/// The radius of a row's avatar.
const double _avatarRadius = 13;

/// The cast: one row per [OcptRole], mock-up layout — a small [OcptRoleAvatar], the role's name on
/// top in the accent colour, the cast member's name under it (a muted italic "Not cast" while there
/// is none), and — when the same person holds other roles too — a small muted line listing them.
///
/// A role the screenplay no longer speaks carries a marker beside its name: its own sheet is where
/// the alert and the two ways out of it live, so this list is what says which sheet to go and read.
///
/// Selecting a row only selects it (`OcptResourcesRoleSelectedEvent`), which is what the mode
/// builds `OcptRoleSheet` from; there is no sheet or dialog of its own to open from here.
class OcptRolesList extends StatelessWidget {
  /// The cast to list, in display order.
  final List<OcptRole> roles;

  /// The whole address book, used to resolve a role's cast member and their other roles.
  final List<OcptPerson> people;

  /// The id of the selected role, or null if none is.
  final String? selectedRoleId;

  /// Called with a role's id when their row is clicked.
  final ValueChanged<String> onRoleSelected;

  /// Class constructor
  const OcptRolesList({
    super.key,
    required this.roles,
    required this.people,
    required this.selectedRoleId,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          Tr.of(context).resourcesRolesEmptyHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      itemCount: roles.length,
      itemBuilder: (context, index) {
        final role = roles[index];
        final castMember = _personOf(role.personId);
        final otherRoleNames = castMember == null
            ? const <String>[]
            : [
                for (final other in roles)
                  if (other.id != role.id && other.personId == castMember.id) other.name,
              ];

        return _OcptRoleEntry(
          role: role,
          castMember: castMember,
          otherRoleNames: otherRoleNames,
          isSelected: role.id == selectedRoleId,
          onTap: () => onRoleSelected(role.id),
        );
      },
    );
  }

  /// The person [personId] names, or null when it is null or names nobody in [people] (a stale
  /// reference from a snapshot rebuilt underneath).
  OcptPerson? _personOf(String? personId) {
    if (personId == null) {
      return null;
    }

    for (final person in people) {
      if (person.id == personId) {
        return person;
      }
    }

    return null;
  }
}

/// One row of [OcptRolesList].
class _OcptRoleEntry extends StatelessWidget {
  /// The role this row shows.
  final OcptRole role;

  /// The person cast in [role], or null while it is uncast.
  final OcptPerson? castMember;

  /// The names of the other roles [castMember] holds, or empty while uncast or holding only this
  /// one.
  final List<String> otherRoleNames;

  /// Whether this role is the selected one.
  final bool isSelected;

  /// Called when the row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptRoleEntry({
    required this.role,
    required this.castMember,
    required this.otherRoleNames,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final castMember = this.castMember;
    final roleName = role.name.isEmpty ? tr.resourcesRoleUnnamed : role.name;
    final castLine = castMember == null
        ? tr.resourcesRoleNotCast
        : (castMember.displayName.isEmpty ? tr.resourcesUnnamedPerson : castMember.displayName);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OcptRoleAvatar(castMember: castMember, radius: _avatarRadius),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            roleName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (role.orphanedName != null) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: tr.resourcesRoleOrphanedMarkerTooltip,
                            child: Icon(
                              Icons.person_off_outlined,
                              size: 14,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      castLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: castMember == null
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                        fontStyle: castMember == null ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    if (otherRoleNames.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        tr.resourcesRolesListOtherRolesLabel(
                          otherRoleNames.join(_otherRolesSeparator),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
