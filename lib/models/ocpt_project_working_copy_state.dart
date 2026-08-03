// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';

/// A live snapshot of the project's working copy, as
/// `OcptProjectVersionsService.captureWorkingCopyState` measures it against the version it
/// descends from.
///
/// This is the one read that answers two different questions with the same capture: what a
/// working-copy card would show (`summary`), and whether a restore needs to take a safety version
/// before it overwrites the working copy (`isModifiedSinceBase`). Capturing the whole project is
/// not free, so both callers share this single object rather than each triggering their own read.
class OcptProjectWorkingCopyState extends Equatable {
  /// The counters the working copy would show right now, measured exactly as a stored version's
  /// are.
  final OcptProjectVersionSummary summary;

  /// The SHA-256 content digest of the working copy right now, in the same canonical form as
  /// `project_versions.contentDigest` (see `OcptProjectVersionCodec.contentDigest`).
  final String contentDigest;

  /// The id of the version the working copy descends from, i.e. `project_info.currentVersionId`,
  /// or null when the project has never had one.
  final String? baseVersionId;

  /// Whether the working copy's content differs from [baseVersionId]'s.
  ///
  /// True whenever there is no base to compare against, or its own digest is unknown (a version
  /// created before `project_versions.contentDigest` existed): both read as "modified" rather than
  /// risk understating a difference that can no longer be measured.
  final bool isModifiedSinceBase;

  /// Class constructor
  const OcptProjectWorkingCopyState({
    required this.summary,
    required this.contentDigest,
    required this.baseVersionId,
    required this.isModifiedSinceBase,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptProjectWorkingCopyState(baseVersionId: $baseVersionId, "
      "isModifiedSinceBase: $isModifiedSinceBase)";

  /// Object properties
  @override
  List<Object?> get props => [summary, contentDigest, baseVersionId, isModifiedSinceBase];
}
