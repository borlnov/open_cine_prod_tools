// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What a `location_availabilities` window allows.
///
/// Both values *are* availabilities — a window the production cannot use at all is simply not
/// declared. The distinction is whether shooting it costs something to respect: the schedule mode
/// may fill an [available] window without reading anything else, while a [conditional] one always
/// carries the condition in the row's note, and is what a call sheet has to repeat.
enum OcptLocationAvailabilityKind {
  /// The location may be shot in over this window, with nothing further to respect.
  available,

  /// The location may be shot in over this window, under the condition the row's note spells out
  /// ("no noise after 22:00", "no vehicle in the courtyard").
  conditional,
}
