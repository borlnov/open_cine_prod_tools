// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The parts of the breakdown mode's shared data that a view can ask the mode to read again after
/// it wrote (`OcptBreakdownBloc.reload`).
///
/// The mode reads them with an exhaustive `switch` over this enum, so a part nobody can ask for
/// or nobody reads does not compile. The screenplay text and the page setup are not here: nothing
/// in the mode writes them, and only a whole load (entry, a version preview, a restore) and the
/// project settings page read them again.
enum OcptBreakdownReloadScope {
  /// The whole breakdown: the scenes with their tags and sheets, and the four catalogues the tags
  /// point into (elements, roles, sets with their locations, people). They are joined into one
  /// snapshot, so no part of it can be read alone.
  snapshot,
}
