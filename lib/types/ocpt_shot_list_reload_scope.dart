// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One part of the shot list mode's shared data that `OcptShotListBloc.reload` can read again from
/// the project database, so a view that has just written only pays for what its write changed.
enum OcptShotListReloadScope {
  /// The shot list itself, joined with where each shot sits in the schedule.
  snapshot,

  /// Every free-text field's suggestion list.
  suggestions,

  /// The storyboard: every shot's panels and their marks.
  storyboard,

  /// The floor plans: every set of every sequence with its symbols and arrows.
  floorPlans,

  /// The project's Resources locations and their sets.
  locations,

  /// The set-scope symbols of every set of the project, keyed by set: what the empty-state
  /// gallery's thumbnails draw.
  setScopeSymbols,

  /// The production's whole cast: every live role.
  roles,
}
