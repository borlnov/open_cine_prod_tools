// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of restoring a project version over the working copy, or of forking from one.
///
/// Restoring is the one operation of the app that rewrites most of a project at once, so every
/// failure here is an all-or-nothing one: the whole restore happens inside a single transaction, and
/// the page margins it also restores are written only once that transaction has committed. A status
/// other than [ok] therefore means the project and the app's preferences are both exactly as they
/// were.
enum OcptProjectRestoreStatus with MixinResultStatus {
  /// The project now holds the version's state, and descends from it.
  ok(isSuccess: true, canBeRetried: false),

  /// No project is open, so there is nothing to restore a version into.
  noProjectOpen(isSuccess: false, canBeRetried: false),

  /// The requested version doesn't exist in this project any more.
  versionNotFound(isSuccess: false, canBeRetried: false),

  /// The version's payload was written by a later build of the app: it is refused rather than
  /// half-restored. The user's way out is to update Open Cine Prod Tools.
  unsupportedFutureFormat(isSuccess: false, canBeRetried: false),

  /// The version's payload isn't readable at all: that version is lost, but the project isn't.
  malformedPayload(isSuccess: false, canBeRetried: false),

  /// The payload was read but writing it back failed; the transaction rolled back and the project
  /// is untouched.
  writeFailed(isSuccess: false, canBeRetried: true);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptProjectRestoreStatus({required this.isSuccess, required this.canBeRetried});
}
