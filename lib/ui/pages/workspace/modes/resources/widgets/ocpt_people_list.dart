// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_avatar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_list_message.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_resources_search.dart';

/// The subset of [people] matching [query], through [ocptResourcesSearchMatches] against every
/// field a row shows or that names the person: the display name, every position (its localized
/// label, or the free custom one when it has no catalogue id), the email, the phone and the city.
///
/// Shared by [OcptPeopleList]'s own body and `OcptResourcesListPanel`'s header count, so the two
/// can never disagree about how many people a query actually matches.
List<OcptPerson> ocptFilteredPeopleOf({
  required List<OcptPerson> people,
  required String query,
  required Tr tr,
}) => [
  for (final person in people)
    if (ocptResourcesSearchMatches(query: query, fields: _searchFieldsOf(tr, person))) person,
];

/// Every field of [person] a search query may match against, see [ocptFilteredPeopleOf].
Iterable<String> _searchFieldsOf(Tr tr, OcptPerson person) => [
  person.displayName,
  for (final position in person.positions)
    position.positionId.isNotEmpty
        ? ocptCrewPositionLabel(tr, position.positionId)
        : position.customLabel,
  person.email,
  person.phone,
  person.city,
];

/// The address book: one row per [OcptPerson], mock-up layout — a small circular avatar filled
/// with the person's own colour and carrying their initials, the display name, and under it the
/// positions summary in a muted small style.
///
/// Role chips and the day count the mock-up's own row also shows belong to later milestones (roles
/// and the schedule aren't wired up yet): this row deliberately leaves them out rather than
/// faking them.
class OcptPeopleList extends StatelessWidget {
  /// The people to list, in display order.
  final List<OcptPerson> people;

  /// The id of the selected person, or null if none is.
  final String? selectedPersonId;

  /// The search query currently filtering the list, or empty while search is closed or nothing was
  /// typed — see [ocptFilteredPeopleOf].
  final String searchQuery;

  /// Called with a person's id when their row is clicked.
  final ValueChanged<String> onPersonSelected;

  /// Class constructor
  const OcptPeopleList({
    super.key,
    required this.people,
    required this.selectedPersonId,
    required this.searchQuery,
    required this.onPersonSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    if (people.isEmpty) {
      return OcptResourcesListMessage(message: tr.resourcesPeopleEmptyHint);
    }

    final filtered = ocptFilteredPeopleOf(people: people, query: searchQuery, tr: tr);
    if (filtered.isEmpty) {
      return OcptResourcesListMessage(message: tr.resourcesSearchNoMatchHint(searchQuery));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) => _OcptPersonEntry(
        person: filtered[index],
        isSelected: filtered[index].id == selectedPersonId,
        onTap: () => onPersonSelected(filtered[index].id),
      ),
    );
  }
}

/// One row of [OcptPeopleList].
class _OcptPersonEntry extends StatelessWidget {
  /// The person this row shows.
  final OcptPerson person;

  /// Whether this person is the selected one.
  final bool isSelected;

  /// Called when the row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptPersonEntry({required this.person, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final displayName = person.displayName;
    final name = displayName.isEmpty ? tr.resourcesUnnamedPerson : displayName;
    final positionsSummary = _positionsSummary(tr);

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
            children: [
              OcptPersonAvatar(person: person, radius: 13),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontStyle: displayName.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    if (positionsSummary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        positionsSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
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

  /// [person]'s positions, localized and joined, or empty when they hold none — the row's own
  /// "postes" summary line.
  String _positionsSummary(Tr tr) => person.positions
      .map(
        (position) => position.positionId.isNotEmpty
            ? ocptCrewPositionLabel(tr, position.positionId)
            : position.customLabel,
      )
      .where((label) => label.isNotEmpty)
      .join(" · ");
}
