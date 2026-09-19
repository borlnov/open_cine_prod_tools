// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The aspect ratio (width / height) a storyboard panel's frame is drawn at when nothing in its
/// shot's `recordingFormat` yields one — see [ocptAspectRatioOf].
const double ocptStoryboardFallbackAspectRatio = 16 / 9;

/// The smallest and largest ratio a bare decimal number found in [ocptAspectRatioOf]'s free text is
/// accepted as an aspect ratio for, rather than as some other figure the text happens to carry (a
/// frame rate, a resolution). Every real-world cinema ratio, from 1.33 (Academy) to 2.76
/// (Ultra Panavision), sits well inside this band.
const double _minimumPlausibleRatio = 1;
const double _maximumPlausibleRatio = 3.5;

/// A `width:height` or `width/height` pair, either side an integer or a decimal.
final RegExp _ratioPattern = RegExp(r'(\d+(?:\.\d+)?)\s*[:/]\s*(\d+(?:\.\d+)?)');

/// A bare decimal number (at least one digit either side of the point), the shape a ratio like
/// `2.39` or `1.85` is written in when no `:1` follows it.
final RegExp _bareDecimalPattern = RegExp(r'\d+\.\d+');

/// The aspect ratio (width / height) found in [recordingFormat]'s free text, or
/// [ocptStoryboardFallbackAspectRatio] (16:9) when none is found.
///
/// A shot's `recordingFormat` is free text (`docs/plans/storyboard.md`, §1, §8/ADR 0031) — this is
/// the one place that guesses a ratio out of it, read alike by the board's frames and by the
/// storyboard PDF, so the two can never disagree. Recognises, in order:
///
/// - a `width:height` or `width/height` pair (`2.39:1`, `16:9`, `4/3`, `4:3`);
/// - a bare decimal already written as a ratio to 1 (`2.39`, `1.85`), accepted only when it falls
///   inside a plausible cinema-ratio band so a frame rate written as a decimal (`23.976 fps`) is
///   never mistaken for one.
///
/// Anything else — `4K · 25 fps`, `anamorphic`, an empty string — falls back to 16:9, the
/// validated choice (`docs/plans/storyboard.md`, §2, §8, decision 3).
double ocptAspectRatioOf(String recordingFormat) {
  final colonOrSlashMatch = _ratioPattern.firstMatch(recordingFormat);
  if (colonOrSlashMatch != null) {
    final width = double.parse(colonOrSlashMatch.group(1)!);
    final height = double.parse(colonOrSlashMatch.group(2)!);
    if (height > 0) {
      return width / height;
    }
  }

  for (final match in _bareDecimalPattern.allMatches(recordingFormat)) {
    final value = double.parse(match.group(0)!);
    if (value >= _minimumPlausibleRatio && value <= _maximumPlausibleRatio) {
      return value;
    }
  }

  return ocptStoryboardFallbackAspectRatio;
}
