// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The shortcut that zooms the page one step out ([direction] -1) or in (1), or back to 100 %
/// (0): the zoom modifier (Ctrl, Cmd on macOS) with a key *producing* a minus, a plus or an equals
/// sign, or a zero.
///
/// It matches the character the key produces rather than a fixed key, because the keys that make
/// those characters are not where a QWERTY keyboard has them: on a French AZERTY layout the minus
/// is the key a QWERTY keyboard has a 6 on, and on a German QWERTZ layout the unshifted plus is
/// the numpad's one. A `Ctrl+6` on QWERTY produces a 6 and is no zoom. When a platform gives no
/// character for the event (a control key chord often has none), the logical key decides, for the
/// keys that mean the same on every layout (minus, equals, plus, zero, and their numpad twins).
class OcptEditorZoomKeyActivator extends ShortcutActivator {
  /// The way to zoom: -1 out, 1 in, 0 back to 100 %.
  final int direction;

  /// Get no trigger key: every key event is looked at, the characters being what matters.
  @override
  Iterable<LogicalKeyboardKey>? get triggers => null;

  /// Class constructor
  const OcptEditorZoomKeyActivator(this.direction);

  /// Tell whether [event] is this zoom: a key down (or repeat) with the zoom modifier alone.
  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    if (isMac ? !state.isMetaPressed : !state.isControlPressed) {
      return false;
    }
    if (state.isAltPressed || (isMac ? state.isControlPressed : state.isMetaPressed)) {
      return false;
    }

    return _directionOf(event) == direction;
  }

  /// Get a description of the shortcut.
  @override
  String debugDescribeKeys() => "zoom ($direction)";

  /// Get the way [event] zooms, or null when it is no zoom key.
  static int? _directionOf(KeyEvent event) {
    final character = event.character;
    if (character != null && character.isNotEmpty) {
      switch (character) {
        case "+" || "=":
          return 1;
        case "-" || "−":
          return -1;
        case "0":
          return 0;
      }
    }

    // A zero is the same key on every layout; the others are read off the logical key only when
    // no digit was produced, so a plain digit never zooms.
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      return 0;
    }
    if (character != null && character.trim().isNotEmpty && character.codeUnitAt(0) >= 0x20) {
      return null;
    }

    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      return 1;
    }
    if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
      return -1;
    }

    return null;
  }
}
