// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What the one-off migration of the legacy Windows application data concluded.
enum OcptLegacyAppDataOutcome {
  /// The legacy directory does not exist: this install never ran under the old product name.
  nothingToMigrate,

  /// The marker of an earlier run is already stored: the migration is done and is not repeated.
  alreadyMigrated,

  /// The legacy data was brought over and the marker written.
  migrated,

  /// A file could not be read or written, or a preferences file is malformed: nothing more was
  /// touched, and no marker was written, so the next start tries again.
  failed,
}
