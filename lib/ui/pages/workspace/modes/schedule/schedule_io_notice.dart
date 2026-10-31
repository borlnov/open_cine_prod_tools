// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The kind of transient notice [OcptScheduleIoNotice] carries, one per schedule export outcome.
///
/// A folder export (the two call sheet kinds) is the one path with a middle ground between success
/// and failure — some files can be written while others aren't — which is why there are three kinds
/// rather than the two a single-file export would need: [folderExportPartiallySucceeded] must never
/// read as a plain success, `OcptCallSheetExportResult.failedFileNames` being non-empty meaning
/// exactly that someone's call sheet did not make it into the folder.
enum OcptScheduleIoNoticeKind {
  /// A single-file export (the shooting plan) was written successfully.
  fileExportSucceeded,

  /// A folder export (a call sheets run) wrote every file it set out to.
  folderExportSucceeded,

  /// A folder export wrote some files but not every one — `OcptCallSheetExportResult
  /// .failedFileNames` is non-empty.
  folderExportPartiallySucceeded,

  /// An export failed outright (an exception was thrown while rendering or writing it). A cancelled
  /// save/folder dialog is a silent no-op instead, exactly as the breakdown sheets export treats
  /// it.
  exportFailed,
}

/// A transient notice, produced by `OcptScheduleBloc`, reporting the outcome of one of the three
/// PDF exports, shown as a SnackBar then dismissed. Modelled on `OcptBreakdownIoNotice`.
///
/// Only the fields [kind] actually needs are ever set: [path] for [OcptScheduleIoNoticeKind
/// .fileExportSucceeded], [folderPath]/[writtenCount] for [OcptScheduleIoNoticeKind
/// .folderExportSucceeded], and all four but [path] for [OcptScheduleIoNoticeKind
/// .folderExportPartiallySucceeded]. [wasShared] can be set alongside any succeeded kind.
class OcptScheduleIoNotice extends Equatable {
  /// The outcome this notice reports.
  final OcptScheduleIoNoticeKind kind;

  /// The path a single-file export was written to, only set when [kind] is
  /// [OcptScheduleIoNoticeKind .fileExportSucceeded] and [wasShared] is false.
  final String? path;

  /// The folder a folder export wrote into, only set for the two folder-export kinds — a temporary
  /// one rather than one the user picked when [wasShared] is true.
  final String? folderPath;

  /// How many files a folder export wrote successfully, only set for the two folder-export kinds.
  final int? writtenCount;

  /// How many files a folder export failed to write, only set for [OcptScheduleIoNoticeKind
  /// .folderExportPartiallySucceeded].
  final int? failedCount;

  /// Whether the export was handed to the OS share sheet rather than written to [path]/[folderPath]
  /// for the user to find — mobile's own outcome, `file_selector`'s `getSaveLocation`/
  /// `getDirectoryPath` having no Android or iOS implementation.
  final bool wasShared;

  /// Class constructor
  const OcptScheduleIoNotice({
    required this.kind,
    this.path,
    this.folderPath,
    this.writtenCount,
    this.failedCount,
    this.wasShared = false,
  });

  /// Object properties
  @override
  List<Object?> get props => [kind, path, folderPath, writtenCount, failedCount, wasShared];
}
