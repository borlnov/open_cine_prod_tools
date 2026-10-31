// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The parts of the resources mode's shared data that a view can ask the mode to read again after
/// it wrote (`OcptResourcesBloc.reload`).
///
/// The mode reads them with an exhaustive `switch` over this enum, so a part nobody can ask for
/// or nobody reads does not compile. The currency, the page setup, the mileage rates and the sets
/// that hold a floor plan are not here: nothing in the mode writes them, and only a whole load
/// (entry, a version preview, the project settings page) reads them again.
enum OcptResourcesReloadScope {
  /// The whole catalogue: the people, the cast with its candidacies, the locations with their
  /// sets, the elements and the scenes they are linked to. The four services' reads are joined
  /// into one snapshot, so no part of it can be read alone.
  snapshot,
}
