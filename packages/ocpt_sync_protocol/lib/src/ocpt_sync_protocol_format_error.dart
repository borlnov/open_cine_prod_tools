// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Thrown by a `fromJson` constructor when a wire value declares a format newer than this build
/// of the protocol knows how to read.
///
/// Mirrors how `OcptProjectVersionCodec` treats a project version payload written by a later
/// build of the app: a **newer** format is refused rather than half-read, while an **older** one
/// is accepted (and, once a stable release has frozen one, upgraded in memory). Refusing here
/// means a replica or a relay talking to a newer peer reports a clear, typed reason instead of
/// silently misreading bytes it does not understand.
class OcptSyncUnsupportedFormatError implements Exception {
  /// Which wire shape declared the unsupported format, for example `"changeset envelope"`.
  final String subject;

  /// The format the wire value declared.
  final int foundFormat;

  /// The highest format this build of the protocol can read.
  final int knownUpTo;

  /// Create an error reporting that [foundFormat] is newer than [knownUpTo], the highest format
  /// this build of `ocpt_sync_protocol` can read, for the wire shape named by [subject] (for
  /// example `"changeset envelope"` or `"snapshot descriptor"`).
  const OcptSyncUnsupportedFormatError({
    required this.subject,
    required this.foundFormat,
    required this.knownUpTo,
  });

  /// Describe this [OcptSyncUnsupportedFormatError] for debugging and logging.
  @override
  String toString() =>
      'OcptSyncUnsupportedFormatError: $subject is written in format $foundFormat, but this '
      'build only knows up to $knownUpTo';
}
