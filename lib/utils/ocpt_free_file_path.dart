// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:path/path.dart' as p;

/// Returns the first path under [directoryPath] that [exists] reports as free: [baseName] itself
/// first (`"$baseName.$extension"`), then `"$baseName (2).$extension"`, `"$baseName (3).$extension"`
/// and so on until one is.
///
/// This is what a caller reaches for instead of writing straight to the obvious path and risking a
/// silent overwrite of whatever is already there: nothing this function returns is ever a path
/// [exists] has just said is taken, so the caller never has to delete or truncate a file it didn't
/// create — the same numbering a file manager offers when a copy lands beside a file of the same
/// name.
///
/// Pure: [exists] is the only I/O this performs, and it is reached through the predicate rather
/// than the filesystem directly, so a test can hand in an in-memory set of taken paths instead of
/// touching disk.
String ocptFreeFilePath({
  required String directoryPath,
  required String baseName,
  required String extension,
  required bool Function(String path) exists,
}) {
  final firstPath = p.join(directoryPath, "$baseName.$extension");
  if (!exists(firstPath)) {
    return firstPath;
  }

  var attempt = 2;
  while (true) {
    final candidatePath = p.join(directoryPath, "$baseName ($attempt).$extension");
    if (!exists(candidatePath)) {
      return candidatePath;
    }
    attempt++;
  }
}
