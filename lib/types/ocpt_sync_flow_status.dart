// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of a sync manager flow that talks to a relay: pairing a project, re-pointing it,
/// publishing a snapshot, joining from one.
///
/// A failure the flow can name rides in the result's `extraInfo` (the relay's `OcptSyncError`, or
/// an `OcptSyncTransportFailure`); anything unforeseen (a database error, a packaging failure)
/// still propagates as an exception for the caller's own catch.
enum OcptSyncFlowStatus with MixinResultStatus {
  /// The flow completed.
  ok(isSuccess: true, canBeRetried: false),

  /// The project has no existing pairing to reuse a token from.
  notPaired(isSuccess: false, canBeRetried: false),

  /// The relay holds no snapshot yet, so there is nothing to join.
  emptyRelay(isSuccess: false, canBeRetried: false),

  /// The relay answered with a sync error.
  rejected(isSuccess: false, canBeRetried: false),

  /// The transport failed before the relay could answer.
  unreachable(isSuccess: false, canBeRetried: false);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptSyncFlowStatus({required this.isSuccess, required this.canBeRetried});
}
