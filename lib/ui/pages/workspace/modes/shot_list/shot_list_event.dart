// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_panel_size.dart';

/// The events handled by `OcptShotListBloc`.
sealed class OcptShotListEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptShotListEvent();
}

/// Requests loading the current project's shot list, together with the persisted dock fractions,
/// visible columns and last right dock tab.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptShotListLoadRequestedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListLoadRequestedEvent();
}

/// Selects the sequence [sequenceId], expanding it in the left dock and showing its shots in the
/// centre table.
///
/// Selecting a sequence other than the one already selected clears the selected shot: the table
/// now shows a different sequence's shots, none of which the previous selection belonged to.
class OcptShotListSequenceSelectedEvent extends OcptShotListEvent {
  /// The `OcptShotSequence.id` of the sequence to select.
  final String sequenceId;

  /// Class constructor
  const OcptShotListSequenceSelectedEvent({required this.sequenceId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sequenceId];
}

/// Selects the shot [shotId], dispatched by a table row and by a shot entry of the left dock.
///
/// Selecting a shot also selects the sequence holding it (so clicking a shot in the left dock's
/// tree switches the centre table too) and opens the right dock on its inspector tab, matching
/// the mock-up's "clicking a row opens the inspector" behaviour.
class OcptShotListShotSelectedEvent extends OcptShotListEvent {
  /// The id of the shot to select.
  final String shotId;

  /// Class constructor
  const OcptShotListShotSelectedEvent({required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId];
}

/// Requests creating a new shot at the end of the selected sequence, then selecting it.
///
/// Does nothing while no sequence is selected, or while the selected one is the orphan group: a
/// shot only ever exists inside a real screenplay scene, and the orphan group is where shots go
/// when their scene disappears, never where new ones are authored.
class OcptShotListShotCreationRequestedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListShotCreationRequestedEvent();
}

/// Toggles the visibility of the left (sequences) dock.
class OcptShotListSequencePanelToggledEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListSequencePanelToggledEvent();
}

/// Selects a tab of the right dock, dispatched by the dock's own tab row.
///
/// Follows the screenplay editor's toggle semantics exactly: selecting the tab already active
/// closes the dock, any other tab opens (or switches) it. Either way [tab] becomes
/// `OcptShotListState.lastRightDockTab`, the tab [OcptShotListRightDockToggledEvent] reopens the
/// dock on, and is persisted.
class OcptShotListRightDockTabSelectedEvent extends OcptShotListEvent {
  /// The tab whose label was clicked.
  final OcptShotListRightDockTab tab;

  /// Class constructor
  const OcptShotListRightDockTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Toggles the right dock as a whole, dispatched by the workspace toolbar's right dock toggle: an
/// open dock closes, a closed one reopens on `OcptShotListState.lastRightDockTab`.
class OcptShotListRightDockToggledEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListRightDockToggledEvent();
}

/// Closes the right dock via its own × close button, whichever tab is currently active.
class OcptShotListRightDockClosedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListRightDockClosedEvent();
}

/// Requests updating the mode's dock width fractions, persisting whichever of [left]/[right] is
/// given.
///
/// Dispatched once per drag gesture, on `onHorizontalDragEnd`, never per frame, exactly like the
/// screenplay editor's own equivalent.
class OcptShotListDockFractionsChangedEvent extends OcptShotListEvent {
  /// The new left (sequences) dock fraction, or null to leave it unchanged.
  final double? left;

  /// The new right (inspector) dock fraction, or null to leave it unchanged.
  final double? right;

  /// Class constructor
  const OcptShotListDockFractionsChangedEvent({this.left, this.right});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, left, right];
}

/// Requests restoring both dock fractions to their defaults ("Reset panel layout").
class OcptShotListDockLayoutResetEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListDockLayoutResetEvent();
}

/// Shows or hides the optional table column [column], persisting the new set.
class OcptShotListColumnToggledEvent extends OcptShotListEvent {
  /// The optional column whose visibility is toggled.
  final OcptShotListColumn column;

  /// Class constructor
  const OcptShotListColumnToggledEvent({required this.column});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, column];
}

/// Dismisses the transient write error currently shown, if any.
class OcptShotListWriteErrorDismissedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListWriteErrorDismissedEvent();
}

/// Requests exporting the whole shot list to an XLSX workbook, dispatched by the table's
/// `Export XLSX` button and by the mode's `⋮` menu alike.
///
/// Both localized payloads are resolved by the widget dispatching this, since the bloc has no
/// `BuildContext` of its own: [labels] is every string the sheet itself carries (see
/// `ocptShotListXlsxLabelsOf`), [fileTypeLabel] the label the native save dialog shows for the
/// `.xlsx` type. Any pending field edit is flushed first, so a value typed seconds before the
/// export is in the workbook rather than only on screen.
class OcptShotListXlsxExportRequestedEvent extends OcptShotListEvent {
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

  /// Object properties
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
class OcptShotListScenarioCoverageExportRequestedEvent extends OcptShotListEvent {
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

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel, episodeTag, shareAnchor];
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
class OcptShotListStoryboardExportRequestedEvent extends OcptShotListEvent {
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

  /// Object properties
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
class OcptShotListFloorPlansExportRequestedEvent extends OcptShotListEvent {
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

  /// Object properties
  @override
  List<Object?> get props => [...super.props, labels, fileTypeLabel, episodeTag, shareAnchor];
}

/// Dismisses the transient export notice currently shown, if any.
class OcptShotListIoNoticeDismissedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListIoNoticeDismissedEvent();
}

/// Requests leaving the workspace and going back to the projects list.
///
/// Flushes any pending field edit before closing the current project, so navigating back right
/// after typing never loses it.
class OcptShotListBackRequestedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListBackRequestedEvent();
}

/// Reports that the project settings page was closed after changing something.
///
/// The page format is the only field the scenario coverage export dialog pre-fills from, so this
/// re-reads it (through `OcptShotListState.pageSetup`) rather than carrying the new value on the
/// event, exactly as the screenplay editor's own equivalent event does.
class OcptShotListProjectSettingsChangedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListProjectSettingsChangedEvent();
}

/// Records the raw text just typed into [field] of shot [shotId], dispatched by the inspector on
/// every keystroke.
///
/// The typed value becomes visible immediately as a pending edit in
/// `OcptShotListState.pendingFieldEdits`, and (re)starts the field-edit autosave debounce that
/// eventually writes it, unless something flushes it sooner (selecting another shot or sequence,
/// leaving the workspace, or the mode itself leaving the widget tree).
class OcptShotListShotFieldChangedEvent extends OcptShotListEvent {
  /// The id of the shot whose field was edited.
  final String shotId;

  /// The field edited.
  final OcptShotListEditableField field;

  /// The raw text now sitting in the field, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptShotListShotFieldChangedEvent({
    required this.shotId,
    required this.field,
    required this.rawValue,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, field, rawValue];
}

/// Fired by the field-edit debounce timer `OcptShotListShotFieldChangedEvent` (re)starts, once it
/// elapses with no further edit. Not meant to be dispatched by a widget directly.
class OcptShotListFieldEditFlushRequestedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListFieldEditFlushRequestedEvent();
}

/// Sets one difficulty axis of shot [shotId] to [value] (0-5), dispatched by the inspector's
/// difficulty dots.
///
/// Written immediately: clicking a dot is a single discrete action, not typing, so it never goes
/// through the field-edit debounce.
class OcptShotListShotDifficultyChangedEvent extends OcptShotListEvent {
  /// The id of the shot whose difficulty changed.
  final String shotId;

  /// The axis changed.
  final OcptShotDifficultyAxis axis;

  /// The new value of [axis], 0-5.
  final int value;

  /// Class constructor
  const OcptShotListShotDifficultyChangedEvent({
    required this.shotId,
    required this.axis,
    required this.value,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, axis, value];
}

/// Attaches role [roleId] to shot [shotId] if it isn't already attached, detaches it otherwise,
/// dispatched by the inspector's character chips.
///
/// Written immediately: toggling a chip is a single discrete action, not typing, so it never goes
/// through the field-edit debounce.
class OcptShotListShotCharacterToggledEvent extends OcptShotListEvent {
  /// The id of the shot whose character list changed.
  final String shotId;

  /// The id of the role toggled.
  final String roleId;

  /// Class constructor
  const OcptShotListShotCharacterToggledEvent({required this.shotId, required this.roleId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, roleId];
}

/// Requests attaching a character typed into the inspector's `＋ Add` field to shot [shotId],
/// dispatched once the field is submitted.
///
/// [characterName] resolves to a live role of that name, or **creates** a hand-added silent role
/// linked to the shot's own episode (decision 1), through
/// `OcptShotListService.resolveOrCreateRoleId` — the resolution the roleId-native
/// `OcptShotListService.attachCharacter` no longer performs on its own. Written immediately, like
/// every other character change.
class OcptShotListCharacterAddRequestedEvent extends OcptShotListEvent {
  /// The id of the shot the character is added to.
  final String shotId;

  /// The character's typed name, not necessarily normalised yet.
  final String characterName;

  /// Class constructor
  const OcptShotListCharacterAddRequestedEvent({required this.shotId, required this.characterName});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, characterName];
}

/// Requests deleting shot [shotId], dispatched once the inspector's own confirmation dialog has
/// already confirmed it. Renumbers the remaining shots of its group and clears the selection if
/// [shotId] was the selected shot (the sequence stays selected).
class OcptShotListShotDeletionRequestedEvent extends OcptShotListEvent {
  /// The id of the shot to delete.
  final String shotId;

  /// Class constructor
  const OcptShotListShotDeletionRequestedEvent({required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId];
}
/// Records a click on a word of the selected shot's scenario coverage.
///
/// One event backs the whole three-state interaction, the bloc rather than the widget deciding
/// what a click means: with no range open, a click on already-covered text removes the range
/// covering it and a click anywhere else opens a range on that word; with a range open, the click
/// closes it, wherever it lands — a range may span several blocks, and clicking the opening word
/// again records a one-word range.
class OcptShotListCoverageWordClickedEvent extends OcptShotListEvent {
  /// The id of the shot whose coverage was clicked.
  final String shotId;

  /// The scene-relative offset at which the clicked word starts.
  final int wordStartOffset;

  /// The scene-relative offset one past the clicked word's last character.
  final int wordEndOffset;

  /// Class constructor
  const OcptShotListCoverageWordClickedEvent({
    required this.shotId,
    required this.wordStartOffset,
    required this.wordEndOffset,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, wordStartOffset, wordEndOffset];
}

/// Requests removing every scenario coverage range of shot [shotId], dispatched by the inspector's
/// `Clear all` action. Written immediately, like every other coverage change.
class OcptShotListCoverageClearRequestedEvent extends OcptShotListEvent {
  /// The id of the shot whose coverage ranges are all removed.
  final String shotId;

  /// Class constructor
  const OcptShotListCoverageClearRequestedEvent({required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId];
}

/// Clears the coverage anchor currently pending, dispatched by the coverage dialog's `Escape` (only
/// while an anchor is pending, so `Escape` still closes the dialog otherwise), a click on empty
/// space in the dialog's script area, or the dialog closing through its × or `Close` button — the
/// user changed their mind about the passage, not just about where it should end.
///
/// Only `OcptShotListState.pendingCoverageAnchor` is cleared: the shot's own coverage ranges are
/// untouched, exactly as the breakdown mode's own equivalent,
/// `OcptBreakdownTagRangeCancelledEvent`, leaves its target's tags untouched.
class OcptShotListCoverageAnchorCancelledEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListCoverageAnchorCancelledEvent();
}

/// Requests deleting role [roleId] for good, dispatched once the shared role alert banner's
/// orphaned variant has already been confirmed through `OcptConfirmDialog`, by the mode.
///
/// Written immediately through `OcptRoleIndexService.deleteRole`, whose cascade tombstones the
/// role's `shot_characters` and `breakdown_tags` rows alongside it: the banner disappears on its
/// own once the reloaded cast no longer holds the role at all.
class OcptShotListOrphanedRoleDeleteRequestedEvent extends OcptShotListEvent {
  /// The id of the orphaned role to delete.
  final String roleId;

  /// Class constructor
  const OcptShotListOrphanedRoleDeleteRequestedEvent({required this.roleId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, roleId];
}

/// Requests keeping orphaned role [roleId] as a hand-added silent role, dispatched by the shared
/// role alert banner's orphaned variant's `Keep as silent` action — not destructive, so reached
/// with no confirmation dialog, exactly as the resources mode's own equivalent isn't.
class OcptShotListOrphanedRoleKeptEvent extends OcptShotListEvent {
  /// The id of the orphaned role to keep.
  final String roleId;

  /// Class constructor
  const OcptShotListOrphanedRoleKeptEvent({required this.roleId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, roleId];
}

/// Requests merging role [sourceRoleId] into role [targetRoleId], dispatched once the shared role
/// alert banner's merge affordance — either variant — has already been confirmed through
/// `OcptConfirmDialog`, by the mode.
///
/// Written immediately through `OcptRoleIndexService.mergeRole`: the banner disappears on its own
/// once the reloaded cast no longer holds [sourceRoleId], or is no longer orphaned/collided.
class OcptShotListRoleMergeRequestedEvent extends OcptShotListEvent {
  /// The id of the role merged away.
  final String sourceRoleId;

  /// The id of the role [sourceRoleId] is merged into.
  final String targetRoleId;

  /// Class constructor
  const OcptShotListRoleMergeRequestedEvent({
    required this.sourceRoleId,
    required this.targetRoleId,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sourceRoleId, targetRoleId];
}

/// Requests clearing shot [shotId]'s `needsCheck` flag and re-stamping every one of its scenario
/// coverage ranges' digests to the screenplay's current text, dispatched by the inspector's
/// `Needs checking` callout's `Mark as checked` button.
class OcptShotListShotMarkedAsCheckedEvent extends OcptShotListEvent {
  /// The id of the shot marked as checked.
  final String shotId;

  /// Class constructor
  const OcptShotListShotMarkedAsCheckedEvent({required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId];
}

/// Selects centre view [view], dispatched by `OcptShotListCentreHeader`'s own switch, and persists
/// it through `OcptPropertiesManager.shotListLastCentreView`.
///
/// Keeps `OcptShotListState.selectedShotId`/`.selectedSequenceId` exactly as they were: the two
/// views read the same selection, one just shows more of it than the other.
class OcptShotListCentreViewSelectedEvent extends OcptShotListEvent {
  /// The view just picked.
  final OcptShotListCentreView view;

  /// Class constructor
  const OcptShotListCentreViewSelectedEvent({required this.view});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, view];
}

/// Selects panel [panelId] on the board, dispatched by a click on one of the selected shot's own
/// `OcptStoryboardPanelFrame`s.
class OcptShotListPanelSelectedEvent extends OcptShotListEvent {
  /// The id of the panel to select.
  final String panelId;

  /// Class constructor
  const OcptShotListPanelSelectedEvent({required this.panelId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, panelId];
}

/// Sets the board's common panel height to [size], dispatched by the header's own `Panel size ▾`
/// menu. A **view preference**, held in state for the session alone — never persisted.
class OcptShotListPanelSizeChangedEvent extends OcptShotListEvent {
  /// The panel size just picked.
  final OcptStoryboardPanelSize size;

  /// Class constructor
  const OcptShotListPanelSizeChangedEvent({required this.size});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, size];
}

/// Requests importing a frame onto shot [shotId]'s storyboard, dispatched by its panel strip's
/// trailing `+ Import frame` slot.
///
/// The bloc picks the file through `FileSelectorManager`, filtered to JPEG and PNG
/// (`ocptStoryboardPanelImageFileExtensions`), then appends a new panel carrying it. A cancelled
/// dialog changes nothing at all. [fileTypeLabel] is the localized label the native picker's own
/// file type filter shows, resolved by the mode — the bloc has no `BuildContext` of its own.
class OcptShotListPanelImportRequestedEvent extends OcptShotListEvent {
  /// The id of the shot the new panel is appended to.
  final String shotId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptShotListPanelImportRequestedEvent({required this.shotId, required this.fileTypeLabel});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, fileTypeLabel];
}

/// Requests replacing panel [panelId]'s image, dispatched by its frame's own `Replace image`
/// action.
///
/// The same picker [OcptShotListPanelImportRequestedEvent] uses; a cancelled dialog leaves the
/// panel's current image untouched. See [OcptShotListPanelImportRequestedEvent] for
/// [fileTypeLabel].
class OcptShotListPanelReplaceRequestedEvent extends OcptShotListEvent {
  /// The id of the panel whose image is replaced.
  final String panelId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptShotListPanelReplaceRequestedEvent({
    required this.panelId,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, panelId, fileTypeLabel];
}

/// Moves panel [panelId] of shot [shotId] to [newPosition] (0-based) among its shot's other panels,
/// dispatched by the strip's own drag-to-reorder gesture. Written immediately, one row
/// (`OcptStoryboardService.reorderPanel`).
class OcptShotListPanelReorderedEvent extends OcptShotListEvent {
  /// The id of the shot the panel belongs to.
  final String shotId;

  /// The id of the panel being moved.
  final String panelId;

  /// The 0-based position the panel is moved to.
  final int newPosition;

  /// Class constructor
  const OcptShotListPanelReorderedEvent({
    required this.shotId,
    required this.panelId,
    required this.newPosition,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, panelId, newPosition];
}

/// Records the raw text just typed into panel [panelId]'s free comment, dispatched by the
/// inspector's Panels group on every keystroke.
///
/// Rides the mode's own field-edit autosave debounce exactly as
/// `OcptShotListShotFieldChangedEvent` does, keyed by `OcptShotListPanelCommentEditKey` rather than
/// `OcptShotListShotFieldEditKey`.
class OcptShotListPanelCommentChangedEvent extends OcptShotListEvent {
  /// The id of the panel whose comment was edited.
  final String panelId;

  /// The comment's raw text, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptShotListPanelCommentChangedEvent({required this.panelId, required this.rawValue});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, panelId, rawValue];
}

/// Requests deleting panel [panelId] for good, dispatched once the inspector's Panels group's own
/// `Delete panel` action has already been confirmed through `OcptConfirmDialog`, by the mode.
class OcptShotListPanelDeletionRequestedEvent extends OcptShotListEvent {
  /// The id of the panel to delete.
  final String panelId;

  /// Class constructor
  const OcptShotListPanelDeletionRequestedEvent({required this.panelId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, panelId];
}

/// Sets the board's active annotation tool to [tool], dispatched by the inspector's own `Annotate`
/// control, or clears it (null) when the tool already on is picked again. Scoped to the currently
/// selected panel — see `OcptShotListState.activeAnnotationTool`'s own doc comment for when it is
/// cleared on its own.
class OcptShotListAnnotationToolSelectedEvent extends OcptShotListEvent {
  /// The tool just picked, or null to turn annotation editing off.
  final OcptStoryboardAnnotationTool? tool;

  /// Class constructor
  const OcptShotListAnnotationToolSelectedEvent({required this.tool});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tool];
}

/// Adds a mark of [kind] to panel [panelId] at the normalised tail/head `(x1, y1)`-`(x2, y2)`,
/// dispatched once a drag over the selected panel's own frame finishes drawing an arrow. Written
/// immediately, then selects the freshly minted mark (`OcptStoryboardService.addAnnotation`).
class OcptShotListAnnotationDrawnEvent extends OcptShotListEvent {
  /// The id of the panel the mark is added to.
  final String panelId;

  /// The kind of mark just drawn (one of the two arrow kinds — a label is placed by
  /// [OcptShotListAnnotationPlacedEvent] instead).
  final OcptStoryboardAnnotationKind kind;

  /// The arrow's tail X coordinate, normalised 0..1 to the frame.
  final double x1;

  /// The arrow's tail Y coordinate, normalised 0..1 to the frame.
  final double y1;

  /// The arrow's head X coordinate, normalised 0..1 to the frame.
  final double x2;

  /// The arrow's head Y coordinate, normalised 0..1 to the frame.
  final double y2;

  /// Class constructor
  const OcptShotListAnnotationDrawnEvent({
    required this.panelId,
    required this.kind,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, panelId, kind, x1, y1, x2, y2];
}

/// Places a [OcptStoryboardAnnotationKind.label] on panel [panelId] at the normalised point
/// `(x1, y1)`, dispatched by a click over the selected panel's own frame while the label tool is
/// on. Written immediately, then selects the freshly minted mark so its text field opens ready
/// for typing (`OcptStoryboardService.addAnnotation`).
class OcptShotListAnnotationPlacedEvent extends OcptShotListEvent {
  /// The id of the panel the label is added to.
  final String panelId;

  /// The label's anchor X coordinate, normalised 0..1 to the frame.
  final double x1;

  /// The label's anchor Y coordinate, normalised 0..1 to the frame.
  final double y1;

  /// Class constructor
  const OcptShotListAnnotationPlacedEvent({
    required this.panelId,
    required this.x1,
    required this.y1,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, panelId, x1, y1];
}

/// Selects mark [annotationId], dispatched by a click on it (either on the frame's own overlay, or
/// on its row of the inspector Panels group's annotation section).
class OcptShotListAnnotationSelectedEvent extends OcptShotListEvent {
  /// The id of the mark to select.
  final String annotationId;

  /// Class constructor
  const OcptShotListAnnotationSelectedEvent({required this.annotationId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, annotationId];
}

/// Records the raw text just typed into mark [annotationId]'s own text — a label's text, or an
/// arrow's optional caption — dispatched by the annotation section's own text field on every
/// keystroke. Rides the mode's field-edit autosave debounce, keyed by
/// `OcptShotListAnnotationTextEditKey`.
class OcptShotListAnnotationTextChangedEvent extends OcptShotListEvent {
  /// The id of the mark whose text was edited.
  final String annotationId;

  /// The text's raw value, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptShotListAnnotationTextChangedEvent({required this.annotationId, required this.rawValue});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, annotationId, rawValue];
}

/// Requests deleting mark [annotationId] for good, dispatched once the annotation section's own
/// remove action has already been confirmed through `OcptConfirmDialog`, by the mode.
class OcptShotListAnnotationDeletionRequestedEvent extends OcptShotListEvent {
  /// The id of the mark to delete.
  final String annotationId;

  /// Class constructor
  const OcptShotListAnnotationDeletionRequestedEvent({required this.annotationId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, annotationId];
}

/// Selects case `event.caseId` on the floor plans view, dispatched by a click on its own tab.
/// Clears the symbol selection: a symbol only ever belongs to the case currently shown.
class OcptShotListCaseSelectedEvent extends OcptShotListEvent {
  /// The id of the case to select.
  final String caseId;

  /// Class constructor
  const OcptShotListCaseSelectedEvent({required this.caseId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, caseId];
}

/// Requests creating a new case on the selected sequence, named after its scene heading's place
/// (`OcptFloorPlanService.addCase`), then selects it. Does nothing while no sequence is selected,
/// or while the selected one is the orphan group: a case only ever belongs to a real screenplay
/// scene, exactly as a new shot only ever belongs to one.
class OcptShotListCaseCreationRequestedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListCaseCreationRequestedEvent();
}

/// Records the raw text just typed into case `event.caseId`'s own tab as a pending edit, and
/// (re)starts the field-edit debounce shared with every other typed field of the mode.
class OcptShotListCaseNameChangedEvent extends OcptShotListEvent {
  /// The id of the case whose name was edited.
  final String caseId;

  /// The case's new name, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptShotListCaseNameChangedEvent({required this.caseId, required this.rawValue});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, caseId, rawValue];
}

/// Moves case `event.caseId` to `event.newPosition` among its own sequence's cases (its tab
/// order), dispatched by the case tabs' own drag-to-reorder gesture. Written immediately, one row
/// (`OcptFloorPlanService.reorderCase`).
class OcptShotListCaseReorderedEvent extends OcptShotListEvent {
  /// The id of the case being moved.
  final String caseId;

  /// The 0-based position the case is moved to.
  final int newPosition;

  /// Class constructor
  const OcptShotListCaseReorderedEvent({required this.caseId, required this.newPosition});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, caseId, newPosition];
}

/// Requests deleting case `event.caseId` for good, dispatched once the tab's own delete action has
/// already been confirmed through `OcptConfirmDialog`, by the mode. Clears the selection (and, with
/// it, the symbol selection) when it was the selected case.
class OcptShotListCaseDeletionRequestedEvent extends OcptShotListEvent {
  /// The id of the case to delete.
  final String caseId;

  /// Class constructor
  const OcptShotListCaseDeletionRequestedEvent({required this.caseId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, caseId];
}

/// Records the floor plans canvas's own zoom as last **settled** by
/// `OcptFloorPlanViewportController`, dispatched once a zoom gesture (the tool bar's `−`/`+`
/// buttons, or the canvas's own scroll-wheel zoom, debounced) ends — never per frame. A view
/// preference, held for the session alone; see `OcptShotListState.floorPlanZoom`'s own doc comment.
class OcptShotListFloorPlanZoomChangedEvent extends OcptShotListEvent {
  /// The zoom just settled on.
  final double zoom;

  /// Class constructor
  const OcptShotListFloorPlanZoomChangedEvent({required this.zoom});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, zoom];
}

/// Picks the floor plans canvas's own active tool, dispatched by the tool bar.
class OcptShotListFloorPlanToolSelectedEvent extends OcptShotListEvent {
  /// The tool just picked.
  final OcptFloorPlanTool tool;

  /// Class constructor
  const OcptShotListFloorPlanToolSelectedEvent({required this.tool});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tool];
}

/// Picks the sequence layer a placed set element lands on, dispatched by a click on one of the
/// tray's own sequence layer rows.
class OcptShotListFloorPlanActiveLayerChangedEvent extends OcptShotListEvent {
  /// The layer just picked. Always sequence-scoped: the tray only ever offers those three rows in
  /// this milestone.
  final OcptFloorPlanLayer layer;

  /// Class constructor
  const OcptShotListFloorPlanActiveLayerChangedEvent({required this.layer});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, layer];
}

/// Toggles the visibility of sequence layer `event.layer` on the floor plans canvas, dispatched by
/// the tray's own eye icon. A view preference; never withheld under a read-only preview, since it
/// only reads.
class OcptShotListFloorPlanLayerVisibilityToggledEvent extends OcptShotListEvent {
  /// The layer whose visibility is toggled.
  final OcptFloorPlanLayer layer;

  /// Class constructor
  const OcptShotListFloorPlanLayerVisibilityToggledEvent({required this.layer});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, layer];
}

/// Toggles the selected case's underlay visibility on the floor plans canvas, dispatched by the
/// tray's own underlay row eye icon. A view preference; never withheld under a read-only preview.
class OcptShotListFloorPlanUnderlayVisibilityToggledEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListFloorPlanUnderlayVisibilityToggledEvent();
}

/// Places a new set element symbol on case `event.caseId`'s `event.layer`, at `event.xM`/`event.yM`
/// (metres), dispatched by a click on empty canvas while the `setElement` tool is on. Written
/// immediately (`OcptFloorPlanService.placeSymbol`), then selects the freshly minted symbol.
class OcptShotListFloorPlanSymbolPlacedEvent extends OcptShotListEvent {
  /// The id of the case the symbol is placed on.
  final String caseId;

  /// The layer the symbol is placed on — the tray's own current active sequence layer for
  /// [OcptFloorPlanTool.setElement], or the fixed layer a shot-scoped tool
  /// ([OcptFloorPlanTool.camera]/[OcptFloorPlanTool.character]/[OcptFloorPlanTool.light]) always
  /// places on.
  final OcptFloorPlanLayer layer;

  /// The id of the shot the symbol belongs to — null on a sequence layer, the focused shot's id on
  /// a shot layer (`docs/plans/storyboard.md`, §4.3, the scope invariant
  /// `OcptFloorPlanService.placeSymbol` enforces).
  final String? shotId;

  /// The symbol's centre X, in metres.
  final double xM;

  /// The symbol's centre Y, in metres.
  final double yM;

  /// Class constructor
  const OcptShotListFloorPlanSymbolPlacedEvent({
    required this.caseId,
    required this.layer,
    required this.shotId,
    required this.xM,
    required this.yM,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, caseId, layer, shotId, xM, yM];
}

/// Selects symbol `event.symbolId` on the floor plans canvas, or clears the selection when
/// `event.symbolId` is null (a click on empty canvas while the `select` tool is on).
class OcptShotListFloorPlanSymbolSelectedEvent extends OcptShotListEvent {
  /// The id of the symbol to select, or null to clear the selection.
  final String? symbolId;

  /// Class constructor
  const OcptShotListFloorPlanSymbolSelectedEvent({required this.symbolId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Moves symbol `event.symbolId` to `event.xM`/`event.yM` (metres), dispatched once a drag on it
/// ends. Written as a single row (`OcptFloorPlanService.updateSymbol`), never per frame: the live
/// drag position is a purely local widget concern, exactly as the underlay's own drag is.
class OcptShotListFloorPlanSymbolMovedEvent extends OcptShotListEvent {
  /// The id of the symbol being moved.
  final String symbolId;

  /// The symbol's new centre X, in metres.
  final double xM;

  /// The symbol's new centre Y, in metres.
  final double yM;

  /// Class constructor
  const OcptShotListFloorPlanSymbolMovedEvent({
    required this.symbolId,
    required this.xM,
    required this.yM,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, xM, yM];
}

/// Resizes set element symbol `event.symbolId` to `event.widthM`/`event.heightM` (metres),
/// dispatched once a drag on its own resize handle ends. Written as a single row, never per frame.
class OcptShotListFloorPlanSymbolResizedEvent extends OcptShotListEvent {
  /// The id of the symbol being resized.
  final String symbolId;

  /// The symbol's new footprint width, in metres.
  final double widthM;

  /// The symbol's new footprint height, in metres.
  final double heightM;

  /// Class constructor
  const OcptShotListFloorPlanSymbolResizedEvent({
    required this.symbolId,
    required this.widthM,
    required this.heightM,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, widthM, heightM];
}

/// Rotates symbol `event.symbolId` to `event.rotationDeg`, dispatched once a drag on its own
/// rotate handle ends. Written as a single row, never per frame.
class OcptShotListFloorPlanSymbolRotatedEvent extends OcptShotListEvent {
  /// The id of the symbol being rotated.
  final String symbolId;

  /// The symbol's new rotation, in degrees.
  final double rotationDeg;

  /// Class constructor
  const OcptShotListFloorPlanSymbolRotatedEvent({
    required this.symbolId,
    required this.rotationDeg,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, rotationDeg];
}

/// Requests deleting symbol `event.symbolId` for good, dispatched once the canvas's own delete
/// action has already been confirmed through `OcptConfirmDialog`, by the mode.
class OcptShotListFloorPlanSymbolDeletionRequestedEvent extends OcptShotListEvent {
  /// The id of the symbol to delete.
  final String symbolId;

  /// Class constructor
  const OcptShotListFloorPlanSymbolDeletionRequestedEvent({required this.symbolId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Requests importing case `event.caseId`'s underlay, dispatched by the tool bar's own underlay
/// action.
///
/// The bloc picks the file through `FileSelectorManager`, filtered to JPEG and PNG
/// (`ocptFloorPlanUnderlayImageFileExtensions`), then places it at a default frame centred on the
/// canvas — the user drags and resizes it to match the reference silhouette afterwards (ADR 0031).
/// A cancelled dialog changes nothing at all. [fileTypeLabel] is the localized label the native
/// picker's own file type filter shows, resolved by the mode.
class OcptShotListFloorPlanUnderlayImportRequestedEvent extends OcptShotListEvent {
  /// The id of the case the underlay is set on.
  final String caseId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptShotListFloorPlanUnderlayImportRequestedEvent({
    required this.caseId,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, caseId, fileTypeLabel];
}

/// Sets case `event.caseId`'s underlay frame to `event.xM`/`event.yM`/`event.widthM`/
/// `event.heightM` (metres), dispatched once a drag moving or resizing it ends. Written as a
/// single call (`OcptFloorPlanService.setCaseUnderlay`, re-pointed at the same already-imported
/// file), never per frame.
class OcptShotListFloorPlanUnderlayTransformChangedEvent extends OcptShotListEvent {
  /// The id of the case whose underlay frame changed.
  final String caseId;

  /// The underlay's new centre X, in metres.
  final double xM;

  /// The underlay's new centre Y, in metres.
  final double yM;

  /// The underlay's new width, in metres.
  final double widthM;

  /// The underlay's new height, in metres.
  final double heightM;

  /// Class constructor
  const OcptShotListFloorPlanUnderlayTransformChangedEvent({
    required this.caseId,
    required this.xM,
    required this.yM,
    required this.widthM,
    required this.heightM,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, caseId, xM, yM, widthM, heightM];
}

/// Requests clearing case `event.caseId`'s underlay for good, dispatched once the tray's own
/// `Clear underlay` action has already been confirmed through `OcptConfirmDialog`, by the mode.
class OcptShotListFloorPlanUnderlayClearRequestedEvent extends OcptShotListEvent {
  /// The id of the case whose underlay is cleared.
  final String caseId;

  /// Class constructor
  const OcptShotListFloorPlanUnderlayClearRequestedEvent({required this.caseId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, caseId];
}

/// Deselects the currently selected shot, dispatched by the floor plans view's own focus strip
/// `Sequence` chip. Flips the mode's derived focus (`selectedShotId == null` reads as the
/// `Sequence` focus, `docs/plans/storyboard.md`, §4.3) without touching what sequence is selected.
class OcptShotListShotDeselectedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListShotDeselectedEvent();
}

/// Walks the selected sequence's own shots by `event.delta` (`-1` for `←`, `1` for `→`),
/// dispatched by the floor plans focus strip's own keyboard shortcut. Selects the sequence's first
/// shot when nothing is selected yet and `event.delta` is positive, does nothing at either end of
/// the list, and does nothing while the selected sequence is the orphan group (its shots have no
/// case to draw a floor plan on).
class OcptShotListFloorPlanShotWalkRequestedEvent extends OcptShotListEvent {
  /// `-1` to walk to the previous shot, `1` to walk to the next one.
  final int delta;

  /// Class constructor
  const OcptShotListFloorPlanShotWalkRequestedEvent({required this.delta});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, delta];
}

/// Toggles the visibility of camera symbol `event.symbolId` on the floor plans canvas, dispatched
/// by the tray's own per-camera eye under the `Sequence` focus's expanded cameras row. A view
/// preference; never withheld under a read-only preview, since it only reads.
class OcptShotListFloorPlanCameraVisibilityToggledEvent extends OcptShotListEvent {
  /// The id of the camera symbol whose visibility is toggled.
  final String symbolId;

  /// Class constructor
  const OcptShotListFloorPlanCameraVisibilityToggledEvent({required this.symbolId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Toggles the onion skin's own previous (`event.isPrevious`) or next neighbour, dispatched by the
/// tray's own `Onion skin` block. A view preference.
class OcptShotListFloorPlanOnionSkinToggledEvent extends OcptShotListEvent {
  /// Whether the previous shot's own ghost is toggled (true) or the next shot's (false).
  final bool isPrevious;

  /// Class constructor
  const OcptShotListFloorPlanOnionSkinToggledEvent({required this.isPrevious});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, isPrevious];
}

/// Sets the onion skin's own ghost opacity, dispatched by the tray's own `Onion skin` block slider.
/// A view preference.
class OcptShotListFloorPlanOnionSkinOpacityChangedEvent extends OcptShotListEvent {
  /// The new opacity, 0..1.
  final double opacity;

  /// Class constructor
  const OcptShotListFloorPlanOnionSkinOpacityChangedEvent({required this.opacity});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, opacity];
}

/// Toggles the metrics overlay, dispatched by the tray's own metrics toggle. A view preference.
class OcptShotListFloorPlanMetricsToggledEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListFloorPlanMetricsToggledEvent();
}

/// Records a tap on symbol `event.symbolId` while the canvas's own `arrow` tool is active,
/// dispatched by a symbol's own hit overlay.
///
/// One event backs the whole two-click interaction, the bloc rather than the widget deciding what
/// a click means — mirroring `OcptShotListCoverageWordClickedEvent`'s own three-state shape: with
/// no anchor pending, the tap picks `event.symbolId` as the arrow's first end; with an anchor
/// already pending and `event.symbolId` naming a different symbol, the tap completes a movement
/// arrow from the anchor to it (`OcptFloorPlanService.addArrow`, on the focused shot) and clears
/// the anchor; a tap on the anchor symbol itself is a no-op.
class OcptShotListFloorPlanArrowSymbolTappedEvent extends OcptShotListEvent {
  /// The id of the symbol tapped.
  final String symbolId;

  /// Class constructor
  const OcptShotListFloorPlanArrowSymbolTappedEvent({required this.symbolId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Cancels the arrow tool's own pending anchor, dispatched by `Escape` (only while an anchor is
/// pending) or a click on empty canvas while the anchor tool is on — mirroring
/// `OcptShotListCoverageAnchorCancelledEvent`.
class OcptShotListFloorPlanArrowAnchorCancelledEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListFloorPlanArrowAnchorCancelledEvent();
}

/// Requests deleting arrow `event.arrowId` for good, dispatched once the Placements group's own
/// remove action has already been confirmed through `OcptConfirmDialog`, by the mode.
class OcptShotListFloorPlanArrowDeletionRequestedEvent extends OcptShotListEvent {
  /// The id of the arrow to delete.
  final String arrowId;

  /// Class constructor
  const OcptShotListFloorPlanArrowDeletionRequestedEvent({required this.arrowId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, arrowId];
}

/// Records the raw text just typed into symbol `event.symbolId`'s own label, dispatched by the
/// canvas's own `label` tool inline text field on every keystroke. Rides the mode's field-edit
/// autosave debounce, keyed by `OcptShotListSymbolLabelEditKey`.
class OcptShotListFloorPlanSymbolLabelChangedEvent extends OcptShotListEvent {
  /// The id of the symbol whose label was edited.
  final String symbolId;

  /// The label's raw text, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptShotListFloorPlanSymbolLabelChangedEvent({
    required this.symbolId,
    required this.rawValue,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, rawValue];
}
