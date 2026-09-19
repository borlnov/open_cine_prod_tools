// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The common height every `OcptStoryboardPanelFrame` of the board shares within a strip, picked
/// from the board header's own `Panel size ▾` menu.
///
/// A **view preference** held in `OcptShotListState.boardPanelSize` for the session alone: it is
/// never written to the project, exactly as the floor plans' own zoom and layer visibility never
/// will be (`docs/adr/0031-storyboard-panels-and-floor-plans-in-metres.md`). A panel's own aspect
/// ratio (`ocptAspectRatioOf`) times [height] gives its frame's width.
enum OcptStoryboardPanelSize {
  /// The board's smallest, densest panel height.
  small(120),

  /// The board's default panel height.
  medium(180),

  /// The board's largest panel height.
  large(260);

  /// The height every frame of the strip is drawn at, in logical pixels.
  final double height;

  /// Class constructor
  const OcptStoryboardPanelSize(this.height);
}
