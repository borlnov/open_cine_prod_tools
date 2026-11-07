// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// Thrown inside a transaction when a call to another service answered a failure: the transaction
/// must not commit what was written before it.
///
/// Only `AbsOcptService.guardResult` and `AbsOcptService.guardOutcome` catch it, and they answer
/// its [failure] as a `databaseError` without logging it again, since whoever answered the failure
/// has logged it.
class OcptDatabaseAbort implements Exception {
  /// The failure the other service answered.
  final StatusWithExtraInfo<MixinResultStatus> failure;

  /// Class constructor
  const OcptDatabaseAbort(this.failure);
}
