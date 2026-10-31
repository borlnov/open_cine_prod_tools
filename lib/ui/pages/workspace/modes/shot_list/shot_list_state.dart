// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_scope_decision.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_prop_summary.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_panel_size.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_io_notice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

export 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_io_notice.dart';
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state_derived.dart';

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
  /// `OcptSceneShotSequence.charStart`/`charEnd`: `buildSelectedCoverageLayout` is what does that
  /// slicing for the selected sequence, and `OcptShotCoverageService.markAsChecked` needs the
  /// whole string rather than a single scene's slice (see `OcptShotListBloc`'s own doc comment on
  /// its `Mark as checked` handler).
  final String screenplayText;

  /// The [OcptShotSequence.id] of the sequence currently selected, or null while none is (an
  /// empty screenplay has no sequence to select in the first place).
  final String? selectedSequenceId;

  /// The id of the shot currently selected, or null while none is.
  ///
  /// Always a shot of `selectedSequence` while both are set: selecting a shot selects its
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
  /// to the shot currently shown, exactly as [selectedFloorPlanSymbolId] is
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

  /// The project's whole Resources catalogue — every location and its own live sets, each
  /// carrying the scenes it is linked to — as last read by `OcptLocationsService.loadLocations`:
  /// the empty-state gallery's own catalogue, the `＋ Set`
  /// menu's own `Link an existing set ▸`/`Create a set ▸` groups, and what
  /// `ocptSceneSetSuggestionOf` reads to suggest one for the selected sequence's own heading.
  /// Project-wide, unlike [floorPlanSnapshot]'s own per-screenplay read.
  final List<OcptLocation> locations;

  /// The set-scope symbols of every live Resources set of the project, keyed by set id, as last
  /// read by `OcptFloorPlanService.loadSetScopeSymbolsByProjectSetId` — the empty-state gallery's
  /// own thumbnail content: a thumbnail draws a set's own
  /// décor alone, never what a sequence or a shot placed on it.
  final Map<String, List<OcptFloorPlanSymbol>> setScopeSymbolsBySetId;

  /// The id of the symbol currently selected on the floor plans canvas, or null while none is.
  ///
  /// Cleared whenever [selectedSetId] or [selectedSequenceId] changes: a symbol only ever belongs
  /// to the set currently shown. Mutually exclusive with [selectedFloorPlanArrowId]: selecting one
  /// clears the other.
  final String? selectedFloorPlanSymbolId;

  /// The id of the arrow currently selected on the floor plans canvas, or null while none is —
  /// what draws its own bendable midpoint handle. Mutually exclusive with
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

  /// The layer a placed set element lands on, picked from the palette's own set/scene group; the
  /// shot layers group is picked separately.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final OcptFloorPlanLayer floorPlanActiveLayer;

  /// The décor primitive a `setElement` click-to-arm placement carries — which of the palette's
  /// own four typed set-element entries (wall/door/furniture/freeform) was armed last.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final OcptFloorPlanSetElementShape floorPlanActiveSetElementShape;

  /// The scope a `setElement` click-to-arm placement lands at — the palette's own `Set`
  /// group arms [OcptFloorPlanScope.set], its `Sequence` group's own furniture/freeform pair arms
  /// [OcptFloorPlanScope.scene].
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final OcptFloorPlanScope floorPlanActiveSetElementScope;

  /// A `prop` click-to-arm placement's own armed label — which breakdown-prop chip, or the
  /// `Other…` chip's own typed-in text, was armed last.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final String floorPlanActiveLabel;

  /// The focused sequence's own breakdown props — the
  /// palette's own `Sequence` group chips. Reloaded whenever the selected sequence changes, and
  /// project-wide, unlike... nothing else in this state — it is this narrow read's own instance.
  final List<OcptScenePropSummary> propsOfSelectedSequence;

  /// A set-scope move, rotate or resize awaiting the scope bubble's own answer — set the
  /// instant such a gesture ends on a symbol whose own set is linked to two or more sequences, and
  /// cleared the moment the bubble is answered (`Every sequence`/`Only sequence n`/`Cancel`) or a
  /// click elsewhere dismisses it as `Cancel`. Null the rest of the time — every set-scope gesture
  /// on a set linked to one sequence alone is written straight away, exactly as before.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project (only what
  /// it resolves into is).
  final OcptFloorPlanScopeDecision? pendingFloorPlanScopeDecision;

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
  /// (`OcptShotCharacterChips`), and what `orphanedRoleAlerts` and `roleCollisionAlerts` are
  /// derived from.
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
    required this.locations,
    required this.setScopeSymbolsBySetId,
    required this.selectedFloorPlanSymbolId,
    required this.selectedFloorPlanArrowId,
    required this.pendingCharacterNamePromptSymbolId,
    required this.floorPlanZoom,
    required this.floorPlanActiveTool,
    required this.floorPlanActiveLayer,
    required this.floorPlanActiveSetElementShape,
    required this.floorPlanActiveSetElementScope,
    required this.floorPlanActiveLabel,
    required this.propsOfSelectedSequence,
    required this.pendingFloorPlanScopeDecision,
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
      locations = const [],
      setScopeSymbolsBySetId = const {},
      selectedFloorPlanSymbolId = null,
      selectedFloorPlanArrowId = null,
      pendingCharacterNamePromptSymbolId = null,
      floorPlanZoom = 1,
      floorPlanActiveTool = OcptFloorPlanTool.select,
      floorPlanActiveLayer = OcptFloorPlanLayer.set,
      floorPlanActiveSetElementShape = OcptFloorPlanSetElementShape.wall,
      floorPlanActiveSetElementScope = OcptFloorPlanScope.set,
      floorPlanActiveLabel = "",
      propsOfSelectedSequence = const [],
      pendingFloorPlanScopeDecision = null,
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
  /// so it needs no force flag. [selectedSequenceId], [selectedShotId], [selectedPanelId],
  /// [rightDockTab], [pendingCoverageAnchor] and [ioNotice] all legitimately go back to null while
  /// the mode is alive (nothing selected any more, the dock closed, no range being drawn, the
  /// export notice dismissed), so each has its own force flag instead.
  @override
  OcptShotListState copyWith({
    bool? isLoading,
    String? title,
    OcptShotListSnapshot? snapshot,
    bool forceSnapshotValue = false,
    OcptPageSetup? pageSetup,
    String? screenplayText,
    String? selectedSequenceId,
    bool forceSelectedSequenceIdValue = false,
    String? selectedShotId,
    bool forceSelectedShotIdValue = false,
    OcptShotListCentreView? centreView,
    OcptStoryboardSnapshot? storyboardSnapshot,
    bool forceStoryboardSnapshotValue = false,
    String? selectedPanelId,
    bool forceSelectedPanelIdValue = false,
    OcptStoryboardPanelSize? boardPanelSize,
    OcptStoryboardAnnotationTool? activeAnnotationTool,
    bool forceActiveAnnotationToolValue = false,
    String? selectedAnnotationId,
    bool forceSelectedAnnotationIdValue = false,
    OcptFloorPlanSnapshot? floorPlanSnapshot,
    bool forceFloorPlanSnapshotValue = false,
    String? selectedSetId,
    bool forceSelectedSetIdValue = false,
    List<OcptLocation>? locations,
    Map<String, List<OcptFloorPlanSymbol>>? setScopeSymbolsBySetId,
    String? selectedFloorPlanSymbolId,
    bool forceSelectedFloorPlanSymbolIdValue = false,
    String? selectedFloorPlanArrowId,
    bool forceSelectedFloorPlanArrowIdValue = false,
    String? pendingCharacterNamePromptSymbolId,
    bool forcePendingCharacterNamePromptSymbolIdValue = false,
    double? floorPlanZoom,
    OcptFloorPlanTool? floorPlanActiveTool,
    OcptFloorPlanLayer? floorPlanActiveLayer,
    OcptFloorPlanSetElementShape? floorPlanActiveSetElementShape,
    OcptFloorPlanScope? floorPlanActiveSetElementScope,
    String? floorPlanActiveLabel,
    List<OcptScenePropSummary>? propsOfSelectedSequence,
    OcptFloorPlanScopeDecision? pendingFloorPlanScopeDecision,
    bool forcePendingFloorPlanScopeDecisionValue = false,
    Set<OcptFloorPlanLayer>? floorPlanHiddenLayers,
    bool? isFloorPlanUnderlayHidden,
    Set<String>? floorPlanHiddenCameraSymbolIds,
    bool? isFloorPlanOnionSkinPreviousShown,
    bool? isFloorPlanOnionSkinNextShown,
    double? floorPlanOnionSkinOpacity,
    bool? isFloorPlanMetricsShown,
    String? pendingFloorPlanArrowAnchorSymbolId,
    bool forcePendingFloorPlanArrowAnchorSymbolIdValue = false,
    bool? isSequencePanelVisible,
    OcptShotListRightDockTab? rightDockTab,
    bool forceRightDockTabValue = false,
    OcptShotListRightDockTab? lastRightDockTab,
    double? leftDockFraction,
    double? rightDockFraction,
    Set<OcptShotListColumn>? visibleColumns,
    bool? hasWriteError,
    OcptShotListIoNotice? ioNotice,
    bool forceIoNoticeValue = false,
    List<String>? screenplayCharacters,
    List<OcptRole>? roles,
    OcptShotFieldSuggestions? suggestions,
    Map<OcptShotListPendingEditKey, String>? pendingFieldEdits,
    ({int wordStartOffset, int wordEndOffset})? pendingCoverageAnchor,
    bool forcePendingCoverageAnchorValue = false,
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool forcePreviewedVersionIdValue = false,
    OcptProjectWorkingCopyState? workingCopy,
    bool forceWorkingCopyValue = false,
    String? versionPendingDeletionId,
    bool forceVersionPendingDeletionIdValue = false,
    String? versionPendingRestoreId,
    bool forceVersionPendingRestoreIdValue = false,
    String? versionPendingRenameId,
    bool forceVersionPendingRenameIdValue = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool forceProjectVersionNoticeValue = false,
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool forceProjectPackagePendingExportValue = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool forceProjectPackageNoticeValue = false,
  }) => OcptShotListState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    snapshot: snapshot ?? (forceSnapshotValue ? null : this.snapshot),
    pageSetup: pageSetup ?? this.pageSetup,
    screenplayText: screenplayText ?? this.screenplayText,
    selectedSequenceId:
        selectedSequenceId ?? (forceSelectedSequenceIdValue ? null : this.selectedSequenceId),
    selectedShotId: selectedShotId ?? (forceSelectedShotIdValue ? null : this.selectedShotId),
    centreView: centreView ?? this.centreView,
    storyboardSnapshot:
        storyboardSnapshot ?? (forceStoryboardSnapshotValue ? null : this.storyboardSnapshot),
    selectedPanelId: selectedPanelId ?? (forceSelectedPanelIdValue ? null : this.selectedPanelId),
    boardPanelSize: boardPanelSize ?? this.boardPanelSize,
    activeAnnotationTool:
        activeAnnotationTool ?? (forceActiveAnnotationToolValue ? null : this.activeAnnotationTool),
    selectedAnnotationId:
        selectedAnnotationId ?? (forceSelectedAnnotationIdValue ? null : this.selectedAnnotationId),
    floorPlanSnapshot:
        floorPlanSnapshot ?? (forceFloorPlanSnapshotValue ? null : this.floorPlanSnapshot),
    selectedSetId: selectedSetId ?? (forceSelectedSetIdValue ? null : this.selectedSetId),
    locations: locations ?? this.locations,
    setScopeSymbolsBySetId: setScopeSymbolsBySetId ?? this.setScopeSymbolsBySetId,
    selectedFloorPlanSymbolId:
        selectedFloorPlanSymbolId ??
        (forceSelectedFloorPlanSymbolIdValue ? null : this.selectedFloorPlanSymbolId),
    selectedFloorPlanArrowId:
        selectedFloorPlanArrowId ??
        (forceSelectedFloorPlanArrowIdValue ? null : this.selectedFloorPlanArrowId),
    pendingCharacterNamePromptSymbolId:
        pendingCharacterNamePromptSymbolId ??
        (forcePendingCharacterNamePromptSymbolIdValue
            ? null
            : this.pendingCharacterNamePromptSymbolId),
    floorPlanZoom: floorPlanZoom ?? this.floorPlanZoom,
    floorPlanActiveTool: floorPlanActiveTool ?? this.floorPlanActiveTool,
    floorPlanActiveLayer: floorPlanActiveLayer ?? this.floorPlanActiveLayer,
    floorPlanActiveSetElementShape:
        floorPlanActiveSetElementShape ?? this.floorPlanActiveSetElementShape,
    floorPlanActiveSetElementScope:
        floorPlanActiveSetElementScope ?? this.floorPlanActiveSetElementScope,
    floorPlanActiveLabel: floorPlanActiveLabel ?? this.floorPlanActiveLabel,
    propsOfSelectedSequence: propsOfSelectedSequence ?? this.propsOfSelectedSequence,
    pendingFloorPlanScopeDecision:
        pendingFloorPlanScopeDecision ??
        (forcePendingFloorPlanScopeDecisionValue ? null : this.pendingFloorPlanScopeDecision),
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
    pendingFloorPlanArrowAnchorSymbolId:
        pendingFloorPlanArrowAnchorSymbolId ??
        (forcePendingFloorPlanArrowAnchorSymbolIdValue
            ? null
            : this.pendingFloorPlanArrowAnchorSymbolId),
    isSequencePanelVisible: isSequencePanelVisible ?? this.isSequencePanelVisible,
    rightDockTab: rightDockTab ?? (forceRightDockTabValue ? null : this.rightDockTab),
    lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
    leftDockFraction: leftDockFraction ?? this.leftDockFraction,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    visibleColumns: visibleColumns ?? this.visibleColumns,
    hasWriteError: hasWriteError ?? this.hasWriteError,
    ioNotice: ioNotice ?? (forceIoNoticeValue ? null : this.ioNotice),
    screenplayCharacters: screenplayCharacters ?? this.screenplayCharacters,
    roles: roles ?? this.roles,
    suggestions: suggestions ?? this.suggestions,
    pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits,
    pendingCoverageAnchor:
        pendingCoverageAnchor ??
        (forcePendingCoverageAnchorValue ? null : this.pendingCoverageAnchor),
    projectVersions: projectVersions ?? this.projectVersions,
    previewedVersionId:
        previewedVersionId ?? (forcePreviewedVersionIdValue ? null : this.previewedVersionId),
    workingCopy: workingCopy ?? (forceWorkingCopyValue ? null : this.workingCopy),
    versionPendingDeletionId:
        versionPendingDeletionId ??
        (forceVersionPendingDeletionIdValue ? null : this.versionPendingDeletionId),
    versionPendingRestoreId:
        versionPendingRestoreId ??
        (forceVersionPendingRestoreIdValue ? null : this.versionPendingRestoreId),
    versionPendingRenameId:
        versionPendingRenameId ??
        (forceVersionPendingRenameIdValue ? null : this.versionPendingRenameId),
    projectVersionNotice:
        projectVersionNotice ?? (forceProjectVersionNoticeValue ? null : this.projectVersionNotice),
    projectPackagePendingExport:
        projectPackagePendingExport ??
        (forceProjectPackagePendingExportValue ? null : this.projectPackagePendingExport),
    projectPackageNotice:
        projectPackageNotice ?? (forceProjectPackageNoticeValue ? null : this.projectPackageNotice),
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.copyProjectVersionsState}
  @override
  OcptShotListState copyProjectVersionsState({
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool forcePreviewedVersionIdValue = false,
    OcptProjectWorkingCopyState? workingCopy,
    bool forceWorkingCopyValue = false,
    String? versionPendingDeletionId,
    bool forceVersionPendingDeletionIdValue = false,
    String? versionPendingRestoreId,
    bool forceVersionPendingRestoreIdValue = false,
    String? versionPendingRenameId,
    bool forceVersionPendingRenameIdValue = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool forceProjectVersionNoticeValue = false,
  }) => copyWith(
    projectVersions: projectVersions,
    previewedVersionId: previewedVersionId,
    forcePreviewedVersionIdValue: forcePreviewedVersionIdValue,
    workingCopy: workingCopy,
    forceWorkingCopyValue: forceWorkingCopyValue,
    versionPendingDeletionId: versionPendingDeletionId,
    forceVersionPendingDeletionIdValue: forceVersionPendingDeletionIdValue,
    versionPendingRestoreId: versionPendingRestoreId,
    forceVersionPendingRestoreIdValue: forceVersionPendingRestoreIdValue,
    versionPendingRenameId: versionPendingRenameId,
    forceVersionPendingRenameIdValue: forceVersionPendingRenameIdValue,
    projectVersionNotice: projectVersionNotice,
    forceProjectVersionNoticeValue: forceProjectVersionNoticeValue,
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.copyProjectPackageState}
  @override
  OcptShotListState copyProjectPackageState({
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool forceProjectPackagePendingExportValue = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool forceProjectPackageNoticeValue = false,
  }) => copyWith(
    projectPackagePendingExport: projectPackagePendingExport,
    forceProjectPackagePendingExportValue: forceProjectPackagePendingExportValue,
    projectPackageNotice: projectPackageNotice,
    forceProjectPackageNoticeValue: forceProjectPackageNoticeValue,
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
    locations,
    setScopeSymbolsBySetId,
    selectedFloorPlanSymbolId,
    selectedFloorPlanArrowId,
    pendingCharacterNamePromptSymbolId,
    floorPlanZoom,
    floorPlanActiveTool,
    floorPlanActiveLayer,
    floorPlanActiveSetElementShape,
    floorPlanActiveSetElementScope,
    floorPlanActiveLabel,
    propsOfSelectedSequence,
    pendingFloorPlanScopeDecision,
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
