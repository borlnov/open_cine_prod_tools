// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The colours the schedule agenda tints a **non-shooting** day with, one per
/// `OcptShootingDayKind` that is not `OcptShootingDayKind.shoot`.
///
/// Plain ARGB integers, exactly like `ocptScheduleEffectColorOf`'s own palette next door and like
/// `ocptCoveragePalette`: two fixed colours that must read the same in every project, a day's kind
/// being a fact about what happens on it rather than project data anybody picked an index for.
///
/// A **pair, not a trio**: a shooting day has no entry here at all and keeps whatever the agenda's
/// own `Colour by` control says — its location, or the effect of what is placed on it. That control
/// gains no third entry either: a casting or a rehearsal day carries its own tint in all three
/// presentations **whatever** `Colour by` currently is, because "this day does not shoot" is not a
/// colouring choice a reader makes, it is the first thing they need to know about the day.
library;

/// The colour a casting day is drawn with, as an ARGB integer.
const int ocptScheduleCastingDayColor = 0xFF2E9E8F;

/// The colour a rehearsal day is drawn with, as an ARGB integer.
const int ocptScheduleRehearsalDayColor = 0xFFB1567D;
