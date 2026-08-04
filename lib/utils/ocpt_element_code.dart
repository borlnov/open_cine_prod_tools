// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';

/// What separates a generated code's prefix from its number: `PRP-3`.
const String _codeSeparator = "-";

/// The shape of a code this file generated and nobody has edited since: three upper-case letters,
/// the separator, then a number with no leading zero.
///
/// Anchored at both ends on purpose — `PRP-3 (bureau)` is a code someone typed over a generated
/// one, and must be left alone by [ocptElementCodeIsGeneratedFor].
final RegExp _generatedCodePattern = RegExp(r"^([A-Z]{3})-([1-9]\d*)$");

/// The three-letter prefix a generated code carries for [category].
///
/// **Stored data, so never localized**: a code ends up in the breakdown margin, in the workbook and
/// in a version's payload, and a project opened in the other UI language must keep reading the same
/// codes. That is the same reason `shots.abbreviation` holds the letters rather than the label they
/// came from.
///
/// Every prefix is three letters and no two categories share one, which is what lets
/// [ocptElementCodeIsGeneratedFor] tell "this code still describes its category" from "somebody
/// typed this".
String ocptElementCodePrefixOf(OcptElementCategory category) => switch (category) {
  OcptElementCategory.prop => "PRP",
  OcptElementCategory.setDressing => "SET",
  OcptElementCategory.costume => "COS",
  OcptElementCategory.makeup => "MUP",
  OcptElementCategory.vehicle => "VEH",
  OcptElementCategory.animal => "ANI",
  OcptElementCategory.specialEquipment => "SFX",
  OcptElementCategory.camera => "CAM",
  OcptElementCategory.lighting => "LGT",
  OcptElementCategory.sound => "SND",
  OcptElementCategory.production => "PRD",
  OcptElementCategory.catering => "CAT",
  OcptElementCategory.extras => "EXT",
  OcptElementCategory.other => "OTH",
};

/// The code a new element of [category] gets: its prefix, then the first number no code in
/// [existingCodes] already uses for that prefix.
///
/// Numbered **within the category** rather than across the catalogue, so a code says which
/// department the item comes from — which is the whole point of printing it in a breakdown margin.
///
/// Counted from the highest number in use rather than from how many elements the category holds:
/// deleting `PRP-2` out of three props must not hand `PRP-3` to the next one and end the day with
/// two of them. Codes nobody generated (`bureau`, `PRP-2 bis`) simply don't match, so a catalogue
/// full of hand-written codes still starts its generated ones at 1.
String ocptElementCodeOf({
  required OcptElementCategory category,
  required Iterable<String> existingCodes,
}) {
  final prefix = ocptElementCodePrefixOf(category);
  var highest = 0;

  for (final code in existingCodes) {
    final match = _generatedCodePattern.firstMatch(code.trim());
    if (match == null || match.group(1) != prefix) {
      continue;
    }

    final number = int.parse(match.group(2)!);
    if (number > highest) {
      highest = number;
    }
  }

  return "$prefix$_codeSeparator${highest + 1}";
}

/// Whether [code] is exactly what [ocptElementCodeOf] would have produced for [category] — the
/// prefix of that category followed by a number — and therefore a code the user has never touched.
///
/// This is what makes a category change safe to follow with a new code: an element moved from props
/// to vehicles while still wearing `PRP-4` gets `VEH-1`, but one whose code somebody typed
/// (`4L jaune`, or a `PRP-4` kept on purpose after the move) keeps it. A hand-written code is a
/// decision; a generated one is a default.
bool ocptElementCodeIsGeneratedFor({
  required String code,
  required OcptElementCategory category,
}) {
  final match = _generatedCodePattern.firstMatch(code.trim());

  return match != null && match.group(1) == ocptElementCodePrefixOf(category);
}
