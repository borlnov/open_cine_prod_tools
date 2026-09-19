// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which of the shot list mode's centre views is currently shown, toggled by
/// `OcptShotListCentreHeader`'s own view switch.
///
/// Mirrors `OcptBreakdownCentreView`. Persisted through
/// `OcptPropertiesManager.shotListLastCentreView`.
enum OcptShotListCentreView {
  /// The dense, read-only table of the selected sequence's shots — the mode's default view.
  table,

  /// Each shot of the selected sequence as a row of its découpage read-outs beside its imported
  /// storyboard panels.
  board,

  /// The floor plan of each décor the selected sequence spans, one camera position per shot.
  floorPlans,
}
