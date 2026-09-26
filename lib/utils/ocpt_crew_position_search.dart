// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/utils/ocpt_resources_search.dart';

/// The middle dot (`·`) a French crew position label's inclusive writing inserts
/// (`réalisateur·rice`), dropped by [ocptCrewPositionSearchNormalized] so it never has to be typed
/// to find the position it marks.
const int _ocptMiddleDotRune = 0xB7;

/// [_ocptMiddleDotRune] as a one-character string, what [ocptInclusiveReadingsOf] splits words on.
const String _ocptMiddleDot = "\u00B7";

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

/// The masculine and the feminine readings of [label], a French crew position label in inclusive
/// writing (`Premier·ère assistant·e réalisateur·rice`), in that order — or an empty list when
/// [label] carries no middle dot at all, an English label or an epicene French one (`Scripte`)
/// having no second reading to offer.
///
/// Each word written `base·ending` reads as `base` in the masculine, and as `base` with its own end
/// replaced by `ending` in the feminine ([ocptInclusiveFeminineOf]); every other word reads the same
/// in both: `Première assistante réalisatrice`, `Premier assistant réalisateur`.
List<String> ocptInclusiveReadingsOf(String label) {
  if (!label.contains(_ocptMiddleDot)) {
    return const [];
  }

  final words = label.split(" ");

  return [
    [for (final word in words) word.split(_ocptMiddleDot).first].join(" "),
    [for (final word in words) ocptInclusiveFeminineOf(word)].join(" "),
  ];
}

/// The feminine reading of [word], one word of a French label in inclusive writing: [word] itself
/// when it carries no middle dot, otherwise its base with its own end replaced by the ending the
/// dot introduces.
///
/// The replacement follows the handful of patterns French inclusive writing uses, which between
/// them cover every label of the crew positions catalogue:
///
/// - `-eur·rice` → `-rice` (`réalisateur·rice` → `réalisatrice`);
/// - `-eur·euse` → `-euse` (`régisseur·euse` → `régisseuse`);
/// - `-er·ère` → `-ère` (`costumier·ère` → `costumière`);
/// - `-f·ve` → `-ve` (`exécutif·ve` → `exécutive`);
/// - any other ending is appended as written (`chef·fe` → `cheffe`, `assistant·e` → `assistante`).
String ocptInclusiveFeminineOf(String word) {
  final parts = word.split(_ocptMiddleDot);
  if (parts.length < 2) {
    return word;
  }

  final base = parts.first;
  final ending = parts.sublist(1).join();

  if ((ending == "rice" || ending == "euse") && base.endsWith("eur")) {
    return "${base.substring(0, base.length - 3)}$ending";
  }
  if (ending == "ère" && base.endsWith("er")) {
    return "${base.substring(0, base.length - 2)}$ending";
  }
  if (ending == "ve" && base.endsWith("f")) {
    return "${base.substring(0, base.length - 1)}$ending";
  }

  return "$base$ending";
}

/// Whether [query] matches [label], both normalized through [ocptCrewPositionSearchNormalized] —
/// [label] itself, or either of its [ocptInclusiveReadingsOf], so `directrice` finds
/// `Directeur·rice` as readily as `directeur` does.
///
/// An empty (or whitespace-only, once normalized) [query] always matches, exactly as
/// `ocptResourcesSearchMatches` treats one — no search is the same as "show everything".
bool ocptCrewPositionSearchMatches({required String query, required String label}) {
  final normalizedQuery = ocptCrewPositionSearchNormalized(query);
  if (normalizedQuery.isEmpty) {
    return true;
  }

  return [label, ...ocptInclusiveReadingsOf(label)].any(
    (reading) => ocptCrewPositionSearchNormalized(reading).contains(normalizedQuery),
  );
}
