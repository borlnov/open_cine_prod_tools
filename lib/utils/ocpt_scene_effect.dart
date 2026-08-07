// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_scene_effect_category.dart';

/// A scene heading's own interior/exterior half, as `ocptSceneEffectOf` reads it. Null (rather than
/// a third value) when the heading's own prefix names neither unambiguously — an `INT/EXT` (or
/// `I/E`) heading, or one starting with neither word at all — since guessing which of the two a
/// scene mixing both actually is would be inventing a fact the heading itself refuses to commit to.
enum OcptScenePlace {
  /// The heading's own prefix reads as interior alone (`INT`).
  interior,

  /// The heading's own prefix reads as exterior alone (`EXT`, or the `EST` variant some scripts
  /// use).
  exterior,
}

/// A scene heading's own time-of-day half, as `ocptSceneEffectOf` reads it. Null when the words
/// found are not one of the small set this app recognises — see `ocptSceneEffectOf`'s own doc
/// comment for why that set stays deliberately small.
enum OcptSceneTimeOfDay {
  /// The heading's own suffix reads as one of the day words `ocptSceneEffectOf` recognises.
  day,

  /// The heading's own suffix reads as one of the night words `ocptSceneEffectOf` recognises.
  night,
}

/// What `ocptSceneEffectOf` read out of one scene heading: [printedEffect] is the heading's own
/// words, verbatim, exactly what `OcptCallSheetPdfService`'s own `EFFET` column has always printed
/// (`EXT / JOUR`) — and, separately, how those same words classify along the two axes a heading can
/// be read on, each nullable on its own terms (see [OcptScenePlace] and [OcptSceneTimeOfDay]).
/// [printedEffect] and the two classifications are never in conflict, since both are read from the
/// very same heading by the very same function, but the two answer different questions: one prints
/// what the heading says, the other says what the app can safely do with it (a shot placed on a
/// day and tinted by effect, chiefly — `ocptSceneEffectCategoryOf` below).
class OcptSceneEffect {
  /// Nothing to report: the heading was null, or carried no `<place> - <time of day>` split at all.
  static const OcptSceneEffect none = OcptSceneEffect._();

  /// The heading's own interior/exterior half joined with its time-of-day half (`EXT / JOUR`), or
  /// null while the heading carried nothing to read.
  final String? printedEffect;

  /// The heading's own interior/exterior half, classified — null while unreadable or ambiguous.
  final OcptScenePlace? place;

  /// The heading's own time-of-day half, classified — null while unreadable or unrecognised.
  final OcptSceneTimeOfDay? timeOfDay;

  /// Class constructor
  const OcptSceneEffect({this.printedEffect, this.place, this.timeOfDay});

  /// Private constructor behind [none], so every "nothing to report" instance is the same constant.
  const OcptSceneEffect._()
    : printedEffect = null,
      place = null,
      timeOfDay = null;
}

/// [heading]'s own interior/exterior half and time-of-day half, joined as the reference call sheet's
/// own `EFFET` column reads (`EXT / JOUR`), plus how those two halves classify along
/// [OcptScenePlace] and [OcptSceneTimeOfDay] — each of the two null on its own terms whenever the
/// heading doesn't say, the app never inventing one for a heading that refuses to commit to it.
///
/// The one place a scene heading is read this way: `OcptCallSheetPdfService`'s own `EFFET` column
/// and the schedule agenda's own "Colour by effect" tint both call this, so a printed call sheet and
/// the agenda's own reading of the very same day can never disagree about what a heading says.
///
/// **Time-of-day classification only ever recognises a small, fixed set of words** — `DAY`/`NIGHT`
/// and their French equivalents `JOUR`/`NUIT`, compared case-insensitively — and everything else
/// (`DUSK`, `AUBE`, `MAGIC HOUR`, a heading naming no time of day worth splitting off at all) reads
/// as [OcptSceneTimeOfDay] null rather than being forced into one of the two. Widening that set is a
/// decision about **which words a screenplay's own language uses for a time of day**, not a bug fix:
/// a future reader adding a word should ask whether it is genuinely unambiguous in that language
/// first, since a wrongly classified heading tints a whole shooting day the wrong colour.
OcptSceneEffect ocptSceneEffectOf(String? heading) {
  if (heading == null) {
    return OcptSceneEffect.none;
  }
  final trimmed = heading.trim();
  final separatorIndex = trimmed.lastIndexOf(" - ");
  if (separatorIndex <= 0) {
    return OcptSceneEffect.none;
  }

  final prefix = trimmed.substring(0, separatorIndex).trim().toUpperCase();
  final timeOfDayText = trimmed.substring(separatorIndex + 3).trim();
  if (prefix.isEmpty || timeOfDayText.isEmpty) {
    return OcptSceneEffect.none;
  }

  final String intExtLabel;
  OcptScenePlace? place;
  if (prefix.startsWith("INT./EXT") ||
      prefix.startsWith("INT/EXT") ||
      prefix.startsWith("I/E")) {
    intExtLabel = "INT/EXT";
    place = null;
  } else if (prefix.startsWith("EXT") || prefix.startsWith("EST")) {
    intExtLabel = "EXT";
    place = OcptScenePlace.exterior;
  } else if (prefix.startsWith("INT")) {
    intExtLabel = "INT";
    place = OcptScenePlace.interior;
  } else {
    intExtLabel = prefix;
    place = null;
  }

  return OcptSceneEffect(
    printedEffect: "$intExtLabel / $timeOfDayText",
    place: place,
    timeOfDay: _timeOfDayOf(timeOfDayText),
  );
}

/// The time-of-day half of [ocptSceneEffectOf]'s own classification — see that function's own doc
/// comment for exactly which words are recognised and why the set stays small.
OcptSceneTimeOfDay? _timeOfDayOf(String timeOfDayText) {
  final upper = timeOfDayText.toUpperCase();
  if (upper == "DAY" || upper == "JOUR") {
    return OcptSceneTimeOfDay.day;
  }
  if (upper == "NIGHT" || upper == "NUIT") {
    return OcptSceneTimeOfDay.night;
  }
  return null;
}

/// A day's own overall effect reading, over every one of [headings] — one [OcptSceneEffectCategory]
/// per classifiable heading (through [ocptSceneEffectOf]), collapsed to a single category when they
/// all agree, [OcptSceneEffectCategory.mixed] when at least two disagree, or null when none of
/// [headings] classifies at all (including an empty list — a day with nothing placed).
///
/// An unclassifiable heading — [ocptSceneEffectOf]'s own [OcptSceneEffect.place] or
/// [OcptSceneEffect.timeOfDay] null — contributes nothing either way, exactly as
/// [ocptSceneEffectOf]'s own doc comment already refuses to guess one: a day whose one classifiable
/// shot reads `INT. … - JOUR` still tints as [OcptSceneEffectCategory.interiorDay] even if another
/// of its shots carries a heading this app can't read, since there is no *known* disagreement to
/// report.
OcptSceneEffectCategory? ocptSceneEffectCategoryOf(Iterable<String?> headings) {
  final categories = <OcptSceneEffectCategory>{};

  for (final heading in headings) {
    final effect = ocptSceneEffectOf(heading);
    final place = effect.place;
    final timeOfDay = effect.timeOfDay;
    if (place == null || timeOfDay == null) {
      continue;
    }
    categories.add(switch ((place, timeOfDay)) {
      (OcptScenePlace.interior, OcptSceneTimeOfDay.day) =>
        OcptSceneEffectCategory.interiorDay,
      (OcptScenePlace.interior, OcptSceneTimeOfDay.night) =>
        OcptSceneEffectCategory.interiorNight,
      (OcptScenePlace.exterior, OcptSceneTimeOfDay.day) =>
        OcptSceneEffectCategory.exteriorDay,
      (OcptScenePlace.exterior, OcptSceneTimeOfDay.night) =>
        OcptSceneEffectCategory.exteriorNight,
    });
  }

  if (categories.isEmpty) {
    return null;
  }
  if (categories.length == 1) {
    return categories.first;
  }
  return OcptSceneEffectCategory.mixed;
}
