// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A tab of the shot list mode's right dock, declared in the order the dock's tab row shows them.
///
/// The screenplay editor's own `OcptEditorRightDockTab` is deliberately not reused: the two modes
/// share the dock *chrome*, not the set of panels it can host (the editor also has a formatted
/// preview and a Fountain syntax guide, neither of which means anything here). [versions] is the
/// one exception both enums declare, since a version covers the whole project rather than any one
/// mode's data — the panel it shows is the very same widget in both docks.
enum OcptShotListRightDockTab {
  /// The shot inspector: every field of the selected shot, and its scenario coverage.
  inspector,

  /// The read-only metadata of the shot list as a whole.
  metadata,

  /// The project's named versions: the production history the user creates, browses read-only and
  /// deletes.
  versions,
}
