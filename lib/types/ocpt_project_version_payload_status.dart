// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of decoding a stored project version payload.
///
/// This is used as the [ResultWithStatus] status of `OcptProjectVersionCodec.decode`. The two
/// failures are kept apart because a user can act on one and not on the other: a payload from a
/// later build of the app means "update Open Cine Prod Tools", while a malformed one means the
/// version is lost.
enum OcptProjectVersionPayloadStatus with MixinResultStatus {
  /// The payload was decoded, upgrading it from an older format if needed.
  ok(isSuccess: true, canBeRetried: false),

  /// The payload declares a format this build doesn't know: the project file has been opened by a
  /// later version of the app. Half-restoring it would corrupt the project, so it is refused.
  unsupportedFutureFormat(isSuccess: false, canBeRetried: false),

  /// The payload isn't readable at all: not JSON, or missing/ill-typed fields.
  malformedPayload(isSuccess: false, canBeRetried: false);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptProjectVersionPayloadStatus({required this.isSuccess, required this.canBeRetried});
}
