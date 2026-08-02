// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The colours the scenario coverage export draws a shot's bars, ticks and legend swatch with.
///
/// Plain ARGB integers rather than a `Color` or a `PdfColor`: the palette is consumed by the PDF
/// renderer today and is wanted on screen later (the shot list table, the coverage dialog), so it
/// must not commit to either package's colour type — each call site converts at the point of use.
///
/// The ordering is the palette itself, not a preference: a shot's colour is the entry at its rank
/// within its sequence, so the same project exported twice always produces the same document. No
/// meaning whatsoever is attached to a particular colour.
library;

/// The 16 colours a coverage bar is drawn with, in the order shots take them.
///
/// Chosen for two properties, in this order:
///
/// * every one of them stays legible on white paper — they are all dark enough for a thin bar and
///   a small label printed in that same colour to read on an ordinary laser print;
/// * consecutive entries are as far apart in hue as the list length allows, so two shots of the
///   same sequence never look alike even to a reader glancing at the margin.
///
/// 16 is a deliberate ceiling rather than a technical one: a sequence with more shots than this
/// takes the palette again through [ocptCoverageColorAt]'s hue rotation, which is the point at
/// which "no two shots of one sequence share a colour" stops being satisfiable exactly.
const List<int> ocptCoveragePalette = [
  0xFFC62828, // Red
  0xFF1565C0, // Blue
  0xFF2E7D32, // Green
  0xFFEF6C00, // Orange
  0xFF6A1B9A, // Purple
  0xFF00838F, // Cyan
  0xFFAD1457, // Pink
  0xFF558B2F, // Light green
  0xFF283593, // Indigo
  0xFFD84315, // Deep orange
  0xFF00695C, // Teal
  0xFF4527A0, // Deep purple
  0xFF0277BD, // Light blue
  0xFF827717, // Lime
  0xFF4E342E, // Brown
  0xFF37474F, // Blue grey
];

/// How far, in degrees, a whole cycle of [ocptCoveragePalette] is rotated around the colour wheel
/// each time a single sequence exhausts it.
///
/// Big enough that a repeated rank reads as a different colour, small enough that the rotated
/// entries keep the lightness and saturation the palette was picked for — only the hue moves.
const double _cycleHueRotationDegrees = 30;

/// The colour a shot of [rank] within its sequence is drawn with, as an ARGB integer.
///
/// [rank] is the shot's 0-based position in its own sequence, unbounded: the first 16 shots take
/// [ocptCoveragePalette] as it stands, and every further cycle takes it again with its hue rotated
/// by [_cycleHueRotationDegrees] per cycle. The 17th shot of one sequence is therefore the point
/// where Benoit's "no two shots of a sequence share a colour" constraint stops holding exactly —
/// the rotation only guarantees the repetition is visibly different, not that it is unique.
int ocptCoverageColorAt(int rank) {
  final index = rank % ocptCoveragePalette.length;
  final cycle = rank ~/ ocptCoveragePalette.length;
  final color = ocptCoveragePalette[index];
  if (cycle == 0) {
    return color;
  }
  return _rotateHue(color, cycle * _cycleHueRotationDegrees);
}

/// [color] with its hue rotated by [degrees], keeping its alpha, saturation and lightness.
///
/// Written out here rather than taken from a colour package because this file must stay free of
/// both Flutter and `pdf`: the conversion is the textbook RGB → HSL → RGB round trip, over the
/// 8-bit channels an ARGB integer packs.
int _rotateHue(int color, double degrees) {
  final alpha = (color >> 24) & 0xFF;
  final red = ((color >> 16) & 0xFF) / 255;
  final green = ((color >> 8) & 0xFF) / 255;
  final blue = (color & 0xFF) / 255;

  final max = [red, green, blue].reduce((a, b) => a > b ? a : b);
  final min = [red, green, blue].reduce((a, b) => a < b ? a : b);
  final lightness = (max + min) / 2;
  final delta = max - min;

  if (delta == 0) {
    // A pure grey has no hue to rotate; the palette holds none today, but a caller passing one
    // must get it back unchanged rather than a rounding artefact of the round trip.
    return color;
  }

  final saturation = delta / (1 - (2 * lightness - 1).abs());
  final double hue;
  if (max == red) {
    hue = 60 * (((green - blue) / delta) % 6);
  } else if (max == green) {
    hue = 60 * ((blue - red) / delta + 2);
  } else {
    hue = 60 * ((red - green) / delta + 4);
  }

  return _fromHsl(
    alpha: alpha,
    hue: (hue + degrees) % 360,
    saturation: saturation,
    lightness: lightness,
  );
}

/// The ARGB integer of the colour with [alpha], [hue] (in degrees), [saturation] and [lightness],
/// the inverse of the decomposition [_rotateHue] runs.
int _fromHsl({
  required int alpha,
  required double hue,
  required double saturation,
  required double lightness,
}) {
  final chroma = (1 - (2 * lightness - 1).abs()) * saturation;
  final secondary = chroma * (1 - ((hue / 60) % 2 - 1).abs());
  final offset = lightness - chroma / 2;

  final (double red, double green, double blue) = switch (hue) {
    < 60 => (chroma, secondary, 0),
    < 120 => (secondary, chroma, 0),
    < 180 => (0, chroma, secondary),
    < 240 => (0, secondary, chroma),
    < 300 => (secondary, 0, chroma),
    _ => (chroma, 0, secondary),
  };

  int channel(double value) => ((value + offset) * 255).round().clamp(0, 255);

  return (alpha << 24) | (channel(red) << 16) | (channel(green) << 8) | channel(blue);
}
