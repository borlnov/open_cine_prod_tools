// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_logo.dart';

/// The application logo stripped of its rounded square: the three perforations and the screenplay
/// page alone, [width] wide and tinted with [color].
///
/// This is the variant for a surface that already carries the accent colour — the workspace
/// toolbar's back badge — where [OcptLogo]'s own violet container would be invisible. The drawing
/// is wider than it is tall, so it takes the width it is given and keeps its own proportions for
/// the height.
class OcptLogoGlyph extends StatelessWidget {
  /// The width the glyph is drawn at, in logical pixels.
  final double width;

  /// The colour the whole glyph is drawn in.
  final Color color;

  /// Class constructor
  const OcptLogoGlyph({required this.width, required this.color, super.key});

  @override
  Widget build(BuildContext context) =>
      _glyphLogoAsset.getWidget(width: width, height: width / _glyphAspectRatio, color: color);
}

/// The application mark without its container, monochrome and always tinted by its call site.
const _glyphLogoAsset = SvgAsset(ocptLogoGlyphAssetPath);

/// The ratio between the glyph asset's width and its height, as authored in its own viewBox: it is
/// wider than it is tall, so a call site sizing it by width gets a slightly shorter drawing back.
const double _glyphAspectRatio = 48 / 41;
