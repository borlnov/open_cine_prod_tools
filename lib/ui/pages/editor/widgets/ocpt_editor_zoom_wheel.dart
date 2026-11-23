// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_zoom_wheel_physics.dart';

/// Turn the mouse wheel, with the zoom modifier held (Ctrl, Cmd on macOS), into one zoom step per
/// notch over [child], and leave a plain wheel to the scrollables beneath it.
///
/// The event is claimed through `GestureBinding.pointerSignalResolver`, so no scrollable scrolls
/// at the same time: a scrollable that would take the same event first (the first to register
/// wins, and the deepest one registers first) has to refuse it while the modifier is held, which
/// is what [OcptZoomWheelPhysics] does for every scrollable built under [child]. A scrollable that
/// reads its scroll behavior above this widget is given the physics by its owner.
///
/// With no [onZoomStepRequested], this is [child] and nothing else: the surfaces where the page
/// can't be zoomed (a compact window) simply don't listen.
class OcptEditorZoomWheel extends StatelessWidget {
  /// Called with the way to step (-1 out, 1 in) and the position of the pointer in this widget's
  /// own coordinates, or null when the page can't be zoomed here.
  final void Function(int direction, Offset localPosition)? onZoomStepRequested;

  /// The area the wheel is listened over.
  final Widget child;

  /// Tell whether the zoom modifier is held down: Cmd on macOS, Ctrl everywhere else.
  static bool get isZoomModifierPressed => defaultTargetPlatform == TargetPlatform.macOS
      ? HardwareKeyboard.instance.isMetaPressed
      : HardwareKeyboard.instance.isControlPressed;

  /// Class constructor
  const OcptEditorZoomWheel({required this.onZoomStepRequested, required this.child, super.key});

  /// Build the zoom wheel as a [Listener].
  @override
  Widget build(BuildContext context) {
    final onZoomStepRequested = this.onZoomStepRequested;
    if (onZoomStepRequested == null) {
      return child;
    }

    final scrollBehavior = ScrollConfiguration.of(context);

    return ScrollConfiguration(
      behavior: scrollBehavior.copyWith(
        physics: OcptZoomWheelPhysics.over(context, isEnabled: true),
      ),
      child: Listener(
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent || !isZoomModifierPressed || event.scrollDelta.dy == 0) {
            return;
          }

          final direction = event.scrollDelta.dy < 0 ? 1 : -1;
          final position = event.localPosition;
          GestureBinding.instance.pointerSignalResolver.register(
            event,
            (event) => onZoomStepRequested(direction, position),
          );
        },
        child: child,
      ),
    );
  }
}
