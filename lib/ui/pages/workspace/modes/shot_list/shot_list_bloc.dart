// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_display_number.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shot_list_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
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
/// What the inspector does with a shot — its typed fields and their autosave, its difficulty, its
/// characters, its scenario coverage ranges and the cast-wide role changes — belongs to
/// `OcptShotListInspectorBloc`, which writes through the services and then asks this bloc to read
/// the data again ([reload]). The board belongs to `OcptShotListStoryboardBloc` the same way, the
/// floor plans' sets, underlays and tray to `OcptShotListFloorPlanSetsBloc`, and the gestures made
/// on the plan — the tool, the selected symbol or arrow, placing, moving, resizing, rotating and
/// duplicating a symbol, drawing and bending an arrow, the scope question — to
/// `OcptShotListFloorPlanCanvasBloc`. What is typed into a floor plan symbol's label is still held
/// here, in [OcptShotListState.pendingFieldEdits], and
/// written [defaultFieldEditDebounce] after the last keystroke, mirroring `OcptEditorBloc`'s own
/// autosave convention. That debounce is flushed
/// immediately, together with the view blocs', whenever the selected shot or sequence changes,
/// when the workspace is left, and (through [flushPendingFieldEdits], called by the mode's own
/// `deactivate()`) whenever the mode leaves the widget tree for any other reason, so a pending edit
/// is never silently dropped.
///
/// The screenplay's Fountain text, [OcptShotListState.screenplayText], is loaded once here, and the
/// speaking characters are derived from it by [_screenplayCharactersOf] rather than by parsing the
/// text a second time.
///
/// It also mixes in [MixinOcptProjectVersionsBloc], which owns everything the right dock's
/// `Versions` tab does: the project's versions are a property of the *project*, so that tab and
/// its state are shared with the screenplay mode rather than reimplemented here. The two hooks the
/// mixin needs are answered by [flushPendingProjectWrites] (a field edit still sitting in the
/// debounce must reach the working copy before a preview swaps the database out) and
/// [reloadFromProjectDatabase]. `_onRightDockTabSelected` and `_flushAllPendingWrites` each
/// dispatch [OcptProjectWorkingCopyRefreshRequestedEvent] — opening the `Versions` tab, and a
/// field edit landing while it is already open — the two moments the mixin's working-copy card is
/// worth a fresh, throttled read (a view bloc asks for it the same way when its own flush lands).
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
  /// role alert banner).
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read a shot's placement in the schedule — its `Jour de tournage` read-out,
  /// see [_loadSnapshot].
  final OcptScheduleService _scheduleService;

  /// The service used to read and write the board's panels: `loadStoryboard`, `addPanel`,
  /// `replacePanelImage`, `reorderPanel`, `updatePanelComment` and `deletePanel`.
  final OcptStoryboardService _storyboardService;

  /// The service used to read and write the floor plans: `loadFloorPlans`, a symbol's placement/
  /// move/resize/rotation/deletion.
  final OcptFloorPlanService _floorPlanService;

  /// The service used to read the project's Resources locations and their sets.
  final OcptLocationsService _locationsService;

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
  /// before it clears `isLoading`, and a mode is never built before that, so [screenplayIdOf]'s
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
    OcptScheduleService? scheduleService,
    OcptStoryboardService? storyboardService,
    OcptFloorPlanService? floorPlanService,
    OcptLocationsService? locationsService,
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
    on<OcptShotListFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptShotListShotDeletionRequestedEvent>(_onShotDeletionRequested);
    on<OcptShotListCentreViewSelectedEvent>(_onCentreViewSelected);
    onAwaited<OcptShotListSetSelectedEvent>(_onSetSelected);
    onAwaited<OcptShotListSetAddedEvent>(_onSetAdded);
    onAwaited<OcptShotListSetRemovedEvent>(_onSetRemoved);
    on<OcptShotListFloorPlanSymbolDeletionRequestedEvent>(_onFloorPlanSymbolDeletionRequested);
    on<OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent>(
      _onFloorPlanSymbolDeleteEverywhereRequested,
    );
    on<OcptShotListFloorPlanSymbolHideRequestedEvent>(_onFloorPlanSymbolHideRequested);
    on<OcptShotListFloorPlanSymbolHideForShotRequestedEvent>(
      _onFloorPlanSymbolHideForShotRequested,
    );
    on<OcptShotListFloorPlanSymbolRestoreRequestedEvent>(_onFloorPlanSymbolRestoreRequested);
    on<OcptShotListFloorPlanArrowDeletionRequestedEvent>(_onFloorPlanArrowDeletionRequested);
    on<OcptShotListFloorPlanSymbolLabelChangedEvent>(_onFloorPlanSymbolLabelChanged);
    on<OcptShotListFloorPlanSymbolFovChangedEvent>(_onFloorPlanSymbolFovChanged);
    on<OcptShotListFloorPlanSymbolFovReachChangedEvent>(_onFloorPlanSymbolFovReachChanged);
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
  String screenplayIdOf(OcptOpenProjectModel project) =>
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

    // Queued with the views' reloads: a read made here but emitted after a newer one would put
    // older data over it.
    await runSerially(() async {
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
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          visibleColumns: visibleColumns,
          lastRightDockTab: lastRightDockTab,
          centreView: effectiveCentreView,
          screenplayCharacters: screenplayCharacters,
          suggestions: suggestions,
          reloadEpoch: state.reloadEpoch + 1,
          selectionEpoch: state.selectionEpoch + 1,
          selectionCause: OcptShotListSelectionCause.load,
        ),
      );
    });
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
    final screenplayId = screenplayIdOf(project);

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
      .loadStoryboard(database: project.database, screenplayId: screenplayIdOf(project));

  /// Reads the whole floor plans of the selected episode's screenplay — every live set of every
  /// sequence, keyed by scene id — what the floor plans view reads through
  /// `OcptShotListState.setsOfSelectedSequence`.
  ///
  /// Read again after every floor plans write, exactly as [_loadStoryboard] is after every board
  /// write: the snapshot in state is only ever a reflection of what the database says.
  Future<OcptFloorPlanSnapshot> _loadFloorPlans(OcptOpenProjectModel project) => _floorPlanService
      .loadFloorPlans(database: project.database, screenplayId: screenplayIdOf(project));

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
      .loadScreenplayText(database: project.database, screenplayId: screenplayIdOf(project));

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
    final screenplayId = screenplayIdOf(project);

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

    emitter(
      state.copyWith(
        selectedSequenceId: event.sequenceId,
        selectedShotId: selectedShotId,
        forceSelectedShotIdValue: selectedShotId == null,
        selectedSetId: firstSetId,
        forceSelectedSetIdValue: firstSetId == null,
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
        screenplayId: screenplayIdOf(project),
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

  /// Records [rawValue] as the pending edit of [key], visible immediately, and (re)starts the
  /// field-edit debounce that eventually writes it — the body [_onFloorPlanSymbolLabelChanged] runs.
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
  /// timer (a no-op if it already fired or there was none), writes each one (a symbol's label),
  /// then reads the shared data again so every view reflects what the database
  /// now says. A no-op while nothing is pending. Answers whether there was anything pending.
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

  /// Writes every entry of [pending], switching on its key's own kind: a symbol's label through
  /// `OcptFloorPlanService.updateSymbol`.
  Future<void> _writeAllPendingFields({
    required OcptOpenProjectModel project,
    required Map<OcptShotListPendingEditKey, String> pending,
  }) async {
    for (final entry in pending.entries) {
      switch (entry.key) {
        case OcptShotListShotFieldEditKey() ||
            OcptShotListPanelCommentEditKey() ||
            OcptShotListAnnotationTextEditKey() ||
            OcptShotListSetNameEditKey():
          // A shot field, a panel comment, a mark's text and a set's name are the inspector,
          // storyboard and floor plan sets blocs' own, and never recorded here.
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

  /// Deletes shot `event.shotId`, reselecting the sequence's own next first shot when it was the
  /// selected one (the sequence stays selected; null only while the sequence now holds none at all
  /// — the "always a current shot" invariant), and dropping any pending floor plan label that
  /// still targeted one of its symbols — `OcptShotListService.deleteShot`'s own cascade tombstones
  /// the shot's panels alongside it, and the inspector and storyboard blocs drop the fields and
  /// comments typed into the shot and its panels once they see the mode read the data again.
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
      OcptShotListShotFieldEditKey() => false,
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

  /// Selects set `event.setId` on the floor plans view. A symbol only ever belongs to the set
  /// currently shown, which the canvas bloc sees in the selection's cause.
  Future<void> _onSetSelected(
    OcptShotListSetSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(
      state.copyWith(
        selectedSetId: event.setId,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptShotListSelectionCause.set,
      ),
    );
  }

  /// Selects set `event.setId`, one the floor plan sets bloc just added to the selected sequence
  /// (created, linked or duplicated) and has had this bloc read the floor plans for. Moves the
  /// selection like any other set selection, saying why.
  Future<void> _onSetAdded(
    OcptShotListSetAddedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(
      state.copyWith(
        selectedSetId: event.setId,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptShotListSelectionCause.setAdded,
      ),
    );
  }

  /// Falls back to the selected sequence's own first set (null while it has none left), after the
  /// floor plan sets bloc unlinked the selected set from it and had this bloc read the floor plans
  /// again.
  Future<void> _onSetRemoved(
    OcptShotListSetRemovedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final nextSetId = ocptFirstSetIdOf(
      floorPlanSnapshot: state.floorPlanSnapshot,
      sequenceId: state.selectedSequenceId,
    );

    emitter(
      state.copyWith(
        selectedSetId: nextSetId,
        forceSelectedSetIdValue: nextSetId == null,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptShotListSelectionCause.setRemoved,
      ),
    );
  }

  /// Reads the floor plans again after a placement was removed or hidden, then moves the selection
  /// saying why and which row ([targetId]): the canvas clears what the gesture always cleared.
  ///
  /// The selection is not moved when the read failed, which raised the transient write error
  /// instead.
  Future<void> _reloadFloorPlansAndMoveSelection({
    required OcptShotListSelectionCause cause,
    required String targetId,
    required Emitter<OcptShotListState> emitter,
  }) async {
    final reloadEpoch = state.reloadEpoch;
    await reloadSerially({OcptShotListReloadScope.floorPlans}, emitter);
    if (state.reloadEpoch == reloadEpoch) {
      return;
    }

    emitter(
      state.copyWith(
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: cause,
        selectionTargetId: targetId,
      ),
    );
  }

  /// Deletes symbol `event.symbolId` for good, dispatched once the canvas's own delete action has
  /// already been confirmed through `OcptConfirmDialog`, by the mode. The canvas bloc drops
  /// its selection of the symbol once it sees the floor plans read again without it.
  Future<void> _onFloorPlanSymbolDeletionRequested(
    OcptShotListFloorPlanSymbolDeletionRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.deleteSymbol(database: project.database, symbolId: event.symbolId);
      await _reloadFloorPlansAndMoveSelection(
        cause: OcptShotListSelectionCause.symbolRemoved,
        targetId: event.symbolId,
        emitter: emitter,
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

    try {
      await _floorPlanService.deleteSymbolEverywhere(
        database: project.database,
        symbolId: event.symbolId,
      );
      await _reloadFloorPlansAndMoveSelection(
        cause: OcptShotListSelectionCause.symbolRemoved,
        targetId: event.symbolId,
        emitter: emitter,
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

    try {
      await _floorPlanService.hideSymbolForScope(
        database: project.database,
        original: original,
        existingOverride: existingOverride,
        sceneId: event.targetSceneId,
        shotId: null,
      );
      await _reloadFloorPlansAndMoveSelection(
        cause: OcptShotListSelectionCause.symbolHidden,
        targetId: event.symbolId,
        emitter: emitter,
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

    try {
      await _floorPlanService.hideSymbolForScope(
        database: project.database,
        original: original,
        existingOverride: existingOverride,
        sceneId: null,
        shotId: event.targetShotId,
      );
      await _reloadFloorPlansAndMoveSelection(
        cause: OcptShotListSelectionCause.symbolHidden,
        targetId: event.symbolId,
        emitter: emitter,
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

    try {
      await _floorPlanService.deleteSymbol(database: project.database, symbolId: event.symbolId);
      await _reloadFloorPlansAndMoveSelection(
        cause: OcptShotListSelectionCause.symbolRemoved,
        targetId: event.symbolId,
        emitter: emitter,
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

  /// Deletes arrow `event.arrowId` for good, dispatched once the Placements group's own remove
  /// action has already been confirmed through `OcptConfirmDialog`, by the mode. The canvas bloc drops
  /// its selection of the arrow once it sees the floor plans read again without it.
  Future<void> _onFloorPlanArrowDeletionRequested(
    OcptShotListFloorPlanArrowDeletionRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.deleteArrow(database: project.database, arrowId: event.arrowId);
      await _reloadFloorPlansAndMoveSelection(
        cause: OcptShotListSelectionCause.arrowRemoved,
        targetId: event.arrowId,
        emitter: emitter,
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
      await reloadSerially({OcptShotListReloadScope.floorPlans}, emitter);
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
      await reloadSerially({OcptShotListReloadScope.floorPlans}, emitter);
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
