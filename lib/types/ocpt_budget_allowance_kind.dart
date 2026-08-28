// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What a `budget_allowances` row reimburses somebody for.
///
/// **Four flat values, and no arithmetic hangs off any of them**: the kind says what a row is
/// *about*, so the régie view can group and title its rows and the provisioning can write one quote
/// line per nature. What a row comes to is `quantityMilli × unitAmountMilliCents` whatever its
/// kind — a kilometre, a night and a meal are all a quantity at a unit price.
enum OcptBudgetAllowanceKind {
  /// A journey: the quantity is a distance and the unit price a rate per kilometre — the shape a
  /// `budget_mileage_rates` row states, which is why the dialog offers those rates as a pre-fill.
  travel,

  /// A stay: the quantity is a number of nights and the unit price a nightly rate.
  accommodation,

  /// A meal taken at somebody's own expense and paid back: the quantity is a number of meals.
  ///
  /// **Not the same thing as the catering the régie view computes above it**, and deliberately
  /// separate: catering is what the production feeds the unit on a shooting day, read off the
  /// schedule; this is what one person is paid back for a meal the production did not provide.
  meal,

  /// Anything else the production defrays: a taxi, a parking, a night train's berth.
  other,
}
