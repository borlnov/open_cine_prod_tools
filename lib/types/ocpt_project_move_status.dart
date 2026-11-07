// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of moving the currently open project's file to a new location.
///
/// This is used as the [ResultWithStatus] status of `OcptProjectsManager.moveCurrentProject`. A
/// status other than [ok] leaves the project exactly where it was: the copy the move takes is only
/// swapped in for the original once it has been verified to open, so a failure before that point
/// never touches the file the user had open.
enum OcptProjectMoveStatus with MixinResultStatus {
  /// The project's file now lives at the new path, and it is still the one currently open.
  ok(isSuccess: true, canBeRetried: false),

  /// No project is open, or the one that is sits under a read-only version preview: there is
  /// nothing here a move may touch. The project settings page never offers `Move…` in either case,
  /// so this is only ever reached by a caller that ignored that.
  noProjectOpen(isSuccess: false, canBeRetried: false),

  /// A file already sits at the requested new path: nothing was copied, nothing was touched, and
  /// the project stays exactly where it was.
  fileAlreadyExists(isSuccess: false, canBeRetried: false),

  /// A filesystem or database error occurred while copying the project or verifying the copy.
  ioError(isSuccess: false, canBeRetried: true),

  /// The project was moved and is open at its new path, but the connection to its old file could
  /// not be closed: the old file, the sidecar and the recent-projects entry are left as they were.
  /// The project settings page stops there without a word, as it did when this failure was raised
  /// rather than answered.
  oldFileNotClosed(isSuccess: false, canBeRetried: false);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptProjectMoveStatus({required this.isSuccess, required this.canBeRetried});
}
