// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The saturation [ocptFloorPlanCharacterColourOf] fixes every derived colour at, 0..1 — high
/// enough that the hue reads clearly on the canvas's near-black surface and on the PDF's white page
/// alike.
const double _characterColourSaturation = 0.55;

/// The lightness [ocptFloorPlanCharacterColourOf] fixes every derived colour at, 0..1 — legible as
/// both a filled disc's own colour and a border stroke, in light and dark theme alike.
const double _characterColourLightness = 0.5;

/// The deterministic, fully-opaque ARGB colour (`0xAARRGGBB`) a character symbol's own disc is
/// drawn in, derived from its [name] (`OcptFloorPlanSymbol.label`) — the same name always yields the
/// same colour, on the canvas and on paper alike, with no palette stored anywhere: the "derived,
/// never stored" rule `docs/plans/storyboard.md` already applies to a camera's own letter, applied
/// here to a character's own colour instead.
///
/// [name] is trimmed and lower-cased first, so `Sam`, `sam ` and `SAM` share one colour; an empty or
/// whitespace-only name still returns a valid, stable colour rather than throwing (every character
/// symbol has *some* colour to draw with the moment it exists, labelled or not).
///
/// The hue is a simple string hash reduced modulo 360 — not cryptographic and not collision-free
/// (two different names can land on the same hue), but stable across app runs and platforms, which
/// is the one property this rule actually needs. Saturation and lightness are fixed
/// ([_characterColourSaturation], [_characterColourLightness]) so only the hue ever varies between
/// two characters.
int ocptFloorPlanCharacterColourOf(String name) {
  final normalized = name.trim().toLowerCase();
  // An empty name still hashes to a real, stable hue rather than a special-cased colour — the
  // seed is a single space, arbitrary but fixed, standing in for "no name" wherever the codeUnits
  // loop below would otherwise see nothing to hash at all.
  final seed = normalized.isEmpty ? " " : normalized;

  var hash = 0;
  for (final codeUnit in seed.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  final hue = (hash % 360).toDouble();

  return _argbOfHsl(
    hue: hue,
    saturation: _characterColourSaturation,
    lightness: _characterColourLightness,
  );
}

/// [hue] (0..360), [saturation] and [lightness] (0..1) converted to a fully opaque ARGB int — the
/// standard HSL-to-RGB conversion, written out directly rather than pulled in from a package for one
/// small, pure computation this rule alone needs.
int _argbOfHsl({required double hue, required double saturation, required double lightness}) {
  final chroma = (1 - (2 * lightness - 1).abs()) * saturation;
  final huePrime = hue / 60;
  final secondLargest = chroma * (1 - (huePrime % 2 - 1).abs());
  final lightnessMatch = lightness - chroma / 2;

  double red1;
  double green1;
  double blue1;
  if (huePrime < 1) {
    red1 = chroma;
    green1 = secondLargest;
    blue1 = 0;
  } else if (huePrime < 2) {
    red1 = secondLargest;
    green1 = chroma;
    blue1 = 0;
  } else if (huePrime < 3) {
    red1 = 0;
    green1 = chroma;
    blue1 = secondLargest;
  } else if (huePrime < 4) {
    red1 = 0;
    green1 = secondLargest;
    blue1 = chroma;
  } else if (huePrime < 5) {
    red1 = secondLargest;
    green1 = 0;
    blue1 = chroma;
  } else {
    red1 = chroma;
    green1 = 0;
    blue1 = secondLargest;
  }

  final red = (((red1 + lightnessMatch) * 255).round()).clamp(0, 255);
  final green = (((green1 + lightnessMatch) * 255).round()).clamp(0, 255);
  final blue = (((blue1 + lightnessMatch) * 255).round()).clamp(0, 255);

  return 0xFF000000 | (red << 16) | (green << 8) | blue;
}
