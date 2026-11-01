// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/events/resources_base_event.dart';

/// The events about exports.
sealed class OcptResourcesExportEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesExportEvent();
}

/// Requests exporting the whole resources catalogue to a four-sheet XLSX workbook, dispatched by
/// the mode's `⋮` menu.
///
/// Both localized payloads are resolved by the widget dispatching this, since the bloc has no
/// `BuildContext` of its own: [labels] is every string the four sheets themselves carry (see
/// `ocptResourcesXlsxLabelsOf`), [fileTypeLabel] the label the native save dialog shows for the
/// `.xlsx` type. Every pending field edit is flushed first, so a value typed seconds before the
/// export is in the workbook rather than only on screen, mirroring
/// `OcptShotListXlsxExportRequestedEvent`.
class OcptResourcesXlsxExportRequestedEvent extends OcptResourcesExportEvent {
  /// Every localized string the exported workbook holds.
  final OcptResourcesXlsxLabels labels;

  /// The localized label of the `.xlsx` file type, shown by the native save dialog.
  final String fileTypeLabel;

  /// The tapped `Export` control's own screen `Rect`, anchoring the OS share sheet's popover on an
  /// iPad/Mac when the export is handed to it rather than to the native save dialog; null on
  /// desktop and wherever no anchor was resolved.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptResourcesXlsxExportRequestedEvent({
    required this.labels,
    required this.fileTypeLabel,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, labels, fileTypeLabel, shareAnchor];
}

/// Requests exporting the crew and the cast to a standalone contact list PDF, dispatched once the
/// export panel's own options dialog has resolved.
///
/// [options] is what that dialog returned — the page format and margins the document is typeset
/// with. Both localized payloads are resolved by the widget dispatching this, since the bloc has no
/// `BuildContext` of its own: [labels] is every string the document itself carries (see
/// `ocptContactListLabelsOf`), [fileTypeLabel] the label the native save dialog shows for the
/// `.pdf` type. Every pending field edit is flushed first, mirroring
/// `OcptResourcesXlsxExportRequestedEvent`, so a phone number typed seconds before the export is on
/// the printed list rather than only on screen.
class OcptResourcesContactListExportRequestedEvent extends OcptResourcesExportEvent {
  /// The one-off options the export runs with.
  final OcptContactListExportOptions options;

  /// Every localized string the exported document holds.
  final OcptContactListLabels labels;

  /// The localized label of the `.pdf` file type, shown by the native save dialog.
  final String fileTypeLabel;

  /// The tapped `Export` control's own screen `Rect`, exactly as
  /// [OcptResourcesXlsxExportRequestedEvent.shareAnchor] is — see its own doc comment.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptResourcesContactListExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel, shareAnchor];
}

/// Dismisses the transient export notice currently shown, if any.
class OcptResourcesIoNoticeDismissedEvent extends OcptResourcesExportEvent {
  /// Class constructor
  const OcptResourcesIoNoticeDismissedEvent();
}
