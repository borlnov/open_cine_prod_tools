// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/utils/ocpt_resources_search.dart';

/// One catalogue row the tag popover can offer, flattened out of whichever of `elements`, `roles`
/// or `sets` [kind] names — the popover shows the three catalogues side by side and needs one shape
/// to rank and cap, not three.
class OcptBreakdownSearchCandidate extends Equatable {
  /// Which of the three catalogues this candidate comes from.
  final OcptBreakdownTargetKind kind;

  /// The stable, unique id of the underlying element, role or set.
  final String id;

  /// This candidate's display name — the only field a query is matched against, see
  /// [ocptBreakdownSearchCatalogues].
  final String name;

  /// The element's category, non-null only when [kind] is [OcptBreakdownTargetKind.element], exactly
  /// as `OcptBreakdownTarget.category` is.
  final OcptElementCategory? category;

  /// How many live scenes this row is already tagged in; 0 for a row the breakdown never touched.
  ///
  /// Used only to break ties in [ocptBreakdownSearchCatalogues]'s ranking: a thing already found
  /// once in the script is the more likely match for the thing being read now.
  final int taggedSceneCount;

  /// Class constructor
  const OcptBreakdownSearchCandidate({
    required this.kind,
    required this.id,
    required this.name,
    required this.category,
    required this.taggedSceneCount,
  });

  /// Object properties
  @override
  List<Object?> get props => [kind, id, name, category, taggedSceneCount];
}

/// The matches of one query, grouped by kind the way the popover groups them — one section for
/// `Roles`, one for `Sets`, one for `Elements`, each already ranked and capped on its own.
class OcptBreakdownSearchResults extends Equatable {
  /// The matching roles, best match first.
  final List<OcptBreakdownSearchCandidate> roles;

  /// The matching sets, best match first.
  final List<OcptBreakdownSearchCandidate> sets;

  /// The matching elements, best match first.
  final List<OcptBreakdownSearchCandidate> elements;

  /// Class constructor
  const OcptBreakdownSearchResults({
    required this.roles,
    required this.sets,
    required this.elements,
  });

  /// Whether every section came back with nothing — the popover's cue to fall back on
  /// `Open in Resources` (§3.8 of the breakdown-mode plan) rather than an empty list.
  bool get isEmpty => roles.isEmpty && sets.isEmpty && elements.isEmpty;

  /// Object properties
  @override
  List<Object?> get props => [roles, sets, elements];
}

/// The default number of matches kept per kind, so the popover keeps its height whatever the
/// catalogue has grown to — a hundred and fifty elements must still fit under the search field.
const int ocptBreakdownSearchPerKindLimit = 5;

/// The [candidates] matching [query], grouped by kind and ranked within each group, each group
/// capped at [perKindLimit].
///
/// Matching is on a candidate's [OcptBreakdownSearchCandidate.name] **alone**, through
/// [ocptResourcesSearchMatches] — deliberately never [OcptBreakdownSearchCandidate.category]: a
/// user typing `propane` while looking for a prop must not be shown every element the catalogue
/// holds in the `prop` category, only the ones actually named after it. An empty or
/// whitespace-only [query] therefore matches every candidate, following straight from
/// [ocptResourcesSearchMatches]'s own contract — the popover opens pre-filled with the clicked
/// passage, and clearing that field means "show me everything", not "show me nothing".
///
/// Within each kind, candidates are ordered:
///
/// 1. a prefix match (the normalized name starts with the normalized query) before one found only
///    elsewhere in the name;
/// 2. then an already-tagged candidate ([OcptBreakdownSearchCandidate.taggedSceneCount] `> 0`)
///    before one nobody has tagged yet — the thing already broken down once is the likelier match;
/// 3. then by name, compared normalized so accents never scatter the order;
/// 4. then by id, so two rows that still tie (same name, same tagged/untagged state) never swap
///    places between two builds — the ordering is total and deterministic throughout.
///
/// The cap is applied **after** ranking, not before: a caller may hand in the whole catalogue in
/// any order, and the [perKindLimit] kept from each group must be its best matches, not whichever
/// [perKindLimit] the caller happened to list first.
///
/// [perKindLimit] must be strictly positive — a cap that keeps nothing is a caller bug, not a valid
/// way to ask for an empty result, so this throws an [ArgumentError] rather than silently returning
/// three empty lists.
OcptBreakdownSearchResults ocptBreakdownSearchCatalogues({
  required String query,
  required Iterable<OcptBreakdownSearchCandidate> candidates,
  int perKindLimit = ocptBreakdownSearchPerKindLimit,
}) {
  if (perKindLimit <= 0) {
    throw ArgumentError.value(
      perKindLimit,
      "perKindLimit",
      "must be strictly positive: a cap that keeps nothing is a caller bug",
    );
  }

  final normalizedQuery = ocptResourcesSearchNormalized(query);

  final roles = <OcptBreakdownSearchCandidate>[];
  final sets = <OcptBreakdownSearchCandidate>[];
  final elements = <OcptBreakdownSearchCandidate>[];

  for (final candidate in candidates) {
    if (!ocptResourcesSearchMatches(query: query, fields: [candidate.name])) {
      continue;
    }

    switch (candidate.kind) {
      case OcptBreakdownTargetKind.role:
        roles.add(candidate);
      case OcptBreakdownTargetKind.set:
        sets.add(candidate);
      case OcptBreakdownTargetKind.element:
        elements.add(candidate);
    }
  }

  return OcptBreakdownSearchResults(
    roles: _rankedAndCapped(roles, normalizedQuery, perKindLimit),
    sets: _rankedAndCapped(sets, normalizedQuery, perKindLimit),
    elements: _rankedAndCapped(elements, normalizedQuery, perKindLimit),
  );
}

/// [candidates], sorted by [_compareCandidates] against [normalizedQuery] and cut to [perKindLimit]
/// — ranking always happens over the whole group, the cap only ever the last step.
List<OcptBreakdownSearchCandidate> _rankedAndCapped(
  List<OcptBreakdownSearchCandidate> candidates,
  String normalizedQuery,
  int perKindLimit,
) {
  final ranked = [...candidates]..sort((a, b) => _compareCandidates(a, b, normalizedQuery));
  return ranked.take(perKindLimit).toList();
}

/// The ranking [ocptBreakdownSearchCatalogues] documents, as a [Comparator]: prefix match, then
/// already-tagged, then normalized name, then id.
int _compareCandidates(
  OcptBreakdownSearchCandidate a,
  OcptBreakdownSearchCandidate b,
  String normalizedQuery,
) {
  final normalizedNameA = ocptResourcesSearchNormalized(a.name);
  final normalizedNameB = ocptResourcesSearchNormalized(b.name);

  final isPrefixMatchA = normalizedNameA.startsWith(normalizedQuery);
  final isPrefixMatchB = normalizedNameB.startsWith(normalizedQuery);
  if (isPrefixMatchA != isPrefixMatchB) {
    return isPrefixMatchA ? -1 : 1;
  }

  final isTaggedA = a.taggedSceneCount > 0;
  final isTaggedB = b.taggedSceneCount > 0;
  if (isTaggedA != isTaggedB) {
    return isTaggedA ? -1 : 1;
  }

  final nameComparison = normalizedNameA.compareTo(normalizedNameB);
  if (nameComparison != 0) {
    return nameComparison;
  }

  return a.id.compareTo(b.id);
}

/// Whether [targetName] (and, where they exist, [categoryLabel]/[subCategory]/[ownerName]/[notes])
/// matches [query] — the recap's own row filter (§5.3 of the plan this mode shipped from): the
/// header's search field filters the recap's **rows**, and this is the predicate one row is kept
/// or dropped by.
///
/// [categoryLabel] is the caller's own resolved label (`ocptBreakdownLegendKeyLabel` applied to
/// the target's legend key), never a `Tr`, exactly as [ocptBreakdownSearchCatalogues] and the
/// resources mode's own list filters take resolved strings rather than reaching for localization
/// themselves. [subCategory]/[ownerName]/[notes] only ever come from an `elements` row — a role or
/// a set carries none of the three (`OcptBreakdownTarget`'s own doc comment explains why) — so the
/// caller simply leaves them null for those two kinds, and this only ever matches against
/// [targetName]/[categoryLabel] for them.
///
/// Folding is [ocptResourcesSearchMatches]'s own, so `lea` finds an owner named `Léa` exactly as it
/// finds a target named `Léa`, and an empty (or whitespace-only) [query] matches every row.
bool ocptBreakdownRecapRowMatches({
  required String query,
  required String targetName,
  required String categoryLabel,
  String? subCategory,
  String? ownerName,
  String? notes,
}) => ocptResourcesSearchMatches(
  query: query,
  fields: [
    targetName,
    categoryLabel,
    if (subCategory != null) subCategory,
    if (ownerName != null) ownerName,
    if (notes != null) notes,
  ],
);

/// The candidates the tag popover searches, flattened out of [snapshot]'s three raw catalogues
/// ([OcptBreakdownSnapshot.elements]/[OcptBreakdownSnapshot.roles]/[OcptBreakdownSnapshot.sets]) —
/// never out of [OcptBreakdownSnapshot.targets] alone, which only ever names a thing **already**
/// tagged somewhere and would therefore hide a role or a set the breakdown pass has not reached
/// yet, even though it is exactly what the popover exists to offer a link to.
///
/// [OcptBreakdownSearchCandidate.taggedSceneCount] is read off the matching `OcptBreakdownTarget`
/// when the row is already tagged somewhere, 0 otherwise.
List<OcptBreakdownSearchCandidate> ocptBreakdownSearchCandidatesOf(OcptBreakdownSnapshot snapshot) {
  final taggedSceneCountByRef = {
    for (final target in snapshot.targets) (target.kind, target.id): target.sceneIds.length,
  };

  return [
    for (final element in snapshot.elements)
      OcptBreakdownSearchCandidate(
        kind: OcptBreakdownTargetKind.element,
        id: element.id,
        name: element.name,
        category: element.category,
        taggedSceneCount: taggedSceneCountByRef[(OcptBreakdownTargetKind.element, element.id)] ?? 0,
      ),
    for (final role in snapshot.roles)
      OcptBreakdownSearchCandidate(
        kind: OcptBreakdownTargetKind.role,
        id: role.id,
        name: role.name,
        category: null,
        taggedSceneCount: taggedSceneCountByRef[(OcptBreakdownTargetKind.role, role.id)] ?? 0,
      ),
    for (final set in snapshot.sets)
      OcptBreakdownSearchCandidate(
        kind: OcptBreakdownTargetKind.set,
        id: set.id,
        name: set.name,
        category: null,
        taggedSceneCount: taggedSceneCountByRef[(OcptBreakdownTargetKind.set, set.id)] ?? 0,
      ),
  ];
}
