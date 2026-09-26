// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_asset_file_types.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_display_number.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_set_suggestion.dart';

/// This is the bloc class for the shot list (découpage technique) production mode.
///
/// It loads the selected episode's whole shot list from [OcptShotListService] on entry —
/// sequences are built in memory by joining the scene index with the shots referencing it, so the
/// mode always shows the screenplay as it stands rather than a duplicated copy of it — together
/// with the screenplay's speaking characters (for the inspector's character chips), every
/// free-text field's own suggestion list, and where each shot sits in the schedule
/// (`OcptScheduleService.loadShotPlacements`, joined onto the snapshot by [_loadSnapshot]: the
/// schedule mode is the only writer of a shot's placement, this mode only ever reads it), and holds
/// the selection, the dock geometry and the visible table columns on top of it.
///
/// Most of a shot's fields are authored one discrete action at a time (picking a status, clicking
/// a difficulty dot, toggling a character chip) and each of those is written to the project
/// database immediately, then the snapshot is re-read so every derived aggregate the UI shows (a
/// sequence's shot count, its average difficulty, a shot's code) stays exactly what the database
/// says. The inspector's typed free-text fields are the exception: an edit is held in
/// [OcptShotListState.pendingFieldEdits] and written [defaultFieldEditDebounce] after the last
/// keystroke, mirroring `OcptEditorBloc`'s own autosave convention. The debounce is flushed
/// immediately whenever the selected shot or sequence changes, when the workspace is left, and
/// (through [flushPendingFieldEdits], called by the mode's own `deactivate()`) whenever the mode
/// leaves the widget tree for any other reason, so a pending edit is never silently dropped.
/// Committing a shot size additionally deduces the shot's abbreviation from it while the shot has
/// none of its own ([_deduceAbbreviationIfEmpty]), which is the only write this bloc performs that
/// the user didn't type themselves.
///
/// A shot's scenario coverage ranges are a further set of discrete, immediately-written actions:
/// [_onCoverageWordClicked] resolves a word click against
/// [OcptShotListState.pendingCoverageAnchor] into adding, removing, or simply moving where the
/// next click would close a range (see that handler's own doc comment for the three-state
/// interaction) — a range being added also attaches the characters it covers to the shot, see
/// [_attachCharactersCoveredBy] —, [_onCoverageClearRequested] drops every range of a shot, and
/// [_onShotMarkedAsChecked] clears a shot's `needsCheck` flag and re-stamps its ranges' digests.
/// [_onCoverageAnchorCancelled] is the odd one out: it never touches a range at all, only the
/// pending anchor a first click opened, so the coverage dialog can be backed out of without
/// recording anything. All three of the former go through [OcptShotListState.screenplayText] — the
/// screenplay's Fountain text as last loaded, which [OcptShotListState.buildSelectedCoverageLayout]
/// slices a scene's own text
/// out of — loaded once here rather than by [_screenplayCharactersOf] on its own, which used to
/// parse the screenplay text a second time to derive the same list of speaking characters.
///
/// It also mixes in [MixinOcptProjectVersionsBloc], which owns everything the right dock's
/// `Versions` tab does: the project's versions are a property of the *project*, so that tab and
/// its state are shared with the screenplay mode rather than reimplemented here. The two hooks the
/// mixin needs are answered by [flushPendingProjectWrites] (a field edit still sitting in the
/// debounce must reach the working copy before a preview swaps the database out) and
/// [reloadFromProjectDatabase]. `_onRightDockTabSelected` and `_flushPendingFieldEdits` each
/// dispatch [OcptProjectWorkingCopyRefreshRequestedEvent] — opening the `Versions` tab, and a
/// field edit landing while it is already open — the two moments the mixin's working-copy card is
/// worth a fresh, throttled read.
///
/// The actions that read the shot list rather than writing to it are its exports — the XLSX
/// workbook ([_onXlsxExportRequested]), the scenario coverage PDF
/// ([_onScenarioCoverageExportRequested]), the storyboard PDF ([_onStoryboardExportRequested]) and
/// the floor plans PDF ([_onFloorPlansExportRequested]): all four flush whatever is still pending,
/// then hand the loaded snapshot(s) to [OcptExportManager], which owns both the document building
/// and the native save dialog.
///
/// It mixes in [MixinOcptProjectPackageBloc] too, which writes the whole project out as a portable
/// package from the `Export` panel's own standing card. That mixin reuses
/// [flushPendingProjectWrites] — what a colleague receives is the project *file*, so a debounced
/// edit has to reach it first — and asks [exportManager] where to write, exactly as this mode's
/// own exports do.
class OcptShotListBloc extends BlocForMixin<OcptShotListState>
    with
        MixinOcptProjectVersionsBloc<OcptShotListState>,
        MixinOcptProjectPackageBloc<OcptShotListState> {
  /// The default delay between the last field edit and its autosave write.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

  /// The centre X, in metres, a set's underlay is framed at the moment it is first imported —
  /// see [_onFloorPlanUnderlayImportRequested].
  static const _defaultUnderlayXM = 0.0;

  /// The centre Y, in metres, a set's underlay is framed at the moment it is first imported.
  static const _defaultUnderlayYM = 0.0;

  /// The width, in metres, a set's underlay is framed at the moment it is first imported — a
  /// plausible room width the user drags and resizes against the reference silhouette (ADR 0031).
  static const _defaultUnderlayWidthM = 6.0;

  /// The height, in metres, a set's underlay is framed at the moment it is first imported.
  static const _defaultUnderlayHeightM = 4.0;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's dock fractions, visible columns and last
  /// right dock tab.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The manager used to export the shot list to an XLSX workbook.
  final OcptExportManager _exportManager;

  /// The service used to read and write the shot list.
  final OcptShotListService _shotListService;

  /// The service used to read the production's whole cast (for the character chips and the shared
  /// role alert banner) and to merge/delete/keep an orphaned or collided role.
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read and write a shot's scenario coverage ranges.
  final OcptShotCoverageService _shotCoverageService;

  /// The service used to read a shot's placement in the schedule — its `Jour de tournage` read-out,
  /// see [_loadSnapshot].
  final OcptScheduleService _scheduleService;

  /// The service used to read and write the board's panels: `loadStoryboard`, `addPanel`,
  /// `replacePanelImage`, `reorderPanel`, `updatePanelComment` and `deletePanel`.
  final OcptStoryboardService _storyboardService;

  /// The service used to read and write the floor plans: `loadFloorPlans`, a symbol's placement/
  /// move/resize/rotation/deletion, the underlay's own CRUD and a set's own plan-copying half of
  /// duplication.
  final OcptFloorPlanService _floorPlanService;

  /// The service used to create, rename, link and unlink a Resources set — the floor plans view's
  /// own set tabs are `scene_sets` links now (`docs/plans/storyboard.md`, §10), so every tab
  /// operation but placing/editing what is drawn on a set goes through this service instead of
  /// [_floorPlanService].
  final OcptLocationsService _locationsService;

  /// The manager used to pick a panel's frame or a set's underlay through the native "open"
  /// dialog, mirroring `OcptResourcesBloc`'s own `_pickFilePath`.
  final FileSelectorManager? _fileSelectorManager;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// The running field-edit debounce timer, if any.
  Timer? _fieldEditTimer;

  /// The episode this bloc reads and writes, handed down by `OcptShotListMode` from
  /// `OcptWorkspaceBloc.state.selectedEpisodeId` at construction time — safe to capture once
  /// rather than watch, since `WorkspacePage` remounts this whole bloc on every episode switch (see
  /// `WorkspacePage._buildActiveMode`'s own doc comment), so the field can never go stale.
  ///
  /// Null only for a project holding no episode at all: `OcptWorkspaceBloc` lands on the first one
  /// before it clears `isLoading`, and a mode is never built before that, so [_screenplayIdOf]'s
  /// fallback to [OcptOpenProjectModel.primaryScreenplayId] is the honest last resort rather than a
  /// routine path.
  final String? _selectedEpisodeId;

  /// Class constructor
  ///
  /// Every dependency can be overridden, which is what the tests do; in the app they all resolve
  /// through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by tests, to keep
  /// it fast and deterministic.
  OcptShotListBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
    OcptShotListService? shotListService,
    OcptRoleIndexService? roleIndexService,
    OcptShotCoverageService? shotCoverageService,
    OcptScheduleService? scheduleService,
    OcptStoryboardService? storyboardService,
    OcptFloorPlanService? floorPlanService,
    OcptLocationsService? locationsService,
    FileSelectorManager? fileSelectorManager,
    Duration fieldEditDebounce = defaultFieldEditDebounce,
    String? selectedEpisodeId,
  }) : _selectedEpisodeId = selectedEpisodeId,
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _shotListService =
           shotListService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).shotListService,
       _roleIndexService =
           roleIndexService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).roleIndexService,
       _shotCoverageService =
           shotCoverageService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).shotCoverageService,
       _scheduleService =
           scheduleService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).scheduleService,
       _storyboardService =
           storyboardService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).storyboardService,
       _floorPlanService =
           floorPlanService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).floorPlanService,
       _locationsService =
           locationsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).locationsService,
       _fileSelectorManager = fileSelectorManager,
       _fieldEditDebounce = fieldEditDebounce,
       super(OcptShotListState.init()) {
    add(const OcptShotListLoadRequestedEvent());
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptShotListLoadRequestedEvent>(_onLoadRequested);
    on<OcptShotListSequenceSelectedEvent>(_onSequenceSelected);
    on<OcptShotListShotSelectedEvent>(_onShotSelected);
    on<OcptShotListShotCreationRequestedEvent>(_onShotCreationRequested);
    on<OcptShotListSequencePanelToggledEvent>(_onSequencePanelToggled);
    on<OcptShotListRightDockTabSelectedEvent>(_onRightDockTabSelected);
    on<OcptShotListRightDockToggledEvent>(_onRightDockToggled);
    on<OcptShotListRightDockClosedEvent>(_onRightDockClosed);
    on<OcptShotListDockFractionsChangedEvent>(_onDockFractionsChanged);
    on<OcptShotListDockLayoutResetEvent>(_onDockLayoutReset);
    on<OcptShotListColumnToggledEvent>(_onColumnToggled);
    on<OcptShotListWriteErrorDismissedEvent>(_onWriteErrorDismissed);
    on<OcptShotListXlsxExportRequestedEvent>(_onXlsxExportRequested);
    on<OcptShotListScenarioCoverageExportRequestedEvent>(_onScenarioCoverageExportRequested);
    on<OcptShotListStoryboardExportRequestedEvent>(_onStoryboardExportRequested);
    on<OcptShotListFloorPlansExportRequestedEvent>(_onFloorPlansExportRequested);
    on<OcptShotListIoNoticeDismissedEvent>(_onIoNoticeDismissed);
    on<OcptShotListBackRequestedEvent>(_onBackRequested);
    on<OcptShotListProjectSettingsChangedEvent>(_onProjectSettingsChanged);
    on<OcptShotListShotFieldChangedEvent>(_onShotFieldChanged);
    on<OcptShotListFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptShotListShotDifficultyChangedEvent>(_onShotDifficultyChanged);
    on<OcptShotListShotCharacterToggledEvent>(_onShotCharacterToggled);
    on<OcptShotListCharacterAddRequestedEvent>(_onCharacterAddRequested);
    on<OcptShotListShotDeletionRequestedEvent>(_onShotDeletionRequested);
    on<OcptShotListOrphanedRoleDeleteRequestedEvent>(_onOrphanedRoleDeleteRequested);
    on<OcptShotListOrphanedRoleKeptEvent>(_onOrphanedRoleKept);
    on<OcptShotListRoleMergeRequestedEvent>(_onRoleMergeRequested);
    on<OcptShotListCoverageWordClickedEvent>(_onCoverageWordClicked);
    on<OcptShotListCoverageClearRequestedEvent>(_onCoverageClearRequested);
    on<OcptShotListCoverageAnchorCancelledEvent>(_onCoverageAnchorCancelled);
    on<OcptShotListShotMarkedAsCheckedEvent>(_onShotMarkedAsChecked);
    on<OcptShotListCentreViewSelectedEvent>(_onCentreViewSelected);
    on<OcptShotListPanelSelectedEvent>(_onPanelSelected);
    on<OcptShotListPanelSizeChangedEvent>(_onPanelSizeChanged);
    on<OcptShotListPanelImportRequestedEvent>(_onPanelImportRequested);
    on<OcptShotListPanelReplaceRequestedEvent>(_onPanelReplaceRequested);
    on<OcptShotListPanelReorderedEvent>(_onPanelReordered);
    on<OcptShotListPanelCommentChangedEvent>(_onPanelCommentChanged);
    on<OcptShotListPanelDeletionRequestedEvent>(_onPanelDeletionRequested);
    on<OcptShotListAnnotationToolSelectedEvent>(_onAnnotationToolSelected);
    on<OcptShotListAnnotationDrawnEvent>(_onAnnotationDrawn);
    on<OcptShotListAnnotationPlacedEvent>(_onAnnotationPlaced);
    on<OcptShotListAnnotationSelectedEvent>(_onAnnotationSelected);
    on<OcptShotListAnnotationTextChangedEvent>(_onAnnotationTextChanged);
    on<OcptShotListAnnotationDeletionRequestedEvent>(_onAnnotationDeletionRequested);
    on<OcptShotListSetSelectedEvent>(_onSetSelected);
    on<OcptShotListSetCreationRequestedEvent>(_onSetCreationRequested);
    on<OcptShotListSetNameChangedEvent>(_onSetNameChanged);
    on<OcptShotListSetDeletionRequestedEvent>(_onSetDeletionRequested);
    on<OcptShotListSetDuplicationRequestedEvent>(_onSetDuplicationRequested);
    on<OcptShotListFloorPlanBlockingCopyRequestedEvent>(_onFloorPlanBlockingCopyRequested);
    on<OcptShotListFloorPlanZoomChangedEvent>(_onFloorPlanZoomChanged);
    on<OcptShotListFloorPlanToolSelectedEvent>(_onFloorPlanToolSelected);
    on<OcptShotListFloorPlanActiveLayerChangedEvent>(_onFloorPlanActiveLayerChanged);
    on<OcptShotListFloorPlanActiveSetElementShapeChangedEvent>(
      _onFloorPlanActiveSetElementShapeChanged,
    );
    on<OcptShotListFloorPlanLayerVisibilityToggledEvent>(_onFloorPlanLayerVisibilityToggled);
    on<OcptShotListFloorPlanUnderlayVisibilityToggledEvent>(
      _onFloorPlanUnderlayVisibilityToggled,
    );
    on<OcptShotListFloorPlanSymbolPlacedEvent>(_onFloorPlanSymbolPlaced);
    on<OcptShotListFloorPlanSymbolSelectedEvent>(_onFloorPlanSymbolSelected);
    on<OcptShotListFloorPlanSymbolMovedEvent>(_onFloorPlanSymbolMoved);
    on<OcptShotListFloorPlanSymbolResizedEvent>(_onFloorPlanSymbolResized);
    on<OcptShotListFloorPlanSymbolRotatedEvent>(_onFloorPlanSymbolRotated);
    on<OcptShotListFloorPlanSymbolDeletionRequestedEvent>(_onFloorPlanSymbolDeletionRequested);
    on<OcptShotListFloorPlanUnderlayImportRequestedEvent>(_onFloorPlanUnderlayImportRequested);
    on<OcptShotListFloorPlanUnderlayTransformChangedEvent>(
      _onFloorPlanUnderlayTransformChanged,
    );
    on<OcptShotListFloorPlanUnderlayClearRequestedEvent>(_onFloorPlanUnderlayClearRequested);
    on<OcptShotListFloorPlanShotWalkRequestedEvent>(_onFloorPlanShotWalkRequested);
    on<OcptShotListFloorPlanCameraVisibilityToggledEvent>(_onFloorPlanCameraVisibilityToggled);
    on<OcptShotListFloorPlanOnionSkinToggledEvent>(_onFloorPlanOnionSkinToggled);
    on<OcptShotListFloorPlanOnionSkinOpacityChangedEvent>(_onFloorPlanOnionSkinOpacityChanged);
    on<OcptShotListFloorPlanMetricsToggledEvent>(_onFloorPlanMetricsToggled);
    on<OcptShotListFloorPlanAllCamerasToggledEvent>(_onFloorPlanAllCamerasToggled);
    on<OcptShotListFloorPlanArrowSymbolTappedEvent>(_onFloorPlanArrowSymbolTapped);
    on<OcptShotListFloorPlanArrowAnchorCancelledEvent>(_onFloorPlanArrowAnchorCancelled);
    on<OcptShotListFloorPlanArrowDeletionRequestedEvent>(_onFloorPlanArrowDeletionRequested);
    on<OcptShotListFloorPlanSymbolLabelChangedEvent>(_onFloorPlanSymbolLabelChanged);
    on<OcptShotListFloorPlanSymbolFovChangedEvent>(_onFloorPlanSymbolFovChanged);
    on<OcptShotListFloorPlanSymbolFovReachChangedEvent>(_onFloorPlanSymbolFovReachChanged);
    on<OcptShotListFloorPlanArrowSelectedEvent>(_onFloorPlanArrowSelected);
    on<OcptShotListFloorPlanArrowCurveChangedEvent>(_onFloorPlanArrowCurveChanged);
    on<OcptShotListFloorPlanSymbolDuplicatedEvent>(_onFloorPlanSymbolDuplicated);
    on<OcptShotListFloorPlanCharacterNamePromptDismissedEvent>(
      _onFloorPlanCharacterNamePromptDismissed,
    );
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageBloc.exportManager}
  @protected
  @override
  OcptExportManager get exportManager => _exportManager;

  /// The screenplay this bloc reads and writes: [_selectedEpisodeId], or [project]'s own
  /// [OcptOpenProjectModel.primaryScreenplayId] on the one path that can reach here with none
  /// selected (see [_selectedEpisodeId]'s own doc comment).
  String _screenplayIdOf(OcptOpenProjectModel project) =>
      _selectedEpisodeId ?? project.primaryScreenplayId;

  /// Writes whatever field edit is still sitting in the field-edit debounce, so a preview about to
  /// swap the database can't send it into the previewed version instead.
  @protected
  @override
  Future<void> flushPendingProjectWrites(Emitter<OcptShotListState> emitter) =>
      _flushPendingFieldEdits(emitter);

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<void> reloadFromProjectDatabase(Emitter<OcptShotListState> emitter) =>
      _onLoadRequested(const OcptShotListLoadRequestedEvent(), emitter);

  /// Loads the persisted preferences and the current project's shot list, selecting its first
  /// sequence.
  ///
  /// The workspace route is guarded by the router manager, so a project is normally always open
  /// here; if none is (e.g. the bloc is built directly in a test), the state simply stops loading
  /// with no snapshot at all.
  ///
  /// This is also [MixinOcptProjectVersionsBloc]'s [reloadFromProjectDatabase] hook, so it emits
  /// which version is being previewed alongside the shot list it just read: what it read comes from
  /// that very version's in-memory database, and the two must reach the mode together (see the
  /// hook's own doc comment).
  Future<void> _onLoadRequested(
    OcptShotListLoadRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final leftDockFraction =
        await _propertiesManager.shotListLeftDockFraction.load() ??
        OcptWorkspaceDock.leftDefaultFraction;
    final rightDockFraction =
        await _propertiesManager.shotListRightDockFraction.load() ??
        OcptWorkspaceDock.rightDefaultFraction;
    final visibleColumns =
        await _propertiesManager.shotListVisibleColumns.load() ??
        OcptShotListColumn.defaultVisibleColumns;
    final lastRightDockTab =
        await _propertiesManager.shotListLastRightDockTab.load() ??
        OcptShotListRightDockTab.inspector;
    final centreView =
        await _propertiesManager.shotListLastCentreView.load() ?? OcptShotListCentreView.table;

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(
        state.copyWith(
          isLoading: false,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          visibleColumns: visibleColumns,
          lastRightDockTab: lastRightDockTab,
          centreView: centreView,
          clearPreviewedVersionId: true,
        ),
      );
      return;
    }

    final previewedVersion = project.previewedVersion;
    final screenplayText = await _loadScreenplayText(project);
    final pageSetup = await _loadPageSetup(project);
    final snapshot = await _loadSnapshot(project);
    final storyboardSnapshot = await _loadStoryboard(project);
    final floorPlanSnapshot = await _loadFloorPlans(project);
    final screenplayCharacters = _screenplayCharactersOf(screenplayText);
    final roles = await _loadRoles(project);
    final suggestions = await _loadSuggestions(project);
    final selectedSequenceId = snapshot.sequences.isEmpty ? null : snapshot.sequences.first.id;
    final firstSetId = _firstSetIdOf(
      floorPlanSnapshot: floorPlanSnapshot,
      sequenceId: selectedSequenceId,
    );
    final firstShotId = _firstShotIdOf(snapshot: snapshot, sequenceId: selectedSequenceId);

    emitter(
      state.copyWith(
        isLoading: false,
        title: project.name,
        previewedVersionId: previewedVersion?.id,
        clearPreviewedVersionId: previewedVersion == null,
        snapshot: snapshot,
        storyboardSnapshot: storyboardSnapshot,
        floorPlanSnapshot: floorPlanSnapshot,
        pageSetup: pageSetup,
        screenplayText: screenplayText,
        roles: roles,
        selectedSequenceId: selectedSequenceId,
        clearSelectedSequenceId: snapshot.sequences.isEmpty,
        selectedShotId: firstShotId,
        clearSelectedShotId: firstShotId == null,
        clearSelectedPanelId: true,
        clearActiveAnnotationTool: true,
        clearSelectedAnnotationId: true,
        selectedSetId: firstSetId,
        clearSelectedSetId: firstSetId == null,
        clearSelectedFloorPlanSymbolId: true,
        clearSelectedFloorPlanArrowId: true,
        clearPendingFloorPlanArrowAnchorSymbolId: true,
        clearPendingCoverageAnchor: true,
        leftDockFraction: leftDockFraction,
        rightDockFraction: rightDockFraction,
        visibleColumns: visibleColumns,
        lastRightDockTab: lastRightDockTab,
        centreView: centreView,
        screenplayCharacters: screenplayCharacters,
        suggestions: suggestions,
      ),
    );
  }

  /// Reads the whole shot list of the selected episode's screenplay, joined with where each of its
  /// shots sits in the schedule (`OcptScheduleService.loadShotPlacements`), keyed by shot id —
  /// what the table's and the metadata panel's own `Jour de tournage` read-out is built from. A
  /// project with no schedule at all simply joins an empty map, so every shot reads as unplaced.
  ///
  /// Read again on every call, alongside every other write this bloc performs: the schedule is
  /// edited from its own mode, never from here, but this mode's own snapshot must still show
  /// whatever it currently says.
  ///
  /// The scenes are numbered with their episode's own prefix: this bloc reads the project's live
  /// episodes through [_projectsManager]'s own `screenplayService` (never through
  /// [_shotListService], which `OcptScreenplayService` already depends on) and resolves the
  /// selected episode's number with `ocptEpisodePrefixNumberOf`, null on a single-episode project.
  Future<OcptShotListSnapshot> _loadSnapshot(OcptOpenProjectModel project) async {
    final database = project.database;
    final screenplayId = _screenplayIdOf(project);

    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: database);
    final snapshot = await _shotListService.loadShotList(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: ocptEpisodePrefixNumberOf(episodes: episodes, screenplayId: screenplayId),
    );
    final placements = await _scheduleService.loadShotPlacements(database: database);

    return snapshot.copyWithPlacements(placements);
  }

  /// Reads the whole storyboard of the selected episode's screenplay — every live shot's panels,
  /// keyed by shot id — what the board reads through `OcptShotListState.panelsOfShot`.
  ///
  /// Read again after every board write, exactly as [_loadSnapshot] is after every shot list write:
  /// the snapshot in state is only ever a reflection of what the database says.
  Future<OcptStoryboardSnapshot> _loadStoryboard(OcptOpenProjectModel project) =>
      _storyboardService.loadStoryboard(
        database: project.database,
        screenplayId: _screenplayIdOf(project),
      );

  /// Reads the whole floor plans of the selected episode's screenplay — every live set of every
  /// sequence, keyed by scene id — what the floor plans view reads through
  /// `OcptShotListState.setsOfSelectedSequence`.
  ///
  /// Read again after every floor plans write, exactly as [_loadStoryboard] is after every board
  /// write: the snapshot in state is only ever a reflection of what the database says.
  Future<OcptFloorPlanSnapshot> _loadFloorPlans(OcptOpenProjectModel project) =>
      _floorPlanService.loadFloorPlans(
        database: project.database,
        screenplayId: _screenplayIdOf(project),
      );

  /// The id of [sequenceId]'s own first floor plan set (its first tab), or null while
  /// [floorPlanSnapshot] holds none for it, [sequenceId] is null, or it isn't a real scene (the
  /// orphan group can never hold a set) — what a freshly selected sequence's floor plans view
  /// defaults to.
  String? _firstSetIdOf({
    required OcptFloorPlanSnapshot? floorPlanSnapshot,
    required String? sequenceId,
  }) {
    if (sequenceId == null || floorPlanSnapshot == null) {
      return null;
    }
    final sets = floorPlanSnapshot.setsOfScene(sequenceId);
    return sets.isEmpty ? null : sets.first.id;
  }

  /// The id of [sequenceId]'s own first shot, or null while [sequenceId] is null, doesn't name a
  /// real scene (the orphan group holds no floor plan set, but it does hold shots — this still
  /// returns null for it, since a floor plan focus only ever makes sense on a real scene) or holds
  /// none in [snapshot] — what a freshly loaded snapshot, or a freshly selected sequence, defaults
  /// [OcptShotListState.selectedShotId] to, guaranteeing it is never null while the sequence holds
  /// at least one shot (R2, "always a current shot": every camera, character, light, prop and arrow
  /// placed on the floor plans view lands on this very shot).
  String? _firstShotIdOf({required OcptShotListSnapshot? snapshot, required String? sequenceId}) {
    if (snapshot == null || sequenceId == null) {
      return null;
    }
    for (final sequence in snapshot.sequences) {
      if (sequence.id == sequenceId && sequence is OcptSceneShotSequence) {
        return sequence.shots.isEmpty ? null : sequence.shots.first.id;
      }
    }
    return null;
  }

  /// Reads the production's whole cast — every live role, in `sortKey` order — what the
  /// inspector's character chips are built from, and what the shared role alert banner's
  /// orphaned/collision alerts are derived from (`OcptShotListState.orphanedRoleAlerts`/
  /// `.roleCollisionAlerts`).
  Future<List<OcptRole>> _loadRoles(OcptOpenProjectModel project) =>
      _roleIndexService.loadRoles(database: project.database);

  /// Reads the selected episode's current Fountain source text, kept in
  /// `OcptShotListState.screenplayText` for [_screenplayCharactersOf] and every scenario coverage
  /// read/write that needs the whole screenplay text rather than a single scene's own slice of it.
  Future<String> _loadScreenplayText(OcptOpenProjectModel project) =>
      _projectsManager.screenplayService.loadScreenplayText(
        database: project.database,
        screenplayId: _screenplayIdOf(project),
      );

  /// Reads the page setup the screenplay is typeset with: the open project's own page format,
  /// paired with the app-wide margins preference, exactly as the screenplay editor's own bloc
  /// pairs them. The scenario coverage dialog's simulated paper sheet is laid out with it.
  ///
  /// A version being previewed is laid out with the setup it was written against instead, which
  /// travels on the open project model and is never written anywhere — again exactly as the
  /// screenplay editor's own bloc does it.
  Future<OcptPageSetup> _loadPageSetup(OcptOpenProjectModel project) async =>
      project.previewedPageSetup ??
      OcptPageSetup(
        format: await _projectsManager.loadCurrentProjectPageFormat() ?? OcptPageFormat.usLetter,
        margins: await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
      );

  /// Parses [screenplayText] and delegates to `fountain_kit`'s `screenplayCharactersOf`, whose
  /// normalisation matches `shot_characters.characterName`'s own (both go through
  /// `normalizeCharacterName`) so a shot's character and a screenplay's own compare equal
  /// byte-for-byte.
  ///
  /// The whole cast, not only the speaking roles: a character introduced in capitals in an action
  /// line and never given a single line of dialogue (a silhouette, an extra, someone who only
  /// crosses the frame) still has to be attachable to a shot, and would otherwise be reported as
  /// removed from the screenplay by `OcptShotListState.removedCharacterAlerts` the moment somebody
  /// attached them.
  List<String> _screenplayCharactersOf(String screenplayText) {
    final document = const FountainParser().parse(screenplayText);
    return screenplayCharactersOf(document.blocks);
  }

  /// Reads every free-text field's suggestion list, scoped to the selected episode: what has
  /// already been entered elsewhere in *this* screenplay, not the whole project's.
  Future<OcptShotFieldSuggestions> _loadSuggestions(OcptOpenProjectModel project) async {
    final database = project.database;
    final screenplayId = _screenplayIdOf(project);

    return OcptShotFieldSuggestions(
      shotSizes: await _shotListService.distinctShotSizes(
        database: database,
        screenplayId: screenplayId,
      ),
      framings: await _shotListService.distinctFramings(
        database: database,
        screenplayId: screenplayId,
      ),
      cameraMoves: await _shotListService.distinctCameraMoves(
        database: database,
        screenplayId: screenplayId,
      ),
      lenses: await _shotListService.distinctLenses(
        database: database,
        screenplayId: screenplayId,
      ),
      recordingFormats: await _shotListService.distinctRecordingFormats(
        database: database,
        screenplayId: screenplayId,
      ),
      sounds: await _shotListService.distinctSounds(
        database: database,
        screenplayId: screenplayId,
      ),
    );
  }

  /// Selects a sequence, clearing the selected shot when it actually changes sequence (the centre
  /// table then lists shots the previous selection isn't among).
  ///
  /// Flushes any pending field edit first, so switching sequences right after typing never loses
  /// it.
  Future<void> _onSequenceSelected(
    OcptShotListSequenceSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final isSameSequence = state.selectedSequenceId == event.sequenceId;
    final firstSetId = isSameSequence
        ? state.selectedSetId
        : _firstSetIdOf(floorPlanSnapshot: state.floorPlanSnapshot, sequenceId: event.sequenceId);
    final selectedShotId = isSameSequence
        ? state.selectedShotId
        : _firstShotIdOf(snapshot: state.snapshot, sequenceId: event.sequenceId);

    emitter(
      state.copyWith(
        selectedSequenceId: event.sequenceId,
        selectedShotId: selectedShotId,
        clearSelectedShotId: selectedShotId == null,
        clearSelectedPanelId: !isSameSequence,
        clearActiveAnnotationTool: !isSameSequence,
        clearSelectedAnnotationId: !isSameSequence,
        selectedSetId: firstSetId,
        clearSelectedSetId: firstSetId == null,
        clearSelectedFloorPlanSymbolId: !isSameSequence,
        clearSelectedFloorPlanArrowId: !isSameSequence,
        clearPendingFloorPlanArrowAnchorSymbolId: true,
        clearPendingCoverageAnchor: true,
      ),
    );
  }

  /// Selects a shot, together with the sequence holding it, and opens the right dock on its
  /// inspector tab.
  ///
  /// Flushes any pending field edit first, so switching shots right after typing never loses it.
  /// A shot id that no longer exists in the current snapshot (a stale click on a list rebuilt
  /// underneath) is ignored rather than selecting nothing.
  Future<void> _onShotSelected(
    OcptShotListShotSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final sequence = _sequenceHolding(event.shotId);
    if (sequence == null) {
      return;
    }

    await _persistLastRightDockTab(OcptShotListRightDockTab.inspector);

    emitter(
      state.copyWith(
        selectedSequenceId: sequence.id,
        selectedShotId: event.shotId,
        clearSelectedPanelId: true,
        clearActiveAnnotationTool: true,
        clearSelectedAnnotationId: true,
        rightDockTab: OcptShotListRightDockTab.inspector,
        lastRightDockTab: OcptShotListRightDockTab.inspector,
        clearPendingCoverageAnchor: true,
        clearSelectedFloorPlanSymbolId: true,
        clearSelectedFloorPlanArrowId: true,
        clearPendingFloorPlanArrowAnchorSymbolId: true,
      ),
    );
  }

  /// The sequence of the current snapshot holding the shot [shotId], or null if no sequence does.
  OcptShotSequence? _sequenceHolding(String shotId) {
    for (final sequence in state.sequences) {
      for (final shot in sequence.shots) {
        if (shot.id == shotId) {
          return sequence;
        }
      }
    }

    return null;
  }

  /// Creates a shot at the end of the selected scene sequence, reloads the shot list and selects
  /// the new shot.
  ///
  /// Deliberately a no-op when the selected sequence is the orphan group (or when nothing is
  /// selected at all): see [OcptShotListShotCreationRequestedEvent].
  Future<void> _onShotCreationRequested(
    OcptShotListShotCreationRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final project = _projectsManager.currentProject;
    final sequence = state.selectedSequence;
    if (project == null || sequence is! OcptSceneShotSequence) {
      return;
    }

    try {
      final shotId = await _shotListService.createShot(
        database: project.database,
        screenplayId: _screenplayIdOf(project),
        sceneId: sequence.sceneId,
      );
      final snapshot = await _loadSnapshot(project);

      await _persistLastRightDockTab(OcptShotListRightDockTab.inspector);

      emitter(
        state.copyWith(
          snapshot: snapshot,
          selectedSequenceId: sequence.sceneId,
          selectedShotId: shotId,
          rightDockTab: OcptShotListRightDockTab.inspector,
          lastRightDockTab: OcptShotListRightDockTab.inspector,
          clearPendingCoverageAnchor: true,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to create a shot in the scene "
          "${sequence.sceneId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Toggles the left (sequences) dock's visibility.
  Future<void> _onSequencePanelToggled(
    OcptShotListSequencePanelToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(isSequencePanelVisible: !state.isSequencePanelVisible));
  }

  /// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens
  /// or switches to it) and records it as the tab the toolbar's toggle reopens the dock on.
  ///
  /// Opening the `Versions` tab is one of the two moments `MixinOcptProjectVersionsBloc`'s
  /// working-copy card needs a fresh read for: the other is a field edit flushing while it is
  /// already the one showing (see `_flushPendingFieldEdits`).
  Future<void> _onRightDockTabSelected(
    OcptShotListRightDockTabSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final isAlreadyActive = state.rightDockTab == event.tab;
    await _persistLastRightDockTab(event.tab);

    emitter(
      state.copyWith(
        rightDockTab: isAlreadyActive ? null : event.tab,
        clearRightDockTab: isAlreadyActive,
        lastRightDockTab: event.tab,
      ),
    );

    if (!isAlreadyActive && event.tab == OcptShotListRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens
  /// on [OcptShotListState.lastRightDockTab].
  Future<void> _onRightDockToggled(
    OcptShotListRightDockToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(
      state.rightDockTab != null
          ? state.copyWith(clearRightDockTab: true)
          : state.copyWith(rightDockTab: state.lastRightDockTab),
    );
  }

  /// Closes the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptShotListRightDockClosedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(clearRightDockTab: true));
  }

  /// Persists [tab] as the mode's last right dock tab, unless it already is.
  Future<void> _persistLastRightDockTab(OcptShotListRightDockTab tab) async {
    if (state.lastRightDockTab == tab) {
      return;
    }

    await _propertiesManager.shotListLastRightDockTab.store(tab);
  }

  /// Applies and persists whichever dock fraction the ended drag gesture reports.
  Future<void> _onDockFractionsChanged(
    OcptShotListDockFractionsChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final left = event.left;
    final right = event.right;

    if (left != null) {
      await _propertiesManager.shotListLeftDockFraction.store(left);
    }
    if (right != null) {
      await _propertiesManager.shotListRightDockFraction.store(right);
    }

    emitter(state.copyWith(leftDockFraction: left, rightDockFraction: right));
  }

  /// Restores both dock fractions to their defaults, persisting them.
  Future<void> _onDockLayoutReset(
    OcptShotListDockLayoutResetEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _propertiesManager.shotListLeftDockFraction.store(
      OcptWorkspaceDock.leftDefaultFraction,
    );
    await _propertiesManager.shotListRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );

    emitter(
      state.copyWith(
        leftDockFraction: OcptWorkspaceDock.leftDefaultFraction,
        rightDockFraction: OcptWorkspaceDock.rightDefaultFraction,
      ),
    );
  }

  /// Shows or hides an optional table column, persisting the new set.
  Future<void> _onColumnToggled(
    OcptShotListColumnToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final visibleColumns = Set<OcptShotListColumn>.of(state.visibleColumns);
    if (!visibleColumns.remove(event.column)) {
      visibleColumns.add(event.column);
    }

    await _propertiesManager.shotListVisibleColumns.store(visibleColumns);
    emitter(state.copyWith(visibleColumns: visibleColumns));
  }

  /// Dismisses the transient write error currently shown.
  Future<void> _onWriteErrorDismissed(
    OcptShotListWriteErrorDismissedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(hasWriteError: false));
  }

  /// Exports the whole shot list to an XLSX workbook.
  ///
  /// Flushes any pending field edit first — that flush re-reads the snapshot, so the workbook
  /// holds the value the user typed seconds ago rather than the one the database held before it —
  /// then hands what the state now carries to [OcptExportManager.exportShotListXlsx]. A cancelled
  /// save dialog is a silent no-op; a failure raises the transient export-failed notice.
  ///
  /// Exports the whole shot list, not only the selected sequence: the workbook is what leaves the
  /// app, and the orphan group travels with it exactly as the left dock shows it.
  Future<void> _onXlsxExportRequested(
    OcptShotListXlsxExportRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final outcome = await _exportManager.exportShotListXlsx(
        snapshot: snapshot,
        labels: event.labels,
        projectName: state.title,
        fileTypeLabel: event.fileTypeLabel,
        episodeTag: event.episodeTag,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptShotListIoNotice(
            kind: OcptShotListIoNoticeKind.xlsxExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the shot list of the project at "
          "${_projectsManager.currentProject?.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptShotListIoNotice(kind: OcptShotListIoNoticeKind.xlsxExportFailed),
        ),
      );
    }
  }

  /// Exports the screenplay annotated with the shots covering it, as a PDF.
  ///
  /// The read-only sibling of [_onXlsxExportRequested], and built the same way: flush whatever is
  /// still pending — that flush re-reads the snapshot, so the legend holds the shot size the user
  /// typed seconds ago — then hand what the state now carries to
  /// [OcptExportManager.exportScenarioCoverage]. A cancelled save dialog is a silent no-op; a
  /// failure raises the transient export-failed notice.
  ///
  /// [OcptShotListState.screenplayText] is parsed here rather than kept parsed in the state: the
  /// document is only ever needed by this export, and the very string it is parsed from travels
  /// alongside it, since a coverage range addresses that text by character offset.
  Future<void> _onScenarioCoverageExportRequested(
    OcptShotListScenarioCoverageExportRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final options = event.options;
      final outcome = await _exportManager.exportScenarioCoverage(
        document: const FountainParser().parse(state.screenplayText),
        screenplayText: state.screenplayText,
        snapshot: snapshot,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: state.title,
        includeSceneNumbers: options.includeSceneNumbers,
        includeTitlePage: options.includeTitlePage,
        includeLegendPage: options.includeLegendPage,
        includeSummaryPage: options.includeSummaryPage,
        fileTypeLabel: event.fileTypeLabel,
        episodeTag: event.episodeTag,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptShotListIoNotice(
            kind: OcptShotListIoNoticeKind.scenarioCoverageExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the scenario coverage of the project "
          "at ${_projectsManager.currentProject?.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptShotListIoNotice(
            kind: OcptShotListIoNoticeKind.scenarioCoverageExportFailed,
          ),
        ),
      );
    }
  }

  /// Exports the storyboard — every shot's imported frames, annotated, with its key information —
  /// as a PDF.
  ///
  /// Built the same way as [_onXlsxExportRequested] and [_onScenarioCoverageExportRequested]:
  /// flush whatever field or panel comment edit is still pending — so the export holds it — then
  /// hand what the state now carries to [OcptExportManager.exportStoryboard]. When
  /// [OcptShotListStoryboardExportRequestedEvent.options] asks for the floor plans to be appended,
  /// [OcptShotListState.floorPlanSnapshot] rides along too; a cancelled save dialog is a silent
  /// no-op, a failure raises the transient export-failed notice.
  Future<void> _onStoryboardExportRequested(
    OcptShotListStoryboardExportRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    final storyboardSnapshot = state.storyboardSnapshot;
    if (snapshot == null || storyboardSnapshot == null) {
      return;
    }

    try {
      final options = event.options;
      final outcome = await _exportManager.exportStoryboard(
        snapshot: snapshot,
        storyboardSnapshot: storyboardSnapshot,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: state.title,
        shotsPerPage: options.shotsPerPage,
        includeFloorPlansAfterEachSequence: options.includeFloorPlansAfterEachSequence,
        floorPlanSnapshot: state.floorPlanSnapshot,
        floorPlanLabels: event.floorPlanLabels,
        fileTypeLabel: event.fileTypeLabel,
        episodeTag: event.episodeTag,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptShotListIoNotice(
            kind: OcptShotListIoNoticeKind.storyboardExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the storyboard of the project at "
          "${_projectsManager.currentProject?.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptShotListIoNotice(kind: OcptShotListIoNoticeKind.storyboardExportFailed),
        ),
      );
    }
  }

  /// Exports the floor plans — one plan per shot that has a camera placed on it — as a PDF.
  ///
  /// The read-only sibling of [_onStoryboardExportRequested], opening no options dialog of its own
  /// (its page format is [OcptShotListState.pageSetup], exactly as the shot list workbook's own
  /// export is): flush whatever is still pending — so a symbol label typed seconds ago is on the
  /// plan — then hand what the state now carries to [OcptExportManager.exportFloorPlans]. A
  /// cancelled save dialog is a silent no-op; a failure raises the transient export-failed notice.
  Future<void> _onFloorPlansExportRequested(
    OcptShotListFloorPlansExportRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    final floorPlanSnapshot = state.floorPlanSnapshot;
    if (snapshot == null || floorPlanSnapshot == null) {
      return;
    }

    try {
      final outcome = await _exportManager.exportFloorPlans(
        snapshot: snapshot,
        floorPlanSnapshot: floorPlanSnapshot,
        pageSetup: state.pageSetup,
        labels: event.labels,
        projectName: state.title,
        fileTypeLabel: event.fileTypeLabel,
        episodeTag: event.episodeTag,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptShotListIoNotice(
            kind: OcptShotListIoNoticeKind.floorPlansExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the floor plans of the project at "
          "${_projectsManager.currentProject?.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptShotListIoNotice(kind: OcptShotListIoNoticeKind.floorPlansExportFailed),
        ),
      );
    }
  }

  /// Clears the transient export notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptShotListIoNoticeDismissedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(clearIoNotice: true));
  }

  /// Leaves the workspace: flushes any pending field edit, closes the current project, and
  /// navigates back to the home page.
  Future<void> _onBackRequested(
    OcptShotListBackRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);
    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }

  /// Re-reads the page setup after the project settings page changed something, so the scenario
  /// coverage export dialog pre-fills from the format actually in effect.
  Future<void> _onProjectSettingsChanged(
    OcptShotListProjectSettingsChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    emitter(state.copyWith(pageSetup: await _loadPageSetup(project)));
  }

  /// Records the raw text just typed into `event.field` of shot `event.shotId` as a pending edit,
  /// visible immediately, and (re)starts the field-edit debounce that eventually writes it.
  Future<void> _onShotFieldChanged(
    OcptShotListShotFieldChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    _recordPendingEdit(
      emitter: emitter,
      key: OcptShotListShotFieldEditKey(shotId: event.shotId, field: event.field),
      rawValue: event.rawValue,
    );
  }

  /// Records [rawValue] as the pending edit of [key], visible immediately, and (re)starts the
  /// field-edit debounce that eventually writes it — the body [_onShotFieldChanged] and
  /// [_onPanelCommentChanged] share, since both ride the very same debounce.
  void _recordPendingEdit({
    required Emitter<OcptShotListState> emitter,
    required OcptShotListPendingEditKey key,
    required String rawValue,
  }) {
    final pending = Map<OcptShotListPendingEditKey, String>.of(state.pendingFieldEdits)
      ..[key] = rawValue;
    emitter(state.copyWith(pendingFieldEdits: pending));

    _fieldEditTimer?.cancel();
    _fieldEditTimer = Timer(_fieldEditDebounce, () {
      if (!isClosed) {
        add(const OcptShotListFieldEditFlushRequestedEvent());
      }
    });
  }

  /// Writes every pending field edit once the field-edit debounce elapses with no further typing.
  Future<void> _onFieldEditFlushRequested(
    OcptShotListFieldEditFlushRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) => _flushPendingFieldEdits(emitter);

  /// Writes every pending field edit immediately: cancels the debounce timer (a no-op if it
  /// already fired or there was none), writes each one through
  /// `OcptShotListService.updateShot`, then reloads the snapshot and the suggestion lists so every
  /// derived aggregate and every field's suggestions reflect what the database now says. A no-op
  /// while nothing is pending.
  ///
  /// Used from inside an event handler, with that handler's own [emitter]: called by
  /// [_onFieldEditFlushRequested] (the debounce firing), and up front by every handler that
  /// changes what shot or sequence is selected, or that leaves the workspace, so a pending edit
  /// is never silently dropped by a selection change. [flushPendingFieldEdits] is the sibling of
  /// this method used outside of an event handler.
  Future<void> _flushPendingFieldEdits(Emitter<OcptShotListState> emitter) async {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWith(pendingFieldEdits: const {}));
      return;
    }

    try {
      await _writeAllPendingFields(project: project, pending: pending);
      final snapshot = await _loadSnapshot(project);
      final suggestions = await _loadSuggestions(project);
      final storyboardSnapshot = await _loadStoryboard(project);
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          snapshot: snapshot,
          suggestions: suggestions,
          storyboardSnapshot: storyboardSnapshot,
          floorPlanSnapshot: floorPlanSnapshot,
          pendingFieldEdits: const {},
        ),
      );

      // The other of the two moments the working-copy card needs a fresh read for (see
      // `_onRightDockTabSelected`): a field edit landing while the tab showing it is already open.
      if (state.rightDockTab == OcptShotListRightDockTab.versions) {
        add(const OcptProjectWorkingCopyRefreshRequestedEvent());
      }
    } catch (error) {
      appLogger().e("A problem occurred when tried to flush a pending shot list field edit of "
          "the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true, pendingFieldEdits: const {}));
    }
  }

  /// Writes every pending field edit directly to the database, bypassing both the debounce timer
  /// and the bloc's own event queue.
  ///
  /// Called by the mode's own `deactivate()`, mirroring
  /// `OcptStyledScreenplayEditor.deactivate()`: `deactivate()` runs before `dispose()` for every
  /// removal from the tree (a mode switch swaps this whole subtree out, and so does the
  /// workspace's own back navigation), so triggering the write here — rather than dispatching an
  /// event, which would only be processed on a later microtask this widget might not survive to
  /// see — is what guarantees the last [defaultFieldEditDebounce] worth of typing isn't lost.
  ///
  /// Unlike [_flushPendingFieldEdits], this never touches [state]: `emit` may only be called from
  /// inside a registered `on<Event>` handler (the package's own rule, enforced by the analyzer's
  /// `visible_for_testing` lint on `Bloc.emit`), and by the time this runs the widget tree that
  /// would show a fresh state is already gone anyway. Like `OcptEditorBloc.disposeLifeCycle`'s own
  /// flush, a failure here is only logged.
  Future<void> flushPendingFieldEdits() async {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _writeAllPendingFields(project: project, pending: pending);
    } catch (error) {
      appLogger().e("A problem occurred when tried to flush a pending shot list field edit of "
          "the project at ${project.path}: $error");
    }
  }

  /// Writes every entry of [pending], switching on its key's own kind: a shot field through
  /// `OcptShotListService.updateShot` (translating it into the matching named argument, see
  /// `OcptShotListEditableField`'s own doc comment for the mapping, and deducing an abbreviation
  /// alongside every shot size committed here, see [_deduceAbbreviationIfEmpty]), a panel comment
  /// through `OcptStoryboardService.updatePanelComment`, or a mark's own text through
  /// `OcptStoryboardService.updateAnnotation`.
  ///
  /// A shot whose abbreviation is being typed in the very same flush is left out of the deduction:
  /// what the user is writing wins over what the shot size would have suggested, whichever of the
  /// two entries this loop happens to reach first.
  Future<void> _writeAllPendingFields({
    required OcptOpenProjectModel project,
    required Map<OcptShotListPendingEditKey, String> pending,
  }) async {
    for (final entry in pending.entries) {
      switch (entry.key) {
        case OcptShotListShotFieldEditKey(:final shotId, :final field):
          await _writeField(
            database: project.database,
            shotId: shotId,
            field: field,
            rawValue: entry.value,
          );

          if (field == OcptShotListEditableField.shotSize &&
              !pending.containsKey(
                OcptShotListShotFieldEditKey(
                  shotId: shotId,
                  field: OcptShotListEditableField.abbreviation,
                ),
              )) {
            await _deduceAbbreviationIfEmpty(
              database: project.database,
              shotId: shotId,
              shotSize: entry.value,
            );
          }
        case OcptShotListPanelCommentEditKey(:final panelId):
          await _storyboardService.updatePanelComment(
            database: project.database,
            panelId: panelId,
            comment: entry.value,
          );
        case OcptShotListAnnotationTextEditKey(:final annotationId):
          await _storyboardService.updateAnnotation(
            database: project.database,
            annotationId: annotationId,
            text: Value(entry.value),
          );
        case OcptShotListSetNameEditKey(:final setId):
          await _locationsService.updateSet(
            database: project.database,
            setId: setId,
            name: Value(entry.value),
          );
        case OcptShotListSymbolLabelEditKey(:final symbolId):
          await _floorPlanService.updateSymbol(
            database: project.database,
            symbolId: symbolId,
            label: Value(entry.value),
          );
      }
    }
  }

  /// Writes onto shot [shotId] the abbreviation [ocptDeduceShotAbbreviation] reads out of the
  /// [shotSize] just committed, unless the shot already carries one.
  ///
  /// Deduced once, at that moment only: an abbreviation the user has typed — or one deduced from
  /// an earlier shot size — is never overwritten by a later edit of the shot size, and clearing
  /// the field leaves it empty until the shot size is committed again. A shot size with no
  /// initials to read at all (blank, or punctuation alone) deduces nothing rather than emptying
  /// what the shot holds.
  Future<void> _deduceAbbreviationIfEmpty({
    required OcptProjectDatabase database,
    required String shotId,
    required String shotSize,
  }) async {
    final stored = state.snapshot?.shotsById[shotId]?.abbreviation ?? "";
    if (stored.trim().isNotEmpty) {
      return;
    }

    final deduced = ocptDeduceShotAbbreviation(shotSize);
    if (deduced.isEmpty) {
      return;
    }

    await _shotListService.updateShot(
      database: database,
      shotId: shotId,
      abbreviation: Value(deduced),
    );
  }

  /// Writes a single field edit through `OcptShotListService.updateShot`.
  /// [OcptShotListEditableField.estimatedDuration] is parsed first; an entry whose raw text
  /// doesn't parse is silently skipped, leaving whatever the database already holds untouched,
  /// rather than failing the whole flush.
  Future<void> _writeField({
    required OcptProjectDatabase database,
    required String shotId,
    required OcptShotListEditableField field,
    required String rawValue,
  }) async {
    switch (field) {
      case OcptShotListEditableField.shotSize:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          shotSize: Value(rawValue),
        );
      case OcptShotListEditableField.abbreviation:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          abbreviation: Value(rawValue),
        );
      case OcptShotListEditableField.framing:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          framing: Value(rawValue),
        );
      case OcptShotListEditableField.cameraMove:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          cameraMove: Value(rawValue),
        );
      case OcptShotListEditableField.lens:
        await _shotListService.updateShot(database: database, shotId: shotId, lens: Value(rawValue));
      case OcptShotListEditableField.recordingFormat:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          recordingFormat: Value(rawValue),
        );
      case OcptShotListEditableField.sound:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          sound: Value(rawValue),
        );
      case OcptShotListEditableField.notes:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          notes: Value(rawValue),
        );
      case OcptShotListEditableField.locationNotes:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          locationNotes: Value(rawValue),
        );
      case OcptShotListEditableField.estimatedDuration:
        final parsed = _tryParseDuration(rawValue);
        if (!parsed.isValid) {
          return;
        }
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          estimatedDurationMs: Value(parsed.value),
        );
    }
  }

  /// Attempts to parse [raw] as a shot's estimated duration through [ocptParseShotDuration],
  /// reporting whether it succeeded rather than throwing: a rejected edit is meant to be silently
  /// skipped, not to crash the flush of every other pending edit alongside it.
  ({bool isValid, int? value}) _tryParseDuration(String raw) {
    try {
      return (isValid: true, value: ocptParseShotDuration(raw));
    } on FormatException {
      return (isValid: false, value: null);
    }
  }

  /// Sets one difficulty axis of shot `event.shotId` to `event.value`, written immediately.
  Future<void> _onShotDifficultyChanged(
    OcptShotListShotDifficultyChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final database = project.database;
      switch (event.axis) {
        case OcptShotDifficultyAxis.set:
          await _shotListService.updateShot(
            database: database,
            shotId: event.shotId,
            difficultySet: Value(event.value),
          );
        case OcptShotDifficultyAxis.camera:
          await _shotListService.updateShot(
            database: database,
            shotId: event.shotId,
            difficultyCamera: Value(event.value),
          );
        case OcptShotDifficultyAxis.acting:
          await _shotListService.updateShot(
            database: database,
            shotId: event.shotId,
            difficultyActing: Value(event.value),
          );
        case OcptShotDifficultyAxis.sound:
          await _shotListService.updateShot(
            database: database,
            shotId: event.shotId,
            difficultySound: Value(event.value),
          );
      }
      emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to change the difficulty of shot "
          "${event.shotId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Attaches role `event.roleId` to shot `event.shotId` if it isn't already, detaches it
  /// otherwise, written immediately.
  Future<void> _onShotCharacterToggled(
    OcptShotListShotCharacterToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final shot = state.snapshot?.shotsById[event.shotId];
    if (project == null || shot == null) {
      return;
    }

    final isAttached = shot.characterRoleIds.contains(event.roleId);

    try {
      if (isAttached) {
        await _shotListService.detachCharacter(
          database: project.database,
          shotId: event.shotId,
          roleId: event.roleId,
        );
      } else {
        await _shotListService.attachCharacter(
          database: project.database,
          shotId: event.shotId,
          roleId: event.roleId,
        );
      }
      emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to toggle role ${event.roleId} on "
          "shot ${event.shotId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Resolves `event.characterName` to a live role, or **creates** a hand-added silent one linked
  /// to the selected episode (decision 1), then attaches it to shot `event.shotId`: the inspector's
  /// `＋ Add` field, dispatched once submitted. Written immediately, and reloads both the snapshot
  /// and the whole cast, since this is the one shot list action that can mint a fresh role.
  Future<void> _onCharacterAddRequested(
    OcptShotListCharacterAddRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final roleId = await _shotListService.resolveOrCreateRoleId(
        database: project.database,
        screenplayId: _screenplayIdOf(project),
        name: event.characterName,
      );
      if (roleId == null) {
        return;
      }

      await _shotListService.attachCharacter(
        database: project.database,
        shotId: event.shotId,
        roleId: roleId,
      );
      emitter(
        state.copyWith(snapshot: await _loadSnapshot(project), roles: await _loadRoles(project)),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to add character ${event.characterName} to "
          "shot ${event.shotId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Deletes shot `event.shotId`, reselecting the sequence's own next first shot when it was the
  /// selected one (the sequence stays selected; null only while the sequence now holds none at all
  /// — the "always a current shot" invariant, R2), and dropping any pending field or panel comment
  /// edit that still targeted it or one of its panels — `OcptShotListService.deleteShot`'s own
  /// cascade tombstones the shot's panels alongside it, so there is nothing left for either to
  /// write to.
  Future<void> _onShotDeletionRequested(
    OcptShotListShotDeletionRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final panelIds = state.panelsOfShot(event.shotId).map((panel) => panel.id).toSet();
    final annotationIds = state
        .panelsOfShot(event.shotId)
        .expand((panel) => panel.annotations)
        .map((annotation) => annotation.id)
        .toSet();
    final floorPlanSets = state.floorPlanSnapshot?.setsById.values;
    final floorPlanSymbolIds = <String>{
      if (floorPlanSets != null)
        for (final floorPlanSet in floorPlanSets)
          for (final symbol in floorPlanSet.symbols)
            if (symbol.shotId == event.shotId) symbol.id,
    };
    final pendingWithoutShot = Map<OcptShotListPendingEditKey, String>.of(state.pendingFieldEdits)
      ..removeWhere(
        (key, _) => switch (key) {
          OcptShotListShotFieldEditKey(:final shotId) => shotId == event.shotId,
          OcptShotListPanelCommentEditKey(:final panelId) => panelIds.contains(panelId),
          OcptShotListAnnotationTextEditKey(:final annotationId) =>
            annotationIds.contains(annotationId),
          OcptShotListSetNameEditKey() => false,
          OcptShotListSymbolLabelEditKey(:final symbolId) => floorPlanSymbolIds.contains(symbolId),
        },
      );
    if (pendingWithoutShot.isEmpty) {
      _fieldEditTimer?.cancel();
      _fieldEditTimer = null;
    }

    final wasSelected = state.selectedShotId == event.shotId;
    final wasPanelSelected = panelIds.contains(state.selectedPanelId);
    final wasFloorPlanSymbolSelected = floorPlanSymbolIds.contains(
      state.selectedFloorPlanSymbolId,
    );

    try {
      await _shotListService.deleteShot(database: project.database, shotId: event.shotId);
      final snapshot = await _loadSnapshot(project);
      final reselectedShotId = wasSelected
          ? _firstShotIdOf(snapshot: snapshot, sequenceId: state.selectedSequenceId)
          : state.selectedShotId;

      emitter(
        state.copyWith(
          snapshot: snapshot,
          suggestions: await _loadSuggestions(project),
          storyboardSnapshot: await _loadStoryboard(project),
          // `OcptShotListService.deleteShot`'s own cascade tombstones the shot's floor plan
          // symbols and arrows alongside it (`OcptFloorPlanService.tombstoneFloorPlanRowsOfShot`),
          // so the floor plans view must re-read too, exactly as the board does above.
          floorPlanSnapshot: await _loadFloorPlans(project),
          pendingFieldEdits: pendingWithoutShot,
          selectedShotId: reselectedShotId,
          clearSelectedShotId: reselectedShotId == null,
          clearSelectedPanelId: wasSelected || wasPanelSelected,
          clearActiveAnnotationTool: wasSelected || wasPanelSelected,
          clearSelectedAnnotationId: wasSelected || wasPanelSelected,
          clearPendingCoverageAnchor: wasSelected,
          clearSelectedFloorPlanSymbolId: wasSelected || wasFloorPlanSymbolSelected,
          clearSelectedFloorPlanArrowId: wasSelected || wasFloorPlanSymbolSelected,
          clearPendingFloorPlanArrowAnchorSymbolId: wasSelected,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to delete shot ${event.shotId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Deletes orphaned role `event.roleId` for good, written immediately: the shared role alert
  /// banner's orphaned variant's `Delete the role` action, dispatched once the mode's own
  /// `OcptConfirmDialog` has already confirmed it.
  Future<void> _onOrphanedRoleDeleteRequested(
    OcptShotListOrphanedRoleDeleteRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) => _writeRoleChange(
    emitter: emitter,
    logContext: "delete role ${event.roleId}",
    action: (project) =>
        _roleIndexService.deleteRole(database: project.database, roleId: event.roleId),
  );

  /// Keeps orphaned role `event.roleId` as a hand-added silent role, written immediately: the
  /// shared role alert banner's orphaned variant's `Keep as silent` action — not destructive, so
  /// reached with no confirmation dialog.
  Future<void> _onOrphanedRoleKept(
    OcptShotListOrphanedRoleKeptEvent event,
    Emitter<OcptShotListState> emitter,
  ) => _writeRoleChange(
    emitter: emitter,
    logContext: "keep orphaned role ${event.roleId} as silent",
    action: (project) =>
        _roleIndexService.keepOrphanedRoleAsSilent(database: project.database, roleId: event.roleId),
  );

  /// Merges role `event.sourceRoleId` into role `event.targetRoleId`, written immediately: the
  /// shared role alert banner's merge affordance — either variant — dispatched once the mode's own
  /// `OcptConfirmDialog` has already confirmed it.
  Future<void> _onRoleMergeRequested(
    OcptShotListRoleMergeRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) => _writeRoleChange(
    emitter: emitter,
    logContext: "merge role ${event.sourceRoleId} into ${event.targetRoleId}",
    action: (project) => _roleIndexService.mergeRole(
      database: project.database,
      sourceRoleId: event.sourceRoleId,
      targetRoleId: event.targetRoleId,
    ),
  );

  /// Writes a cast-wide role change through [action] and reloads both the snapshot and the whole
  /// cast, so every view derived from either (the shared role alert banner, a shot's own chips, the
  /// table's characters column) reflects what the database now says. Mirrors
  /// [_writeCoverageChange]'s own try/catch shape, for the three actions the shared role alert
  /// banner offers.
  Future<void> _writeRoleChange({
    required Emitter<OcptShotListState> emitter,
    required String logContext,
    required Future<void> Function(OcptOpenProjectModel project) action,
  }) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await action(project);
      emitter(
        state.copyWith(snapshot: await _loadSnapshot(project), roles: await _loadRoles(project)),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to $logContext of the project at "
          "${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Resolves a click on a scenario coverage word, exactly as `OcptShotListCoverageWordClickedEvent`
  /// documents: with no range open, a click on one of the selected shot's own already-covered words
  /// removes the range covering it and any other click opens a range on that word; with a range
  /// open, the click closes it wherever it lands. Written immediately, like every other coverage
  /// change; a stale click — a shot no longer selected, or nothing left to lay out — is silently
  /// ignored, since the layout the click was resolved against might no longer describe what is on
  /// screen.
  ///
  /// A closing click is never rejected for landing in another block than the one the range was
  /// opened in: a range legitimately runs from an action paragraph into the dialogue below it, and
  /// `OcptShotCoverageService.addRange` stopped enforcing anything about blocks along with it.
  ///
  /// The click that closes a range writes the characters that range covers alongside it, in the
  /// same [_writeCoverageChange] action so both land before the snapshot is re-read: see
  /// [_attachCharactersCoveredBy].
  Future<void> _onCoverageWordClicked(
    OcptShotListCoverageWordClickedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final layout = state.buildSelectedCoverageLayout();
    if (project == null || layout == null || state.selectedShotId != event.shotId) {
      return;
    }

    final anchor = state.pendingCoverageAnchor;

    if (anchor == null) {
      final coveringRange = layout.rangeAt(
        event.wordStartOffset,
        state.selectedShot?.coverageRanges ?? const [],
      );
      if (coveringRange == null) {
        emitter(
          state.copyWith(
            pendingCoverageAnchor: (
              wordStartOffset: event.wordStartOffset,
              wordEndOffset: event.wordEndOffset,
            ),
          ),
        );
        return;
      }

      await _writeCoverageChange(
        emitter: emitter,
        project: project,
        shotId: event.shotId,
        action: () => _shotCoverageService.removeRange(
          database: project.database,
          rangeId: coveringRange.id,
        ),
      );
      return;
    }

    final range = layout.rangeBetween(
      OcptScriptWord(
        text: layout.sceneText.substring(anchor.wordStartOffset, anchor.wordEndOffset),
        startOffset: anchor.wordStartOffset,
        endOffset: anchor.wordEndOffset,
      ),
      OcptScriptWord(
        text: layout.sceneText.substring(event.wordStartOffset, event.wordEndOffset),
        startOffset: event.wordStartOffset,
        endOffset: event.wordEndOffset,
      ),
    );

    await _writeCoverageChange(
      emitter: emitter,
      project: project,
      shotId: event.shotId,
      action: () async {
        await _shotCoverageService.addRange(
          database: project.database,
          shotId: event.shotId,
          sceneId: layout.sceneId,
          startOffset: range.startOffset,
          endOffset: range.endOffset,
          sceneText: layout.sceneText,
        );
        await _attachCharactersCoveredBy(
          project: project,
          shotId: event.shotId,
          layout: layout,
          range: range,
        );
      },
    );
  }

  /// Attaches to shot [shotId] every character the range just recorded covers, so selecting a
  /// shot's scenario coverage ticks its character chips on its own instead of leaving the same
  /// names to be clicked twice.
  ///
  /// Deliberately additive: a range that stops covering a character (removed, or narrowed) never
  /// detaches anybody, since a shot's characters are the director's own list — a silent role, an
  /// extra, a character kept in frame through a reply they don't speak — and only the user knows
  /// which of them the coverage happens to explain. A role already attached is skipped, and so is a
  /// covered name matching no live role of [OcptShotListState.roles] — one not reconciled yet,
  /// which the next save resolves.
  Future<void> _attachCharactersCoveredBy({
    required OcptOpenProjectModel project,
    required String shotId,
    required OcptScriptWordLayout layout,
    required ({int startOffset, int endOffset}) range,
  }) async {
    final attachedRoleIds = state.snapshot?.shotsById[shotId]?.characterRoleIds ?? const <String>[];
    final covered = layout.charactersCoveredBy(
      startOffset: range.startOffset,
      endOffset: range.endOffset,
    );

    for (final characterName in covered) {
      final role = state.roles.firstWhereOrNull((role) => role.name == characterName);
      if (role == null || attachedRoleIds.contains(role.id)) {
        continue;
      }

      await _shotListService.attachCharacter(
        database: project.database,
        shotId: shotId,
        roleId: role.id,
      );
    }
  }

  /// Removes every scenario coverage range of shot `event.shotId`, written immediately: the
  /// inspector's `Clear all` action.
  Future<void> _onCoverageClearRequested(
    OcptShotListCoverageClearRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _writeCoverageChange(
      emitter: emitter,
      project: project,
      shotId: event.shotId,
      action: () => _shotCoverageService.clearRangesOfShot(
        database: project.database,
        shotId: event.shotId,
      ),
    );
  }

  /// Clears the pending coverage anchor, exactly as `OcptShotListCoverageAnchorCancelledEvent`
  /// documents: dispatched by the coverage dialog's `Escape`, a click on empty space in its script
  /// area, or the dialog closing. Leaves the selected shot's own coverage ranges untouched.
  Future<void> _onCoverageAnchorCancelled(
    OcptShotListCoverageAnchorCancelledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(clearPendingCoverageAnchor: true));
  }

  /// Clears shot `event.shotId`'s `needsCheck` flag and re-stamps every one of its scenario
  /// coverage ranges' digests to the screenplay's current text, written immediately: the
  /// inspector's `Needs checking` callout's `Mark as checked` button.
  ///
  /// Passes the whole [OcptShotListState.screenplayText], not a single scene's slice of it: the
  /// offsets `OcptShotCoverageService.markAsChecked` re-stamps are scene-relative to each range's
  /// own scene's `charStart`, and a shot's ranges may span more than one scene. This also clears a
  /// `needsCheck` the shot carries for `OcptShotCheckReason.sceneDeleted` (an orphaned shot, which
  /// has no range to re-stamp at all) exactly as it clears any other reason.
  Future<void> _onShotMarkedAsChecked(
    OcptShotListShotMarkedAsCheckedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _writeCoverageChange(
      emitter: emitter,
      project: project,
      shotId: event.shotId,
      action: () => _shotCoverageService.markAsChecked(
        database: project.database,
        shotId: event.shotId,
        currentFountainText: state.screenplayText,
      ),
    );
  }

  /// Writes a scenario coverage change through [action], reloads the snapshot so every dependent
  /// aggregate (the `modified` badge, the "also covered by" wash, a shot's `needsCheck`) reflects
  /// what the database now says, and clears the pending coverage anchor — a coverage write always
  /// leaves the interaction back at its initial, no-anchor state. Mirrors
  /// `_onShotDifficultyChanged`/`_onShotCharacterToggled`'s own try/catch shape.
  Future<void> _writeCoverageChange({
    required Emitter<OcptShotListState> emitter,
    required OcptOpenProjectModel project,
    required String shotId,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
      emitter(
        state.copyWith(snapshot: await _loadSnapshot(project), clearPendingCoverageAnchor: true),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to change the scenario coverage of shot "
          "$shotId of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true, clearPendingCoverageAnchor: true));
    }
  }

  /// Selects centre view `event.view`, dispatched by `OcptShotListCentreHeader`'s own switch, and
  /// persists it so reopening the mode restores it.
  ///
  /// Keeps [OcptShotListState.selectedShotId]/`.selectedSequenceId` untouched: the two views read
  /// the same selection.
  Future<void> _onCentreViewSelected(
    OcptShotListCentreViewSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _propertiesManager.shotListLastCentreView.store(event.view);
    emitter(state.copyWith(centreView: event.view));
  }

  /// Selects panel `event.panelId` on the board, dispatched by a click on one of the selected
  /// shot's own panel frames. Clears the annotation tool and mark selection: both are scoped to
  /// the panel that was selected before this one (`OcptShotListState.activeAnnotationTool`'s own
  /// doc comment).
  Future<void> _onPanelSelected(
    OcptShotListPanelSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(
      state.copyWith(
        selectedPanelId: event.panelId,
        clearActiveAnnotationTool: true,
        clearSelectedAnnotationId: true,
      ),
    );
  }

  /// Sets the board's common panel height, a view preference held for the session alone.
  Future<void> _onPanelSizeChanged(
    OcptShotListPanelSizeChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(boardPanelSize: event.size));
  }

  /// Picks a frame through the native "open" dialog, filtered to JPEG and PNG
  /// (`ocptStoryboardPanelImageFileExtensions`), appends a new panel of shot `event.shotId` and
  /// points it at the file picked, then selects the new panel. A cancelled dialog changes nothing
  /// at all.
  Future<void> _onPanelImportRequested(
    OcptShotListPanelImportRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final path = await _pickPanelImagePath(fileTypeLabel: event.fileTypeLabel);
    if (path == null) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final panelId = await _storyboardService.addPanel(
        database: project.database,
        shotId: event.shotId,
      );
      if (panelId == null) {
        return;
      }

      await _storyboardService.replacePanelImage(
        database: project.database,
        panelId: panelId,
        path: path,
      );
      emitter(
        state.copyWith(
          storyboardSnapshot: await _loadStoryboard(project),
          selectedPanelId: panelId,
          clearActiveAnnotationTool: true,
          clearSelectedAnnotationId: true,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to import a storyboard frame onto shot "
          "${event.shotId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Picks a fresh frame the same way [_onPanelImportRequested] does and re-points panel
  /// `event.panelId` at it, dispatched by its frame's own `Replace image` action. A cancelled
  /// dialog leaves the panel's current image untouched.
  Future<void> _onPanelReplaceRequested(
    OcptShotListPanelReplaceRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final path = await _pickPanelImagePath(fileTypeLabel: event.fileTypeLabel);
    if (path == null) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _storyboardService.replacePanelImage(
        database: project.database,
        panelId: event.panelId,
        path: path,
      );
      emitter(state.copyWith(storyboardSnapshot: await _loadStoryboard(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to replace the image of panel "
          "${event.panelId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Shows the native "open" dialog filtered to [ocptStoryboardPanelImageFileExtensions] and
  /// returns the path picked, or null when the user cancelled it, when it failed, or when the
  /// platform gave a file with no path at all.
  ///
  /// **The file itself is never read here** (`docs/adr/0013-binary-assets-referenced-by-path.md`):
  /// mirrors `OcptResourcesBloc._pickFilePath` exactly, a pick going to [FileSelectorManager]
  /// directly rather than through `OcptExportManager` since there is nothing to decode, only a
  /// path to keep.
  Future<String?> _pickPanelImagePath({required String fileTypeLabel}) async {
    final fileSelectorManager = _fileSelectorManager ?? globalGetIt().get<FileSelectorManager>();

    final selection = await fileSelectorManager.openSelector(
      allowedExtensions: ocptStoryboardPanelImageFileExtensions,
      label: fileTypeLabel,
    );

    final file = selection.value;
    if (!selection.status.isSuccess || file == null) {
      return null;
    }

    return file.path.isEmpty ? null : file.path;
  }

  /// Shows the native "open" dialog filtered to [ocptFloorPlanUnderlayImageFileExtensions] and
  /// returns the path picked, or null when the user cancelled it, when it failed, or when the
  /// platform gave a file with no path at all. The underlay's own sibling of
  /// [_pickPanelImagePath].
  Future<String?> _pickFloorPlanUnderlayPath({required String fileTypeLabel}) async {
    final fileSelectorManager = _fileSelectorManager ?? globalGetIt().get<FileSelectorManager>();

    final selection = await fileSelectorManager.openSelector(
      allowedExtensions: ocptFloorPlanUnderlayImageFileExtensions,
      label: fileTypeLabel,
    );

    final file = selection.value;
    if (!selection.status.isSuccess || file == null) {
      return null;
    }

    return file.path.isEmpty ? null : file.path;
  }

  /// Moves panel `event.panelId` of shot `event.shotId` to `event.newPosition`, writing exactly one
  /// row (`OcptStoryboardService.reorderPanel`), dispatched by the strip's own drag-to-reorder
  /// gesture.
  Future<void> _onPanelReordered(
    OcptShotListPanelReorderedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _storyboardService.reorderPanel(
        database: project.database,
        panelId: event.panelId,
        newPosition: event.newPosition,
      );
      emitter(state.copyWith(storyboardSnapshot: await _loadStoryboard(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to reorder panel ${event.panelId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Records the raw text just typed into panel `event.panelId`'s comment as a pending edit, and
  /// (re)starts the field-edit debounce shared with [_onShotFieldChanged].
  Future<void> _onPanelCommentChanged(
    OcptShotListPanelCommentChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    _recordPendingEdit(
      emitter: emitter,
      key: OcptShotListPanelCommentEditKey(panelId: event.panelId),
      rawValue: event.rawValue,
    );
  }

  /// Deletes panel `event.panelId` for good, dispatched once the inspector's Panels group's own
  /// `Delete panel` action has already been confirmed through `OcptConfirmDialog`, by the mode.
  /// Clears the panel selection (and, with it, the annotation tool and selection — see
  /// `OcptShotListState.activeAnnotationTool`'s own doc comment) and drops any pending comment or
  /// mark-text edit that still targeted it or one of its own marks —
  /// `OcptStoryboardService.deletePanel`'s own cascade tombstones them alongside it.
  Future<void> _onPanelDeletionRequested(
    OcptShotListPanelDeletionRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final wasSelected = state.selectedPanelId == event.panelId;
    final annotationIds = (state.storyboardSnapshot?.panelsByShotId.values
                .expand((panels) => panels)
                .firstWhereOrNull((panel) => panel.id == event.panelId)
                ?.annotations ??
            const [])
        .map((annotation) => annotation.id)
        .toSet();
    final pendingWithoutPanel = Map<OcptShotListPendingEditKey, String>.of(
      state.pendingFieldEdits,
    )..removeWhere(
        (key, _) => switch (key) {
          OcptShotListPanelCommentEditKey(:final panelId) => panelId == event.panelId,
          OcptShotListAnnotationTextEditKey(:final annotationId) =>
            annotationIds.contains(annotationId),
          OcptShotListShotFieldEditKey() => false,
          OcptShotListSetNameEditKey() => false,
          OcptShotListSymbolLabelEditKey() => false,
        },
      );

    try {
      await _storyboardService.deletePanel(database: project.database, panelId: event.panelId);
      emitter(
        state.copyWith(
          storyboardSnapshot: await _loadStoryboard(project),
          pendingFieldEdits: pendingWithoutPanel,
          clearSelectedPanelId: wasSelected,
          clearActiveAnnotationTool: wasSelected,
          clearSelectedAnnotationId: wasSelected,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to delete panel ${event.panelId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Sets the board's active annotation tool, dispatched by the inspector's own `Annotate`
  /// control — `event.tool` is null both for "turn it off" and for the control's own toggle-off
  /// gesture (picking the tool already on again), so this always writes through
  /// `clearActiveAnnotationTool` rather than leaning on `copyWith`'s `??` fallback, which could
  /// never move a nullable field back to null.
  Future<void> _onAnnotationToolSelected(
    OcptShotListAnnotationToolSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final tool = event.tool;
    emitter(
      state.copyWith(activeAnnotationTool: tool, clearActiveAnnotationTool: tool == null),
    );
  }

  /// Adds a mark of `event.kind` to panel `event.panelId` at the normalised tail/head just dragged
  /// out on its own frame, then selects the freshly minted mark
  /// (`OcptStoryboardService.addAnnotation`).
  Future<void> _onAnnotationDrawn(
    OcptShotListAnnotationDrawnEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final annotationId = await _storyboardService.addAnnotation(
        database: project.database,
        panelId: event.panelId,
        kind: event.kind,
        x1: event.x1,
        y1: event.y1,
        x2: event.x2,
        y2: event.y2,
      );
      if (annotationId == null) {
        return;
      }

      emitter(
        state.copyWith(
          storyboardSnapshot: await _loadStoryboard(project),
          selectedAnnotationId: annotationId,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to draw a ${event.kind} mark onto panel "
          "${event.panelId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Places a label on panel `event.panelId` at the normalised point just clicked, then selects
  /// the freshly minted mark so its own text field opens ready for typing
  /// (`OcptStoryboardService.addAnnotation`).
  Future<void> _onAnnotationPlaced(
    OcptShotListAnnotationPlacedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final annotationId = await _storyboardService.addAnnotation(
        database: project.database,
        panelId: event.panelId,
        kind: OcptStoryboardAnnotationKind.label,
        x1: event.x1,
        y1: event.y1,
      );
      if (annotationId == null) {
        return;
      }

      emitter(
        state.copyWith(
          storyboardSnapshot: await _loadStoryboard(project),
          selectedAnnotationId: annotationId,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to place a label onto panel "
          "${event.panelId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Selects mark `event.annotationId`, dispatched by a click on it — on its own frame's overlay,
  /// or on its row of the inspector Panels group's annotation section.
  Future<void> _onAnnotationSelected(
    OcptShotListAnnotationSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(selectedAnnotationId: event.annotationId));
  }

  /// Records the raw text just typed into mark `event.annotationId`'s own text as a pending edit,
  /// and (re)starts the field-edit debounce shared with [_onShotFieldChanged] and
  /// [_onPanelCommentChanged].
  Future<void> _onAnnotationTextChanged(
    OcptShotListAnnotationTextChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    _recordPendingEdit(
      emitter: emitter,
      key: OcptShotListAnnotationTextEditKey(annotationId: event.annotationId),
      rawValue: event.rawValue,
    );
  }

  /// Deletes mark `event.annotationId` for good, dispatched once the annotation section's own
  /// remove action has already been confirmed through `OcptConfirmDialog`, by the mode. Clears the
  /// mark's own selection and drops any pending text edit that still targeted it.
  Future<void> _onAnnotationDeletionRequested(
    OcptShotListAnnotationDeletionRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final wasSelected = state.selectedAnnotationId == event.annotationId;
    final pendingWithoutAnnotation = Map<OcptShotListPendingEditKey, String>.of(
      state.pendingFieldEdits,
    )..removeWhere(
        (key, _) =>
            key is OcptShotListAnnotationTextEditKey &&
            key.annotationId == event.annotationId,
      );

    try {
      await _storyboardService.deleteAnnotation(
        database: project.database,
        annotationId: event.annotationId,
      );
      emitter(
        state.copyWith(
          storyboardSnapshot: await _loadStoryboard(project),
          pendingFieldEdits: pendingWithoutAnnotation,
          clearSelectedAnnotationId: wasSelected,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to delete mark ${event.annotationId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Selects set `event.setId` on the floor plans view, clearing the symbol selection: a symbol
  /// only ever belongs to the set currently shown.
  Future<void> _onSetSelected(
    OcptShotListSetSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(
      state.copyWith(
        selectedSetId: event.setId,
        clearSelectedFloorPlanSymbolId: true,
        clearSelectedFloorPlanArrowId: true,
        clearPendingFloorPlanArrowAnchorSymbolId: true,
      ),
    );
  }

  /// Creates a new Resources set named after the selected sequence's own heading place, links it
  /// to that sequence (`OcptLocationsService.createSetLinkedToScene`, the breakdown's own path),
  /// reloads the floor plans and selects it. Deliberately a no-op when the selected sequence is the
  /// orphan group (or when nothing is selected at all): see
  /// [OcptShotListSetCreationRequestedEvent].
  Future<void> _onSetCreationRequested(
    OcptShotListSetCreationRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final sequence = state.selectedSequence;
    if (project == null || sequence is! OcptSceneShotSequence) {
      return;
    }

    try {
      final setId = await _locationsService.createSetLinkedToScene(
        database: project.database,
        sceneId: sequence.sceneId,
        name: ocptSceneHeadingPlaceOf(sequence.heading),
      );
      if (setId == null) {
        return;
      }

      emitter(
        state.copyWith(
          floorPlanSnapshot: await _loadFloorPlans(project),
          selectedSetId: setId,
          clearSelectedFloorPlanSymbolId: true,
          clearSelectedFloorPlanArrowId: true,
          clearPendingFloorPlanArrowAnchorSymbolId: true,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to create a floor plan set on scene "
          "${sequence.sceneId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Records the raw text just typed into set `event.setId`'s own tab as a pending edit, and
  /// (re)starts the field-edit debounce shared with [_onShotFieldChanged] and
  /// [_onPanelCommentChanged].
  Future<void> _onSetNameChanged(
    OcptShotListSetNameChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    _recordPendingEdit(
      emitter: emitter,
      key: OcptShotListSetNameEditKey(setId: event.setId),
      rawValue: event.rawValue,
    );
  }

  /// Unlinks set `event.setId` from the selected sequence
  /// (`OcptLocationsService.removeSceneFromSet`), dispatched once the tab's own close action has
  /// already been confirmed through `OcptConfirmDialog`, by the mode. The plan itself — its
  /// underlay, its symbols, its arrows — is untouched: relinking the same set brings every
  /// placement back. Selects the sequence's own next first set when it was the selected one
  /// (clearing the symbol selection alongside it).
  Future<void> _onSetDeletionRequested(
    OcptShotListSetDeletionRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final sceneId = state.selectedSequenceId;
    if (project == null || sceneId == null) {
      return;
    }

    final wasSelected = state.selectedSetId == event.setId;
    final pendingWithoutSet = Map<OcptShotListPendingEditKey, String>.of(state.pendingFieldEdits)
      ..removeWhere((key, _) => key is OcptShotListSetNameEditKey && key.setId == event.setId);

    try {
      await _locationsService.removeSceneFromSet(
        database: project.database,
        sceneId: sceneId,
        setId: event.setId,
      );
      final floorPlanSnapshot = await _loadFloorPlans(project);
      final nextSetId = wasSelected
          ? _firstSetIdOf(
              floorPlanSnapshot: floorPlanSnapshot,
              sequenceId: state.selectedSequenceId,
            )
          : state.selectedSetId;

      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          pendingFieldEdits: pendingWithoutSet,
          selectedSetId: nextSetId,
          clearSelectedSetId: nextSetId == null,
          clearSelectedFloorPlanSymbolId: wasSelected,
          clearSelectedFloorPlanArrowId: wasSelected,
          clearPendingFloorPlanArrowAnchorSymbolId: wasSelected,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to unlink set ${event.setId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Duplicates set `event.setId` into a new Resources set in the same location, named
  /// `event.newSetName`, copying its set-scope symbols only and linking it to the selected
  /// sequence — the set tabs' own `＋ Set` menu `Duplicate this set` entry, put together from three
  /// calls across the two services this bloc holds (see `OcptFloorPlanService.duplicateSet`'s own
  /// doc comment for why): `OcptLocationsService.createSiblingSet` mints the new set,
  /// `OcptFloorPlanService.duplicateSet` copies its plan, and `OcptLocationsService
  /// .assignSceneToSet` links it — rolling back (tombstoning the freshly minted set) if the link
  /// somehow fails. Reloads the floor plans and selects the freshly minted copy.
  Future<void> _onSetDuplicationRequested(
    OcptShotListSetDuplicationRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final sceneId = state.selectedSequenceId;
    if (project == null || sceneId == null) {
      return;
    }

    try {
      final newSetId = await _locationsService.createSiblingSet(
        database: project.database,
        sourceSetId: event.setId,
        name: event.newSetName,
      );
      if (newSetId == null) {
        return;
      }

      await _floorPlanService.duplicateSet(
        database: project.database,
        sourceSetId: event.setId,
        destinationSetId: newSetId,
      );

      final linkId = await _locationsService.assignSceneToSet(
        database: project.database,
        sceneId: sceneId,
        setId: newSetId,
      );
      if (linkId == null) {
        await _locationsService.deleteSet(database: project.database, setId: newSetId);
        return;
      }

      emitter(
        state.copyWith(
          floorPlanSnapshot: await _loadFloorPlans(project),
          selectedSetId: newSetId,
          clearSelectedFloorPlanSymbolId: true,
          clearSelectedFloorPlanArrowId: true,
          clearPendingFloorPlanArrowAnchorSymbolId: true,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to duplicate set ${event.setId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Copies shot `event.sourceShotId`'s own live blocking on set `event.setId` onto the currently
  /// focused shot (`OcptFloorPlanService.copyShotBlocking`), reloading the floor plans — the set
  /// tabs' own `＋ Set` menu `Copy blocking from another shot` entry, dispatched once the mode's
  /// own source-shot picker returns a pick. A no-op while no shot is focused (defensive only: the
  /// mode never offers the menu entry without one).
  Future<void> _onFloorPlanBlockingCopyRequested(
    OcptShotListFloorPlanBlockingCopyRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final destinationShotId = state.selectedShotId;
    if (project == null || destinationShotId == null) {
      return;
    }

    try {
      await _floorPlanService.copyShotBlocking(
        database: project.database,
        sourceSetId: event.setId,
        sourceShotId: event.sourceShotId,
        destinationSetId: event.setId,
        destinationShotId: destinationShotId,
      );
      emitter(state.copyWith(floorPlanSnapshot: await _loadFloorPlans(project)));
    } catch (error) {
      appLogger().e(
        "A problem occurred when tried to copy shot ${event.sourceShotId}'s own blocking onto "
        "shot $destinationShotId of set ${event.setId} of the project at ${project.path}: $error",
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Records the floor plans canvas's own zoom as last settled by
  /// `OcptFloorPlanViewportController`. A view preference; see
  /// `OcptShotListState.floorPlanZoom`'s own doc comment.
  Future<void> _onFloorPlanZoomChanged(
    OcptShotListFloorPlanZoomChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(floorPlanZoom: event.zoom));
  }

  /// Picks the floor plans canvas's own active tool. A view preference.
  ///
  /// Clears the arrow tool's own pending anchor whenever a different tool is picked: leaving the
  /// arrow tool abandons whatever first click was still waiting for its second.
  Future<void> _onFloorPlanToolSelected(
    OcptShotListFloorPlanToolSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(
      state.copyWith(
        floorPlanActiveTool: event.tool,
        clearPendingFloorPlanArrowAnchorSymbolId: event.tool != OcptFloorPlanTool.arrow,
      ),
    );
  }

  /// Picks the sequence layer a placed set element lands on. A view preference.
  Future<void> _onFloorPlanActiveLayerChanged(
    OcptShotListFloorPlanActiveLayerChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(floorPlanActiveLayer: event.layer));
  }

  /// Picks the décor primitive a `setElement` placement carries. A view preference.
  Future<void> _onFloorPlanActiveSetElementShapeChanged(
    OcptShotListFloorPlanActiveSetElementShapeChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(floorPlanActiveSetElementShape: event.shape));
  }

  /// Toggles the visibility of sequence layer `event.layer` on the floor plans canvas. A view
  /// preference; never withheld under a read-only preview, since it only reads.
  Future<void> _onFloorPlanLayerVisibilityToggled(
    OcptShotListFloorPlanLayerVisibilityToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final hidden = Set<OcptFloorPlanLayer>.of(state.floorPlanHiddenLayers);
    if (!hidden.remove(event.layer)) {
      hidden.add(event.layer);
    }
    emitter(state.copyWith(floorPlanHiddenLayers: hidden));
  }

  /// Toggles the selected set's underlay visibility on the floor plans canvas. A view preference;
  /// never withheld under a read-only preview.
  Future<void> _onFloorPlanUnderlayVisibilityToggled(
    OcptShotListFloorPlanUnderlayVisibilityToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(isFloorPlanUnderlayHidden: !state.isFloorPlanUnderlayHidden));
  }

  /// Places a new symbol on set `event.setId`'s `event.layer`, at `event.xM`/`event.yM`, carrying
  /// `event.setElementShape` on a décor placement, then selects it
  /// (`OcptFloorPlanService.placeSymbol`). Written immediately.
  ///
  /// `event.shotId` is null on a sequence layer (the `setElement` tool) and the focused shot's id
  /// on a shot layer (the `camera`/`character`/`light` tools), exactly what the canvas resolves
  /// from its own active tool before dispatching this — see `OcptFloorPlanCanvas`'s own doc
  /// comment. A freshly placed character symbol's own [_defaultCharacterLabelFor] pre-fills its
  /// label from the shot's own characters field, the mock-up's "offered first as a convenience"
  /// (`docs/plans/storyboard.md`, §4.3) — never a link, the placed symbol still carries no `roleId`
  /// — and also arms [OcptShotListState.pendingCharacterNamePromptSymbolId] (R2), so the mode opens
  /// `OcptFloorPlanCharacterNamePickerDialog` for it the moment placement lands, pre-filled with
  /// that very default and offering the shot's other characters too, letting the user confirm or
  /// change it on the spot rather than only through the inline label editor later.
  Future<void> _onFloorPlanSymbolPlaced(
    OcptShotListFloorPlanSymbolPlacedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final shotId = event.shotId;
    final label = event.layer == OcptFloorPlanLayer.characters && shotId != null
        ? _defaultCharacterLabelFor(setId: event.setId, shotId: shotId)
        : "";

    try {
      final symbolId = await _floorPlanService.placeSymbol(
        database: project.database,
        setId: event.setId,
        sceneId: null,
        shotId: shotId,
        layer: event.layer,
        xM: event.xM,
        yM: event.yM,
        label: label,
        setElementShape: event.setElementShape,
      );
      if (symbolId == null) {
        return;
      }

      final isCharacter = event.layer == OcptFloorPlanLayer.characters && shotId != null;
      emitter(
        state.copyWith(
          floorPlanSnapshot: await _loadFloorPlans(project),
          selectedFloorPlanSymbolId: symbolId,
          clearSelectedFloorPlanArrowId: true,
          pendingCharacterNamePromptSymbolId: isCharacter ? symbolId : null,
          clearPendingCharacterNamePromptSymbolId: !isCharacter,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to place a ${event.layer} symbol on set "
          "${event.setId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// The first of shot [shotId]'s own `OcptShot.characters` not already carried by one of its live
  /// character symbols on set [setId], or `""` while it has none left (or none at all) — the
  /// convenience pre-fill [_onFloorPlanSymbolPlaced] gives a freshly placed character symbol's own
  /// label.
  String _defaultCharacterLabelFor({required String setId, required String shotId}) {
    final shot = state.snapshot?.shotsById[shotId];
    if (shot == null || shot.characters.isEmpty) {
      return "";
    }

    final floorPlanSet = state.floorPlanSnapshot?.setsById[setId];
    final alreadyLabelled = {
      for (final symbol in floorPlanSet?.symbols ?? const <OcptFloorPlanSymbol>[])
        if (symbol.shotId == shotId &&
            symbol.layer == OcptFloorPlanLayer.characters &&
            symbol.label.isNotEmpty)
          symbol.label,
    };

    for (final characterName in shot.characters) {
      if (!alreadyLabelled.contains(characterName)) {
        return characterName;
      }
    }
    return "";
  }

  /// Selects symbol `event.symbolId`, or clears the selection when it is null. Also clears the
  /// arrow selection when a symbol actually gets selected: the two are mutually exclusive on the
  /// canvas.
  Future<void> _onFloorPlanSymbolSelected(
    OcptShotListFloorPlanSymbolSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final symbolId = event.symbolId;
    emitter(
      state.copyWith(
        selectedFloorPlanSymbolId: symbolId,
        clearSelectedFloorPlanSymbolId: symbolId == null,
        clearSelectedFloorPlanArrowId: symbolId != null,
      ),
    );
  }

  /// Moves symbol `event.symbolId` to `event.xM`/`event.yM`, writing exactly one row, dispatched
  /// once a drag on it ends.
  Future<void> _onFloorPlanSymbolMoved(
    OcptShotListFloorPlanSymbolMovedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.updateSymbol(
        database: project.database,
        symbolId: event.symbolId,
        xM: Value(event.xM),
        yM: Value(event.yM),
      );
      emitter(state.copyWith(floorPlanSnapshot: await _loadFloorPlans(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to move symbol ${event.symbolId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Resizes symbol `event.symbolId` to `event.widthM`/`event.heightM`, writing exactly one row,
  /// dispatched once a drag on its own resize handle ends.
  Future<void> _onFloorPlanSymbolResized(
    OcptShotListFloorPlanSymbolResizedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.updateSymbol(
        database: project.database,
        symbolId: event.symbolId,
        widthM: Value(event.widthM),
        heightM: Value(event.heightM),
      );
      emitter(state.copyWith(floorPlanSnapshot: await _loadFloorPlans(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to resize symbol ${event.symbolId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Rotates symbol `event.symbolId` to `event.rotationDeg`, writing exactly one row, dispatched
  /// once a drag on its own rotate handle ends.
  Future<void> _onFloorPlanSymbolRotated(
    OcptShotListFloorPlanSymbolRotatedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.updateSymbol(
        database: project.database,
        symbolId: event.symbolId,
        rotationDeg: Value(event.rotationDeg),
      );
      emitter(state.copyWith(floorPlanSnapshot: await _loadFloorPlans(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to rotate symbol ${event.symbolId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Deletes symbol `event.symbolId` for good, dispatched once the canvas's own delete action has
  /// already been confirmed through `OcptConfirmDialog`, by the mode. Clears the symbol's own
  /// selection when it was the selected one.
  Future<void> _onFloorPlanSymbolDeletionRequested(
    OcptShotListFloorPlanSymbolDeletionRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final wasSelected = state.selectedFloorPlanSymbolId == event.symbolId;

    try {
      await _floorPlanService.deleteSymbol(database: project.database, symbolId: event.symbolId);
      emitter(
        state.copyWith(
          floorPlanSnapshot: await _loadFloorPlans(project),
          clearSelectedFloorPlanSymbolId: wasSelected,
          // `OcptFloorPlanService.deleteSymbol`'s own cascade tombstones every arrow touching this
          // symbol, so the selected arrow (if any) may no longer exist.
          clearSelectedFloorPlanArrowId: true,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to delete symbol ${event.symbolId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Picks a file through the native "open" dialog, filtered to JPEG and PNG
  /// (`ocptFloorPlanUnderlayImageFileExtensions`), and sets set `event.setId`'s underlay to it,
  /// framed at a default rectangle centred on the canvas (`_defaultUnderlayXM`/…): the user drags
  /// and resizes it afterwards to match the reference silhouette (ADR 0031). A cancelled dialog
  /// changes nothing at all.
  Future<void> _onFloorPlanUnderlayImportRequested(
    OcptShotListFloorPlanUnderlayImportRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final path = await _pickFloorPlanUnderlayPath(fileTypeLabel: event.fileTypeLabel);
    if (path == null) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.setSetUnderlay(
        database: project.database,
        setId: event.setId,
        path: path,
        xM: _defaultUnderlayXM,
        yM: _defaultUnderlayYM,
        widthM: _defaultUnderlayWidthM,
        heightM: _defaultUnderlayHeightM,
      );
      emitter(state.copyWith(floorPlanSnapshot: await _loadFloorPlans(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to import the underlay of set "
          "${event.setId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Re-frames set `event.setId`'s underlay to `event.xM`/`event.yM`/`event.widthM`/
  /// `event.heightM`, dispatched once a drag moving or resizing it ends.
  /// `OcptFloorPlanService.updateUnderlayFrame` — never `setSetUnderlay`, which would tombstone
  /// and re-mint the underlay's own `assets` row on every drag-end — is the one write this touches;
  /// its own current rotation is left alone, since this milestone builds no underlay rotate handle.
  /// A no-op while the set carries no underlay at all (nothing to move).
  Future<void> _onFloorPlanUnderlayTransformChanged(
    OcptShotListFloorPlanUnderlayTransformChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final floorPlanSet = state.floorPlanSnapshot?.setsById[event.setId];
    if (floorPlanSet?.underlayAssetId == null) {
      return;
    }

    try {
      await _floorPlanService.updateUnderlayFrame(
        database: project.database,
        setId: event.setId,
        xM: Value(event.xM),
        yM: Value(event.yM),
        widthM: Value(event.widthM),
        heightM: Value(event.heightM),
      );
      emitter(state.copyWith(floorPlanSnapshot: await _loadFloorPlans(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to move/resize the underlay of set "
          "${event.setId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Clears set `event.setId`'s underlay for good, dispatched once the tray's own `Clear
  /// underlay` action has already been confirmed through `OcptConfirmDialog`, by the mode.
  Future<void> _onFloorPlanUnderlayClearRequested(
    OcptShotListFloorPlanUnderlayClearRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.clearSetUnderlay(database: project.database, setId: event.setId);
      emitter(state.copyWith(floorPlanSnapshot: await _loadFloorPlans(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to clear the underlay of set "
          "${event.setId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Walks the selected sequence's own shots by `event.delta`, dispatched by the floor plans focus
  /// strip's own `←`/`→` keyboard shortcut: see [OcptShotListFloorPlanShotWalkRequestedEvent]'s own
  /// doc comment for the full rule. Reuses [_onShotSelected]'s own body — walking to a neighbour is
  /// exactly selecting it.
  Future<void> _onFloorPlanShotWalkRequested(
    OcptShotListFloorPlanShotWalkRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final sequence = state.selectedSequence;
    if (sequence is! OcptSceneShotSequence || sequence.shots.isEmpty) {
      return;
    }

    final selectedShotId = state.selectedShotId;
    if (selectedShotId == null) {
      if (event.delta > 0) {
        await _onShotSelected(
          OcptShotListShotSelectedEvent(shotId: sequence.shots.first.id),
          emitter,
        );
      }
      return;
    }

    final neighbour = event.delta < 0
        ? state.previousShotOfSelectedShot
        : state.nextShotOfSelectedShot;
    if (neighbour == null) {
      return;
    }

    await _onShotSelected(OcptShotListShotSelectedEvent(shotId: neighbour.id), emitter);
  }

  /// Toggles the visibility of camera symbol `event.symbolId` on the floor plans canvas. A view
  /// preference; never withheld under a read-only preview, since it only reads.
  Future<void> _onFloorPlanCameraVisibilityToggled(
    OcptShotListFloorPlanCameraVisibilityToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final hidden = Set<String>.of(state.floorPlanHiddenCameraSymbolIds);
    if (!hidden.remove(event.symbolId)) {
      hidden.add(event.symbolId);
    }
    emitter(state.copyWith(floorPlanHiddenCameraSymbolIds: hidden));
  }

  /// Toggles the onion skin's own previous or next ghost. A view preference.
  Future<void> _onFloorPlanOnionSkinToggled(
    OcptShotListFloorPlanOnionSkinToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(
      event.isPrevious
          ? state.copyWith(
              isFloorPlanOnionSkinPreviousShown: !state.isFloorPlanOnionSkinPreviousShown,
            )
          : state.copyWith(isFloorPlanOnionSkinNextShown: !state.isFloorPlanOnionSkinNextShown),
    );
  }

  /// Sets the onion skin's own ghost opacity, clamped to a visible range. A view preference.
  Future<void> _onFloorPlanOnionSkinOpacityChanged(
    OcptShotListFloorPlanOnionSkinOpacityChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(floorPlanOnionSkinOpacity: event.opacity.clamp(0.05, 1.0)));
  }

  /// Toggles the metrics overlay. A view preference.
  Future<void> _onFloorPlanMetricsToggled(
    OcptShotListFloorPlanMetricsToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(isFloorPlanMetricsShown: !state.isFloorPlanMetricsShown));
  }

  /// Toggles the focus strip's own "All cameras" toggle. A view preference; a display toggle only.
  Future<void> _onFloorPlanAllCamerasToggled(
    OcptShotListFloorPlanAllCamerasToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(isFloorPlanAllCamerasShown: !state.isFloorPlanAllCamerasShown));
  }

  /// Resolves a tap on symbol `event.symbolId` while the arrow tool is active, exactly as
  /// `OcptShotListFloorPlanArrowSymbolTappedEvent` documents: with no anchor pending, picks it as
  /// the arrow's first end; with one already pending and a different symbol tapped, completes a
  /// movement arrow from the anchor to it, on the focused shot; a tap on the anchor itself is a
  /// no-op. Written immediately; a stale tap (no set or no shot focused any more) is silently
  /// ignored, mirroring [_onCoverageWordClicked]'s own guard.
  Future<void> _onFloorPlanArrowSymbolTapped(
    OcptShotListFloorPlanArrowSymbolTappedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final selectedSetId = state.selectedSetId;
    final selectedShotId = state.selectedShotId;
    if (project == null || selectedSetId == null || selectedShotId == null) {
      return;
    }

    final anchor = state.pendingFloorPlanArrowAnchorSymbolId;
    if (anchor == null) {
      emitter(state.copyWith(pendingFloorPlanArrowAnchorSymbolId: event.symbolId));
      return;
    }

    if (anchor == event.symbolId) {
      return;
    }

    try {
      await _floorPlanService.addArrow(
        database: project.database,
        setId: selectedSetId,
        shotId: selectedShotId,
        kind: OcptFloorPlanArrowKind.movement,
        fromSymbolId: anchor,
        toSymbolId: event.symbolId,
      );
      emitter(
        state.copyWith(
          floorPlanSnapshot: await _loadFloorPlans(project),
          clearPendingFloorPlanArrowAnchorSymbolId: true,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to add an arrow from symbol $anchor to "
          "${event.symbolId} of the project at ${project.path}: $error");
      emitter(
        state.copyWith(hasWriteError: true, clearPendingFloorPlanArrowAnchorSymbolId: true),
      );
    }
  }

  /// Cancels the arrow tool's own pending anchor, dispatched by `Escape` or a click on empty
  /// canvas while it is on. Leaves every arrow untouched, exactly as
  /// [_onCoverageAnchorCancelled] leaves every coverage range untouched.
  Future<void> _onFloorPlanArrowAnchorCancelled(
    OcptShotListFloorPlanArrowAnchorCancelledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(clearPendingFloorPlanArrowAnchorSymbolId: true));
  }

  /// Deletes arrow `event.arrowId` for good, dispatched once the Placements group's own remove
  /// action has already been confirmed through `OcptConfirmDialog`, by the mode. Clears the arrow's
  /// own selection when it was the selected one.
  Future<void> _onFloorPlanArrowDeletionRequested(
    OcptShotListFloorPlanArrowDeletionRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final wasSelected = state.selectedFloorPlanArrowId == event.arrowId;

    try {
      await _floorPlanService.deleteArrow(database: project.database, arrowId: event.arrowId);
      emitter(
        state.copyWith(
          floorPlanSnapshot: await _loadFloorPlans(project),
          clearSelectedFloorPlanArrowId: wasSelected,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to delete arrow ${event.arrowId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Records the raw text just typed into symbol `event.symbolId`'s own label as a pending edit,
  /// visible immediately, and (re)starts the field-edit debounce shared with every other typed
  /// field of the mode.
  Future<void> _onFloorPlanSymbolLabelChanged(
    OcptShotListFloorPlanSymbolLabelChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    _recordPendingEdit(
      emitter: emitter,
      key: OcptShotListSymbolLabelEditKey(symbolId: event.symbolId),
      rawValue: event.rawValue,
    );
  }

  /// Sets camera symbol `event.symbolId`'s own field-of-view wedge to `event.fovDeg`, dispatched by
  /// a drag on one of its own edge handles ending, or by the inspector's own Placements group
  /// `−`/`+` stepper. Written immediately, one row (`OcptFloorPlanService.updateSymbol(fovDeg:)`).
  Future<void> _onFloorPlanSymbolFovChanged(
    OcptShotListFloorPlanSymbolFovChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.updateSymbol(
        database: project.database,
        symbolId: event.symbolId,
        fovDeg: Value(event.fovDeg),
      );
      emitter(state.copyWith(floorPlanSnapshot: await _loadFloorPlans(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to change the field of view of symbol "
          "${event.symbolId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Sets camera symbol `event.symbolId`'s own field-of-view wedge reach to `event.fovReachM`,
  /// dispatched by a drag on its own tip handle ending. Written immediately
  /// (`OcptFloorPlanService.updateSymbol(fovReachM:)`), one row.
  Future<void> _onFloorPlanSymbolFovReachChanged(
    OcptShotListFloorPlanSymbolFovReachChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.updateSymbol(
        database: project.database,
        symbolId: event.symbolId,
        fovReachM: Value(event.fovReachM),
      );
      emitter(state.copyWith(floorPlanSnapshot: await _loadFloorPlans(project)));
    } catch (error) {
      appLogger().e(
        "A problem occurred when tried to change the field-of-view reach of symbol "
        "${event.symbolId} of the project at ${project.path}: $error",
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Selects arrow `event.arrowId`, or clears the selection when it is null. A view preference;
  /// also clears the symbol selection, the two being mutually exclusive on the canvas.
  Future<void> _onFloorPlanArrowSelected(
    OcptShotListFloorPlanArrowSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final arrowId = event.arrowId;
    emitter(
      state.copyWith(
        selectedFloorPlanArrowId: arrowId,
        clearSelectedFloorPlanArrowId: arrowId == null,
        clearSelectedFloorPlanSymbolId: arrowId != null,
      ),
    );
  }

  /// Bends arrow `event.arrowId` through `event.ctrlXM`/`event.ctrlYM`, or straightens it back out
  /// when both are null, writing exactly one row (`OcptFloorPlanService.updateArrowCurve`),
  /// dispatched once a drag on its own midpoint handle ends, or by its own straighten button.
  Future<void> _onFloorPlanArrowCurveChanged(
    OcptShotListFloorPlanArrowCurveChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.updateArrowCurve(
        database: project.database,
        arrowId: event.arrowId,
        ctrlXM: event.ctrlXM == null ? const Value(null) : Value(event.ctrlXM),
        ctrlYM: event.ctrlYM == null ? const Value(null) : Value(event.ctrlYM),
      );
      emitter(state.copyWith(floorPlanSnapshot: await _loadFloorPlans(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to bend arrow ${event.arrowId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Duplicates symbol `event.symbolId` into an independent copy — never a link — on the very same
  /// set/shot/layer, at `event.xM`/`event.yM` when given or offset from the source by
  /// `ocptFloorPlanDuplicateOffsetM` otherwise (`Ctrl+D`, which reports no position of its own),
  /// then selects the copy. A no-op while the source symbol can no longer be found (a stale
  /// shortcut on a canvas rebuilt underneath).
  Future<void> _onFloorPlanSymbolDuplicated(
    OcptShotListFloorPlanSymbolDuplicatedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final source = _findFloorPlanSymbol(event.symbolId);
    if (source == null) {
      return;
    }

    try {
      final symbolId = await _floorPlanService.placeSymbol(
        database: project.database,
        setId: source.setId,
        sceneId: source.sceneId,
        shotId: source.shotId,
        layer: source.layer,
        xM: event.xM ?? source.xM + ocptFloorPlanDuplicateOffsetM,
        yM: event.yM ?? source.yM + ocptFloorPlanDuplicateOffsetM,
        rotationDeg: source.rotationDeg,
        widthM: source.widthM,
        heightM: source.heightM,
        fovDeg: source.fovDeg,
        fovReachM: source.fovReachM,
        label: source.label,
        setElementShape: source.setElementShape,
      );
      if (symbolId == null) {
        return;
      }

      emitter(
        state.copyWith(
          floorPlanSnapshot: await _loadFloorPlans(project),
          selectedFloorPlanSymbolId: symbolId,
          clearSelectedFloorPlanArrowId: true,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to duplicate symbol ${event.symbolId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// The live `floor_plan_symbols` row [symbolId] names, searched across every set of
  /// [OcptShotListState.floorPlanSnapshot] — [_onFloorPlanSymbolDuplicated]'s own source lookup, the
  /// duplicate's every field but its position copied from here.
  OcptFloorPlanSymbol? _findFloorPlanSymbol(String symbolId) {
    for (final floorPlanSet in state.floorPlanSnapshot?.setsById.values ??
        const <OcptFloorPlanSet>[]) {
      for (final symbol in floorPlanSet.symbols) {
        if (symbol.id == symbolId) {
          return symbol;
        }
      }
    }
    return null;
  }

  /// Clears [OcptShotListState.pendingCharacterNamePromptSymbolId], dispatched by the mode's own
  /// listener the moment it opens `OcptFloorPlanCharacterNamePickerDialog` for it.
  Future<void> _onFloorPlanCharacterNamePromptDismissed(
    OcptShotListFloorPlanCharacterNamePromptDismissedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(clearPendingCharacterNamePromptSymbolId: true));
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// A further safety net alongside [flushPendingFieldEdits] (the mode's own `deactivate()`) and
  /// the flush every selection-changing handler already performs: whichever path the bloc closes
  /// through, a pending field edit still gets written rather than silently dropped, mirroring
  /// `OcptEditorBloc.disposeLifeCycle`'s own best-effort flush.
  @override
  Future<void> disposeLifeCycle() async {
    await flushPendingFieldEdits();
    return super.disposeLifeCycle();
  }
}
