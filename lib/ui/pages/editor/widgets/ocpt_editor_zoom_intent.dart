// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The intent behind the zoom shortcuts: zoom the screenplay page one step out ([direction] -1) or
/// in (1), or back to 100 % (0).
///
/// The shortcuts are Ctrl and + (also = and the numpad's +, since + asks for Shift on many
/// keyboards), Ctrl and −, Ctrl and 0, with Cmd for Ctrl on macOS ([shortcuts]). None of them is
/// claimed by the styled editor's own keyboard actions, so they bubble up to the page that maps
/// them, the way Ctrl+S does.
class OcptEditorZoomIntent extends Intent {
  /// The shortcuts that raise an [OcptEditorZoomIntent], with Ctrl and with Cmd.
  static const Map<ShortcutActivator, Intent> shortcuts = {
    SingleActivator(LogicalKeyboardKey.equal, control: true): OcptEditorZoomIntent(direction: 1),
    SingleActivator(LogicalKeyboardKey.equal, control: true, shift: true): OcptEditorZoomIntent(
      direction: 1,
    ),
    SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): OcptEditorZoomIntent(
      direction: 1,
    ),
    SingleActivator(LogicalKeyboardKey.minus, control: true): OcptEditorZoomIntent(direction: -1),
    SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true): OcptEditorZoomIntent(
      direction: -1,
    ),
    SingleActivator(LogicalKeyboardKey.digit0, control: true): OcptEditorZoomIntent(direction: 0),
    SingleActivator(LogicalKeyboardKey.numpad0, control: true): OcptEditorZoomIntent(direction: 0),
    SingleActivator(LogicalKeyboardKey.equal, meta: true): OcptEditorZoomIntent(direction: 1),
    SingleActivator(LogicalKeyboardKey.equal, meta: true, shift: true): OcptEditorZoomIntent(
      direction: 1,
    ),
    SingleActivator(LogicalKeyboardKey.numpadAdd, meta: true): OcptEditorZoomIntent(direction: 1),
    SingleActivator(LogicalKeyboardKey.minus, meta: true): OcptEditorZoomIntent(direction: -1),
    SingleActivator(LogicalKeyboardKey.numpadSubtract, meta: true): OcptEditorZoomIntent(
      direction: -1,
    ),
    SingleActivator(LogicalKeyboardKey.digit0, meta: true): OcptEditorZoomIntent(direction: 0),
    SingleActivator(LogicalKeyboardKey.numpad0, meta: true): OcptEditorZoomIntent(direction: 0),
  };

  /// The way to zoom: -1 out, 1 in, 0 back to 100 %.
  final int direction;

  /// Class constructor
  const OcptEditorZoomIntent({required this.direction});
}
