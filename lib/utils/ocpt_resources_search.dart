// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Every accented lower-case character the app's two UI languages (English, French) actually type,
/// mapped to the plain Latin letter(s) it folds to for search purposes.
///
/// This is a **display-language fold**, not a Unicode normalization: it only covers the Latin-1
/// accented letters `en_GB` and `fr` need, has no notion of combining marks, and does nothing for a
/// script outside the Latin alphabet. It exists so a French user typing `lea` finds `Léa` and one
/// typing `LÉA` finds a record stored as `lea` — the one thing worth solving here, not general
/// text normalization.
const Map<String, String> _ocptDiacriticsFoldingMap = {
  "à": "a",
  "â": "a",
  "ä": "a",
  "á": "a",
  "ã": "a",
  "å": "a",
  "ç": "c",
  "é": "e",
  "è": "e",
  "ê": "e",
  "ë": "e",
  "í": "i",
  "ì": "i",
  "î": "i",
  "ï": "i",
  "ñ": "n",
  "ó": "o",
  "ò": "o",
  "ô": "o",
  "ö": "o",
  "õ": "o",
  "ú": "u",
  "ù": "u",
  "û": "u",
  "ü": "u",
  "ý": "y",
  "ÿ": "y",
  "œ": "oe",
  "æ": "ae",
};

/// Trims [value], lower-cases it and folds every accented character
/// [_ocptDiacriticsFoldingMap] knows about to its plain equivalent, so two spellings of the same
/// word that only differ by case, accents or stray leading/trailing whitespace (a space bar
/// pressed before the first real character) compare equal.
///
/// Every caller that needs to compare two pieces of text for a search match goes through this
/// (directly, or through [ocptResourcesSearchMatches]), so no two tabs of the resources mode can
/// ever disagree about what "the same text" means.
String ocptResourcesSearchNormalized(String value) {
  final lowerCased = value.trim().toLowerCase();
  final buffer = StringBuffer();

  for (final rune in lowerCased.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_ocptDiacriticsFoldingMap[char] ?? char);
  }

  return buffer.toString();
}

/// Whether [query] matches at least one of [fields], both normalized through
/// [ocptResourcesSearchNormalized] first.
///
/// An empty (or whitespace-only, once normalized) [query] always matches: no search is the same as
/// "show everything". Otherwise this is true the moment the normalized query is contained
/// **anywhere** inside a normalized field — not just at its start — so a query typed into the
/// middle of a name still finds it.
bool ocptResourcesSearchMatches({required String query, required Iterable<String> fields}) {
  final normalizedQuery = ocptResourcesSearchNormalized(query);
  if (normalizedQuery.isEmpty) {
    return true;
  }

  for (final field in fields) {
    if (ocptResourcesSearchNormalized(field).contains(normalizedQuery)) {
      return true;
    }
  }

  return false;
}
