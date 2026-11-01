// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_notice_kind.dart';

/// A transient notice, produced by `OcptEditorBloc`, reporting the outcome of an export or an
/// import-and-replace, shown as a SnackBar then dismissed.
class OcptEditorIoNotice extends Equatable {
  /// The outcome this notice reports.
  final OcptEditorIoNoticeKind kind;

  /// The path the screenplay was exported to, only set when [kind] is
  /// [OcptEditorIoNoticeKind.exportSucceeded] or [OcptEditorIoNoticeKind.pdfExportSucceeded] and
  /// [wasShared] is false — a mobile export hands the file to the OS share sheet instead of
  /// writing it to a path the user picked, so there is none to show.
  final String? path;

  /// Whether the export was handed to the OS share sheet rather than written to [path] — mobile's
  /// own outcome, `file_selector`'s `getSaveLocation` having no Android or iOS implementation.
  final bool wasShared;

  /// Class constructor
  const OcptEditorIoNotice({required this.kind, this.path, this.wasShared = false});

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [kind, path, wasShared];
}
