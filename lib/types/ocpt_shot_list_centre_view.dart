// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which of the shot list mode's centre views is currently shown, toggled by
/// `OcptShotListCentreHeader`'s own view switch.
///
/// Mirrors `OcptBreakdownCentreView`. [floorPlans] exists here because M5/M6 (the floor plans view,
/// `docs/plans/storyboard.md`) reference it on `OcptShotListState.centreView` and persist it through
/// `OcptPropertiesManager.shotListLastCentreView` exactly like the other two — but **its segment is
/// not offered by the switch yet**: `OcptShotListCentreHeader` shows `Table · Board` only in this
/// milestone, so a stored `floorPlans` value from a later build downgrading to this one, or a value
/// this build never actually offers, is never reachable from the switch itself. Wiring it into the
/// switch is M5's own change, not this one's.
enum OcptShotListCentreView {
  /// The dense, read-only table of the selected sequence's shots — the mode's default view.
  table,

  /// Each shot of the selected sequence as a row of its découpage read-outs beside its imported
  /// storyboard panels.
  board,

  /// The floor plan of each décor the selected sequence spans, one camera position per shot. Not
  /// reachable from the switch yet — see the class doc comment.
  floorPlans,
}
