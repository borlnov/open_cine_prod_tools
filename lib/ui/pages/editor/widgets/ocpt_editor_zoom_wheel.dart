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
/// A step is a notch of the wheel: an event of at least [stepDelta] steps once (never more, however
/// far it turns, since a notch is 53 pixels on Linux and up to 200 on Windows), and the first event
/// of a turn steps at once. A smooth or high-resolution wheel, which sends many small events for
/// one notch, adds them up until they are worth a step.
///
/// With no [onZoomStepRequested], this is [child] and nothing else: the surfaces where the page
/// can't be zoomed (a compact window) simply don't listen.
class OcptEditorZoomWheel extends StatefulWidget {
  /// The scroll delta, in logical pixels, that is worth one step once a turn of the wheel has
  /// started, whether in one event or added up: under the smallest notch of the platforms.
  static const double stepDelta = 40;

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
          final isStep = _isStep(event, direction);
          final position = event.localPosition;
          // Claimed even when it makes no step yet: no scrollable may take it.
          GestureBinding.instance.pointerSignalResolver.register(event, (event) {
            if (isStep) {
              onZoomStepRequested(direction, position);
            }
          });
        },
        child: widget.child,
      ),
    );
  }

  /// Tell whether [event], turning the wheel [direction] way, makes a step.
  bool _isStep(PointerScrollEvent event, int direction) {
    final isNewTurn = direction != _direction || event.timeStamp - _lastTime > _pause;
    _direction = direction;
    _lastTime = event.timeStamp;
    if (isNewTurn) {
      _accumulated = 0;
      return true;
    }

    final delta = event.scrollDelta.dy.abs();
    if (delta < OcptEditorZoomWheel.stepDelta) {
      _accumulated += delta;
      if (_accumulated < OcptEditorZoomWheel.stepDelta) {
        return false;
      }
    }

    _accumulated = 0;
    return true;
  }
}
