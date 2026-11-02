// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The kind of transient notice [OcptShotListIoNotice] carries, one per shot list export outcome.
enum OcptShotListIoNoticeKind {
  /// The shot list was successfully exported to an XLSX workbook.
  xlsxExportSucceeded,

  /// Exporting the shot list to an XLSX workbook failed.
  xlsxExportFailed,

  /// The scenario coverage was successfully exported to an annotated screenplay PDF.
  scenarioCoverageExportSucceeded,

  /// Exporting the scenario coverage to an annotated screenplay PDF failed.
  scenarioCoverageExportFailed,

  /// The storyboard was successfully exported to a PDF.
  storyboardExportSucceeded,

  /// Exporting the storyboard to a PDF failed.
  storyboardExportFailed,

  /// The floor plans were successfully exported to a PDF.
  floorPlansExportSucceeded,

  /// Exporting the floor plans to a PDF failed.
  floorPlansExportFailed,
}

/// A transient notice, produced by `OcptShotListExportBloc`, reporting the outcome of an export,
/// shown as a SnackBar then dismissed.
///
/// Modelled on the screenplay editor's own `OcptEditorIoNotice`, and deliberately kept apart from
/// `OcptShotListState.hasWriteError`: a failed export leaves the project untouched and says
/// nothing about the shot list itself, while a write error reports that an edit the user made
/// never reached the database.
class OcptShotListIoNotice extends Equatable {
  /// The outcome this notice reports.
  final OcptShotListIoNoticeKind kind;

  /// The path the export was written to, only set when [kind] is one of the two succeeded kinds
  /// and [wasShared] is false — a mobile export hands the file to the OS share sheet instead of
  /// writing it to a path the user picked, so there is none to show.
  final String? path;

  /// Whether the export was handed to the OS share sheet rather than written to [path] — mobile's
  /// own outcome, `file_selector`'s `getSaveLocation` having no Android or iOS implementation.
  final bool wasShared;

  /// Class constructor
  const OcptShotListIoNotice({required this.kind, this.path, this.wasShared = false});

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [kind, path, wasShared];
}
