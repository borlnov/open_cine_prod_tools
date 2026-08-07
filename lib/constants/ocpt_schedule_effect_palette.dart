// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The colours the schedule agenda tints a day with under `OcptScheduleAgendaColorMode.effect`, one
/// per `OcptSceneEffectCategory`.
///
/// Plain ARGB integers, exactly like `ocptCoveragePalette`/`ocptBreakdownColorOf`: five fixed
/// colours that must read the same in every project and every legend, since — unlike the location
/// tint's own per-project palette index (`ocpt_coverage_palette.dart`, picked from a location's own
/// `colorIndex`) — an effect category is not project data, it is a fact about the words a heading
/// uses. [ocptScheduleEffectMixedColor] is deliberately as fixed and as legible as the four: it is
/// information (a day genuinely mixes more than one effect), not its absence. The absence itself — a
/// day with nothing placed, or with nothing classifiable — has no entry here at all: it tints with
/// the theme's own `outlineVariant`, `ocptScheduleDayLocationTint`'s own "no location" convention,
/// since there is no project-independent fact to colour it with either.
library;

import 'package:open_cine_prod_tools/types/ocpt_scene_effect_category.dart';

/// The colour [OcptSceneEffectCategory.interiorDay] is drawn with, as an ARGB integer.
const int ocptScheduleEffectInteriorDayColor = 0xFFE0A93E;

/// The colour [OcptSceneEffectCategory.interiorNight] is drawn with, as an ARGB integer.
const int ocptScheduleEffectInteriorNightColor = 0xFF5E72C4;

/// The colour [OcptSceneEffectCategory.exteriorDay] is drawn with, as an ARGB integer.
const int ocptScheduleEffectExteriorDayColor = 0xFFEF7B45;

/// The colour [OcptSceneEffectCategory.exteriorNight] is drawn with, as an ARGB integer.
const int ocptScheduleEffectExteriorNightColor = 0xFF2A3B7A;

/// The colour [OcptSceneEffectCategory.mixed] is drawn with, as an ARGB integer.
const int ocptScheduleEffectMixedColor = 0xFF8C7FB8;

/// The colour of effect category [category], as an ARGB integer.
///
/// A `switch` with no `default`: a new [OcptSceneEffectCategory] value must be given its own colour
/// here rather than silently falling back to one already in use, exactly as `_elementColorOf`
/// (`ocpt_breakdown_palette.dart`) already does for `OcptElementCategory`.
int ocptScheduleEffectColorOf(
  OcptSceneEffectCategory category,
) => switch (category) {
  OcptSceneEffectCategory.interiorDay => ocptScheduleEffectInteriorDayColor,
  OcptSceneEffectCategory.interiorNight => ocptScheduleEffectInteriorNightColor,
  OcptSceneEffectCategory.exteriorDay => ocptScheduleEffectExteriorDayColor,
  OcptSceneEffectCategory.exteriorNight => ocptScheduleEffectExteriorNightColor,
  OcptSceneEffectCategory.mixed => ocptScheduleEffectMixedColor,
};
