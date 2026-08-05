// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The colour the breakdown mode draws a tagged target with — its highlight in the script view, its
/// bar in the recap table, its swatch in the legend, and its print in the sheets export.
///
/// Plain ARGB integers rather than a `Color` or a `PdfColor`, exactly like `ocptCoveragePalette`:
/// the palette is wanted on screen and in a PDF alike, so it must not commit to either package's
/// colour type — each call site converts at the point of use.
///
/// Unlike `ocptCoveragePalette`, which colours a shot by its **rank** within its sequence, this
/// palette colours a target by its **category**: a category's colour must be the same in every
/// project and every export, since the legend is what teaches a reader to read it, and a legend
/// that meant something different from one project to the next would teach nothing. There is
/// therefore no rotation and no cycling here — sixteen categories, sixteen fixed colours.
library;

import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';

/// The colour [OcptBreakdownTargetKind.role] is drawn with, as an ARGB integer.
const int ocptBreakdownRoleColor = 0xFF9B8AFB;

/// The colour [OcptBreakdownTargetKind.set] is drawn with, as an ARGB integer.
const int ocptBreakdownSetColor = 0xFF4DB6AC;

/// The colour of a target of [kind], as an ARGB integer — [ocptBreakdownRoleColor] or
/// [ocptBreakdownSetColor] for a role or a set, [category]'s own colour for an element.
///
/// [category] is required when [kind] is [OcptBreakdownTargetKind.element] (an [ArgumentError] is
/// thrown when it is missing) and ignored otherwise, so a caller never has to branch on [kind]
/// itself before asking for a colour.
int ocptBreakdownColorOf({required OcptBreakdownTargetKind kind, OcptElementCategory? category}) {
  switch (kind) {
    case OcptBreakdownTargetKind.role:
      return ocptBreakdownRoleColor;
    case OcptBreakdownTargetKind.set:
      return ocptBreakdownSetColor;
    case OcptBreakdownTargetKind.element:
      if (category == null) {
        throw ArgumentError.value(category, "category", "An element target must carry a category");
      }
      return _elementColorOf(category);
  }
}

/// The colour of an element of [category], as an ARGB integer.
///
/// A `switch` with no `default`: a new [OcptElementCategory] value must be given its own colour
/// here rather than silently falling back to one already in use.
int _elementColorOf(OcptElementCategory category) => switch (category) {
  OcptElementCategory.prop => 0xFFFFD166,
  OcptElementCategory.setDressing => 0xFF7FD1A0,
  OcptElementCategory.costume => 0xFFF48FB1,
  OcptElementCategory.makeup => 0xFFFFAB7F,
  OcptElementCategory.vehicle => 0xFF5ECFD6,
  OcptElementCategory.animal => 0xFFB98B5E,
  OcptElementCategory.specialEquipment => 0xFFFF6B6B,
  OcptElementCategory.camera => 0xFF9FA8DA,
  OcptElementCategory.lighting => 0xFFE879F9,
  OcptElementCategory.sound => 0xFFA3E635,
  OcptElementCategory.production => 0xFF6B7CB8,
  OcptElementCategory.catering => 0xFFC98A3B,
  OcptElementCategory.extras => 0xFF6FA8FF,
  OcptElementCategory.other => 0xFF8E8A96,
};
