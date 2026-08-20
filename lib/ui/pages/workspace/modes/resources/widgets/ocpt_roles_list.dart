// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_list_message.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_avatar.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_resources_search.dart';
import 'package:open_cine_prod_tools/utils/ocpt_role_casting_progress.dart';

/// The separator joining the names of the other roles a cast member holds, in
/// [_OcptRoleEntry]'s own muted line.
const _otherRolesSeparator = ", ";

/// The separator joining the printed numbers of the episodes a role speaks in, in
/// [_OcptRoleEntry]'s own muted line.
const _episodeNumbersSeparator = ", ";

/// The radius of a row's avatar.
const double _avatarRadius = 13;

/// The subset of [roles] matching [query], through [ocptResourcesSearchMatches] against every
/// field a row shows or that names the role: its own name, the name it had before it was orphaned
/// (still worth finding by), the cast member's display name and the localized role kind.
///
/// Shared by [OcptRolesList]'s own body and `OcptResourcesListPanel`'s header count, so the two
/// can never disagree about how many roles a query actually matches.
List<OcptRole> ocptFilteredRolesOf({
  required List<OcptRole> roles,
  required List<OcptPerson> people,
  required String query,
  required Tr tr,
}) => [
  for (final role in roles)
    if (ocptResourcesSearchMatches(
      query: query,
      fields: _searchFieldsOf(tr, role, _personOf(people, role.personId)),
    ))
      role,
];

/// The person [personId] names, or null when it is null or names nobody in [people] (a stale
/// reference from a snapshot rebuilt underneath). Shared by [ocptFilteredRolesOf] and
/// [OcptRolesList]'s own build method.
OcptPerson? _personOf(List<OcptPerson> people, String? personId) {
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

/// Every field of [role] a search query may match against, see [ocptFilteredRolesOf].
Iterable<String> _searchFieldsOf(Tr tr, OcptRole role, OcptPerson? castMember) => [
  role.name,
  role.orphanedName ?? "",
  castMember?.displayName ?? "",
  ocptRoleKindLabel(tr, role.kind),
];

/// The cast: one row per [OcptRole], mock-up layout — a small [OcptRoleAvatar], the role's name on
/// top in the accent colour, the cast member's name under it (a muted italic "Not cast" while there
/// is none), a small muted line naming the episodes the role speaks in while the project holds
/// more than one, and — when the same person holds other roles too — a small muted line listing
/// them.
///
/// The episodes line reads `Ep. 1, 2, 5`: numbers only, comma-separated, in the episodes' own
/// order (see [OcptRole.episodeIds]'s own doc comment) — a single-episode project names no episode
/// anywhere (`docs/adr/0019-one-project-several-episodes.md` §8), so the line is absent there, and
/// absent too for a role named in none of [episodes] (a hand-added role whose episodes have not
/// been picked yet).
///
/// A role the screenplay no longer speaks carries a marker beside its name: its own sheet is where
/// the alert and the two ways out of it live, so this list is what says which sheet to go and read.
///
/// The name line also wears a text pill, read off `OcptRoleCastingProgress` — `Cast` while the role
/// is cast, `{n} seen` while candidates are in progress, nothing at all otherwise — see
/// [_OcptRoleCastingPill], the one place that reading is drawn.
///
/// Selecting a row only selects it (`OcptResourcesRoleSelectedEvent`), which is what the mode
/// builds `OcptRoleSheet` from; there is no sheet or dialog of its own to open from here.
class OcptRolesList extends StatelessWidget {
  /// The cast to list, in display order.
  final List<OcptRole> roles;

  /// The whole address book, used to resolve a role's cast member and their other roles.
  final List<OcptPerson> people;

  /// Every live candidacy of the project, grouped by `roleId` — what a row's own pill is read out
  /// of, see [OcptRoleCastingProgress].
  final Map<String, List<OcptRoleCandidate>> candidatesByRoleId;

  /// Every episode of the project, in display order — what a row's own episodes line is read out
  /// of, see the class doc comment.
  final List<OcptEpisode> episodes;

  /// The id of the selected role, or null if none is.
  final String? selectedRoleId;

  /// The search query currently filtering the list, or empty while search is closed or nothing was
  /// typed — see [ocptFilteredRolesOf].
  final String searchQuery;

  /// Called with a role's id when their row is clicked.
  final ValueChanged<String> onRoleSelected;

  /// Class constructor
  const OcptRolesList({
    super.key,
    required this.roles,
    required this.people,
    required this.candidatesByRoleId,
    required this.episodes,
    required this.selectedRoleId,
    required this.searchQuery,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    if (roles.isEmpty) {
      return OcptResourcesListMessage(message: tr.resourcesRolesEmptyHint);
    }

    final filtered = ocptFilteredRolesOf(roles: roles, people: people, query: searchQuery, tr: tr);
    if (filtered.isEmpty) {
      return OcptResourcesListMessage(message: tr.resourcesSearchNoMatchHint(searchQuery));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final role = filtered[index];
        final castMember = _personOf(people, role.personId);
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
          episodeNumbers: _episodeNumbersOf(episodes, role),
          progress: OcptRoleCastingProgress.of(
            role: role,
            candidates: candidatesByRoleId[role.id] ?? const [],
          ),
          isSelected: role.id == selectedRoleId,
          onTap: () => onRoleSelected(role.id),
        );
      },
    );
  }
}

/// The printed numbers of the episodes [role] is named in, in the episodes' own order (see
/// [OcptRole.episodeIds]'s own doc comment), or empty while [episodes] holds one episode or none
/// (a single-episode project names no episode anywhere) or [role] names none of [episodes] — a
/// stale id from a snapshot rebuilt underneath is silently dropped rather than shown as a number
/// nobody can look up.
List<int> _episodeNumbersOf(List<OcptEpisode> episodes, OcptRole role) {
  if (episodes.length <= 1) {
    return const [];
  }

  final numberById = {for (final episode in episodes) episode.id: episode.number};
  return [
    for (final episodeId in role.episodeIds)
      if (numberById[episodeId] case final number?) number,
  ];
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

  /// The printed numbers of the episodes this role speaks in, or empty while there is nothing to
  /// show — see [_episodeNumbersOf].
  final List<int> episodeNumbers;

  /// Where this role's casting stands — the row's own pill is read out of it, see
  /// [_OcptRoleCastingPill].
  final OcptRoleCastingProgress progress;

  /// Whether this role is the selected one.
  final bool isSelected;

  /// Called when the row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptRoleEntry({
    required this.role,
    required this.castMember,
    required this.otherRoleNames,
    required this.episodeNumbers,
    required this.progress,
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
                        if (progress.stage != OcptRoleCastingStage.notStarted) ...[
                          const SizedBox(width: 6),
                          _OcptRoleCastingPill(progress: progress),
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
                    if (episodeNumbers.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        tr.resourcesRolesListEpisodesLabel(
                          episodeNumbers.join(_episodeNumbersSeparator),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

/// A row's own text pill, reading [OcptRoleCastingProgress]: `Cast` in the accent colour while the
/// role is cast, `{n} leads` in a muted tint while candidates are still in the running, and `No
/// lead` in the **error** colour once every candidacy has stopped — never drawn for
/// [OcptRoleCastingStage.notStarted], see [_OcptRoleEntry.build].
///
/// The error colour on [OcptRoleCastingStage.exhausted] is deliberate and is the only place this
/// list raises its voice: a part everybody has turned down looks, on every other line of the row,
/// exactly like a part nobody has started, and it is the opposite of it.
///
/// A text pill rather than a coloured dot, the developer's own pick: it has to read without
/// hovering, which a dot never does on its own.
class _OcptRoleCastingPill extends StatelessWidget {
  /// The progress this pill reads.
  final OcptRoleCastingProgress progress;

  /// Class constructor
  const _OcptRoleCastingPill({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = switch (progress.stage) {
      OcptRoleCastingStage.cast => theme.colorScheme.primary,
      OcptRoleCastingStage.inProgress => theme.colorScheme.tertiary,
      OcptRoleCastingStage.exhausted => theme.colorScheme.error,
      OcptRoleCastingStage.notStarted => theme.colorScheme.onSurfaceVariant,
    };
    final label = switch (progress.stage) {
      OcptRoleCastingStage.cast => tr.resourcesRolesListCastPill,
      OcptRoleCastingStage.inProgress => tr.resourcesRolesListCandidatesPill(
        progress.candidateCount,
      ),
      OcptRoleCastingStage.exhausted => tr.resourcesRolesListNoLeadPill,
      // Never drawn — the caller skips the pill entirely for a role nobody has been recorded on
      // (see [_OcptRoleEntry.build]) — but a `switch` that answers every stage is what keeps a
      // later reader from having to prove that again.
      OcptRoleCastingStage.notStarted => "",
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
