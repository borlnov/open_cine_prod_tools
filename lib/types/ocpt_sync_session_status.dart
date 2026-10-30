// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of asking a sync session, or the sync manager, to do something that depends on
/// whether a session runs.
enum OcptSyncSessionStatus with MixinResultStatus {
  /// The request was served.
  ok(isSuccess: true, canBeRetried: false),

  /// The session was already started; stop it first to restart it.
  alreadyRunning(isSuccess: false, canBeRetried: false),

  /// No session is running to serve the request.
  notRunning(isSuccess: false, canBeRetried: false);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptSyncSessionStatus({required this.isSuccess, required this.canBeRetried});
}
