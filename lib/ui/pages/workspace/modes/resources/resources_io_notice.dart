// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The kind of transient notice [OcptResourcesIoNotice] carries, one per resources export outcome.
enum OcptResourcesIoNoticeKind {
  /// The resources catalogue was successfully exported to a four-sheet XLSX workbook.
  xlsxExportSucceeded,

  /// Exporting the resources catalogue to a four-sheet XLSX workbook failed.
  xlsxExportFailed,

  /// The contact list was successfully exported to a PDF.
  contactListExportSucceeded,

  /// Exporting the contact list to a PDF failed.
  contactListExportFailed,
}

/// A transient notice, produced by `OcptResourcesExportBloc`, reporting the outcome of an export, shown
/// as a SnackBar then dismissed. Modelled on `OcptShotListIoNotice`.
class OcptResourcesIoNotice extends Equatable {
  /// The outcome this notice reports.
  final OcptResourcesIoNoticeKind kind;

  /// The path the export was written to, only set when [kind] is the succeeded kind and
  /// [wasShared] is false — a mobile export hands the file to the OS share sheet instead of
  /// writing it to a path the user picked, so there is none to show.
  final String? path;

  /// Whether the export was handed to the OS share sheet rather than written to [path] — mobile's
  /// own outcome, `file_selector`'s `getSaveLocation` having no Android or iOS implementation.
  final bool wasShared;

  /// Class constructor
  const OcptResourcesIoNotice({required this.kind, this.path, this.wasShared = false});

  /// Object properties
  @override
  List<Object?> get props => [kind, path, wasShared];
}
