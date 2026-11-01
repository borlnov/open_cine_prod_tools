// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';

import 'package:open_cine_prod_tools/models/ocpt_floor_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_labels.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/events/shot_list_base_event.dart';

/// The events of `OcptShotListExportBloc`, about exports.
sealed class OcptShotListExportEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListExportEvent();
}

/// Requests exporting the whole shot list to an XLSX workbook, dispatched by the table's
/// `Export XLSX` button and by the mode's `⋮` menu alike.
///
/// Both localized payloads are resolved by the widget dispatching this, since the bloc has no
/// `BuildContext` of its own: [labels] is every string the sheet itself carries (see
/// `ocptShotListXlsxLabelsOf`), [fileTypeLabel] the label the native save dialog shows for the
/// `.xlsx` type. Any pending field edit is flushed first, so a value typed seconds before the
/// export is in the workbook rather than only on screen.
class OcptShotListXlsxExportRequestedEvent extends OcptShotListExportEvent {
  /// Every localized string the exported sheet holds.
  final OcptShotListXlsxLabels labels;

  /// The localized label of the `.xlsx` file type, shown by the native save dialog.
  final String fileTypeLabel;

  /// The selected episode's own tag (`ep. 2`), resolved by `OcptShotListMode` from
  /// `OcptWorkspaceBloc.state.episodes`/`.selectedEpisodeId` and null while the open project holds
  /// one episode or none — see `ocptWorkspaceEpisodeExportTagOf`.
  final String? episodeTag;

  /// The tapped `Export` control's own screen `Rect`, anchoring the OS share sheet's popover on an
  /// iPad/Mac when the export is handed to it rather than to the native save dialog; null on
  /// desktop and wherever no anchor was resolved.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptShotListXlsxExportRequestedEvent({
    required this.labels,
    required this.fileTypeLabel,
    this.episodeTag,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, labels, fileTypeLabel, episodeTag, shareAnchor];
}

/// Requests exporting the screenplay annotated with the shots covering it, dispatched by the mode's
/// `⋮` menu once its own options dialog has resolved.
///
/// [options] is what that dialog returned — the page format and margins the document is typeset
/// with, and the four content toggles. Both localized payloads are resolved by the widget
/// dispatching this, since the bloc has no `BuildContext` of its own: [labels] is every string the
/// document itself carries (see `ocptScenarioCoverageLabelsOf`), [fileTypeLabel] the label the
/// native save dialog shows for the `.pdf` type. Any pending field edit is flushed first, exactly
/// as [OcptShotListXlsxExportRequestedEvent] does, so a shot size typed seconds before the export
/// is in the legend rather than only on screen.
class OcptShotListScenarioCoverageExportRequestedEvent extends OcptShotListExportEvent {
  /// The one-off options the export runs with.
  final OcptScenarioCoverageExportOptions options;

  /// Every localized string the exported document holds.
  final OcptScenarioCoverageLabels labels;

  /// The localized label of the `.pdf` file type, shown by the native save dialog.
  final String fileTypeLabel;

  /// The selected episode's own tag, exactly as
  /// [OcptShotListXlsxExportRequestedEvent.episodeTag] is — see its own doc comment.
  final String? episodeTag;

  /// The tapped `Export` control's own screen `Rect`, exactly as
  /// [OcptShotListXlsxExportRequestedEvent.shareAnchor] is — see its own doc comment.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptShotListScenarioCoverageExportRequestedEvent({
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

/// Requests exporting the storyboard — every shot's imported frames, annotated, with its key
/// information — dispatched by the mode's own `⋮` menu once its own options dialog has resolved.
///
/// [options] is what that dialog returned — the page format and margins, the shots-per-page count
/// and whether the floor plan sheets are appended after each sequence. Both localized payloads are
/// resolved by the widget dispatching this, since the bloc has no `BuildContext` of its own:
/// [labels] is every string the document itself carries (see `ocptStoryboardLabelsOf`),
/// [fileTypeLabel] the label the native save dialog shows for the `.pdf` type. Any pending field
/// edit is flushed first, exactly as [OcptShotListXlsxExportRequestedEvent] does, so a panel
/// comment typed seconds before the export is in the document rather than only on screen.
class OcptShotListStoryboardExportRequestedEvent extends OcptShotListExportEvent {
  /// The one-off options the export runs with.
  final OcptStoryboardExportOptions options;

  /// Every localized string the exported document holds.
  final OcptStoryboardLabels labels;

  /// Every localized string the appended floor plan sheets hold, when [OcptStoryboardExportOptions
  /// .includeFloorPlansAfterEachSequence] is true — unused otherwise, but always resolved by the
  /// caller alongside [labels] so the bloc never has to reach for a `Tr` of its own to build it on
  /// demand.
  final OcptFloorPlanLabels floorPlanLabels;

  /// The localized label of the `.pdf` file type, shown by the native save dialog.
  final String fileTypeLabel;

  /// The selected episode's own tag, exactly as
  /// [OcptShotListXlsxExportRequestedEvent.episodeTag] is — see its own doc comment.
  final String? episodeTag;

  /// The tapped `Export` control's own screen `Rect`, exactly as
  /// [OcptShotListXlsxExportRequestedEvent.shareAnchor] is — see its own doc comment.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptShotListStoryboardExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.floorPlanLabels,
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
    floorPlanLabels,
    fileTypeLabel,
    episodeTag,
    shareAnchor,
  ];
}

/// Requests exporting the floor plans — one plan per shot that has a camera placed on it —
/// dispatched by the toolbar's export panel directly: unlike the storyboard, this document opens
/// no options dialog of its own, its page format coming from `OcptShotListState.pageSetup`
/// (mirroring the shot list workbook's own `Export XLSX` button).
///
/// [labels] is every string the document itself carries (see `ocptFloorPlanLabelsOf`), resolved by
/// the widget dispatching this since the bloc has no `BuildContext` of its own; [fileTypeLabel] the
/// label the native save dialog shows for the `.pdf` type. Any pending field edit is flushed first,
/// exactly as [OcptShotListXlsxExportRequestedEvent] does, so a symbol label typed seconds before
/// the export is on the plan rather than only on screen.
class OcptShotListFloorPlansExportRequestedEvent extends OcptShotListExportEvent {
  /// Every localized string the exported document holds.
  final OcptFloorPlanLabels labels;

  /// The localized label of the `.pdf` file type, shown by the native save dialog.
  final String fileTypeLabel;

  /// The selected episode's own tag, exactly as
  /// [OcptShotListXlsxExportRequestedEvent.episodeTag] is — see its own doc comment.
  final String? episodeTag;

  /// The tapped `Export` control's own screen `Rect`, exactly as
  /// [OcptShotListXlsxExportRequestedEvent.shareAnchor] is — see its own doc comment.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptShotListFloorPlansExportRequestedEvent({
    required this.labels,
    required this.fileTypeLabel,
    this.episodeTag,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, labels, fileTypeLabel, episodeTag, shareAnchor];
}

/// Dismisses the transient export notice currently shown, if any.
class OcptShotListIoNoticeDismissedEvent extends OcptShotListExportEvent {
  /// Class constructor
  const OcptShotListIoNoticeDismissedEvent();
}
