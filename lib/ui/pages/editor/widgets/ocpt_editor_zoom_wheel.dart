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
/// A step is a notch's worth of wheel: the first event of a turn steps at once, and the following
/// ones add up to [notchDelta] each, so a smooth or high-resolution wheel, which sends many small
/// events for one notch, does not jump several steps.
///
/// With no [onZoomStepRequested], this is [child] and nothing else: the surfaces where the page
/// can't be zoomed (a compact window) simply don't listen.
class OcptEditorZoomWheel extends StatefulWidget {
  /// The scroll delta, in logical pixels, that is worth one step once a turn of the wheel has
  /// started: the delta of one notch of a common mouse.
  static const double notchDelta = 100;

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

  /// Create the [_OcptEditorZoomWheelState] holding the state of the zoom wheel.
  @override
  State<OcptEditorZoomWheel> createState() => _OcptEditorZoomWheelState();
}

/// The state of [OcptEditorZoomWheel]: adds the wheel's deltas up into steps.
class _OcptEditorZoomWheelState extends State<OcptEditorZoomWheel> {
  /// The silence after which the next event starts a new turn of the wheel.
  static const Duration _pause = Duration(milliseconds: 300);

  /// The delta added up since the last step of the turn that is going on, in logical pixels.
  double _accumulated = 0;

  /// The way of the turn that is going on: -1, 1, or 0 before any.
  int _direction = 0;

  /// The time of the last event, to tell where a turn ends.
  Duration _lastTime = Duration.zero;

  /// Build the zoom wheel as a [Listener].
  @override
  Widget build(BuildContext context) {
    final onZoomStepRequested = widget.onZoomStepRequested;
    if (onZoomStepRequested == null) {
      return widget.child;
    }

    final scrollBehavior = ScrollConfiguration.of(context);

    return ScrollConfiguration(
      behavior: scrollBehavior.copyWith(
        physics: OcptZoomWheelPhysics.over(context, isEnabled: true),
      ),
      child: Listener(
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent ||
              !OcptEditorZoomWheel.isZoomModifierPressed ||
              event.scrollDelta.dy == 0) {
            return;
          }

          final direction = event.scrollDelta.dy < 0 ? 1 : -1;
          final steps = _stepsOf(event, direction);
          final position = event.localPosition;
          // Claimed even when it makes no step yet: no scrollable may take it.
          GestureBinding.instance.pointerSignalResolver.register(event, (event) {
            for (var step = 0; step < steps; step++) {
              onZoomStepRequested(direction, position);
            }
          });
        },
        child: widget.child,
      ),
    );
  }

  /// Get how many steps [event], turning the wheel [direction] way, makes.
  int _stepsOf(PointerScrollEvent event, int direction) {
    final isNewTurn = direction != _direction || event.timeStamp - _lastTime > _pause;
    _direction = direction;
    _lastTime = event.timeStamp;
    if (isNewTurn) {
      _accumulated = 0;
      return 1;
    }

    _accumulated += event.scrollDelta.dy.abs();
    final steps = _accumulated ~/ OcptEditorZoomWheel.notchDelta;
    _accumulated -= steps * OcptEditorZoomWheel.notchDelta;

    return steps;
  }
}
