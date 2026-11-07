// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_xlsx_labels.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/events/breakdown_base_event.dart';

/// The events about the mode's exports.
sealed class OcptBreakdownExportEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownExportEvent();
}

/// Request exporting one breakdown sheet per scene as a PDF, dispatched by the mode's `⋮` menu
/// once its own options dialog has resolved.
///
/// [options] is what that dialog returned — the page format and margins the document is typeset
/// with, which scenes are printed, and the two sections a sheet may leave out. Both localized
/// payloads are resolved by the widget dispatching this, since the bloc has no `BuildContext` of
/// its own: [labels] is every string the document itself carries (see
/// `ocptBreakdownSheetsLabelsOf`), [fileTypeLabel] the label the native save dialog shows for the
/// `.pdf` type. Any pending field edit is flushed first, exactly as the other two modes' own export
/// events do, so an element renamed or a note typed seconds before the export is on the sheet
/// rather than only on screen.
class OcptBreakdownSheetsExportRequestedEvent extends OcptBreakdownExportEvent {
  /// The one-off options the export runs with.
  final OcptBreakdownSheetsExportOptions options;

  /// Every localized string the exported document holds.
  final OcptBreakdownSheetsLabels labels;

  /// The localized label of the `.pdf` file type, shown by the native save dialog.
  final String fileTypeLabel;

  /// The selected episode's own tag (`ep. 2`), resolved by `OcptBreakdownMode` from
  /// `OcptWorkspaceBloc.state.episodes`/`.selectedEpisodeId` and null while the open project holds
  /// one episode or none — see `ocptWorkspaceEpisodeExportTagOf`.
  final String? episodeTag;

  /// {@macro open_cine_prod_tools.exportShareAnchor}
  final Rect? shareAnchor;

  /// Class constructor
  const OcptBreakdownSheetsExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
    this.episodeTag,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    options,
    labels,
    fileTypeLabel,
    episodeTag,
    shareAnchor,
  ];
}

/// Request exporting the whole breakdown as a two-sheet XLSX workbook, dispatched by the mode's
/// export panel — this document takes no options dialog, so this event goes straight from the
/// panel's own card to the bloc.
///
/// [labels] is every string the workbook itself carries (see `ocptBreakdownXlsxLabelsOf`),
/// resolved by the widget dispatching this since the bloc has no `BuildContext` of its own, and
/// [fileTypeLabel] the label the native save dialog shows for the `.xlsx` type. Any pending field
/// edit is flushed first, exactly as [OcptBreakdownSheetsExportRequestedEvent] already does, so an
/// element renamed or a note typed seconds before the export lands in a cell rather than only on
/// screen.
class OcptBreakdownXlsxExportRequestedEvent extends OcptBreakdownExportEvent {
  /// Every localized string the exported workbook holds.
  final OcptBreakdownXlsxLabels labels;

  /// The localized label of the `.xlsx` file type, shown by the native save dialog.
  final String fileTypeLabel;

  /// The selected episode's own tag, exactly as
  /// [OcptBreakdownSheetsExportRequestedEvent.episodeTag] is — see its own doc comment.
  final String? episodeTag;

  /// The tapped `Export` control's own screen `Rect`, exactly as
  /// [OcptBreakdownSheetsExportRequestedEvent.shareAnchor] is — see its own doc comment.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptBreakdownXlsxExportRequestedEvent({
    required this.labels,
    required this.fileTypeLabel,
    this.episodeTag,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, labels, fileTypeLabel, episodeTag, shareAnchor];
}

/// Dismiss the transient export notice currently shown, if any.
class OcptBreakdownIoNoticeDismissedEvent extends OcptBreakdownExportEvent {
  /// Class constructor
  const OcptBreakdownIoNoticeDismissedEvent();
}
