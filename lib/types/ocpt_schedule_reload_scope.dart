// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The parts of the schedule mode's shared data that a view can ask the mode to read again after
/// it wrote (`OcptScheduleBloc.reload`).
///
/// The mode reads them with an exhaustive `switch` over this enum, so a part nobody can ask for
/// or nobody reads does not compile. The catalogues (locations, roles, people, elements,
/// candidacies) and the page setup are not here: nothing in the mode writes them, and only a whole
/// load (entry, a version preview, the project settings page) reads them again.
enum OcptScheduleReloadScope {
  /// The schedule itself: the days with their slots, crew, cast, guests, blocks and events.
  schedule,

  /// Every episode's own shot list, with the project's episodes it is read for.
  shotLists,
}
