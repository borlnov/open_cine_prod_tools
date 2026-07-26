// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:super_editor/super_editor.dart';

/// Maps every [OcptInlineStyle] to the super_editor `Attribution` it toggles, mirroring
/// `OcptFountainLineAttributions`'s own block-level mapping pattern.
///
/// Unlike the block-type mapping, no reverse lookup by attribution name is needed here: the
/// controller/toolbar side only ever asks "is this style active" (checked directly against
/// [attributionOf]'s result), never "what style does this arbitrary attribution mean".
class OcptInlineStyleAttributions {
  /// Private constructor: this class only exposes static members.
  const OcptInlineStyleAttributions._();

  /// The attribution toggled for each [OcptInlineStyle].
  static const Map<OcptInlineStyle, Attribution> _attributionsByStyle = {
    OcptInlineStyle.bold: boldAttribution,
    OcptInlineStyle.italic: italicsAttribution,
    OcptInlineStyle.underline: underlineAttribution,
  };

  /// The `Attribution` toggled when applying [style].
  static Attribution attributionOf(OcptInlineStyle style) => _attributionsByStyle[style]!;
}
