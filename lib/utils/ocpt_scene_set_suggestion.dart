// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_location.dart';

/// The scene-heading prefixes that say whether a scene is interior or exterior, stripped before
/// anything is matched: every heading carries one and none of them says *where*.
///
/// Written longest first so `INT./EXT.` is recognised before `INT.` can claim its first half.
const _headingPrefixes = [
  "INT./EXT.",
  "INT/EXT.",
  "INT./EXT",
  "INT/EXT",
  "I/E.",
  "I/E",
  "INT.",
  "EXT.",
  "EST.",
  "INT",
  "EXT",
  "EST",
];

/// The separator a heading puts before its time of day (`… - NUIT`), and what everything after the
/// last one of them is taken to be.
const _timeOfDaySeparator = " - ";

/// The shortest a normalised name may be before it is matched by containment rather than by
/// equality: below it, a two-letter set name would be suggested for every heading that happens to
/// spell it.
const _minimumContainmentLength = 3;

/// The set the scene headed [heading] is most likely shot in, among every set of [locations], or
/// null when nothing in the project resembles it.
///
/// This is a **suggestion and only ever a suggestion** (§4.5 of the plan this ships under): the
/// caller offers it and the user confirms it, because `INT. CUISINE` in two different houses is two
/// different sets and only they know which. Nothing here writes, and nothing here is applied
/// automatically.
///
/// A heading is reduced to the place it names — its interior/exterior prefix and its time of day
/// dropped, its whitespace collapsed, upper-cased — and matched against each set's name, then
/// against each location's. The best hit wins, in this order:
///
/// 1. a set whose name **is** the place named;
/// 2. a set whose name contains it, or is contained in it (`CUISINE` for `CUISINE DU HANGAR`);
/// 3. a location whose name is the place named and that holds exactly one set — a heading naming a
///    house rather than a room says which house to shoot in, and there is only one answer to give.
///
/// Ties go to the first set in display order. Accents are **not** folded: both sides are the user's
/// own text about one production, and `CUISINE` matching `CUISINÉ` would be a coincidence rather
/// than a match.
String? ocptSceneSetSuggestionOf({
  required String heading,
  required List<OcptLocation> locations,
}) {
  final place = ocptSceneHeadingPlaceOf(heading);
  if (place.isEmpty) {
    return null;
  }

  String? bestSetId;
  var bestScore = 0;

  void consider(String setId, int score) {
    if (score > bestScore) {
      bestScore = score;
      bestSetId = setId;
    }
  }

  for (final location in locations) {
    for (final set in location.sets) {
      final setName = _normalize(set.name);
      if (setName.isEmpty) {
        continue;
      }

      if (setName == place) {
        consider(set.id, 3);
      } else if (_containsEitherWay(place, setName)) {
        consider(set.id, 2);
      }
    }

    if (location.sets.length == 1 && _normalize(location.name) == place) {
      consider(location.sets.single.id, 1);
    }
  }

  return bestSetId;
}

/// The place scene heading [heading] names: its interior/exterior prefix and its time of day
/// dropped, its whitespace collapsed, upper-cased.
///
/// Exposed on its own because it is also what a reader wants to *see* — a scene offered for a set
/// reads better as `APPARTEMENT DE LÉA` than as the whole heading — and because it is the one half
/// of [ocptSceneSetSuggestionOf] worth testing against real headings on its own.
String ocptSceneHeadingPlaceOf(String heading) {
  var place = _normalize(heading);

  for (final prefix in _headingPrefixes) {
    if (place == prefix) {
      return "";
    }
    if (place.startsWith("$prefix ")) {
      place = place.substring(prefix.length + 1);
      break;
    }
  }

  final separatorIndex = place.lastIndexOf(_timeOfDaySeparator);
  if (separatorIndex > 0) {
    place = place.substring(0, separatorIndex);
  }

  return place.trim();
}

/// [value] upper-cased, with its outer whitespace trimmed and its inner runs of whitespace
/// collapsed to one space, so `INT.  CUISINE` and `int. cuisine` are one and the same place.
String _normalize(String value) => value.trim().toUpperCase().replaceAll(RegExp(r"\s+"), " ");

/// Whether one of [place] and [setName] contains the other, both being long enough for that to
/// mean something (see [_minimumContainmentLength]).
bool _containsEitherWay(String place, String setName) {
  if (place.length < _minimumContainmentLength || setName.length < _minimumContainmentLength) {
    return false;
  }

  return place.contains(setName) || setName.contains(place);
}
