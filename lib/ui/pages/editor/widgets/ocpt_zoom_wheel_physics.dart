// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_zoom_wheel.dart';

/// Scroll physics refusing the user's offset while the zoom modifier is held, so a Ctrl + wheel
/// notch is left to `OcptEditorZoomWheel` instead of scrolling the page it is zooming.
///
/// A scrollable only takes a wheel event when its physics accept the user's offset, and the one
/// nearest to the pointer registers first: this is how a zoom gesture gets to be the one that
/// wins.
///
/// A desktop scrolling (clamped, keeping its range when the content changes size), which is the
/// one a window wide enough to zoom in has; the instance is a constant on purpose, since a new one
/// at every build is a new scroll behavior for the scrollables reading it.
class OcptZoomWheelPhysics extends ClampingScrollPhysics {
  /// Class constructor
  const OcptZoomWheelPhysics({super.parent = const RangeMaintainingScrollPhysics()});

  /// Create the physics applied on top of [ancestor].
  @override
  OcptZoomWheelPhysics applyTo(ScrollPhysics? ancestor) =>
      OcptZoomWheelPhysics(parent: buildParent(ancestor));

  /// Tell whether the user's offset is accepted: not while the zoom modifier is held.
  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      !OcptEditorZoomWheel.isZoomModifierPressed && super.shouldAcceptUserOffset(position);
}
