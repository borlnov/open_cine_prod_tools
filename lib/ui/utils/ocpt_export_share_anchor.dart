// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';

/// [context]'s own render box, in screen coordinates, or null when it has none yet (not laid out,
/// or already unmounted).
///
/// This is the `Rect` `Share.shareXFiles` needs to anchor the OS share sheet's popover on an
/// iPad/Mac — `OcptExportManager` sees no `BuildContext` to resolve one itself, so every export
/// control resolves its own here, at the moment it is tapped, and hands it down to the export it
/// dispatches.
Rect? ocptExportShareAnchorOf(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }

  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}
