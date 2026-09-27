// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The scope bubble's own three answers to a pending set-scope move/rotate/resize
/// (`OcptShotListState.pendingFloorPlanScopeDecision`, `docs/plans/storyboard.md`, §10.4).
enum OcptFloorPlanScopeChoice {
  /// Writes the change onto the set-scope original, shared by every sequence the set is linked to.
  every,

  /// Writes the change onto a scene-scope override of the focused sequence alone — updating one
  /// that already exists, or creating one.
  only,

  /// Drops the pending decision without writing anything: the element snaps back.
  cancel,
}
