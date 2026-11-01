// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:ocpt_sync_protocol/src/ocpt_sync_protocol_format_error.dart';

/// Thrown by a `fromJson` constructor when the decoded JSON does not have the shape a wire value
/// requires: a missing key, a key of the wrong type, or a JSON value that is not even an object.
///
/// Kept distinct from [OcptSyncUnsupportedFormatError]: a malformed value is a bug or data
/// corruption at either end, while an unsupported format is an expected consequence of two
/// peers running different builds and is handled differently by a caller.
class OcptSyncMalformedDataError implements Exception {
  /// A short, human-readable description of what was wrong with the decoded JSON.
  final String reason;

  /// Create an error reporting [reason], a short, human-readable description of what was wrong
  /// with the decoded JSON.
  const OcptSyncMalformedDataError(this.reason);

  /// Describe this [OcptSyncMalformedDataError] for debugging and logging.
  @override
  String toString() => 'OcptSyncMalformedDataError: $reason';
}
