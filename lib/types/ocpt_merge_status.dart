// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of applying an incoming changeset to a project's file.
///
/// See `OcptMergeService`. A changeset that names something this replica does not know means the
/// sender and this replica disagree about the synchronised schema: it is reported as a value, the
/// `extraInfo` being an `OcptSyncMergeFailure`, and none of the changeset is applied.
enum OcptMergeStatus with MixinResultStatus {
  /// Every stamp of the changeset was applied or lost to a newer local one.
  ok(isSuccess: true, canBeRetried: false),

  /// A stamp names a table that is not part of this replica's synchronised tables.
  unknownTable(isSuccess: false, canBeRetried: false),

  /// A stamp names a column that no column of its table maps to.
  unknownColumn(isSuccess: false, canBeRetried: false),

  /// The merge of a screenplay's text failed on the database: nothing of the changeset is applied.
  /// The `extraInfo` is an `OcptSyncMergeFailure` carrying the type of what failed.
  databaseError(isSuccess: false, canBeRetried: true);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptMergeStatus({required this.isSuccess, required this.canBeRetried});
}
