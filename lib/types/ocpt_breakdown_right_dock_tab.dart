// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A tab of the breakdown mode's right dock, mirroring `OcptShotListRightDockTab`'s own two-tab
/// shape.
enum OcptBreakdownRightDockTab {
  /// The selected target's sheet (`OcptBreakdownTargetInspector`), or — while nothing is selected —
  /// the current scene's own breakdown sheet (`OcptBreakdownSceneInspector`).
  inspector,

  /// The project's named versions: the production history the user creates, browses read-only and
  /// deletes.
  versions,
}
