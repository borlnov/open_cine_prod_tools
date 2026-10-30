// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of reading a shot's estimated duration from the text the user typed.
///
/// The status of the [ResultWithStatus] `ocptParseShotDuration` answers; a successful one with no
/// value is the blank "no estimate" answer.
enum OcptShotDurationStatus with MixinResultStatus {
  /// The text is a duration, or blank.
  ok(isSuccess: true, canBeRetried: false),

  /// The text is neither blank nor a duration (`mm:ss`, or a bare number of minutes).
  malformed(isSuccess: false, canBeRetried: false);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptShotDurationStatus({required this.isSuccess, required this.canBeRetried});
}
