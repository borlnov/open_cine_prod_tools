// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What kind of mark a `storyboard_annotations` row draws over a storyboard panel's frame.
///
/// The fixed vocabulary the storyboard's light annotation layer is limited to — no freehand drawing
/// of any kind (`docs/plans/storyboard.md`, §1). `movementArrow` and `cameraMoveArrow` each read
/// `x1`/`y1`/`x2`/`y2` (an arrow's two ends); `label` reads `x1`/`y1` only, the point it is anchored
/// to.
enum OcptStoryboardAnnotationKind {
  /// An arrow marking how something *in frame* moves — an actor crossing, a car passing.
  movementArrow,

  /// An arrow marking how the *camera* moves — a pan, a dolly, a push-in.
  cameraMoveArrow,

  /// A short text label anchored to a single point of the frame.
  label,
}
