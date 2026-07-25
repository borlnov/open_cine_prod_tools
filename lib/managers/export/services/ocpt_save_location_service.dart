// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

/// Shows the native "save as" dialog and resolves the path the user picked.
///
/// Pure Flutter-plugin wrapper around `package:file_selector`'s [getSaveLocation]: it's owned by
/// `OcptExportManager` as a public final field (RFL18), reached through the manager rather than
/// through `globalGetIt()`, so it can be replaced by a test double.
class OcptSaveLocationService {
  /// Class constructor
  const OcptSaveLocationService();

  /// Shows the native save dialog, pre-filled with [suggestedFileName] and restricted to
  /// [extensions] (labelled [fileTypeLabel] in the dialog's type filter).
  ///
  /// Returns the path the user picked, appending the first of [extensions] when the returned
  /// path has none (the GTK dialog does not add it itself), or null if the user cancelled the
  /// dialog or a problem occurred (logged, exactly like the manager's other soft failures).
  Future<String?> pickSaveLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
  }) async {
    try {
      final location = await getSaveLocation(
        suggestedName: suggestedFileName,
        acceptedTypeGroups: [XTypeGroup(label: fileTypeLabel, extensions: extensions)],
      );

      final path = location?.path;
      if (path == null) {
        return null;
      }

      return p.extension(path).isEmpty ? "$path.${extensions.first}" : path;
    } catch (error) {
      appLogger().e(
        "A problem occurred when tried to pick a save location for: $suggestedFileName, "
        "error: $error",
      );
      return null;
    }
  }
}
