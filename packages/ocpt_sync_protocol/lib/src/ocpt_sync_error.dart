// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:ocpt_sync_protocol/src/ocpt_sync_error_code.dart';
import 'package:ocpt_sync_protocol/src/ocpt_sync_malformed_data_error.dart';
import 'package:ocpt_sync_protocol/src/ocpt_sync_protocol_format_error.dart';
import 'package:ocpt_sync_protocol/src/ocpt_sync_wire_json.dart';

/// What a relay's five routes report instead of a normal response, when a request cannot be
/// honoured.
///
/// [code] is what a caller branches on; [message] is a human-readable detail meant for a log or a
/// status indicator, never parsed. Kept as a plain value rather than a Dart [Exception] subclass:
/// a caller may want to display it, retry against it, or carry it across the wire again — an
/// [OcptSyncError] describes a *server response*, unlike [OcptSyncUnsupportedFormatError] and
/// [OcptSyncMalformedDataError], which describe *this build's own decoding failures* and are
/// thrown, never carried as data.
class OcptSyncError extends Equatable {
  /// The JSON key of `code`.
  static const _codeKey = 'code';

  /// The JSON key of `message`.
  static const _messageKey = 'message';

  /// Which kind of failure this is, for a caller to branch on.
  final OcptSyncErrorCode code;

  /// A human-readable detail describing this failure, for a log or a status indicator — never
  /// parsed.
  final String message;

  /// Create an error report pairing [code] with a human-readable [message].
  const OcptSyncError({required this.code, required this.message});

  /// Parse an error from the JSON object a relay reports it as.
  ///
  /// Throws [OcptSyncMalformedDataError] when [json]'s `code` is missing, not a string, or not
  /// one of [OcptSyncErrorCode]'s own names — an unrecognised code is itself malformed data here,
  /// since every code this build can report is named in that enum.
  factory OcptSyncError.fromJson(Map<String, dynamic> json) {
    final codeName = OcptSyncWireJson.string(json, _codeKey);
    var code = OcptSyncErrorCode.malformed;
    var codeFound = false;
    for (final candidate in OcptSyncErrorCode.values) {
      if (candidate.name == codeName) {
        code = candidate;
        codeFound = true;
        break;
      }
    }
    if (!codeFound) {
      throw OcptSyncMalformedDataError("'$_codeKey' isn't a known sync error code: $codeName");
    }
    return OcptSyncError(code: code, message: OcptSyncWireJson.string(json, _messageKey));
  }

  /// Serialise this error to the JSON object a relay reports it as.
  Map<String, dynamic> toJson() => {_codeKey: code.name, _messageKey: message};

  /// Describe this [OcptSyncError] for debugging and logging.
  @override
  String toString() => 'OcptSyncError(code: $code, message: $message)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [code, message];
}
