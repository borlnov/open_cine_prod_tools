// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_asset_file_types.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_scope_decision.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_prop_summary.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_display_number.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_set_suggestion.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shot_list_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';

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
/// screenplay's Fountain text as last loaded, which `OcptShotListState.buildSelectedCoverageLayout`
/// slices a scene's own text
/// out of — loaded once here rather than by [_screenplayCharactersOf] on its own, which used to
/// parse the screenplay text a second time to derive the same list of speaking characters.
///
/// It also mixes in [MixinOcptProjectVersionsBloc], which owns everything the right dock's
/// `Versions` tab does: the project's versions are a property of the *project*, so that tab and
/// its state are shared with the screenplay mode rather than reimplemented here. The two hooks the
/// mixin needs are answered by [flushPendingProjectWrites] (a field edit still sitting in the
/// debounce must reach the working copy before a preview swaps the database out) and
/// [reloadFromProjectDatabase]. `_onRightDockTabSelected` and `_flushAllPendingWrites` each
/// dispatch [OcptProjectWorkingCopyRefreshRequestedEvent] — opening the `Versions` tab, and a
/// field edit landing while it is already open — the two moments the mixin's working-copy card is
/// worth a fresh, throttled read.
///
/// The actions that read the shot list rather than writing to it — its four exports — belong to
/// `OcptShotListExportBloc`, which asks this bloc to write every pending edit
/// ([flushAllPendingWrites]) and then reads the snapshots this bloc holds.
///
/// It mixes in [MixinOcptProjectPackageBloc] too, which writes the whole project out as a portable
/// package from the `Export` panel's own standing card. That mixin reuses
/// [flushPendingProjectWrites] — what a colleague receives is the project *file*, so a debounced
/// edit has to reach it first — and asks [exportManager] where to write, exactly as this mode's
/// own exports do.
class OcptShotListBloc extends BlocForMixin<OcptShotListState>
    with
        MixinOcptProjectVersionsBloc<OcptShotListState>,
        MixinOcptProjectPackageBloc<OcptShotListState>,
        MixinOcptModeBloc<OcptShotListState, OcptShotListReloadScope> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "shot_list_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger = buildOcptLogsHelper(_loggerCategory);

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
  /// own set tabs are `scene_sets` links now, so every tab
  /// operation but placing/editing what is drawn on a set goes through this service instead of
  /// [_floorPlanService].
  final OcptLocationsService _locationsService;

  /// The service used to read the focused sequence's own breakdown props, for the floor plans
  /// palette's own `Sequence` group chips.
  final OcptElementsService _elementsService;

  /// The manager used to pick a panel's frame or a set's underlay through the native "open"
  /// dialog, mirroring `OcptResourcesBloc`'s own `_pickFilePath`.
  final FileSelectorManager? _fileSelectorManager;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// The running field-edit debounce timer, if any.
  Timer? _fieldEditTimer;

  /// The episode this bloc reads and writes, handed down by `OcptShotListMode` from
  /// `OcptWorkspaceBloc.state.selectedEpisodeId` at construction time — safe to capture once rather
  /// than watch, since `OcptWorkspacePage` remounts this whole bloc on every episode switch (see
  /// `OcptWorkspacePage._buildActiveMode`'s own doc comment), so the field can never go stale.
  ///
  /// Null only for a project holding no episode at all: `OcptWorkspaceBloc` lands on the first one
  /// before it clears `isLoading`, and a mode is never built before that, so [_screenplayIdOf]'s
  /// fallback to [OcptOpenProjectModel.primaryScreenplayId] is the honest last resort rather than a
  /// routine path.
  final String? _selectedEpisodeId;

  /// What this mode should land on once its very first load resolves, handed down by
  /// `OcptShotListMode` from its own constructor — the Resources location sheet's own `Open in
  /// shot list`, mirroring `OcptResourcesBloc
  /// ._pendingRevealRequest`. Nulled the moment [_onLoadRequested] applies it, so it can never
  /// re-apply itself on a later reload (a version preview entered or left, say).
  OcptShotListRevealRequest? _pendingRevealRequest;

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
    OcptElementsService? elementsService,
    FileSelectorManager? fileSelectorManager,
    Duration fieldEditDebounce = defaultFieldEditDebounce,
    String? selectedEpisodeId,
    OcptShotListRevealRequest? revealRequest,
  }) : _selectedEpisodeId = selectedEpisodeId,
       _pendingRevealRequest = revealRequest,
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
       _elementsService =
           elementsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).elementsService,
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
    // The three selection events are awaitable: a view bloc moves the shared selection through
    // `addAndWait` and then emits its own state (see `MixinOcptModeBloc.addAndWait`).
    onAwaited<OcptShotListSequenceSelectedEvent>(_onSequenceSelected);
    onAwaited<OcptShotListShotSelectedEvent>(_onShotSelected);
    on<OcptShotListShotCreationRequestedEvent>(_onShotCreationRequested);
    on<OcptShotListSequencePanelToggledEvent>(_onSequencePanelToggled);
    on<OcptShotListRightDockTabSelectedEvent>(_onRightDockTabSelected);
    on<OcptShotListRightDockToggledEvent>(_onRightDockToggled);
    on<OcptShotListRightDockClosedEvent>(_onRightDockClosed);
    on<OcptShotListDockFractionsChangedEvent>(_onDockFractionsChanged);
    on<OcptShotListDockLayoutResetEvent>(_onDockLayoutReset);
    on<OcptShotListColumnToggledEvent>(_onColumnToggled);
    on<OcptShotListWriteErrorDismissedEvent>(_onWriteErrorDismissed);
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
    onAwaited<OcptShotListSetSelectedEvent>(_onSetSelected);
    on<OcptShotListSetCreationRequestedEvent>(_onSetCreationRequested);
    on<OcptShotListSetLinkRequestedEvent>(_onSetLinkRequested);
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
    on<OcptShotListFloorPlanActiveSetElementScopeChangedEvent>(
      _onFloorPlanActiveSetElementScopeChanged,
    );
    on<OcptShotListFloorPlanActiveLabelChangedEvent>(_onFloorPlanActiveLabelChanged);
    on<OcptShotListFloorPlanLayerVisibilityToggledEvent>(_onFloorPlanLayerVisibilityToggled);
    on<OcptShotListFloorPlanUnderlayVisibilityToggledEvent>(_onFloorPlanUnderlayVisibilityToggled);
    on<OcptShotListFloorPlanSymbolPlacedEvent>(_onFloorPlanSymbolPlaced);
    on<OcptShotListFloorPlanSymbolSelectedEvent>(_onFloorPlanSymbolSelected);
    on<OcptShotListFloorPlanSymbolMovedEvent>(_onFloorPlanSymbolMoved);
    on<OcptShotListFloorPlanSymbolResizedEvent>(_onFloorPlanSymbolResized);
    on<OcptShotListFloorPlanSymbolRotatedEvent>(_onFloorPlanSymbolRotated);
    on<OcptShotListFloorPlanSymbolDeletionRequestedEvent>(_onFloorPlanSymbolDeletionRequested);
    on<OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent>(
      _onFloorPlanSymbolDeleteEverywhereRequested,
    );
    on<OcptShotListFloorPlanSymbolHideRequestedEvent>(_onFloorPlanSymbolHideRequested);
    on<OcptShotListFloorPlanSymbolHideForShotRequestedEvent>(
      _onFloorPlanSymbolHideForShotRequested,
    );
    on<OcptShotListFloorPlanSymbolRestoreRequestedEvent>(_onFloorPlanSymbolRestoreRequested);
    on<OcptShotListFloorPlanScopeDecisionRequestedEvent>(_onFloorPlanScopeDecisionRequested);
    on<OcptShotListFloorPlanScopeDecisionResolvedEvent>(_onFloorPlanScopeDecisionResolved);
    on<OcptShotListFloorPlanUnderlayImportRequestedEvent>(_onFloorPlanUnderlayImportRequested);
    on<OcptShotListFloorPlanUnderlayTransformChangedEvent>(_onFloorPlanUnderlayTransformChanged);
    on<OcptShotListFloorPlanUnderlayClearRequestedEvent>(_onFloorPlanUnderlayClearRequested);
    on<OcptShotListFloorPlanShotWalkRequestedEvent>(_onFloorPlanShotWalkRequested);
    on<OcptShotListFloorPlanCameraVisibilityToggledEvent>(_onFloorPlanCameraVisibilityToggled);
    on<OcptShotListFloorPlanOnionSkinToggledEvent>(_onFloorPlanOnionSkinToggled);
    on<OcptShotListFloorPlanOnionSkinOpacityChangedEvent>(_onFloorPlanOnionSkinOpacityChanged);
    on<OcptShotListFloorPlanMetricsToggledEvent>(_onFloorPlanMetricsToggled);
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
      _flushAllPendingWrites(emitter);

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.flushAllPendingWritesIn}
  @protected
  @override
  Future<void> flushAllPendingWritesIn(Emitter<OcptShotListState> emitter) =>
      _flushAllPendingWrites(emitter);

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.reloadScopesIn}
  ///
  /// A failed read raises the transient write error, like a failed write: the view that asked has
  /// already written its row, and what is on screen no longer says what the database holds.
  @protected
  @override
  Future<void> reloadScopesIn(
    Set<OcptShotListReloadScope> scopes,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      OcptShotListSnapshot? snapshot;
      OcptShotFieldSuggestions? suggestions;
      OcptStoryboardSnapshot? storyboardSnapshot;
      OcptFloorPlanSnapshot? floorPlanSnapshot;
      List<OcptLocation>? locations;
      Map<String, List<OcptFloorPlanSymbol>>? setScopeSymbolsBySetId;
      List<OcptRole>? roles;

      // A switch statement over an enum must name every value: a scope added to the enum does not
      // compile until it is read here.
      for (final scope in scopes) {
        switch (scope) {
          case OcptShotListReloadScope.snapshot:
            snapshot = await _loadSnapshot(project);
          case OcptShotListReloadScope.suggestions:
            suggestions = await _loadSuggestions(project);
          case OcptShotListReloadScope.storyboard:
            storyboardSnapshot = await _loadStoryboard(project);
          case OcptShotListReloadScope.floorPlans:
            floorPlanSnapshot = await _loadFloorPlans(project);
          case OcptShotListReloadScope.locations:
            locations = await _loadLocations(project);
          case OcptShotListReloadScope.setScopeSymbols:
            setScopeSymbolsBySetId = await _loadSetScopeSymbolsBySetId(project);
          case OcptShotListReloadScope.roles:
            roles = await _loadRoles(project);
        }
      }

      emitter(
        state.copyWith(
          snapshot: snapshot,
          suggestions: suggestions,
          storyboardSnapshot: storyboardSnapshot,
          floorPlanSnapshot: floorPlanSnapshot,
          locations: locations,
          setScopeSymbolsBySetId: setScopeSymbolsBySetId,
          roles: roles,
          reloadEpoch: state.reloadEpoch + 1,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to read again the $scopes of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

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
          forcePreviewedVersionIdValue: true,
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
    final locations = await _loadLocations(project);
    final setScopeSymbolsBySetId = await _loadSetScopeSymbolsBySetId(project);
    final screenplayCharacters = _screenplayCharactersOf(screenplayText);
    final roles = await _loadRoles(project);
    final suggestions = await _loadSuggestions(project);

    final revealRequest = _pendingRevealRequest;
    _pendingRevealRequest = null;
    final revealedSequenceId = ocptRevealedSequenceIdOf(
      revealRequest: revealRequest,
      snapshot: snapshot,
    );

    final selectedSequenceId =
        revealedSequenceId ?? (snapshot.sequences.isEmpty ? null : snapshot.sequences.first.id);
    final firstSetId = ocptFirstSetIdOf(
      floorPlanSnapshot: floorPlanSnapshot,
      sequenceId: selectedSequenceId,
    );
    final revealedSetId = ocptRevealedSetIdOf(
      revealRequest: revealRequest,
      floorPlanSnapshot: floorPlanSnapshot,
      sequenceId: selectedSequenceId,
    );
    final selectedSetId = revealedSetId ?? firstSetId;
    final firstShotId = ocptFirstShotIdOf(snapshot: snapshot, sequenceId: selectedSequenceId);
    final effectiveCentreView = revealedSequenceId != null
        ? OcptShotListCentreView.floorPlans
        : centreView;
    final propsOfSelectedSequence = await _loadPropsOfSequence(
      project: project,
      sequences: snapshot.sequences,
      sequenceId: selectedSequenceId,
    );

    emitter(
      state.copyWith(
        isLoading: false,
        title: project.name,
        previewedVersionId: previewedVersion?.id,
        forcePreviewedVersionIdValue: previewedVersion == null,
        snapshot: snapshot,
        storyboardSnapshot: storyboardSnapshot,
        floorPlanSnapshot: floorPlanSnapshot,
        locations: locations,
        setScopeSymbolsBySetId: setScopeSymbolsBySetId,
        pageSetup: pageSetup,
        screenplayText: screenplayText,
        roles: roles,
        selectedSequenceId: selectedSequenceId,
        forceSelectedSequenceIdValue: snapshot.sequences.isEmpty,
        selectedShotId: firstShotId,
        forceSelectedShotIdValue: firstShotId == null,
        selectedSetId: selectedSetId,
        forceSelectedSetIdValue: selectedSetId == null,
        forceSelectedFloorPlanSymbolIdValue: true,
        forceSelectedFloorPlanArrowIdValue: true,
        forcePendingFloorPlanArrowAnchorSymbolIdValue: true,
        forcePendingCoverageAnchorValue: true,
        leftDockFraction: leftDockFraction,
        rightDockFraction: rightDockFraction,
        visibleColumns: visibleColumns,
        lastRightDockTab: lastRightDockTab,
        centreView: effectiveCentreView,
        screenplayCharacters: screenplayCharacters,
        suggestions: suggestions,
        propsOfSelectedSequence: propsOfSelectedSequence,
        reloadEpoch: state.reloadEpoch + 1,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptShotListSelectionCause.load,
      ),
    );
  }

  /// [sequenceId]'s own breakdown props (`OcptElementsService.propsOfScene`), or an empty list
  /// while [sequenceId] is null or names the orphan group, which has no scene of its own to read —
  /// the floor plans palette's own `Sequence` group chips.
  Future<List<OcptScenePropSummary>> _loadPropsOfSequence({
    required OcptOpenProjectModel project,
    required List<OcptShotSequence> sequences,
    required String? sequenceId,
  }) async {
    if (sequenceId == null) {
      return const [];
    }
    for (final sequence in sequences) {
      if (sequence.id == sequenceId && sequence is OcptSceneShotSequence) {
        return _elementsService.propsOfScene(database: project.database, sceneId: sequence.sceneId);
      }
    }
    return const [];
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
  Future<OcptStoryboardSnapshot> _loadStoryboard(OcptOpenProjectModel project) => _storyboardService
      .loadStoryboard(database: project.database, screenplayId: _screenplayIdOf(project));

  /// Reads the whole floor plans of the selected episode's screenplay — every live set of every
  /// sequence, keyed by scene id — what the floor plans view reads through
  /// `OcptShotListState.setsOfSelectedSequence`.
  ///
  /// Read again after every floor plans write, exactly as [_loadStoryboard] is after every board
  /// write: the snapshot in state is only ever a reflection of what the database says.
  Future<OcptFloorPlanSnapshot> _loadFloorPlans(OcptOpenProjectModel project) => _floorPlanService
      .loadFloorPlans(database: project.database, screenplayId: _screenplayIdOf(project));

  /// Reads the project's whole Resources catalogue — every location and its own sets, each
  /// carrying the scenes it is linked to — what the set tabs' own `＋ Set` menu groups `Link an
  /// existing set ▸`/`Create a set ▸` by, and what `ocptSceneSetSuggestionOf` reads to suggest one
  /// for the selected sequence's own heading. Project-wide,
  /// unlike [_loadFloorPlans]'s own per-screenplay read: a set the empty-state gallery offers to
  /// link may already be linked to another episode's own sequence.
  Future<List<OcptLocation>> _loadLocations(OcptOpenProjectModel project) =>
      _locationsService.loadLocations(database: project.database);

  /// Reads the set-scope symbols of every live Resources set of the project, keyed by set id — the
  /// empty-state gallery's own thumbnail content: a thumbnail
  /// draws a set's own décor alone, never what a sequence or a shot placed on it, so this is all it
  /// ever needs. Project-wide, exactly like [_loadLocations] and unlike [_loadFloorPlans].
  Future<Map<String, List<OcptFloorPlanSymbol>>> _loadSetScopeSymbolsBySetId(
    OcptOpenProjectModel project,
  ) => _floorPlanService.loadSetScopeSymbolsByProjectSetId(database: project.database);

  /// Reads the production's whole cast — every live role, in `sortKey` order — what the
  /// inspector's character chips are built from, and what the shared role alert banner's
  /// orphaned/collision alerts are derived from (`OcptShotListState.orphanedRoleAlerts`/
  /// `.roleCollisionAlerts`).
  Future<List<OcptRole>> _loadRoles(OcptOpenProjectModel project) =>
      _roleIndexService.loadRoles(database: project.database);

  /// Reads the selected episode's current Fountain source text, kept in
  /// `OcptShotListState.screenplayText` for [_screenplayCharactersOf] and every scenario coverage
  /// read/write that needs the whole screenplay text rather than a single scene's own slice of it.
  Future<String> _loadScreenplayText(OcptOpenProjectModel project) => _projectsManager
      .screenplayService
      .loadScreenplayText(database: project.database, screenplayId: _screenplayIdOf(project));

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
        margins:
            await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
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
      lenses: await _shotListService.distinctLenses(database: database, screenplayId: screenplayId),
      recordingFormats: await _shotListService.distinctRecordingFormats(
        database: database,
        screenplayId: screenplayId,
      ),
      sounds: await _shotListService.distinctSounds(database: database, screenplayId: screenplayId),
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
    await _flushAllPendingWrites(emitter);

    final isSameSequence = state.selectedSequenceId == event.sequenceId;
    final firstSetId = isSameSequence
        ? state.selectedSetId
        : ocptFirstSetIdOf(
            floorPlanSnapshot: state.floorPlanSnapshot,
            sequenceId: event.sequenceId,
          );
    final selectedShotId = isSameSequence
        ? state.selectedShotId
        : ocptFirstShotIdOf(snapshot: state.snapshot, sequenceId: event.sequenceId);
    final project = _projectsManager.currentProject;
    final propsOfSelectedSequence = isSameSequence || project == null
        ? state.propsOfSelectedSequence
        : await _loadPropsOfSequence(
            project: project,
            sequences: state.sequences,
            sequenceId: event.sequenceId,
          );

    emitter(
      state.copyWith(
        selectedSequenceId: event.sequenceId,
        selectedShotId: selectedShotId,
        forceSelectedShotIdValue: selectedShotId == null,
        selectedSetId: firstSetId,
        forceSelectedSetIdValue: firstSetId == null,
        forceSelectedFloorPlanSymbolIdValue: !isSameSequence,
        forceSelectedFloorPlanArrowIdValue: !isSameSequence,
        forcePendingFloorPlanArrowAnchorSymbolIdValue: true,
        forcePendingCoverageAnchorValue: true,
        forcePendingFloorPlanScopeDecisionValue: !isSameSequence,
        propsOfSelectedSequence: propsOfSelectedSequence,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: isSameSequence
            ? OcptShotListSelectionCause.sequenceReselected
            : OcptShotListSelectionCause.sequence,
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
    await _flushAllPendingWrites(emitter);

    final sequence = ocptSequenceHolding(sequences: state.sequences, shotId: event.shotId);
    if (sequence == null) {
      return;
    }

    await _persistLastRightDockTab(OcptShotListRightDockTab.inspector);

    emitter(
      state.copyWith(
        selectedSequenceId: sequence.id,
        selectedShotId: event.shotId,
        rightDockTab: OcptShotListRightDockTab.inspector,
        lastRightDockTab: OcptShotListRightDockTab.inspector,
        forcePendingCoverageAnchorValue: true,
        forceSelectedFloorPlanSymbolIdValue: true,
        forceSelectedFloorPlanArrowIdValue: true,
        forcePendingFloorPlanArrowAnchorSymbolIdValue: true,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptShotListSelectionCause.shot,
      ),
    );
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
    await _flushAllPendingWrites(emitter);

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
          forcePendingCoverageAnchorValue: true,
          selectionEpoch: state.selectionEpoch + 1,
          selectionCause: OcptShotListSelectionCause.shotCreated,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to create a shot in the scene ${sequence.sceneId} of "
        "project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
  /// already the one showing (see `_flushAllPendingWrites`).
  Future<void> _onRightDockTabSelected(
    OcptShotListRightDockTabSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final isAlreadyActive = state.rightDockTab == event.tab;
    await _persistLastRightDockTab(event.tab);

    emitter(
      state.copyWith(
        rightDockTab: isAlreadyActive ? null : event.tab,
        forceRightDockTabValue: isAlreadyActive,
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
          ? state.copyWith(forceRightDockTabValue: true)
          : state.copyWith(rightDockTab: state.lastRightDockTab),
    );
  }

  /// Closes the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptShotListRightDockClosedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(forceRightDockTabValue: true));
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
    await _propertiesManager.shotListLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
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

  /// Leaves the workspace: flushes any pending field edit, closes the current project, and
  /// navigates back to the home page.
  Future<void> _onBackRequested(
    OcptShotListBackRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushAllPendingWrites(emitter);
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

    final pageSetup = await _loadPageSetup(project);
    emitter(state.copyWith(pageSetup: pageSetup));
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
  /// field-edit debounce that eventually writes it — the body [_onShotFieldChanged],
  /// [_onSetNameChanged] and [_onFloorPlanSymbolLabelChanged] share, since all ride the very same
  /// debounce.
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
      if (!isClosing) {
        add(const OcptShotListFieldEditFlushRequestedEvent());
      }
    });
  }

  /// Writes every pending field edit once the field-edit debounce elapses with no further typing.
  Future<void> _onFieldEditFlushRequested(
    OcptShotListFieldEditFlushRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) => _flushOwnPendingFieldEdits(emitter);

  /// Writes every pending write of the mode and of its views immediately — the views' through the
  /// flushers they registered, then the mode's own typed edits.
  ///
  /// Up front of every handler that changes what shot or sequence is selected, that leaves the
  /// workspace, or that is about to read the database (an export, a preview): a pending edit is
  /// never silently dropped by one of them. A view that wrote something leaves the working copy
  /// changed, so the `Versions` tab's working-copy card is refreshed if it is the one showing,
  /// exactly as when the mode wrote something itself.
  Future<void> _flushAllPendingWrites(Emitter<OcptShotListState> emitter) async {
    final haveViewsWritten = await runPendingWritesFlushers();
    final hasOwnWritten = await _flushOwnPendingFieldEdits(emitter);

    if (haveViewsWritten && !hasOwnWritten) {
      _requestWorkingCopyRefreshIfVersionsOpen();
    }
  }

  /// Asks for a fresh read of the working-copy card if the `Versions` tab is the one showing.
  void _requestWorkingCopyRefreshIfVersionsOpen() {
    if (state.rightDockTab == OcptShotListRightDockTab.versions) {
      addUnlessClosing(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Writes every pending field edit the mode itself holds immediately: cancels the debounce
  /// timer (a no-op if it already fired or there was none), writes each one through
  /// `OcptShotListService.updateShot`, then reloads the snapshot and the suggestion lists so every
  /// derived aggregate and every field's suggestions reflect what the database now says. A no-op
  /// while nothing is pending. Answers whether there was anything pending.
  ///
  /// Used from inside an event handler, with that handler's own [emitter]: called by
  /// [_onFieldEditFlushRequested] (the debounce firing) and by [_flushAllPendingWrites].
  /// [flushPendingFieldEdits] is the sibling of this method used outside of an event handler.
  Future<bool> _flushOwnPendingFieldEdits(Emitter<OcptShotListState> emitter) async {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return false;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWith(pendingFieldEdits: const {}));
      return true;
    }

    try {
      await _writeAllPendingFields(project: project, pending: pending);

      // Queued with the views' reloads: a read made here but emitted after a newer one would put
      // older data over it.
      await runSerially(() async {
        final snapshot = await _loadSnapshot(project);
        final suggestions = await _loadSuggestions(project);
        final storyboardSnapshot = await _loadStoryboard(project);
        final floorPlanSnapshot = await _loadFloorPlans(project);
        final locations = await _loadLocations(project);
        emitter(
          state.copyWith(
            snapshot: snapshot,
            suggestions: suggestions,
            storyboardSnapshot: storyboardSnapshot,
            floorPlanSnapshot: floorPlanSnapshot,
            locations: locations,
            pendingFieldEdits: ocptPendingEditsAfterWrite(
              current: state.pendingFieldEdits,
              written: pending,
            ),
            reloadEpoch: state.reloadEpoch + 1,
          ),
        );
      });

      // The other of the two moments the working-copy card needs a fresh read for (see
      // `_onRightDockTabSelected`): a field edit landing while the tab showing it is already open.
      _requestWorkingCopyRefreshIfVersionsOpen();
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending shot list field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(
          hasWriteError: true,
          pendingFieldEdits: ocptPendingEditsAfterWrite(
            current: state.pendingFieldEdits,
            written: pending,
          ),
        ),
      );
    }

    return true;
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
  /// Unlike [_flushOwnPendingFieldEdits], this never touches [state]: `emit` may only be called from
  /// inside a registered `on<Event>` handler (the package's own rule, enforced by the analyzer's
  /// `visible_for_testing` lint on `Bloc.emit`), and by the time this runs the widget tree that
  /// would show a fresh state is already gone anyway. Like `OcptEditorBloc.disposeLifeCycle`'s own
  /// flush, a failure here is only logged.
  Future<void> flushPendingFieldEdits() => Future.wait([
    _flushOwnPendingFieldEditsWithoutState(),
    runPendingWritesFlushersWithoutState(),
  ]);

  /// Writes every pending field edit the mode itself holds, without touching [state]: the mode's
  /// half of [flushPendingFieldEdits].
  Future<void> _flushOwnPendingFieldEditsWithoutState() async {
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
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending shot list field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
        case OcptShotListSetNameEditKey(:final setId):
          await _locationsService.updateSet(
            database: project.database,
            setId: setId,
            name: Value(entry.value),
          );
        case OcptShotListPanelCommentEditKey() || OcptShotListAnnotationTextEditKey():
          // A panel comment and a mark's text are the storyboard bloc's own, and never recorded
          // here.
          break;
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
    if (field != OcptShotListEditableField.estimatedDuration) {
      await _shotListService.updateTextField(
        database: database,
        shotId: shotId,
        field: field,
        rawValue: rawValue,
      );
      return;
    }

    // A mistyped duration is the field's own error state, not a failure: the edit is skipped
    // so it doesn't stop the flush of every other pending edit alongside it, and nothing is
    // logged, since the text it would quote is the user's.
    final parsed = ocptParseShotDuration(rawValue);
    if (!parsed.status.isSuccess) {
      return;
    }
    await _shotListService.updateShot(
      database: database,
      shotId: shotId,
      estimatedDurationMs: Value(parsed.value),
    );
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
      await _shotListService.updateDifficulty(
        database: project.database,
        shotId: event.shotId,
        axis: event.axis,
        value: event.value,
      );
      final snapshot = await _loadSnapshot(project);
      emitter(state.copyWith(snapshot: snapshot));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to change the difficulty of shot ${event.shotId} of "
        "project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
      final snapshot = await _loadSnapshot(project);
      emitter(state.copyWith(snapshot: snapshot));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to toggle role ${event.roleId} on shot ${event.shotId} "
        "of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
      final snapshot = await _loadSnapshot(project);
      final roles = await _loadRoles(project);
      emitter(state.copyWith(snapshot: snapshot, roles: roles));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to add a character to shot "
        "${event.shotId} of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Deletes shot `event.shotId`, reselecting the sequence's own next first shot when it was the
  /// selected one (the sequence stays selected; null only while the sequence now holds none at all
  /// — the "always a current shot" invariant), and dropping any pending field edit that
  /// still targeted it — `OcptShotListService.deleteShot`'s own cascade tombstones the shot's
  /// panels alongside it, and the storyboard bloc drops the comments typed into them once it sees
  /// the mode read the storyboard again.
  Future<void> _onShotDeletionRequested(
    OcptShotListShotDeletionRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final floorPlanSets = state.floorPlanSnapshot?.setsById.values;
    final floorPlanSymbolIds = <String>{
      if (floorPlanSets != null)
        for (final floorPlanSet in floorPlanSets)
          for (final symbol in floorPlanSet.symbols)
            if (symbol.shotId == event.shotId) symbol.id,
    };
    bool isOfShot(OcptShotListPendingEditKey key) => switch (key) {
      OcptShotListShotFieldEditKey(:final shotId) => shotId == event.shotId,
      OcptShotListPanelCommentEditKey() => false,
      OcptShotListAnnotationTextEditKey() => false,
      OcptShotListSetNameEditKey() => false,
      OcptShotListSymbolLabelEditKey(:final symbolId) => floorPlanSymbolIds.contains(symbolId),
    };
    if (state.pendingFieldEdits.keys.every(isOfShot)) {
      _fieldEditTimer?.cancel();
      _fieldEditTimer = null;
    }

    final wasSelected = state.selectedShotId == event.shotId;
    final wasFloorPlanSymbolSelected = floorPlanSymbolIds.contains(state.selectedFloorPlanSymbolId);

    try {
      await _shotListService.deleteShot(database: project.database, shotId: event.shotId);
      final snapshot = await _loadSnapshot(project);
      final reselectedShotId = wasSelected
          ? ocptFirstShotIdOf(snapshot: snapshot, sequenceId: state.selectedSequenceId)
          : state.selectedShotId;

      final suggestions = await _loadSuggestions(project);
      final storyboardSnapshot = await _loadStoryboard(project);
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          snapshot: snapshot,
          suggestions: suggestions,
          storyboardSnapshot: storyboardSnapshot,
          // `OcptShotListService.deleteShot`'s own cascade tombstones the shot's floor plan
          // symbols and arrows alongside it (`OcptFloorPlanService.tombstoneFloorPlanRowsOfShot`),
          // so the floor plans view must re-read too, exactly as the board does above.
          floorPlanSnapshot: floorPlanSnapshot,
          // Taken now, not before the delete: a keystroke typed meanwhile is not the shot's.
          pendingFieldEdits: Map.of(state.pendingFieldEdits)
            ..removeWhere((key, _) => isOfShot(key)),
          selectedShotId: reselectedShotId,
          forceSelectedShotIdValue: reselectedShotId == null,
          forcePendingCoverageAnchorValue: wasSelected,
          forceSelectedFloorPlanSymbolIdValue: wasSelected || wasFloorPlanSymbolSelected,
          forceSelectedFloorPlanArrowIdValue: wasSelected || wasFloorPlanSymbolSelected,
          forcePendingFloorPlanArrowAnchorSymbolIdValue: wasSelected,
          reloadEpoch: state.reloadEpoch + 1,
          selectionEpoch: wasSelected ? state.selectionEpoch + 1 : null,
          selectionCause: wasSelected ? OcptShotListSelectionCause.shotDeleted : null,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete shot ${event.shotId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
    action: (project) => _roleIndexService.keepOrphanedRoleAsSilent(
      database: project.database,
      roleId: event.roleId,
    ),
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
      final snapshot = await _loadSnapshot(project);
      final roles = await _loadRoles(project);
      emitter(state.copyWith(snapshot: snapshot, roles: roles));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to $logContext of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Resolves a click on a scenario coverage word, exactly as
  /// `OcptShotListCoverageWordClickedEvent` documents: with no range open, a click on one of the
  /// selected shot's own already-covered words removes the range covering it and any other click
  /// opens a range on that word; with a range open, the click closes it wherever it lands. Written
  /// immediately, like every other coverage change; a stale click — a shot no longer selected, or
  /// nothing left to lay out — is silently ignored, since the layout the click was resolved against
  /// might no longer describe what is on screen.
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
        action: () =>
            _shotCoverageService.removeRange(database: project.database, rangeId: coveringRange.id),
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
      action: () =>
          _shotCoverageService.clearRangesOfShot(database: project.database, shotId: event.shotId),
    );
  }

  /// Clears the pending coverage anchor, exactly as `OcptShotListCoverageAnchorCancelledEvent`
  /// documents: dispatched by the coverage dialog's `Escape`, a click on empty space in its script
  /// area, or the dialog closing. Leaves the selected shot's own coverage ranges untouched.
  Future<void> _onCoverageAnchorCancelled(
    OcptShotListCoverageAnchorCancelledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(forcePendingCoverageAnchorValue: true));
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
      final snapshot = await _loadSnapshot(project);
      emitter(state.copyWith(snapshot: snapshot, forcePendingCoverageAnchorValue: true));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to change the scenario coverage of shot $shotId of "
        "project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true, forcePendingCoverageAnchorValue: true));
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

  /// Shows the native "open" dialog filtered to [ocptFloorPlanUnderlayImageFileExtensions] and
  /// returns the path picked, or null when the user cancelled it, when it failed, or when the
  /// platform gave a file with no path at all. The underlay's own sibling of
  /// `OcptShotListStoryboardBloc`'s panel frame picker.
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

  /// Selects set `event.setId` on the floor plans view, clearing the symbol selection: a symbol
  /// only ever belongs to the set currently shown.
  Future<void> _onSetSelected(
    OcptShotListSetSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(
      state.copyWith(
        selectedSetId: event.setId,
        forceSelectedFloorPlanSymbolIdValue: true,
        forceSelectedFloorPlanArrowIdValue: true,
        forcePendingFloorPlanArrowAnchorSymbolIdValue: true,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptShotListSelectionCause.set,
      ),
    );
  }

  /// Creates a new Resources set named after the selected sequence's own heading place, in
  /// `event.locationId` (or a fresh location of its own, when null), links it to that sequence
  /// (`OcptLocationsService.createSetLinkedToScene`, the breakdown's own path), reloads the floor
  /// plans and the Resources catalogue, and selects it. Deliberately a no-op when the selected
  /// sequence is the orphan group (or when nothing is selected at all): see
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
        locationId: event.locationId,
      );
      if (setId == null) {
        return;
      }

      final floorPlanSnapshot = await _loadFloorPlans(project);
      final locations = await _loadLocations(project);
      final setScopeSymbolsBySetId = await _loadSetScopeSymbolsBySetId(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          locations: locations,
          setScopeSymbolsBySetId: setScopeSymbolsBySetId,
          selectedSetId: setId,
          forceSelectedFloorPlanSymbolIdValue: true,
          forceSelectedFloorPlanArrowIdValue: true,
          forcePendingFloorPlanArrowAnchorSymbolIdValue: true,
          selectionEpoch: state.selectionEpoch + 1,
          selectionCause: OcptShotListSelectionCause.setAdded,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to create a floor plan set on scene ${sequence.sceneId} "
        "of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Links Resources set `event.setId` to the selected sequence
  /// (`OcptLocationsService.assignSceneToSet`), reloads the floor plans and selects it — the
  /// empty-state gallery's own card click and the `＋ Set` menu's own suggestion/`Link an existing
  /// set ▸` entries. Deliberately a no-op when the selected
  /// sequence is the orphan group (or when nothing is selected at all), exactly like
  /// [_onSetCreationRequested].
  Future<void> _onSetLinkRequested(
    OcptShotListSetLinkRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final sequence = state.selectedSequence;
    if (project == null || sequence is! OcptSceneShotSequence) {
      return;
    }

    try {
      final linkId = await _locationsService.assignSceneToSet(
        database: project.database,
        sceneId: sequence.sceneId,
        setId: event.setId,
      );
      if (linkId == null) {
        return;
      }

      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          selectedSetId: event.setId,
          forceSelectedFloorPlanSymbolIdValue: true,
          forceSelectedFloorPlanArrowIdValue: true,
          forcePendingFloorPlanArrowAnchorSymbolIdValue: true,
          selectionEpoch: state.selectionEpoch + 1,
          selectionCause: OcptShotListSelectionCause.setAdded,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to link set ${event.setId} to scene ${sequence.sceneId} "
        "of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Records the raw text just typed into set `event.setId`'s own tab as a pending edit, and
  /// (re)starts the field-edit debounce shared with [_onShotFieldChanged].
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
    bool isOfSet(OcptShotListPendingEditKey key) =>
        key is OcptShotListSetNameEditKey && key.setId == event.setId;

    try {
      await _locationsService.removeSceneFromSet(
        database: project.database,
        sceneId: sceneId,
        setId: event.setId,
      );
      final floorPlanSnapshot = await _loadFloorPlans(project);
      final nextSetId = wasSelected
          ? ocptFirstSetIdOf(
              floorPlanSnapshot: floorPlanSnapshot,
              sequenceId: state.selectedSequenceId,
            )
          : state.selectedSetId;

      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          // Taken now, not before the unlink: a keystroke typed meanwhile is not the set's.
          pendingFieldEdits: Map.of(state.pendingFieldEdits)..removeWhere((key, _) => isOfSet(key)),
          selectedSetId: nextSetId,
          forceSelectedSetIdValue: nextSetId == null,
          forceSelectedFloorPlanSymbolIdValue: wasSelected,
          forceSelectedFloorPlanArrowIdValue: wasSelected,
          forcePendingFloorPlanArrowAnchorSymbolIdValue: wasSelected,
          selectionEpoch: wasSelected ? state.selectionEpoch + 1 : null,
          selectionCause: wasSelected ? OcptShotListSelectionCause.setRemoved : null,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to unlink set ${event.setId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Duplicates set `event.setId` into a new Resources set in the same location, named
  /// `event.newSetName`, copying its set-scope symbols only and linking it to the selected
  /// sequence — the set tabs' own `＋ Set` menu `Duplicate this set` entry, now **one** atomic call
  /// (`OcptLocationsService.duplicateSetForScene`): the mode used
  /// to put its three steps together itself, which is exactly the risk of an orphan set that
  /// service method's own transaction rules out. Reloads the floor plans and selects the freshly
  /// minted copy.
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
      final newSetId = await _locationsService.duplicateSetForScene(
        database: project.database,
        sourceSetId: event.setId,
        name: event.newSetName,
        sceneId: sceneId,
      );
      if (newSetId == null) {
        return;
      }

      final floorPlanSnapshot = await _loadFloorPlans(project);
      final locations = await _loadLocations(project);
      final setScopeSymbolsBySetId = await _loadSetScopeSymbolsBySetId(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          locations: locations,
          setScopeSymbolsBySetId: setScopeSymbolsBySetId,
          selectedSetId: newSetId,
          forceSelectedFloorPlanSymbolIdValue: true,
          forceSelectedFloorPlanArrowIdValue: true,
          forcePendingFloorPlanArrowAnchorSymbolIdValue: true,
          selectionEpoch: state.selectionEpoch + 1,
          selectionCause: OcptShotListSelectionCause.setAdded,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to duplicate set ${event.setId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(state.copyWith(floorPlanSnapshot: floorPlanSnapshot));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to copy shot ${event.sourceShotId}'s own blocking onto "
        "shot $destinationShotId of set ${event.setId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
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
        forcePendingFloorPlanArrowAnchorSymbolIdValue: event.tool != OcptFloorPlanTool.arrow,
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

  /// Picks the scope a `setElement` placement lands at. A view preference.
  Future<void> _onFloorPlanActiveSetElementScopeChanged(
    OcptShotListFloorPlanActiveSetElementScopeChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(floorPlanActiveSetElementScope: event.scope));
  }

  /// Picks the label a `prop` placement carries. A view preference.
  Future<void> _onFloorPlanActiveLabelChanged(
    OcptShotListFloorPlanActiveLabelChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(floorPlanActiveLabel: event.label));
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
  /// comment. A freshly placed character symbol's own `ocptDefaultCharacterLabelOf` pre-fills its
  /// label from the shot's own characters field, the mock-up's "offered first as a convenience"
  /// — never a link, the placed symbol still carries no `roleId`
  /// — and also arms [OcptShotListState.pendingCharacterNamePromptSymbolId], so the mode opens
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
        ? ocptDefaultCharacterLabelOf(
            shot: state.snapshot?.shotsById[shotId],
            floorPlanSet: state.floorPlanSnapshot?.setsById[event.setId],
          )
        : event.label;

    try {
      final symbolId = await _floorPlanService.placeSymbol(
        database: project.database,
        setId: event.setId,
        sceneId: event.sceneId,
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          selectedFloorPlanSymbolId: symbolId,
          forceSelectedFloorPlanArrowIdValue: true,
          pendingCharacterNamePromptSymbolId: isCharacter ? symbolId : null,
          forcePendingCharacterNamePromptSymbolIdValue: !isCharacter,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to place a ${event.layer} symbol on set ${event.setId} "
        "of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
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
        forceSelectedFloorPlanSymbolIdValue: symbolId == null,
        forceSelectedFloorPlanArrowIdValue: symbolId != null,
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(state.copyWith(floorPlanSnapshot: floorPlanSnapshot));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to move symbol ${event.symbolId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(state.copyWith(floorPlanSnapshot: floorPlanSnapshot));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to resize symbol ${event.symbolId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(state.copyWith(floorPlanSnapshot: floorPlanSnapshot));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to rotate symbol ${event.symbolId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          forceSelectedFloorPlanSymbolIdValue: wasSelected,
          // `OcptFloorPlanService.deleteSymbol`'s own cascade tombstones every arrow touching this
          // symbol, so the selected arrow (if any) may no longer exist.
          forceSelectedFloorPlanArrowIdValue: true,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete symbol ${event.symbolId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Deletes set-scope symbol `event.symbolId` **everywhere** — itself (or, when it names a
  /// scene-scope override, the set-scope original it overrides) and every live override of it, in
  /// every sequence (`OcptFloorPlanService.deleteSymbolEverywhere`) — the destructive branch of the
  /// extended delete confirmation, dispatched once it has already been confirmed through
  /// `OcptConfirmDialog.showWithAlternative`, by the mode.
  Future<void> _onFloorPlanSymbolDeleteEverywhereRequested(
    OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final wasSelected = state.selectedFloorPlanSymbolId == event.symbolId;

    try {
      await _floorPlanService.deleteSymbolEverywhere(
        database: project.database,
        symbolId: event.symbolId,
      );
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          forceSelectedFloorPlanSymbolIdValue: wasSelected,
          forceSelectedFloorPlanArrowIdValue: true,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete symbol ${event.symbolId} everywhere, of "
        "project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Masks set-scope symbol `event.symbolId` for sequence `event.targetSceneId` alone — a hidden
  /// override, setting `isHidden` on one that already exists or creating one copied from the
  /// original's own geometry — the alternative branch ("Remove from sequence n") of the extended
  /// delete confirmation, dispatched once it has already been confirmed through
  /// `OcptConfirmDialog.showWithAlternative`, by the mode.
  Future<void> _onFloorPlanSymbolHideRequested(
    OcptShotListFloorPlanSymbolHideRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final selected = ocptFloorPlanSymbolById(
      floorPlanSnapshot: state.floorPlanSnapshot,
      symbolId: event.symbolId,
    );
    if (selected == null) {
      return;
    }
    final originalId = selected.overridesSymbolId ?? selected.id;
    final original = ocptFloorPlanSymbolById(
      floorPlanSnapshot: state.floorPlanSnapshot,
      symbolId: originalId,
    );
    if (original == null) {
      return;
    }

    final existingOverride = state.floorPlanSnapshot?.setsById[selected.setId]?.symbols
        .firstWhereOrNull(
          (symbol) =>
              symbol.overridesSymbolId == originalId && symbol.sceneId == event.targetSceneId,
        );

    final wasSelected = state.selectedFloorPlanSymbolId == event.symbolId;

    try {
      await _floorPlanService.hideSymbolForScope(
        database: project.database,
        original: original,
        existingOverride: existingOverride,
        sceneId: event.targetSceneId,
        shotId: null,
      );
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          forceSelectedFloorPlanSymbolIdValue: wasSelected,
          forceSelectedFloorPlanArrowIdValue: wasSelected,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to hide symbol ${event.symbolId} for sequence "
        "${event.targetSceneId} of project ${project.primaryScreenplayId}: "
        "${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Masks scene-scope symbol `event.symbolId` for shot `event.targetShotId` alone — a hidden
  /// shot-scope override, mirroring [_onFloorPlanSymbolHideRequested] one level down: setting
  /// `isHidden` on one that already exists or creating
  /// one copied from the scene symbol's own geometry — the alternative branch ("Remove from shot
  /// n") of the shot-level extended delete confirmation.
  Future<void> _onFloorPlanSymbolHideForShotRequested(
    OcptShotListFloorPlanSymbolHideForShotRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final selected = ocptFloorPlanSymbolById(
      floorPlanSnapshot: state.floorPlanSnapshot,
      symbolId: event.symbolId,
    );
    if (selected == null) {
      return;
    }
    // Only resolve "up" through `overridesSymbolId` when `selected` is itself a shot-scope
    // override — a scene-scope symbol's own `overridesSymbolId` (if any) names a *different*
    // level's original (a set-scope one) and is never followed here.
    final originalId = selected.shotId != null
        ? (selected.overridesSymbolId ?? selected.id)
        : selected.id;
    final original = ocptFloorPlanSymbolById(
      floorPlanSnapshot: state.floorPlanSnapshot,
      symbolId: originalId,
    );
    if (original == null) {
      return;
    }

    final existingOverride = state.floorPlanSnapshot?.setsById[selected.setId]?.symbols
        .firstWhereOrNull(
          (symbol) => symbol.overridesSymbolId == originalId && symbol.shotId == event.targetShotId,
        );

    final wasSelected = state.selectedFloorPlanSymbolId == event.symbolId;

    try {
      await _floorPlanService.hideSymbolForScope(
        database: project.database,
        original: original,
        existingOverride: existingOverride,
        sceneId: null,
        shotId: event.targetShotId,
      );
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          forceSelectedFloorPlanSymbolIdValue: wasSelected,
          forceSelectedFloorPlanArrowIdValue: wasSelected,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to hide symbol ${event.symbolId} for shot "
        "${event.targetShotId} of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Restores scene-scope override `event.symbolId` as in the set — tombstones it, so its own
  /// set-scope original reappears for that sequence. Reversible: never asks.
  Future<void> _onFloorPlanSymbolRestoreRequested(
    OcptShotListFloorPlanSymbolRestoreRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final wasSelected = state.selectedFloorPlanSymbolId == event.symbolId;

    try {
      await _floorPlanService.deleteSymbol(database: project.database, symbolId: event.symbolId);
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          forceSelectedFloorPlanSymbolIdValue: wasSelected,
          forceSelectedFloorPlanArrowIdValue: true,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to restore override ${event.symbolId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Stores the pending scope decision, dispatched by the mode the instant a set-scope move (or a
  /// scene-scope one — see `event.level`) rotate or resize ends on a symbol two-or-more
  /// sequences/shots share — no write yet, [_onFloorPlanScopeDecisionResolved] is what actually
  /// writes (or drops) it.
  Future<void> _onFloorPlanScopeDecisionRequested(
    OcptShotListFloorPlanScopeDecisionRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(
      state.copyWith(
        pendingFloorPlanScopeDecision: OcptFloorPlanScopeDecision(
          symbolId: event.symbolId,
          setId: event.setId,
          level: event.level,
          sequenceCount: event.sequenceCount,
          xM: event.xM,
          yM: event.yM,
          widthM: event.widthM,
          heightM: event.heightM,
          rotationDeg: event.rotationDeg,
        ),
      ),
    );
  }

  /// Resolves `state.pendingFloorPlanScopeDecision` — writes it onto the original (`every`), onto
  /// an override of the focused sequence or shot, per `decision.level` (`only`, updating one that
  /// already exists or creating one), or simply drops it (`cancel`, the element snaps back since
  /// nothing was ever written). A no-op while nothing is pending, or the focused sequence isn't a
  /// scene-shot one, or (at shot level) no shot is focused (defensive only: the bubble that
  /// dispatches `only` never shows otherwise).
  Future<void> _onFloorPlanScopeDecisionResolved(
    OcptShotListFloorPlanScopeDecisionResolvedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final decision = state.pendingFloorPlanScopeDecision;
    if (decision == null) {
      return;
    }

    if (event.choice == OcptFloorPlanScopeChoice.cancel) {
      emitter(state.copyWith(forcePendingFloorPlanScopeDecisionValue: true));
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWith(forcePendingFloorPlanScopeDecisionValue: true));
      return;
    }

    try {
      final onEveryScope = event.choice == OcptFloorPlanScopeChoice.every;
      String? targetSceneId;
      String? targetShotId;
      if (!onEveryScope) {
        if (decision.level == OcptFloorPlanOverrideLevel.sequence) {
          final sequence = state.selectedSequence;
          if (sequence is! OcptSceneShotSequence) {
            emitter(state.copyWith(forcePendingFloorPlanScopeDecisionValue: true));
            return;
          }
          targetSceneId = sequence.sceneId;
        } else {
          final shotId = state.selectedShotId;
          if (shotId == null) {
            emitter(state.copyWith(forcePendingFloorPlanScopeDecisionValue: true));
            return;
          }
          targetShotId = shotId;
        }
      }

      final existingOverride = onEveryScope
          ? null
          : state.floorPlanSnapshot?.setsById[decision.setId]?.symbols.firstWhereOrNull(
              (symbol) =>
                  symbol.overridesSymbolId == decision.symbolId &&
                  symbol.sceneId == targetSceneId &&
                  symbol.shotId == targetShotId,
            );
      final isWritten = await _floorPlanService.applyScopeDecision(
        database: project.database,
        decision: decision,
        onEveryScope: onEveryScope,
        original: ocptFloorPlanSymbolById(
          floorPlanSnapshot: state.floorPlanSnapshot,
          symbolId: decision.symbolId,
        ),
        existingOverride: existingOverride,
        targetSceneId: targetSceneId,
        targetShotId: targetShotId,
      );
      if (!isWritten) {
        emitter(state.copyWith(forcePendingFloorPlanScopeDecisionValue: true));
        return;
      }

      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          forcePendingFloorPlanScopeDecisionValue: true,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to resolve the scope decision on symbol "
        "${decision.symbolId} of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true, forcePendingFloorPlanScopeDecisionValue: true));
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(state.copyWith(floorPlanSnapshot: floorPlanSnapshot));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to import the underlay of set ${event.setId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Re-frames set `event.setId`'s underlay to `event.xM`/`event.yM`/`event.widthM`/
  /// `event.heightM`, dispatched once a drag moving or resizing it ends.
  /// `OcptFloorPlanService.updateUnderlayFrame` — never `setSetUnderlay`, which would tombstone
  /// and re-mint the underlay's own `assets` row on every drag-end — is the one write this touches;
  /// its own current rotation is left alone, since no underlay rotate handle exists.
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(state.copyWith(floorPlanSnapshot: floorPlanSnapshot));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to move/resize the underlay of set ${event.setId} of "
        "project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(state.copyWith(floorPlanSnapshot: floorPlanSnapshot));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to clear the underlay of set ${event.setId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          forcePendingFloorPlanArrowAnchorSymbolIdValue: true,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to add an arrow from symbol $anchor to ${event.symbolId} "
        "of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(hasWriteError: true, forcePendingFloorPlanArrowAnchorSymbolIdValue: true),
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
    emitter(state.copyWith(forcePendingFloorPlanArrowAnchorSymbolIdValue: true));
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          forceSelectedFloorPlanArrowIdValue: wasSelected,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete arrow ${event.arrowId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(state.copyWith(floorPlanSnapshot: floorPlanSnapshot));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to change the field of view of symbol ${event.symbolId} "
        "of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(state.copyWith(floorPlanSnapshot: floorPlanSnapshot));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to change the field-of-view reach of symbol "
        "${event.symbolId} of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
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
        forceSelectedFloorPlanArrowIdValue: arrowId == null,
        forceSelectedFloorPlanSymbolIdValue: arrowId != null,
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
      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(state.copyWith(floorPlanSnapshot: floorPlanSnapshot));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to bend arrow ${event.arrowId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
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

    final source = ocptFloorPlanSymbolById(
      floorPlanSnapshot: state.floorPlanSnapshot,
      symbolId: event.symbolId,
    );
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

      final floorPlanSnapshot = await _loadFloorPlans(project);
      emitter(
        state.copyWith(
          floorPlanSnapshot: floorPlanSnapshot,
          selectedFloorPlanSymbolId: symbolId,
          forceSelectedFloorPlanArrowIdValue: true,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to duplicate symbol ${event.symbolId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Clears [OcptShotListState.pendingCharacterNamePromptSymbolId], dispatched by the mode's own
  /// listener the moment it opens `OcptFloorPlanCharacterNamePickerDialog` for it.
  Future<void> _onFloorPlanCharacterNamePromptDismissed(
    OcptShotListFloorPlanCharacterNamePromptDismissedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(forcePendingCharacterNamePromptSymbolIdValue: true));
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
