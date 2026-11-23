// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_zoom_key_activator.dart';

/// The intent behind the zoom shortcuts: zoom the screenplay page one step out ([direction] -1) or
/// in (1), or back to 100 % (0).
///
/// The shortcuts are Ctrl and + (also =, since + asks for Shift on many keyboards), Ctrl and −,
/// Ctrl and 0, with Cmd for Ctrl on macOS ([shortcuts]), wherever the layout puts those keys
/// (`OcptEditorZoomKeyActivator`). None of them is
/// claimed by the styled editor's own keyboard actions, so they bubble up to the page that maps
/// them, the way Ctrl+S does.
class OcptEditorZoomIntent extends Intent {
  /// The shortcuts that raise an [OcptEditorZoomIntent].
  static const Map<ShortcutActivator, Intent> shortcuts = {
    OcptEditorZoomKeyActivator(1): OcptEditorZoomIntent(direction: 1),
    OcptEditorZoomKeyActivator(-1): OcptEditorZoomIntent(direction: -1),
    OcptEditorZoomKeyActivator(0): OcptEditorZoomIntent(direction: 0),
  };

  /// The way to zoom: -1 out, 1 in, 0 back to 100 %.
  final int direction;

  /// Class constructor
  const OcptEditorZoomIntent({required this.direction});
}
