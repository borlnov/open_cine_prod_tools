// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_collision_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_panel_size.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

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

/// A transient notice, produced by `OcptShotListBloc`, reporting the outcome of an export, shown
/// as a SnackBar then dismissed.
///
/// Modelled on the screenplay editor's own `OcptEditorIoNotice`, and deliberately kept apart from
/// [OcptShotListState.hasWriteError]: a failed export leaves the project untouched and says
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

  /// Object properties
  @override
  List<Object?> get props => [kind, path, wasShared];
}

/// The state of `OcptShotListBloc`.
///
/// Unlike the screenplay editor's own state, this one carries no single dirty/saving pair: most
/// of a shot's fields (status, a difficulty axis, a character chip) write straight to the project
/// database the moment they change. [pendingFieldEdits] is the exception — the inspector's typed
/// free-text fields go through a 2 s autosave debounce of their own, so a field can be "dirty" in
/// that narrow sense while nothing else in this state is.
class OcptShotListState extends BlocStateForMixin<OcptShotListState>
    with
        MixinOcptProjectVersionsState<OcptShotListState>,
        MixinOcptProjectPackageState<OcptShotListState> {
  /// Whether the shot list is still being loaded from the project database.
  final bool isLoading;

  /// The title shown in the toolbar: the name of the project currently open.
  final String title;

  /// The whole shot list as last read from the project database, or null while nothing has been
  /// loaded yet.
  final OcptShotListSnapshot? snapshot;

  /// The page setup the screenplay is typeset with, as last loaded by the bloc.
  ///
  /// The shot list itself never prints anything; this is what the scenario coverage dialog's
  /// simulated paper sheet is laid out with, so the sequence it shows reads exactly like the same
  /// text does in the screenplay mode's own preview (`OcptPageSetup.toMetrics` being the single
  /// entry point both go through).
  final OcptPageSetup pageSetup;

  /// The screenplay's Fountain text, as last loaded by the bloc.
  ///
  /// Every scene's own text is sliced out of this string using
  /// `OcptSceneShotSequence.charStart`/`charEnd`: [buildSelectedCoverageLayout] is what does that
  /// slicing for the selected sequence, and `OcptShotCoverageService.markAsChecked` needs the
  /// whole string rather than a single scene's slice (see `OcptShotListBloc`'s own doc comment on
  /// its `Mark as checked` handler).
  final String screenplayText;

  /// The [OcptShotSequence.id] of the sequence currently selected, or null while none is (an
  /// empty screenplay has no sequence to select in the first place).
  final String? selectedSequenceId;

  /// The id of the shot currently selected, or null while none is.
  ///
  /// Always a shot of [selectedSequence] while both are set: selecting a shot selects its
  /// sequence too, and selecting another sequence clears the shot.
  final String? selectedShotId;

  /// Which of the mode's centre views is currently shown, persisted through
  /// `OcptPropertiesManager.shotListLastCentreView`. The switch offering it is
  /// `OcptShotListCentreHeader`; a compact width shows the table regardless of this value (see
  /// `OcptShotListState.isBoardShown` on the mode side — the mode itself decides that, this state
  /// only ever carries what the user last picked).
  final OcptShotListCentreView centreView;

  /// The whole storyboard of the selected episode's screenplay, as last read by
  /// `OcptStoryboardService.loadStoryboard`, or null while nothing has been loaded yet. Reloaded
  /// after every write a board affordance makes (importing, replacing, reordering or deleting a
  /// panel, flushing a pending comment edit).
  final OcptStoryboardSnapshot? storyboardSnapshot;

  /// The id of the panel currently selected on the board, or null while none is.
  ///
  /// Cleared whenever [selectedShotId] or [selectedSequenceId] changes: a panel only ever belongs
  /// to the shot currently shown, exactly as `OcptFloorPlanState.selectedSymbolId` (M5/M6) will be
  /// cleared the same way.
  final String? selectedPanelId;

  /// The common height every panel frame of the board's strips is drawn at, picked from the
  /// header's own `Panel size ▾` menu.
  ///
  /// A **view preference** held here for the session alone, never persisted to the project or to
  /// `OcptPropertiesManager` — see [OcptStoryboardPanelSize]'s own doc comment.
  final OcptStoryboardPanelSize boardPanelSize;

  /// The board's active annotation editing tool, or null while none is on.
  ///
  /// A **view/session state** value, like [boardPanelSize]: never written to the project. Scoped
  /// to the currently selected panel, so it is cleared — together with [selectedAnnotationId] —
  /// whenever [selectedPanelId], [selectedShotId] or [selectedSequenceId] changes: a tool left on
  /// while looking at a different panel would draw onto a frame the user can no longer see is the
  /// target.
  final OcptStoryboardAnnotationTool? activeAnnotationTool;

  /// The id of the currently selected mark, or null while none is.
  ///
  /// Cleared alongside [activeAnnotationTool] — see its own doc comment — and whenever the mark
  /// itself is deleted.
  final String? selectedAnnotationId;

  /// The whole floor plans of the selected episode's screenplay, as last read by
  /// `OcptFloorPlanService.loadFloorPlans`, or null while nothing has been loaded yet. Reloaded
  /// after every write a floor plans affordance makes (a set's own CRUD, placing/moving/resizing a
  /// symbol, the underlay's own CRUD).
  final OcptFloorPlanSnapshot? floorPlanSnapshot;

  /// The id of the set currently shown on the floor plans view, or null while none is (no set
  /// exists yet for the selected sequence, or the selected sequence is the orphan group, which has
  /// no scene to hold one).
  ///
  /// Cleared whenever [selectedSequenceId] changes: a set only ever belongs to the sequence
  /// currently shown.
  final String? selectedSetId;

  /// The id of the symbol currently selected on the floor plans canvas, or null while none is.
  ///
  /// Cleared whenever [selectedSetId] or [selectedSequenceId] changes: a symbol only ever belongs
  /// to the set currently shown. Mutually exclusive with [selectedFloorPlanArrowId]: selecting one
  /// clears the other.
  final String? selectedFloorPlanSymbolId;

  /// The id of the arrow currently selected on the floor plans canvas, or null while none is —
  /// what draws its own bendable midpoint handle (R2). Mutually exclusive with
  /// [selectedFloorPlanSymbolId] and cleared on every occasion that field is: a different set or
  /// sequence shown, the shot deleted, the arrow itself deleted.
  final String? selectedFloorPlanArrowId;

  /// The id of a character symbol just placed by [OcptFloorPlanTool.character], asking
  /// `OcptFloorPlanCharacterNamePickerDialog` to open for it, or null while none is pending — a
  /// one-shot trigger read by the mode's own `BlocConsumer` listener exactly like
  /// [projectPackagePendingExport] is, and cleared the moment that listener opens the dialog so a
  /// later emission never stacks a second one behind it.
  final String? pendingCharacterNamePromptSymbolId;

  /// The floor plans canvas's own current zoom (1.0 = neutral/100%), last **settled** by
  /// `OcptFloorPlanViewportController` — see that class's own doc comment for why only the settled
  /// value, not every per-frame one, ever reaches this state.
  ///
  /// A **view preference** held here for the session alone, never persisted to the project or to
  /// `OcptPropertiesManager` (`docs/adr/0031-storyboard-panels-and-floor-plans-in-metres.md`: zoom
  /// is a view concern, kept out of the synchronised model). It exists in this state at all only so
  /// a fresh `OcptFloorPlanView` (built again after switching centre views, or after leaving and
  /// reopening the mode) resumes at the zoom the user last settled on rather than always resetting
  /// to 100%.
  final double floorPlanZoom;

  /// The floor plans canvas's own currently active tool, picked from the tool bar.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final OcptFloorPlanTool floorPlanActiveTool;

  /// The sequence layer a placed set element lands on, picked from the tray's own sequence layers
  /// group. Always one of the three sequence-scoped layers
  /// (`OcptFloorPlanLayerScope.isSequenceScoped`): the tray only ever offers those three rows in
  /// this milestone (the shot layers group is M6).
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final OcptFloorPlanLayer floorPlanActiveLayer;

  /// The sequence layers currently hidden on the floor plans canvas, out of the tray's own three
  /// rows. Empty means every sequence layer is shown — the tray's own default.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final Set<OcptFloorPlanLayer> floorPlanHiddenLayers;

  /// Whether the selected set's underlay is currently hidden on the floor plans canvas, toggled
  /// by the tray's own underlay row.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final bool isFloorPlanUnderlayHidden;

  /// The ids of every camera symbol currently hidden on the floor plans canvas, out of every live
  /// camera of the selected sequence — the tray's own per-camera eyes, under the `Sequence` focus's
  /// expanded cameras row. Empty means every camera is shown.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final Set<String> floorPlanHiddenCameraSymbolIds;

  /// Whether the onion skin's own previous-shot ghost is shown, under a shot focus.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final bool isFloorPlanOnionSkinPreviousShown;

  /// Whether the onion skin's own next-shot ghost is shown, under a shot focus.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final bool isFloorPlanOnionSkinNextShown;

  /// The onion skin's own ghost opacity, 0..1, the tray's own `Onion skin` block slider.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final double floorPlanOnionSkinOpacity;

  /// Whether the metrics overlay is shown, the tray's own metrics toggle: the distance from the
  /// selected symbol to every other visible symbol of the set, and camera-to-subject for a
  /// selected camera.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final bool isFloorPlanMetricsShown;

  /// The id of the symbol picked as the arrow tool's own first end, or null while none is pending
  /// (no click yet, or the anchor was just completed into an arrow or cancelled) — the floor plans
  /// canvas's own pending anchor, mirroring [pendingCoverageAnchor]'s own shape. Cleared whenever
  /// [selectedShotId], [selectedSequenceId] or [selectedSetId] changes, and whenever
  /// [floorPlanActiveTool] is picked away from [OcptFloorPlanTool.arrow].
  final String? pendingFloorPlanArrowAnchorSymbolId;

  /// Whether the left (sequences) dock is shown.
  final bool isSequencePanelVisible;

  /// The right dock's currently active tab, or null if the dock is closed.
  final OcptShotListRightDockTab? rightDockTab;

  /// The tab the right dock last showed, kept even while the dock is closed so the toolbar's own
  /// right dock toggle can reopen it where the user left it.
  ///
  /// Unlike [rightDockTab] this never goes back to null, and unlike the screenplay editor's own
  /// equivalent it is persisted, through `OcptPropertiesManager.shotListLastRightDockTab`.
  final OcptShotListRightDockTab lastRightDockTab;

  /// The left (sequences) dock's width, as a fraction of the mode's content row width.
  ///
  /// Persisted through `OcptPropertiesManager.shotListLeftDockFraction`, loaded once on entry and
  /// updated (debounced to the end of a drag, never per-frame) on every resize.
  final double leftDockFraction;

  /// The right (inspector) dock's width, as a fraction of the mode's content row width.
  ///
  /// Persisted through `OcptPropertiesManager.shotListRightDockFraction`, loaded once on entry
  /// and updated (debounced to the end of a drag, never per-frame) on every resize.
  final double rightDockFraction;

  /// The optional table columns currently shown, out of every [OcptShotListColumn].
  ///
  /// Persisted through `OcptPropertiesManager.shotListVisibleColumns`, loaded once on entry and
  /// updated on every toggle of the `Columns ▾` menu.
  final Set<OcptShotListColumn> visibleColumns;

  /// Whether the last write to the project database failed; shown as a transient SnackBar then
  /// dismissed.
  final bool hasWriteError;

  /// The outcome of the last shot list export, or null while there is nothing to report; shown as
  /// a transient SnackBar then dismissed.
  final OcptShotListIoNotice? ioNotice;

  /// The screenplay's whole cast — the speaking roles and the characters introduced in capitals in
  /// an action line alike, see `fountain_kit`'s `screenplayCharactersOf` — normalised through
  /// `normalizeCharacterName` and in first-appearance order, as parsed once on entry.
  ///
  /// Kept for `OcptShotListBloc`'s own internal use resolving a scenario coverage range's covered
  /// text onto [roles] (`_attachCharactersCoveredBy`) rather than for display any more: the
  /// inspector's character chips are built from [roles], the production's whole cast, not from this
  /// screenplay-only list (`OcptShotCharacterChips`).
  final List<String> screenplayCharacters;

  /// The production's whole cast — every live role, in `sortKey` order — as last read by
  /// `OcptRoleIndexService.loadRoles`: what the inspector's character chips are built from
  /// (`OcptShotCharacterChips`), and what [orphanedRoleAlerts] and [roleCollisionAlerts] are derived
  /// from.
  final List<OcptRole> roles;

  /// The selected episode's own suggestion lists the inspector's free-text fields with suggestions
  /// read from, reloaded after every field-edit flush.
  final OcptShotFieldSuggestions suggestions;

  /// Every field edit currently sitting in the field-edit autosave debounce, keyed by
  /// [OcptShotListPendingEditKey] (a shot's own field, or a board panel's comment), holding the raw
  /// text last typed for it.
  ///
  /// What a field or a panel comment shows takes this map's entry over its own stored value
  /// whenever one is present, so typing is never overwritten by a reload triggered by an unrelated
  /// write (another field's own flush, a status change on a different shot). An entry is removed
  /// the moment its write lands, whether through the debounce elapsing or an explicit flush.
  final Map<OcptShotListPendingEditKey, String> pendingFieldEdits;

  /// The first word clicked of a scenario coverage range currently being drawn in the coverage
  /// dialog, or null while none is being drawn (no click yet, or the range was just closed or
  /// removed).
  ///
  /// Its two fields are the anchor word's own scene-relative `OcptScriptWord` offsets, which
  /// identify it on their own — a range may span several blocks, so the block a click lands in
  /// never takes part in the decision. Cleared whenever the selected shot or sequence changes, and
  /// after every coverage write (see `OcptShotListBloc`'s own doc comment on its coverage
  /// word-click handler for the full three-state interaction this backs).
  final ({int wordStartOffset, int wordEndOffset})? pendingCoverageAnchor;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.projectVersions}
  @override
  final List<OcptProjectVersion> projectVersions;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.previewedVersionId}
  @override
  final String? previewedVersionId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.workingCopy}
  @override
  final OcptProjectWorkingCopyState? workingCopy;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.versionPendingDeletionId}
  @override
  final String? versionPendingDeletionId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.versionPendingRestoreId}
  @override
  final String? versionPendingRestoreId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.versionPendingRenameId}
  @override
  final String? versionPendingRenameId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.projectVersionNotice}
  @override
  final OcptProjectVersionNoticeKind? projectVersionNotice;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.projectPackagePendingExport}
  @override
  final OcptProjectPackagePreflight? projectPackagePendingExport;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.projectPackageNotice}
  @override
  final OcptProjectPackageNotice? projectPackageNotice;

  /// Every sequence of [snapshot], in display order (empty while nothing is loaded).
  List<OcptShotSequence> get sequences => snapshot?.sequences ?? const [];

  /// The sequence [selectedSequenceId] identifies, or null if none is selected (or the selected
  /// one disappeared from a freshly loaded [snapshot]).
  OcptShotSequence? get selectedSequence {
    final selectedSequenceId = this.selectedSequenceId;
    if (selectedSequenceId == null) {
      return null;
    }

    for (final sequence in sequences) {
      if (sequence.id == selectedSequenceId) {
        return sequence;
      }
    }

    return null;
  }

  /// The shot [selectedShotId] identifies, or null if none is selected (or the selected one
  /// disappeared from a freshly loaded [snapshot]).
  OcptShot? get selectedShot {
    final selectedShotId = this.selectedShotId;
    return selectedShotId == null ? null : snapshot?.shotsById[selectedShotId];
  }

  /// [shotId]'s own panels, in order, or an empty list while [storyboardSnapshot] hasn't loaded yet
  /// or the shot has none.
  List<OcptStoryboardPanel> panelsOfShot(String shotId) =>
      storyboardSnapshot?.panelsOfShot(shotId) ?? const [];

  /// The selected shot's own panels, or an empty list while no shot is selected.
  List<OcptStoryboardPanel> get panelsOfSelectedShot {
    final selectedShotId = this.selectedShotId;
    return selectedShotId == null ? const [] : panelsOfShot(selectedShotId);
  }

  /// The panel [selectedPanelId] identifies, or null if none is selected (or the selected one
  /// disappeared from a freshly loaded [storyboardSnapshot]).
  OcptStoryboardPanel? get selectedPanel {
    final selectedPanelId = this.selectedPanelId;
    if (selectedPanelId == null) {
      return null;
    }
    for (final panel in panelsOfSelectedShot) {
      if (panel.id == selectedPanelId) {
        return panel;
      }
    }
    return null;
  }

  /// Whether any live shot of the screenplay holds at least one storyboard panel — what the
  /// export panel's storyboard card checks to decide whether it has anything to print
  /// (`docs/plans/storyboard.md`, §5): a shot list can hold shots without holding a single panel,
  /// which is a state of its own, not the same as holding no shot at all.
  bool get hasAnyStoryboardPanel =>
      storyboardSnapshot?.panelsByShotId.values.any((panels) => panels.isNotEmpty) ?? false;

  /// The selected sequence's own floor plan sets, in tab order, or an empty list while
  /// [floorPlanSnapshot] hasn't loaded yet, no sequence is selected, or the selected sequence is
  /// the orphan group (which has no scene, so it can never hold a set).
  List<OcptFloorPlanSet> get setsOfSelectedSequence {
    final sequence = selectedSequence;
    if (floorPlanSnapshot == null || sequence is! OcptSceneShotSequence) {
      return const [];
    }
    return floorPlanSnapshot!.setsOfScene(sequence.sceneId);
  }

  /// Whether any live floor plan set of the screenplay holds at least one camera symbol, on any
  /// shot — what the export panel's floor plans card checks to decide whether it has anything to
  /// print (`docs/plans/storyboard.md`, §5).
  bool get hasAnyFloorPlanCamera =>
      floorPlanSnapshot?.setsById.values.any(
        (floorPlanSet) =>
            floorPlanSet.symbols.any((symbol) => symbol.layer == OcptFloorPlanLayer.cameras),
      ) ??
      false;

  /// The set [selectedSetId] identifies, or null if none is selected (or the selected one
  /// disappeared from a freshly loaded [floorPlanSnapshot]).
  OcptFloorPlanSet? get selectedSet {
    final selectedSetId = this.selectedSetId;
    if (selectedSetId == null) {
      return null;
    }
    for (final floorPlanSet in setsOfSelectedSequence) {
      if (floorPlanSet.id == selectedSetId) {
        return floorPlanSet;
      }
    }
    return null;
  }

  /// The symbol [selectedFloorPlanSymbolId] identifies among [selectedSet]'s own symbols, or null
  /// if none is selected (or the selected one disappeared from a freshly loaded
  /// [floorPlanSnapshot]).
  OcptFloorPlanSymbol? get selectedFloorPlanSymbol {
    final selectedFloorPlanSymbolId = this.selectedFloorPlanSymbolId;
    final selectedSet = this.selectedSet;
    if (selectedFloorPlanSymbolId == null || selectedSet == null) {
      return null;
    }
    for (final symbol in selectedSet.symbols) {
      if (symbol.id == selectedFloorPlanSymbolId) {
        return symbol;
      }
    }
    return null;
  }

  /// The floor plans view's own focus — **derived, never a second field**
  /// (`docs/plans/storyboard.md`, §4.3): `true` while a shot is selected (the shot focus), `false`
  /// while none is (the `Sequence` focus). Every floor plans widget that needs to know which of the
  /// two is showing reads this rather than [selectedShotId] directly, so the one rule ("no shot
  /// selected means the sequence focus") lives in exactly one place.
  bool get isFloorPlanShotFocusActive => selectedShotId != null;

  /// The selected sequence's own shot immediately before [selectedShotId], or null while none is
  /// selected, it is the sequence's first shot, or the selected sequence is the orphan group (no
  /// floor plan set can ever belong to it) — the onion skin's own previous-shot ghost.
  OcptShot? get previousShotOfSelectedShot => _neighbourShotOf(-1);

  /// The selected sequence's own shot immediately after [selectedShotId]. See
  /// [previousShotOfSelectedShot].
  OcptShot? get nextShotOfSelectedShot => _neighbourShotOf(1);

  /// [selectedShotId]'s own neighbour [offset] shots away in the selected sequence's own shot
  /// order, or null while there is none (out of range, nothing selected, or the orphan group) — the
  /// body [previousShotOfSelectedShot]/[nextShotOfSelectedShot] share.
  OcptShot? _neighbourShotOf(int offset) {
    final sequence = selectedSequence;
    final selectedShotId = this.selectedShotId;
    if (selectedShotId == null || sequence is! OcptSceneShotSequence) {
      return null;
    }

    final shots = sequence.shots;
    final index = shots.indexWhere((shot) => shot.id == selectedShotId);
    final neighbourIndex = index + offset;
    if (index < 0 || neighbourIndex < 0 || neighbourIndex >= shots.length) {
      return null;
    }
    return shots[neighbourIndex];
  }

  /// The total number of live panels across every shot of the selected sequence — the board
  /// header's own `· N panels` read-out.
  int get boardPanelCountOfSelectedSequence {
    final sequence = selectedSequence;
    if (sequence == null) {
      return 0;
    }
    return sequence.shots.fold(0, (total, shot) => total + panelsOfShot(shot.id).length);
  }

  /// The total number of shots across every sequence, orphan group included.
  int get totalShotCount => snapshot?.totalShotCount ?? 0;

  /// The number of sequences the shot list holds, orphan group included: the status bar's first
  /// counter.
  int get sequenceCount => sequences.length;

  /// The number of shots already filmed across every sequence, orphan group included.
  int get filmedShotCount =>
      snapshot?.shotsById.values.where((shot) => shot.status == OcptShotStatus.shot).length ?? 0;

  /// The number of shots currently flagged as needing checking, across every sequence.
  int get shotsToCheckCount =>
      snapshot?.shotsById.values.where((shot) => shot.needsCheck).length ?? 0;

  /// One alert per orphaned role of [roles] — the screenplay no longer names it, but its casting
  /// and notes are kept — the orphaned variant of the shared role alert banner, shown above the shot
  /// table (ADR 0030, decision 4).
  ///
  /// Derived on demand from [roles], like [otherShotsCoverageOfSelectedScene] and
  /// [buildSelectedCoverageLayout] are, rather than stored: it is already in memory, and computing
  /// it here is what keeps it impossible for a banner to survive the write that resolved it.
  List<OcptRemovedRoleAlert> get orphanedRoleAlerts => OcptRemovedRoleAlert.buildAll(roles);

  /// One alert per hand-added role sharing a name with a live screenplay role — the collision
  /// variant of the shared role alert banner (ADR 0030, decision 2). Derived the same way
  /// [orphanedRoleAlerts] is.
  List<OcptRoleCollisionAlert> get roleCollisionAlerts => OcptRoleCollisionAlert.buildAll(roles);

  /// The roles [alert]'s own role can be merged into: every live, `isFromScreenplay` role of
  /// [roles] that isn't itself orphaned and isn't [alert]'s own — the orphaned banner's `Merge
  /// with:` chips.
  List<OcptRole> mergeTargetsOf(OcptRemovedRoleAlert alert) => [
    for (final role in roles)
      if (role.isFromScreenplay && role.orphanedName == null && role.id != alert.roleId) role,
  ];

  /// Builds the scenario coverage layout of the selected shot's scene, or null when no shot is
  /// selected, none is (or the selected sequence is the orphan group: an orphaned shot's scene
  /// text is gone, so there is nothing left to lay out).
  ///
  /// Rebuilt on demand every time this is called, rather than cached in the state: laying a
  /// scene's few hundred characters out is cheap, and caching it here would only mean
  /// invalidating it by hand on every snapshot or [screenplayText] reload instead of simply
  /// calling this again.
  OcptScriptWordLayout? buildSelectedCoverageLayout() {
    final sequence = selectedSequence;
    if (selectedShot == null || sequence is! OcptSceneShotSequence) {
      return null;
    }

    return OcptScriptWordLayout.of(
      sceneId: sequence.sceneId,
      sceneText: screenplayText.substring(sequence.charStart, sequence.charEnd),
    );
  }

  /// Every shot other than the selected one that has a scenario coverage range of the selected
  /// scene, keyed by that shot's [OcptShot.code], in code order, skipping a shot with no range of
  /// this scene at all: the inspector's "also covered by" wash.
  ///
  /// Derived from [snapshot], already held in memory, rather than through
  /// `OcptShotCoverageService.shotIdsCoveringRange`: the snapshot already carries every shot's own
  /// ranges, so querying the database for each block rendered would mean an async call inside a
  /// build. Empty when no shot is selected or the selected sequence is the orphan group.
  Map<String, List<OcptShotCoverageRange>> otherShotsCoverageOfSelectedScene() {
    final sequence = selectedSequence;
    final selectedShotId = this.selectedShotId;
    if (selectedShotId == null || sequence is! OcptSceneShotSequence) {
      return const {};
    }

    final entries = <MapEntry<String, List<OcptShotCoverageRange>>>[];
    for (final shot in snapshot?.shotsById.values ?? const <OcptShot>[]) {
      if (shot.id == selectedShotId) {
        continue;
      }
      final ranges = shot.coverageRanges
          .where((range) => range.sceneId == sequence.sceneId)
          .toList(growable: false);
      if (ranges.isNotEmpty) {
        entries.add(MapEntry(shot.code, ranges));
      }
    }
    entries.sort((a, b) => a.key.compareTo(b.key));

    return {for (final entry in entries) entry.key: entry.value};
  }

  /// The selected shot's own coverage ranges of [layout]'s scene that currently disagree with its
  /// current text, decided range by range through `OcptShotCoverageService.isRangeStale` rather
  /// than through the coarser, shot-wide `OcptShotCoverageRange.isStale` (which mirrors the whole
  /// shot's `needsCheck` flag): this is what lets the inspector's `modified` badge mark exactly
  /// the blocks whose covered text actually changed.
  Set<String> staleCoverageRangeIdsOfSelectedShot(OcptScriptWordLayout layout) {
    final shot = selectedShot;
    if (shot == null) {
      return const {};
    }

    return {
      for (final range in shot.coverageRanges)
        if (range.sceneId == layout.sceneId &&
            OcptShotCoverageService.isRangeStale(range: range, sceneText: layout.sceneText))
          range.id,
    };
  }

  /// Class constructor
  const OcptShotListState({
    required this.isLoading,
    required this.title,
    required this.snapshot,
    required this.pageSetup,
    required this.screenplayText,
    required this.selectedSequenceId,
    required this.selectedShotId,
    required this.centreView,
    required this.storyboardSnapshot,
    required this.selectedPanelId,
    required this.boardPanelSize,
    required this.activeAnnotationTool,
    required this.selectedAnnotationId,
    required this.floorPlanSnapshot,
    required this.selectedSetId,
    required this.selectedFloorPlanSymbolId,
    required this.selectedFloorPlanArrowId,
    required this.pendingCharacterNamePromptSymbolId,
    required this.floorPlanZoom,
    required this.floorPlanActiveTool,
    required this.floorPlanActiveLayer,
    required this.floorPlanHiddenLayers,
    required this.isFloorPlanUnderlayHidden,
    required this.floorPlanHiddenCameraSymbolIds,
    required this.isFloorPlanOnionSkinPreviousShown,
    required this.isFloorPlanOnionSkinNextShown,
    required this.floorPlanOnionSkinOpacity,
    required this.isFloorPlanMetricsShown,
    required this.pendingFloorPlanArrowAnchorSymbolId,
    required this.isSequencePanelVisible,
    required this.rightDockTab,
    required this.lastRightDockTab,
    required this.leftDockFraction,
    required this.rightDockFraction,
    required this.visibleColumns,
    required this.hasWriteError,
    required this.ioNotice,
    required this.screenplayCharacters,
    required this.roles,
    required this.suggestions,
    required this.pendingFieldEdits,
    required this.pendingCoverageAnchor,
    required this.projectVersions,
    required this.previewedVersionId,
    required this.workingCopy,
    required this.versionPendingDeletionId,
    required this.versionPendingRestoreId,
    required this.versionPendingRenameId,
    required this.projectVersionNotice,
    required this.projectPackagePendingExport,
    required this.projectPackageNotice,
  });

  /// Init class constructor
  OcptShotListState.init()
    : isLoading = true,
      title = "",
      snapshot = null,
      pageSetup = const OcptPageSetup.standard(),
      screenplayText = "",
      selectedSequenceId = null,
      selectedShotId = null,
      centreView = OcptShotListCentreView.table,
      storyboardSnapshot = null,
      selectedPanelId = null,
      boardPanelSize = OcptStoryboardPanelSize.medium,
      activeAnnotationTool = null,
      selectedAnnotationId = null,
      floorPlanSnapshot = null,
      selectedSetId = null,
      selectedFloorPlanSymbolId = null,
      selectedFloorPlanArrowId = null,
      pendingCharacterNamePromptSymbolId = null,
      floorPlanZoom = 1,
      floorPlanActiveTool = OcptFloorPlanTool.select,
      floorPlanActiveLayer = OcptFloorPlanLayer.set,
      floorPlanHiddenLayers = const {},
      isFloorPlanUnderlayHidden = false,
      floorPlanHiddenCameraSymbolIds = const {},
      isFloorPlanOnionSkinPreviousShown = true,
      isFloorPlanOnionSkinNextShown = true,
      floorPlanOnionSkinOpacity = 0.4,
      isFloorPlanMetricsShown = false,
      pendingFloorPlanArrowAnchorSymbolId = null,
      isSequencePanelVisible = true,
      rightDockTab = null,
      lastRightDockTab = OcptShotListRightDockTab.inspector,
      leftDockFraction = OcptWorkspaceDock.leftDefaultFraction,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      visibleColumns = OcptShotListColumn.defaultVisibleColumns,
      hasWriteError = false,
      ioNotice = null,
      screenplayCharacters = const [],
      roles = const [],
      suggestions = const OcptShotFieldSuggestions.empty(),
      pendingFieldEdits = const {},
      pendingCoverageAnchor = null,
      projectVersions = const [],
      previewedVersionId = null,
      workingCopy = null,
      versionPendingDeletionId = null,
      versionPendingRestoreId = null,
      versionPendingRenameId = null,
      projectVersionNotice = null,
      projectPackagePendingExport = null,
      projectPackageNotice = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [snapshot] is only replaced when a new one is given: it never goes back to null once loaded,
  /// so it needs no clear flag. [selectedSequenceId], [selectedShotId], [selectedPanelId],
  /// [rightDockTab], [pendingCoverageAnchor] and [ioNotice] all legitimately go back to null while
  /// the mode is alive (nothing selected any more, the dock closed, no range being drawn, the
  /// export notice dismissed), so each has its own clear flag instead.
  @override
  OcptShotListState copyWith({
    bool? isLoading,
    String? title,
    OcptShotListSnapshot? snapshot,
    OcptPageSetup? pageSetup,
    String? screenplayText,
    String? selectedSequenceId,
    bool clearSelectedSequenceId = false,
    String? selectedShotId,
    bool clearSelectedShotId = false,
    OcptShotListCentreView? centreView,
    OcptStoryboardSnapshot? storyboardSnapshot,
    String? selectedPanelId,
    bool clearSelectedPanelId = false,
    OcptStoryboardPanelSize? boardPanelSize,
    OcptStoryboardAnnotationTool? activeAnnotationTool,
    bool clearActiveAnnotationTool = false,
    String? selectedAnnotationId,
    bool clearSelectedAnnotationId = false,
    OcptFloorPlanSnapshot? floorPlanSnapshot,
    String? selectedSetId,
    bool clearSelectedSetId = false,
    String? selectedFloorPlanSymbolId,
    bool clearSelectedFloorPlanSymbolId = false,
    String? selectedFloorPlanArrowId,
    bool clearSelectedFloorPlanArrowId = false,
    String? pendingCharacterNamePromptSymbolId,
    bool clearPendingCharacterNamePromptSymbolId = false,
    double? floorPlanZoom,
    OcptFloorPlanTool? floorPlanActiveTool,
    OcptFloorPlanLayer? floorPlanActiveLayer,
    Set<OcptFloorPlanLayer>? floorPlanHiddenLayers,
    bool? isFloorPlanUnderlayHidden,
    Set<String>? floorPlanHiddenCameraSymbolIds,
    bool? isFloorPlanOnionSkinPreviousShown,
    bool? isFloorPlanOnionSkinNextShown,
    double? floorPlanOnionSkinOpacity,
    bool? isFloorPlanMetricsShown,
    String? pendingFloorPlanArrowAnchorSymbolId,
    bool clearPendingFloorPlanArrowAnchorSymbolId = false,
    bool? isSequencePanelVisible,
    OcptShotListRightDockTab? rightDockTab,
    bool clearRightDockTab = false,
    OcptShotListRightDockTab? lastRightDockTab,
    double? leftDockFraction,
    double? rightDockFraction,
    Set<OcptShotListColumn>? visibleColumns,
    bool? hasWriteError,
    OcptShotListIoNotice? ioNotice,
    bool clearIoNotice = false,
    List<String>? screenplayCharacters,
    List<OcptRole>? roles,
    OcptShotFieldSuggestions? suggestions,
    Map<OcptShotListPendingEditKey, String>? pendingFieldEdits,
    ({int wordStartOffset, int wordEndOffset})? pendingCoverageAnchor,
    bool clearPendingCoverageAnchor = false,
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool clearPreviewedVersionId = false,
    OcptProjectWorkingCopyState? workingCopy,
    bool clearWorkingCopy = false,
    String? versionPendingDeletionId,
    bool clearVersionPendingDeletionId = false,
    String? versionPendingRestoreId,
    bool clearVersionPendingRestoreId = false,
    String? versionPendingRenameId,
    bool clearVersionPendingRenameId = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool clearProjectVersionNotice = false,
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool clearProjectPackagePendingExport = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool clearProjectPackageNotice = false,
  }) => OcptShotListState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    snapshot: snapshot ?? this.snapshot,
    pageSetup: pageSetup ?? this.pageSetup,
    screenplayText: screenplayText ?? this.screenplayText,
    selectedSequenceId: clearSelectedSequenceId
        ? null
        : (selectedSequenceId ?? this.selectedSequenceId),
    selectedShotId: clearSelectedShotId ? null : (selectedShotId ?? this.selectedShotId),
    centreView: centreView ?? this.centreView,
    storyboardSnapshot: storyboardSnapshot ?? this.storyboardSnapshot,
    selectedPanelId: clearSelectedPanelId ? null : (selectedPanelId ?? this.selectedPanelId),
    boardPanelSize: boardPanelSize ?? this.boardPanelSize,
    activeAnnotationTool: clearActiveAnnotationTool
        ? null
        : (activeAnnotationTool ?? this.activeAnnotationTool),
    selectedAnnotationId: clearSelectedAnnotationId
        ? null
        : (selectedAnnotationId ?? this.selectedAnnotationId),
    floorPlanSnapshot: floorPlanSnapshot ?? this.floorPlanSnapshot,
    selectedSetId: clearSelectedSetId ? null : (selectedSetId ?? this.selectedSetId),
    selectedFloorPlanSymbolId: clearSelectedFloorPlanSymbolId
        ? null
        : (selectedFloorPlanSymbolId ?? this.selectedFloorPlanSymbolId),
    selectedFloorPlanArrowId: clearSelectedFloorPlanArrowId
        ? null
        : (selectedFloorPlanArrowId ?? this.selectedFloorPlanArrowId),
    pendingCharacterNamePromptSymbolId: clearPendingCharacterNamePromptSymbolId
        ? null
        : (pendingCharacterNamePromptSymbolId ?? this.pendingCharacterNamePromptSymbolId),
    floorPlanZoom: floorPlanZoom ?? this.floorPlanZoom,
    floorPlanActiveTool: floorPlanActiveTool ?? this.floorPlanActiveTool,
    floorPlanActiveLayer: floorPlanActiveLayer ?? this.floorPlanActiveLayer,
    floorPlanHiddenLayers: floorPlanHiddenLayers ?? this.floorPlanHiddenLayers,
    isFloorPlanUnderlayHidden: isFloorPlanUnderlayHidden ?? this.isFloorPlanUnderlayHidden,
    floorPlanHiddenCameraSymbolIds:
        floorPlanHiddenCameraSymbolIds ?? this.floorPlanHiddenCameraSymbolIds,
    isFloorPlanOnionSkinPreviousShown:
        isFloorPlanOnionSkinPreviousShown ?? this.isFloorPlanOnionSkinPreviousShown,
    isFloorPlanOnionSkinNextShown:
        isFloorPlanOnionSkinNextShown ?? this.isFloorPlanOnionSkinNextShown,
    floorPlanOnionSkinOpacity: floorPlanOnionSkinOpacity ?? this.floorPlanOnionSkinOpacity,
    isFloorPlanMetricsShown: isFloorPlanMetricsShown ?? this.isFloorPlanMetricsShown,
    pendingFloorPlanArrowAnchorSymbolId: clearPendingFloorPlanArrowAnchorSymbolId
        ? null
        : (pendingFloorPlanArrowAnchorSymbolId ?? this.pendingFloorPlanArrowAnchorSymbolId),
    isSequencePanelVisible: isSequencePanelVisible ?? this.isSequencePanelVisible,
    rightDockTab: clearRightDockTab ? null : (rightDockTab ?? this.rightDockTab),
    lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
    leftDockFraction: leftDockFraction ?? this.leftDockFraction,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    visibleColumns: visibleColumns ?? this.visibleColumns,
    hasWriteError: hasWriteError ?? this.hasWriteError,
    ioNotice: clearIoNotice ? null : (ioNotice ?? this.ioNotice),
    screenplayCharacters: screenplayCharacters ?? this.screenplayCharacters,
    roles: roles ?? this.roles,
    suggestions: suggestions ?? this.suggestions,
    pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits,
    pendingCoverageAnchor: clearPendingCoverageAnchor
        ? null
        : (pendingCoverageAnchor ?? this.pendingCoverageAnchor),
    projectVersions: projectVersions ?? this.projectVersions,
    previewedVersionId: clearPreviewedVersionId
        ? null
        : (previewedVersionId ?? this.previewedVersionId),
    workingCopy: clearWorkingCopy ? null : (workingCopy ?? this.workingCopy),
    versionPendingDeletionId: clearVersionPendingDeletionId
        ? null
        : (versionPendingDeletionId ?? this.versionPendingDeletionId),
    versionPendingRestoreId: clearVersionPendingRestoreId
        ? null
        : (versionPendingRestoreId ?? this.versionPendingRestoreId),
    versionPendingRenameId: clearVersionPendingRenameId
        ? null
        : (versionPendingRenameId ?? this.versionPendingRenameId),
    projectVersionNotice: clearProjectVersionNotice
        ? null
        : (projectVersionNotice ?? this.projectVersionNotice),
    projectPackagePendingExport: clearProjectPackagePendingExport
        ? null
        : (projectPackagePendingExport ?? this.projectPackagePendingExport),
    projectPackageNotice: clearProjectPackageNotice
        ? null
        : (projectPackageNotice ?? this.projectPackageNotice),
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.copyProjectVersionsState}
  @override
  OcptShotListState copyProjectVersionsState({
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool clearPreviewedVersionId = false,
    OcptProjectWorkingCopyState? workingCopy,
    bool clearWorkingCopy = false,
    String? versionPendingDeletionId,
    bool clearVersionPendingDeletionId = false,
    String? versionPendingRestoreId,
    bool clearVersionPendingRestoreId = false,
    String? versionPendingRenameId,
    bool clearVersionPendingRenameId = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool clearProjectVersionNotice = false,
  }) => copyWith(
    projectVersions: projectVersions,
    previewedVersionId: previewedVersionId,
    clearPreviewedVersionId: clearPreviewedVersionId,
    workingCopy: workingCopy,
    clearWorkingCopy: clearWorkingCopy,
    versionPendingDeletionId: versionPendingDeletionId,
    clearVersionPendingDeletionId: clearVersionPendingDeletionId,
    versionPendingRestoreId: versionPendingRestoreId,
    clearVersionPendingRestoreId: clearVersionPendingRestoreId,
    versionPendingRenameId: versionPendingRenameId,
    clearVersionPendingRenameId: clearVersionPendingRenameId,
    projectVersionNotice: projectVersionNotice,
    clearProjectVersionNotice: clearProjectVersionNotice,
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.copyProjectPackageState}
  @override
  OcptShotListState copyProjectPackageState({
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool clearProjectPackagePendingExport = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool clearProjectPackageNotice = false,
  }) => copyWith(
    projectPackagePendingExport: projectPackagePendingExport,
    clearProjectPackagePendingExport: clearProjectPackagePendingExport,
    projectPackageNotice: projectPackageNotice,
    clearProjectPackageNotice: clearProjectPackageNotice,
  );

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    title,
    snapshot,
    pageSetup,
    screenplayText,
    selectedSequenceId,
    selectedShotId,
    centreView,
    storyboardSnapshot,
    selectedPanelId,
    boardPanelSize,
    activeAnnotationTool,
    selectedAnnotationId,
    floorPlanSnapshot,
    selectedSetId,
    selectedFloorPlanSymbolId,
    selectedFloorPlanArrowId,
    pendingCharacterNamePromptSymbolId,
    floorPlanZoom,
    floorPlanActiveTool,
    floorPlanActiveLayer,
    floorPlanHiddenLayers,
    isFloorPlanUnderlayHidden,
    floorPlanHiddenCameraSymbolIds,
    isFloorPlanOnionSkinPreviousShown,
    isFloorPlanOnionSkinNextShown,
    floorPlanOnionSkinOpacity,
    isFloorPlanMetricsShown,
    pendingFloorPlanArrowAnchorSymbolId,
    isSequencePanelVisible,
    rightDockTab,
    lastRightDockTab,
    leftDockFraction,
    rightDockFraction,
    visibleColumns,
    hasWriteError,
    ioNotice,
    screenplayCharacters,
    roles,
    suggestions,
    pendingFieldEdits,
    pendingCoverageAnchor,
  ];
}
