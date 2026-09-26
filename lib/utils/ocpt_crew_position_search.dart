// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/utils/ocpt_resources_search.dart';

/// The middle dot (`·`) a French crew position label's inclusive writing inserts
/// (`réalisateur·rice`), dropped by [ocptCrewPositionSearchNormalized] so it never has to be typed
/// to find the position it marks.
const int _ocptMiddleDotRune = 0xB7;

/// Folds [value] the way `ocptResourcesSearchNormalized` does (trimmed, lower-cased, accents
/// folded through `ocptResourcesSearchFoldedRune`) and additionally drops every middle dot, so
/// `OcptCrewPositionPickerDialog`'s search field matches a position's label whether or not the
/// query types the inclusive-writing mark the label itself carries — `realisateurrice` and
/// `réalisateur·rice` fold to the same string.
///
/// A small pure function of its own rather than a parameter on `ocptResourcesSearchNormalized`:
/// the resources mode's own search never meets a middle dot (no record field holds one), so
/// teaching that function about a mark it will otherwise never see would only widen what it has to
/// be read against for no caller that needs it.
String ocptCrewPositionSearchNormalized(String value) {
  final buffer = StringBuffer();

  for (final rune in value.trim().runes) {
    if (rune == _ocptMiddleDotRune) {
      continue;
    }
    buffer.write(ocptResourcesSearchFoldedRune(rune));
  }

  return buffer.toString();
}

/// Whether [query] matches [label], both normalized through [ocptCrewPositionSearchNormalized].
///
/// An empty (or whitespace-only, once normalized) [query] always matches, exactly as
/// `ocptResourcesSearchMatches` treats one — no search is the same as "show everything".
bool ocptCrewPositionSearchMatches({required String query, required String label}) {
  final normalizedQuery = ocptCrewPositionSearchNormalized(query);
  if (normalizedQuery.isEmpty) {
    return true;
  }

  return ocptCrewPositionSearchNormalized(label).contains(normalizedQuery);
}
