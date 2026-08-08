// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which day a week starts on, an app-wide display preference persisted through
/// `OcptPropertiesManager.firstWeekday` and read by the schedule mode's week and month agendas.
///
/// A calendar preference rather than a locale one: it is deliberately **not** deduced from the UI
/// language, because the two answer different questions — a French-speaking production working with
/// an American schedule reads its weeks from Sunday while still wanting a French interface, and
/// `intl` carries no per-locale first weekday this app could have honoured anyway.
enum OcptFirstWeekday {
  /// The week starts on Monday — the ISO-8601 reading, and the default.
  monday(DateTime.monday),

  /// The week starts on Sunday, as it does across North America and much of Asia.
  sunday(DateTime.sunday);

  /// The [DateTime] weekday constant this entry stands for (`DateTime.monday` is 1 through
  /// `DateTime.sunday` is 7), which is what the week-start arithmetic is done in.
  final int dateTimeWeekday;

  /// Class constructor
  const OcptFirstWeekday(this.dateTimeWeekday);
}
