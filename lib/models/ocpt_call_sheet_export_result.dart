// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What a call sheet export actually wrote — the one export of this app that writes more than one
/// file, so a plain written-path string (every other `OcptExportManager` method's own return type)
/// cannot say what happened.
///
/// [writtenFileNames] and [failedFileNames] are both file names alone (`FDS-J2.pdf`), not full
/// paths — every one of them sits directly under [folderPath]. A caller reporting the run back to
/// the user reads both: a run where every file failed still holds a non-empty [folderPath] (the
/// directory itself was created/chosen before the first write was attempted), which is what tells
/// that case apart from a cancelled dialog, reported instead as a null result by
/// `OcptExportManager.exportGeneralCallSheets`/`exportNamedCallSheets` themselves.
///
/// **A partial failure is never hidden as a success**: a write failure is logged (this app's usual
/// soft-failure convention) and the file's own name is recorded in [failedFileNames] rather than
/// silently dropped, so [isComplete] is the one place a caller asks "did every file make it" without
/// having to compare the two lists' lengths by hand.
class OcptCallSheetExportResult extends Equatable {
  /// The folder every written file sits directly under.
  final String folderPath;

  /// The file names that were written successfully, in the order they were attempted.
  final List<String> writtenFileNames;

  /// The file names whose write failed, in the order they were attempted. Empty on a run that wrote
  /// everything it set out to.
  final List<String> failedFileNames;

  /// Class constructor
  const OcptCallSheetExportResult({
    required this.folderPath,
    required this.writtenFileNames,
    required this.failedFileNames,
  });

  /// Whether every file this run attempted was written successfully.
  bool get isComplete => failedFileNames.isEmpty;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptCallSheetExportResult(folderPath: $folderPath, "
      "writtenCount: ${writtenFileNames.length}, failedCount: ${failedFileNames.length})";

  /// Object properties
  @override
  List<Object?> get props => [folderPath, writtenFileNames, failedFileNames];
}
