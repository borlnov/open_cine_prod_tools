// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of reading a pasted or scanned string back as an `OcptRelayEnrolment`.
///
/// A failure is the answer to a string that is not an enrolment, which is how a wrong paste or
/// scan is told apart; none of them is worth more than the refusal.
enum OcptRelayEnrolmentStatus with MixinResultStatus {
  /// The string was read back in full.
  ok(isSuccess: true, canBeRetried: false),

  /// The string is not a URI at all.
  malformedUri(isSuccess: false, canBeRetried: false),

  /// The URI does not use the `ocpt` scheme.
  wrongScheme(isSuccess: false, canBeRetried: false),

  /// The URI is not an `ocpt://relay` one.
  wrongHost(isSuccess: false, canBeRetried: false),

  /// The relay parameter is absent or empty.
  missingRelay(isSuccess: false, canBeRetried: false),

  /// The enrolment secret parameter is absent or empty.
  missingSecret(isSuccess: false, canBeRetried: false),

  /// The relay parameter is not a URI.
  malformedRelay(isSuccess: false, canBeRetried: false);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptRelayEnrolmentStatus({required this.isSuccess, required this.canBeRetried});
}
