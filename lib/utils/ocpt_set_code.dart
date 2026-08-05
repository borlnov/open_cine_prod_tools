// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The letters a generated set code is spelled with, in order: `A` is 1, `Z` is 26, `AA` is 27 —
/// the numbering a spreadsheet gives its columns.
const String _alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

/// How many letters long a code may be before it stops being read as one.
///
/// Three is 17 576 sets, well past what any production reaches, and the cap is what keeps a word
/// somebody typed into the field back when it was free text (`CUISINE`) from being read as a
/// number in the hundreds of millions and pushing every code that follows out of reach.
const int _maximumLength = 3;

/// The shape of a code this file generated: nothing but capital letters, at most [_maximumLength]
/// of them.
final RegExp _generatedCodePattern = RegExp("^[A-Z]{1,$_maximumLength}\$");

/// The code a new set gets: the first letters no code in [existingCodes] already uses.
///
/// Letters rather than the `PRP-3` shape an element's code carries, for two reasons. A set has no
/// category, so a prefix would be the same three characters on every row of the project and would
/// say nothing; and a code is read in a breakdown margin, where two characters are worth having.
/// The two shapes can never be confused for one another either, an element's code always carrying
/// its separator.
///
/// Numbered across the **whole project** rather than within a location: a code is what names a set
/// on a sheet that has long stopped saying which house it belongs to, so two `A`s in two locations
/// would be exactly the ambiguity a code exists to remove.
///
/// Counted from the highest code in use rather than from how many sets the project holds, for the
/// reason `ocptElementCodeOf` counts that way too: deleting `B` out of three sets must not hand `C`
/// to the next one and end the day with two of them. Codes nobody generated (`Cuisine 2`, `EXT-1`)
/// simply don't match, so a project full of hand-written ones still starts its generated codes
/// at `A`.
String ocptSetCodeOf({required Iterable<String> existingCodes}) {
  var highest = 0;

  for (final code in existingCodes) {
    final index = _indexOf(code);
    if (index != null && index > highest) {
      highest = index;
    }
  }

  return _codeOf(highest + 1);
}

/// The 1-based rank [code] names (`A` is 1, `AA` is 27), or null when it is not a code this file
/// would have generated.
int? _indexOf(String code) {
  final trimmed = code.trim();
  if (!_generatedCodePattern.hasMatch(trimmed)) {
    return null;
  }

  var index = 0;
  for (final unit in trimmed.codeUnits) {
    index = index * _alphabet.length + (unit - _alphabet.codeUnitAt(0) + 1);
  }

  return index;
}

/// The code of the 1-based rank [index], the inverse of [_indexOf].
String _codeOf(int index) {
  final letters = <String>[];
  var remaining = index;

  while (remaining > 0) {
    final digit = (remaining - 1) % _alphabet.length;
    letters.add(_alphabet[digit]);
    remaining = (remaining - 1) ~/ _alphabet.length;
  }

  return letters.reversed.join();
}
