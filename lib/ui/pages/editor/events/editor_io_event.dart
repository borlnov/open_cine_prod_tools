// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';

import 'package:open_cine_prod_tools/models/ocpt_pdf_export_options.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/events/editor_base_event.dart';

/// The events about exporting the screenplay and importing a file over it.
sealed class OcptEditorIoEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorIoEvent();
}

/// Request exporting the current screenplay to a `.fountain` file.
///
/// If the screenplay is dirty, it's saved first (tagged `OcptSnapshotReason.export`) so the
/// exported file matches exactly what the project stores.
class OcptEditorExportRequestedEvent extends OcptEditorIoEvent {
  /// The label of the file type shown in the native save dialog, localized by the caller.
  final String fileTypeLabel;

  /// The selected episode's own tag (`ep. 2`), resolved by `OcptEditorPage` from
  /// `OcptWorkspaceBloc.state.episodes`/`.selectedEpisodeId` and null while the open project holds
  /// one episode or none — see `ocptWorkspaceEpisodeExportTagOf`.
  final String? episodeTag;

  /// The tapped `Export` control's own screen `Rect`, anchoring the OS share sheet's popover on an
  /// iPad/Mac when the export is handed to it rather than to the native save dialog; null on
  /// desktop and wherever no anchor was resolved.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptEditorExportRequestedEvent({
    required this.fileTypeLabel,
    this.episodeTag,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, fileTypeLabel, episodeTag, shareAnchor];
}

/// Request exporting the current screenplay to a PDF file.
///
/// If the screenplay is dirty, it's saved first (tagged `OcptSnapshotReason.export`) so the
/// exported PDF matches exactly what the project stores. [options] carries the one-off
/// format/margins and content toggles picked in the export dialog.
class OcptEditorExportPdfRequestedEvent extends OcptEditorIoEvent {
  /// The options this export runs with.
  final OcptPdfExportOptions options;

  /// The label of the file type shown in the native save dialog, localized by the caller.
  final String fileTypeLabel;

  /// The selected episode's own tag, exactly as [OcptEditorExportRequestedEvent.episodeTag] is —
  /// see its own doc comment.
  final String? episodeTag;

  /// The tapped `Export` control's own screen `Rect`, exactly as
  /// [OcptEditorExportRequestedEvent.shareAnchor] is — see its own doc comment.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptEditorExportPdfRequestedEvent({
    required this.options,
    required this.fileTypeLabel,
    this.episodeTag,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, options, fileTypeLabel, episodeTag, shareAnchor];
}

/// Request replacing the current screenplay text with the content of a picked screenplay file —
/// a `.fountain`, an `.fdx` or a `.celtx`.
///
/// Dispatched only once the user confirmed the replacement in the import confirmation dialog.
class OcptEditorImportRequestedEvent extends OcptEditorIoEvent {
  /// The label of the file type shown in the open-file dialog, localized by the caller.
  final String fileTypeLabel;

  /// Class constructor
  const OcptEditorImportRequestedEvent({required this.fileTypeLabel});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, fileTypeLabel];
}

/// Dismiss the transient export/import notice currently shown, if any.
class OcptEditorIoNoticeDismissedEvent extends OcptEditorIoEvent {
  /// Class constructor
  const OcptEditorIoNoticeDismissedEvent();
}
