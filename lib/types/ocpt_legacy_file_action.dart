// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What the legacy data migration did with one file of the legacy directory.
enum OcptLegacyFileAction {
  /// The legacy directory has no such file: nothing to bring over.
  absent,

  /// The current directory had none, so the legacy file was copied.
  copied,

  /// Both directories had one and their content was merged into the current one.
  merged,

  /// Both directories had one and the current one was kept as it is.
  keptCurrent,

  /// The file could not be read or is malformed, so it was left alone.
  unreadable,

  /// The migration did not get as far as this file.
  skipped,
}
