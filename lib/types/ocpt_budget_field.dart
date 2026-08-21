// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One of the budget mode's typed, free-text fields — a poste's or a quote line's own — whose
/// edits go through `OcptBudgetBloc`'s 2 s autosave debounce rather than being written immediately,
/// mirroring `OcptScheduleField`'s own single flat enum over several kinds of entity (a poste's own
/// fields are prefixed `poste…`, a line's `line…`, so one pending-edit map can key on either
/// without the two ever colliding).
///
/// Every non-typed write of this mode — a line's tax-basis radio, a reorder, a delete, a creation —
/// is its own bloc event instead, written the moment it is dispatched: only what somebody is
/// actively typing rides the debounce.
///
/// [lineVatRateOverride] is the one case with no direct mirror on `OcptElementField`: parsing its
/// text through `ocptVatRateBasisPointsOf` already answers null for an empty or unparseable
/// submission, and this mode reads that null as "leave the override exactly as it is" rather than
/// as "clear it" — the field's own way back to inheriting the project's rate is
/// `OcptBudgetLineVatRateInheritedRequestedEvent`, a dedicated, immediate gesture, exactly as the
/// project settings' own `No rate` button is for `defaultVatRateBasisPoints`. An empty text field is
/// not that gesture: a stray backspace must never silently drop an override typed on purpose.
enum OcptBudgetField {
  /// Maps to `OcptBudgetQuoteService.updatePoste`'s `label`.
  posteLabel,

  /// Maps to `OcptBudgetQuoteService.updatePoste`'s `code`.
  posteCode,

  /// Maps to `OcptBudgetQuoteService.updateLine`'s `label`.
  lineLabel,

  /// Maps to `OcptBudgetQuoteService.updateLine`'s `quantityMilli`, read through the typed figure
  /// (`ocptBudgetQuantityMilliOf`) — a submission that doesn't parse is skipped rather than written
  /// as zero, `budget_lines.quantityMilli` never being nullable.
  lineQuantity,

  /// Maps to `OcptBudgetQuoteService.updateLine`'s `unit`.
  lineUnit,

  /// Maps to `OcptBudgetQuoteService.updateLine`'s `unitAmountCents`, read through
  /// `ocptCostCentsOf` — a submission that doesn't parse is skipped, `unitAmountCents` never being
  /// nullable either.
  lineUnitAmount,

  /// Maps to `OcptBudgetQuoteService.updateLine`'s `vatRateBasisPoints`, read through
  /// `ocptVatRateBasisPointsOf` — see the class doc comment for why an empty submission is skipped
  /// rather than read as "inherit".
  lineVatRateOverride,

  /// Maps to `OcptBudgetQuoteService.updateLine`'s `notes`.
  lineNotes,
}
