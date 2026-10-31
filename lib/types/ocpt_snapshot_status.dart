// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of turning a project into snapshot bytes, or snapshot bytes back into a project.
///
/// See `OcptSnapshotService`. A snapshot is an expected failure whenever it comes from the network
/// or from a file: it is reported as a value rather than raised.
enum OcptSnapshotStatus with MixinResultStatus {
  /// The snapshot was built, or materialised, in full.
  ok(isSuccess: true, canBeRetried: false),

  /// The bytes do not match the content digest their descriptor announced, so they are not what
  /// the relay described.
  digestMismatch(isSuccess: false, canBeRetried: false),

  /// The portable package behind the snapshot could not be written or read; the package service
  /// has already logged why.
  packageFailed(isSuccess: false, canBeRetried: false);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptSnapshotStatus({required this.isSuccess, required this.canBeRetried});
}
