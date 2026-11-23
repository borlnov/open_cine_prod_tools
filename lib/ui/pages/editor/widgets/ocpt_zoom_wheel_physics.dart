// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_zoom_wheel.dart';

/// Scroll physics refusing the user's offset while the zoom modifier is held, so a Ctrl + wheel
/// notch is left to `OcptEditorZoomWheel` instead of scrolling the page it is zooming.
///
/// A scrollable only takes a wheel event when its physics accept the user's offset, and the one
/// nearest to the pointer registers first: this is how a zoom gesture gets to be the one that
/// wins. Everything else defers to the parent physics, which is the platform's own scrolling
/// ([over]), so a platform keeps its feel (iOS its bounce).
///
/// The same question is asked a second time, by Flutter, to decide whether the scrollable reacts
/// to a drag at all, and only when its content changes size: answering "no" then would leave
/// touch and trackpad drags dead until the next resize, whenever a size change happens with the
/// modifier held (a zoom, a paste). That second question is asked while a frame is being built,
/// whereas a wheel event is dispatched between frames: the offset is only refused outside a frame.
///
/// Build it with [over], which hands back the same instance for the same parent: a new instance
/// at every build is a new scroll behavior for the scrollables reading it.
class OcptZoomWheelPhysics extends ScrollPhysics {
  /// The last instance [over] built, kept so the next call with the same parent returns it.
  static OcptZoomWheelPhysics? _last;

  /// Tell whether no frame is being produced, which is when a pointer event is dispatched.
  bool get _isBetweenFrames => switch (SchedulerBinding.instance.schedulerPhase) {
    SchedulerPhase.idle || SchedulerPhase.postFrameCallbacks => true,
    _ => false,
  };

  /// Class constructor
  const OcptZoomWheelPhysics({super.parent});

  /// Create the physics applied on top of [ancestor].
  @override
  OcptZoomWheelPhysics applyTo(ScrollPhysics? ancestor) =>
      OcptZoomWheelPhysics(parent: buildParent(ancestor));

  /// Tell whether the user's offset is accepted: not while the zoom modifier is held.
  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      !(OcptEditorZoomWheel.isZoomModifierPressed && _isBetweenFrames) &&
      super.shouldAcceptUserOffset(position);

  /// Get the physics refusing the zoom modifier's offset on top of the platform scrolling [context]
  /// resolves, or null while [isEnabled] is false (the page can't be zoomed there, and the
  /// scrolling stays the platform's own).
  static OcptZoomWheelPhysics? over(BuildContext context, {required bool isEnabled}) {
    if (!isEnabled) {
      return null;
    }

    final parent = ScrollConfiguration.of(context).getScrollPhysics(context);
    final last = _last;
    if (last != null && last.parent == parent) {
      return last;
    }

    return _last = OcptZoomWheelPhysics(parent: parent);
  }
}
