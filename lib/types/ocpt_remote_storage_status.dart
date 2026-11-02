// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of one call to an `OcptRemoteStorage` transport, and of what pushes or pulls through
/// one.
///
/// A transport never throws for a failure it can name: it answers one of these, the detail riding
/// in the result's `extraInfo`.
enum OcptRemoteStorageStatus with MixinResultStatus {
  /// The call went through.
  ok(isSuccess: true, canBeRetried: false),

  /// The relay answered with a sync error (a bad token, an unknown project, a sequence conflict…);
  /// the `extraInfo` is that `OcptSyncError`.
  rejected(isSuccess: false, canBeRetried: false),

  /// The transport itself failed (no network, a file that cannot be read, an answer that cannot be
  /// decoded); the `extraInfo` is an `OcptSyncTransportFailure`.
  unreachable(isSuccess: false, canBeRetried: false);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptRemoteStorageStatus({required this.isSuccess, required this.canBeRetried});
}
