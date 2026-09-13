// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:ui';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands an export's bytes to the OS share sheet — mobile's only avenue for getting them anywhere,
/// `file_selector`'s `getSaveLocation`/`getDirectoryPath` having no Android or iOS implementation.
///
/// Pure `package:path_provider`/`package:share_plus` wrapper, owned by `OcptExportManager` as a
/// public final field (RFL18), reached through the manager rather than through `globalGetIt()`, so
/// it can be replaced by a test double — exactly as `OcptSaveLocationService` is for the native
/// save dialog.
class OcptShareService {
  /// Class constructor
  const OcptShareService();

  /// Resolves a writable, per-run temporary directory the share sheet's own files are staged into.
  Future<Directory> temporaryDirectory() => getTemporaryDirectory();

  /// Shows the OS share sheet for the files at [paths], all in the one gesture.
  ///
  /// [sharePositionOrigin] anchors the popover the share sheet opens as on an iPad or a Mac; the OS
  /// call throws there without one, which is why every `OcptExportManager` export method threads
  /// one down from the tapped `Export` control's own `RenderBox` (a manager sees no
  /// `BuildContext`). It is ignored, and safe to leave null, on every other platform.
  ///
  /// Returns whether the share sheet was shown — an exception is caught, logged and reported as
  /// false, exactly like the manager's own writes.
  Future<bool> shareFiles({required List<String> paths, Rect? sharePositionOrigin}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [for (final path in paths) XFile(path)],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return true;
    } catch (error) {
      appLogger().e("A problem occurred when tried to share the files at: $paths, error: $error");
      return false;
    }
  }
}
