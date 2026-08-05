// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A tab of the breakdown mode's right dock.
///
/// A single entry today, mirroring `OcptResourcesRightDockTab`: the `Inspector` tab the plan this
/// mode ships under describes is a later milestone's, and a tab nothing can select yet would be
/// dead code. [versions] still has to exist here because the `Versions` tab is hosted by *every*
/// production mode's right dock once project versions landed, and a mode with no right dock at all
/// would be the only one from which a user could not seal or browse one.
enum OcptBreakdownRightDockTab {
  /// The project's named versions: the production history the user creates, browses read-only and
  /// deletes.
  versions,
}
