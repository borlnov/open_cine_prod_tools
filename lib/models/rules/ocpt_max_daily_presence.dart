// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Reads [text] as a person's maximum daily presence and returns it in **minutes**, or null when
/// it holds no figure at all — an empty field, something that isn't a whole number, or a negative
/// one.
///
/// The one place the app turns what is typed into `people.maxDailyPresenceMinutes`, mirroring
/// `ocptCostCentsOf`'s own shape for the element sheet's cost field: a plain non-negative integer
/// is the whole grammar — there is no clock reading to parse, since this is a **length**, not a
/// point in the day, exactly as `OcptPeopleTable.maxDailyPresenceMinutes`'s own doc comment says.
/// Nothing here ever refuses a keystroke: the sheet autosaves as it is typed, and a field half-way
/// through being corrected reads as "nobody has said" rather than as a claim of "no maximum at
/// all".
int? ocptMaxDailyPresenceMinutesOf(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final minutes = int.tryParse(trimmed);
  if (minutes == null || minutes < 0) {
    return null;
  }

  return minutes;
}

/// Writes [minutes] the way [ocptMaxDailyPresenceMinutesOf] reads it back: the bare number, or an
/// empty string while nobody has recorded one.
String ocptMaxDailyPresenceTextOf(int? minutes) => minutes == null ? "" : "$minutes";
