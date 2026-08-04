// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A tab of the resources mode's right dock.
///
/// A single entry, unlike the shot list's or the screenplay editor's own right dock tabs: the
/// resources mode has no inspector tab of its own because the centre sheet already is the
/// inspector — whichever item is selected in the left dock shows its full editable sheet in the
/// centre, so there is nothing left for a dock tab to add. [versions] still has to exist here
/// because the `Versions` tab is hosted by *every* production mode's right dock once project
/// versions landed, and a mode with no right dock at all would be the only one from which a user
/// could not seal or browse one.
enum OcptResourcesRightDockTab {
  /// The project's named versions: the production history the user creates, browses read-only and
  /// deletes.
  versions,
}
