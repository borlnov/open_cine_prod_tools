// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter/material.dart';

/// The application mark drawn for light surfaces: the accent-filled rounded square.
const _lightLogoAsset = SvgAsset("assets/branding/ocpt_logo_light.svg");

/// The application mark drawn for dark surfaces: the same drawing, but hollow, so it reads as a
/// light figure on a near-black background rather than as a bright violet block.
const _darkLogoAsset = SvgAsset("assets/branding/ocpt_logo_dark.svg");

/// The path of the container-less variant of the mark, the one [OcptLogoGlyph] draws.
const ocptLogoGlyphAssetPath = "assets/branding/ocpt_logo_glyph.svg";

/// The application mark without its container, monochrome and always tinted by its call site.
const _glyphLogoAsset = SvgAsset(ocptLogoGlyphAssetPath);

/// The ratio between the glyph asset's width and its height, as authored in its own viewBox: it is
/// wider than it is tall, so a call site sizing it by width gets a slightly shorter drawing back.
const double _glyphAspectRatio = 48 / 41;

/// Returns the variant of the mark that suits [brightness]: the accent-filled square on a light
/// surface, the hollow one on a dark surface, where a violet block would glare.
///
/// This is what [OcptLogo] resolves against the ambient theme; it is exposed so the choice itself
/// can be checked without going through a rendered SVG.
SvgAsset ocptLogoAssetFor(Brightness brightness) =>
    brightness == Brightness.dark ? _darkLogoAsset : _lightLogoAsset;

/// The application logo, sized to a [size] square and picking the variant that suits the ambient
/// theme: the accent-filled square in light theme, the hollow one in dark theme.
///
/// This is the mark as a whole, container included; use [OcptLogoGlyph] instead to lay it over a
/// surface that already carries the accent colour.
class OcptLogo extends StatelessWidget {
  /// The side of the square the logo is drawn in, in logical pixels.
  final double size;

  /// Class constructor
  const OcptLogo({required this.size, super.key});

  @override
  Widget build(BuildContext context) =>
      ocptLogoAssetFor(Theme.of(context).brightness).getWidget(width: size, height: size);
}

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
