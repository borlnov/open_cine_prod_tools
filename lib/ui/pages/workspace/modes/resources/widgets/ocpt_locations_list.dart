// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_list_message.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_resources_search.dart';

/// The width of a row's colour bar.
const double _colorBarWidth = 3;

/// The height of a row's colour bar.
const double _colorBarHeight = 28;

/// The separator between a location's city and its set count, on a row's own muted second line.
const String _secondLineSeparator = " · ";

/// The subset of [locations] matching [query], through [ocptResourcesSearchMatches] against every
/// field a row shows or that names the location: its name, its city, each of its sets' codes and
/// names, and the localized permit status.
///
/// Shared by [OcptLocationsList]'s own body and `OcptResourcesListPanel`'s header count, so the two
/// can never disagree about how many locations a query actually matches.
List<OcptLocation> ocptFilteredLocationsOf({
  required List<OcptLocation> locations,
  required String query,
  required Tr tr,
}) => [
  for (final location in locations)
    if (ocptResourcesSearchMatches(query: query, fields: _searchFieldsOf(tr, location))) location,
];

/// Every field of [location] a search query may match against, see [ocptFilteredLocationsOf].
Iterable<String> _searchFieldsOf(Tr tr, OcptLocation location) => [
  location.name,
  location.city,
  for (final set in location.sets) ...[set.code, set.name],
  ocptPermitStatusLabel(tr, location.permitStatus),
];

/// The filming locations: one row per [OcptLocation], mock-up layout — the location's own colour
/// bar, its name, a muted line reading `city · N sets`, and its permit status on the right, painted
/// the colour that status is painted everywhere else in the mode.
///
/// The permit is on the row rather than only inside the sheet because it is the one thing about a
/// location that decides whether the production may shoot there at all: a list of six locations is
/// scanned for the one still amber.
class OcptLocationsList extends StatelessWidget {
  /// The locations to list, in display order.
  final List<OcptLocation> locations;

  /// The id of the selected location, or null if none is.
  final String? selectedLocationId;

  /// The search query currently filtering the list, or empty while search is closed or nothing was
  /// typed — see [ocptFilteredLocationsOf].
  final String searchQuery;

  /// Called with a location's id when its row is clicked.
  final ValueChanged<String> onLocationSelected;

  /// Class constructor
  const OcptLocationsList({
    super.key,
    required this.locations,
    required this.selectedLocationId,
    required this.searchQuery,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    if (locations.isEmpty) {
      return OcptResourcesListMessage(message: tr.resourcesLocationsEmptyHint);
    }

    final filtered = ocptFilteredLocationsOf(locations: locations, query: searchQuery, tr: tr);
    if (filtered.isEmpty) {
      return OcptResourcesListMessage(message: tr.resourcesSearchNoMatchHint(searchQuery));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final location = filtered[index];

        return _OcptLocationEntry(
          location: location,
          isSelected: location.id == selectedLocationId,
          onTap: () => onLocationSelected(location.id),
        );
      },
    );
  }
}

/// One row of [OcptLocationsList].
class _OcptLocationEntry extends StatelessWidget {
  /// The location this row shows.
  final OcptLocation location;

  /// Whether this location is the selected one.
  final bool isSelected;

  /// Called when the row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptLocationEntry({
    required this.location,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final permitColor = ocptPermitStatusColor(context, location.permitStatus);

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
              Container(
                width: _colorBarWidth,
                height: _colorBarHeight,
                decoration: BoxDecoration(
                  color: Color(ocptCoverageColorAt(location.colorIndex)),
                  borderRadius: BorderRadius.circular(_colorBarWidth),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name.isEmpty ? tr.resourcesLocationUnnamed : location.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontStyle: location.name.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _secondLineOf(tr),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ocptPermitStatusLabel(tr, location.permitStatus),
                style: theme.textTheme.labelSmall?.copyWith(color: permitColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The row's muted second line: the city and the number of sets, or the set count alone while the
  /// city is still empty — a leading separator would read as a missing word.
  String _secondLineOf(Tr tr) {
    final setsLabel = tr.resourcesLocationSetCount(location.sets.length);
    if (location.city.isEmpty) {
      return setsLabel;
    }

    return "${location.city}$_secondLineSeparator$setsLabel";
  }
}
