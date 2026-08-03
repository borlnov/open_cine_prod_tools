// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The seven weekdays as one integer: which days of the week a dated range actually covers.
///
/// Bit `1 << (weekday - 1)` stands for `weekday`, using `DateTime`'s own numbering
/// (`DateTime.monday` = 1 … `DateTime.sunday` = 7) so nothing here ever has to translate a date's
/// own answer. A mask is stored in `location_availabilities.weekdays` and read by the schedule mode
/// later; the functions below are the only place that knows how it is packed.
///
/// A mask is **never empty**: a window covering no day of the week at all says nothing, so
/// [ocptWeekdayMaskToggled] refuses to clear the last day rather than letting a row become
/// meaningless.
library;

/// The mask covering every day of the week — the value a fresh range starts on, since a range says
/// every day of itself until the user says otherwise.
const int ocptEveryWeekdayMask = 0x7F;

/// The weekday numbers, in `DateTime`'s own order, Monday first.
const List<int> ocptWeekdays = [
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
  DateTime.sunday,
];

/// Whether [mask] covers [weekday], a `DateTime.monday`…`DateTime.sunday` value.
bool ocptWeekdayMaskContains(int mask, int weekday) => mask & _bitOf(weekday) != 0;

/// Whether [mask] covers the whole week, i.e. whether it narrows its range to nothing in
/// particular — which is how a range with no weekday restriction reads.
bool ocptWeekdayMaskCoversEveryDay(int mask) =>
    mask & ocptEveryWeekdayMask == ocptEveryWeekdayMask;

/// [mask] with [weekday] added when it was missing, removed when it was there.
///
/// Removing the **last** covered day returns [mask] untouched: a window has to cover some day, and
/// the caller's control simply doesn't move rather than reporting an error the user can do nothing
/// with.
int ocptWeekdayMaskToggled(int mask, int weekday) {
  final bit = _bitOf(weekday);
  if (mask & bit == 0) {
    return mask | bit;
  }

  final cleared = mask & ~bit & ocptEveryWeekdayMask;
  return cleared == 0 ? mask : cleared;
}

/// Whether [date] falls on a day of the week [mask] covers.
bool ocptWeekdayMaskCoversDate(int mask, DateTime date) =>
    ocptWeekdayMaskContains(mask, date.weekday);

/// The bit standing for [weekday] in a mask, 0 for a number that is no weekday at all — a stored
/// mask outlives the code that wrote it, so nothing here throws on one.
int _bitOf(int weekday) =>
    weekday < DateTime.monday || weekday > DateTime.sunday ? 0 : 1 << (weekday - 1);
