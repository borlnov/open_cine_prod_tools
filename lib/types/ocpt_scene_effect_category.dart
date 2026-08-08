// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One of the four ways a scene heading's own EFFET reading classifies under `ocptSceneEffectOf`
/// (`lib/utils/ocpt_scene_effect.dart`) — its interior/exterior half crossed with its day/night
/// half — plus [mixed]: a day whose placed shots classify into more than one of the four
/// (`ocptSceneEffectCategoryOf`), read by the schedule agenda's own "Colour by" control
/// (`OcptScheduleAgendaColorMode.effect`).
///
/// There is deliberately no "nothing to say" entry: a day with no classifiable heading among its
/// shots — nothing placed, or every heading unclassifiable — reads `null` wherever this type is
/// used, the same way `ocptScheduleDayLocationTint`'s own null location does. That is the absence
/// of a fact, not a fifth fact, and [mixed] must stay visually distinct from it (see
/// `lib/constants/ocpt_schedule_effect_palette.dart`'s own doc comment) since [mixed] **is**
/// information — the day genuinely mixes more than one effect — while the null case is its absence.
enum OcptSceneEffectCategory {
  /// Every classifiable heading among a day's placed shots read `INT. … - <day word>`.
  interiorDay,

  /// Every classifiable heading among a day's placed shots read `INT. … - <night word>`.
  interiorNight,

  /// Every classifiable heading among a day's placed shots read `EXT. … - <day word>`.
  exteriorDay,

  /// Every classifiable heading among a day's placed shots read `EXT. … - <night word>`.
  exteriorNight,

  /// A day's placed shots classify into more than one of the four categories above.
  mixed,
}
