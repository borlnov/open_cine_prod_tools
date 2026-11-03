// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart' show useResult;
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
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_screenplay_characters_of.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shot_list_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_reader.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// This is the bloc class for the shot list (découpage technique) production mode.
///
/// It loads the selected episode's whole shot list from [OcptShotListService] on entry —
/// sequences are built in memory by joining the scene index with the shots referencing it, so the
/// mode always shows the screenplay as it stands — together with the screenplay's speaking
/// characters, every free-text field's suggestion list, and where each shot sits in the schedule
/// (joined onto the snapshot by [OcptShotListReader.loadSnapshot]: the schedule mode is the only
/// writer of a shot's placement), and holds the selection, the dock geometry and the visible table
/// columns on top.
///
/// What the inspector does with a shot — its typed fields and their autosave, its difficulty, its
/// characters, its scenario coverage ranges and the cast-wide role changes — belongs to
/// `OcptShotListInspectorBloc`, which writes through the services and then asks this bloc to read
/// the data again ([reload]). The board belongs to `OcptShotListStoryboardBloc` the same way, the
/// floor plans' sets, underlays and tray to `OcptShotListFloorPlanSetsBloc`, and the gestures made
/// on the plan — the tool, the selected symbol or arrow, placing, moving, resizing, rotating and
/// duplicating a symbol, drawing and bending an arrow, the scope question — to
/// `OcptShotListFloorPlanCanvasBloc`. What the inspector's Placements group does with a symbol or
/// an arrow — deleting, hiding, restoring, a camera's field of view and the label typed in place,
/// with its autosave debounce — belongs to `OcptShotListFloorPlanPlacementsBloc`, which asks this
/// bloc to read the floor plans again and, when it removed or hid a placement, to move the
/// selection with the cause that says so (`OcptShotListFloorPlanPlacementChangedEvent`).
///
/// Every pending edit the view blocs hold is flushed immediately whenever the selected shot or
/// sequence changes, when the workspace is left, and (through [flushPendingFieldEdits], called by
/// the mode's own `deactivate()`) whenever the mode leaves the widget tree for any other reason, so
/// a pending edit is never silently dropped. [defaultFieldEditDebounce] is the delay they write
/// after, mirroring `OcptEditorBloc`'s own autosave convention.
///
/// The screenplay's Fountain text is loaded once here, and the speaking characters are derived from
/// it by `ocptScreenplayCharactersOf` rather than by parsing the text a second time.
///
/// It also mixes in [MixinOcptProjectVersionsBloc], which owns everything the right dock's
/// `Versions` tab does: the project's versions are a property of the *project*, so that tab and
/// its state are shared with the screenplay mode rather than reimplemented here. The two hooks the
/// mixin needs are answered by [flushPendingProjectWrites] (a field edit still sitting in a view's
/// debounce must reach the working copy before a preview swaps the database out) and
/// [reloadFromProjectDatabase]. `_onRightDockTabSelected` and `_flushAllPendingWrites` each
/// dispatch [OcptProjectWorkingCopyRefreshRequestedEvent] — opening the `Versions` tab, and a
/// field edit landing while it is already open — the two moments the mixin's working-copy card is
/// worth a fresh, throttled read (a view bloc asks for it the same way when its own flush lands).
///
/// The four exports belong to `OcptShotListExportBloc`, which asks this bloc to write every pending
/// edit ([flushAllPendingWrites]) and then reads the snapshots this bloc holds.
///
/// It mixes in [MixinOcptProjectPackageBloc] too, which writes the whole project out as a portable
/// package from the `Export` panel's own standing card. That mixin reuses
/// [flushPendingProjectWrites] — what a colleague receives is the project *file*, so a debounced
/// edit has to reach it first — and asks [exportManager] where to write.
class OcptShotListBloc extends BlocForMixin<OcptShotListState>
    with
        MixinAsyncInitBloc<OcptShotListState>,
        MixinOcptProjectVersionsBloc<OcptShotListState>,
        MixinOcptProjectPackageBloc<OcptShotListState>,
        MixinOcptModeBloc<OcptShotListState, OcptShotListReloadScope> {
  /// The default delay between the last field edit and its autosave write, for the view blocs.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

  /// The logger category linked to this BLoC.
  static const _loggerCategory = "shot_list_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the dock fractions, columns and last right dock tab.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The manager used to export the shot list to an XLSX workbook.
  final OcptExportManager _exportManager;

  /// The service used to write the shot list.
  final OcptShotListService _shotListService;

  /// The reads of the data this mode shows, see [OcptShotListReader].
  late final OcptShotListReader _reader;

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

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageBloc.exportManager}
  @protected
  @override
  OcptExportManager get exportManager => _exportManager;

  /// {@macro open_cine_prod_tools.modeBlocConstructor}
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
    String? selectedEpisodeId,
    OcptShotListRevealRequest? revealRequest,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _selectedEpisodeId = selectedEpisodeId,
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _shotListService =
           shotListService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).shotListService,
       super(OcptShotListState.init(revealRequest: revealRequest)) {
    _reader = OcptShotListReader(
      projectsManager: _projectsManager,
      propertiesManager: _propertiesManager,
      shotListService: _shotListService,
      roleIndexService: roleIndexService ?? _projectsManager.roleIndexService,
      scheduleService: scheduleService ?? _projectsManager.scheduleService,
      storyboardService: storyboardService ?? _projectsManager.storyboardService,
      floorPlanService: floorPlanService ?? _projectsManager.floorPlanService,
      locationsService: locationsService ?? _projectsManager.locationsService,
      screenplayIdOf: screenplayIdOf,
    );
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
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
    on<OcptShotListShotDeletionRequestedEvent>(_onShotDeletionRequested);
    on<OcptShotListCentreViewSelectedEvent>(_onCentreViewSelected);
    onAwaited<OcptShotListSetSelectedEvent>(_onSetSelected);
    onAwaited<OcptShotListSetAddedEvent>(_onSetAdded);
    onAwaited<OcptShotListSetRemovedEvent>(_onSetRemoved);
    onAwaited<OcptShotListFloorPlanPlacementChangedEvent>(_onFloorPlanPlacementChanged);
  }

  /// Get the screenplay this bloc reads and writes: [_selectedEpisodeId], or [project]'s own
  /// [OcptOpenProjectModel.primaryScreenplayId] on the one path that can reach here with none
  /// selected (see [_selectedEpisodeId]'s own doc comment).
  String screenplayIdOf(OcptOpenProjectModel project) =>
      _selectedEpisodeId ?? project.primaryScreenplayId;

  /// Writes whatever field edit is still sitting in a view's field-edit debounce, so a preview
  /// about to swap the database can't send it into the previewed version instead.
  @protected
  @override
  ///
  /// Always answers true: every view of this mode shows a failed write itself (its own
  /// `hasWriteError`) and carries on, so a preview, a restore or an export goes ahead and finds the
  /// value the database still holds.
  Future<bool> flushPendingProjectWrites(Emitter<OcptShotListState> emitter) async {
    await _flushAllPendingWrites(emitter);
    return true;
  }

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.flushAllPendingWritesIn}
  ///
  /// Always true, for the reason [flushPendingProjectWrites] gives.
  @protected
  @override
  Future<bool> flushAllPendingWritesIn(Emitter<OcptShotListState> emitter) async {
    await _flushAllPendingWrites(emitter);
    return true;
  }

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.reloadScopesIn}
  ///
  /// A failed read raises the transient write error, like a failed write: the view that asked has
  /// already written its row, and what is on screen no longer says what the database holds.
  @protected
  @override
  Future<bool> reloadScopesIn(
    Set<OcptShotListReloadScope> scopes,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return false;
    }

    var isReloaded = false;
    try {
      OcptShotListSnapshot? snapshot;
      OcptShotFieldSuggestions? suggestions;
      OcptStoryboardSnapshot? storyboardSnapshot;
      OcptFloorPlanSnapshot? floorPlanSnapshot;
      List<OcptLocation>? locations;
      Map<String, List<OcptFloorPlanSymbol>>? setScopeSymbolsBySetId;
      List<OcptRole>? roles;

      var isRead = true;

      // A switch statement over an enum must name every value: a scope added to the enum does not
      // compile until it is read here.
      for (final scope in scopes) {
        switch (scope) {
          case OcptShotListReloadScope.snapshot:
            final read = await _reader.loadSnapshot(project);
            isRead = !read.isError;
            snapshot = read.value;
          case OcptShotListReloadScope.suggestions:
            suggestions = await _reader.loadSuggestions(project);
          case OcptShotListReloadScope.storyboard:
            final read = await _reader.loadStoryboard(project);
            isRead = !read.isError;
            storyboardSnapshot = read.value;
          case OcptShotListReloadScope.floorPlans:
            final read = await _reader.loadFloorPlans(project);
            isRead = !read.isError;
            floorPlanSnapshot = read.value;
          case OcptShotListReloadScope.locations:
            locations = await _reader.loadLocations(project);
          case OcptShotListReloadScope.setScopeSymbols:
            final read = await _reader.loadSetScopeSymbolsBySetId(project);
            isRead = !read.isError;
            setScopeSymbolsBySetId = read.value;
          case OcptShotListReloadScope.roles:
            final read = await _reader.loadRoles(project);
            isRead = !read.isError;
            roles = read.value;
        }

        if (!isRead) {
          break;
        }
      }

      if (isRead) {
        emitter(
          state.copyWithReloadedData(
            snapshot: snapshot,
            suggestions: suggestions,
            storyboardSnapshot: storyboardSnapshot,
            floorPlanSnapshot: floorPlanSnapshot,
            locations: locations,
            setScopeSymbolsBySetId: setScopeSymbolsBySetId,
            roles: roles,
          ),
        );
      } else {
        emitter(state.copyToWriteFailed());
      }

      isReloaded = isRead;
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to read again the $scopes of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }

    return isReloaded;
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<bool> reloadFromProjectDatabase(Emitter<OcptShotListState> emitter) => _load(emitter);

  /// {@macro act_flutter_utility.MixinAsyncInitBloc.initAsyncBloc}
  ///
  /// Loads the mode for the first time, see [_load]; adding an [AsyncInitEvent] again loads it
  /// again.
  @protected
  @override
  Future<void> initAsyncBloc({required Emitter<OcptShotListState> emit}) async {
    await super.initAsyncBloc(emit: emit);
    final _ = await _load(emit);
  }

  /// Write every pending edit of the views directly to the database, without touching [state].
  ///
  /// Called by the mode's own `deactivate()`, mirroring
  /// `OcptStyledScreenplayEditor.deactivate()`: `deactivate()` runs before `dispose()` for every
  /// removal from the tree (a mode switch swaps this whole subtree out, and so does the
  /// workspace's own back navigation), so triggering the write here — rather than dispatching an
  /// event, which would only be processed on a later microtask this widget might not survive to
  /// see — is what guarantees the last [defaultFieldEditDebounce] worth of typing isn't lost.
  Future<void> flushPendingFieldEdits() => runPendingWritesFlushersWithoutState();

  /// Load the persisted preferences and the current project's shot list, selecting its first
  /// sequence.
  ///
  /// The workspace route is guarded by the router manager, so a project is normally always open
  /// here; if none is (e.g. the bloc is built directly in a test), the state simply stops loading
  /// with no snapshot at all.
  ///
  /// This is also [MixinOcptProjectVersionsBloc]'s [reloadFromProjectDatabase] hook, so it emits
  /// which version is being previewed alongside the shot list it just read, the two reaching the
  /// mode together (see the hook's own doc comment).
  ///
  /// Answers false when the shot list could not be read, in which case nothing is emitted and the
  /// caller stops there.
  @useResult
  Future<bool> _load(Emitter<OcptShotListState> emitter) async {
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
        state.copyToLoadedWithoutProject(
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          visibleColumns: visibleColumns,
          lastRightDockTab: lastRightDockTab,
          centreView: centreView,
        ),
      );
      return true;
    }

    // Queued with the views' reloads: a read made here but emitted after a newer one would put
    // older data over it.
    return runSerially(() async {
      final previewedVersion = project.previewedVersion;
      final screenplayText = await _reader.loadScreenplayText(project);
      final pageSetup = await _reader.loadPageSetup(project);
      final snapshotRead = await _reader.loadSnapshot(project);
      if (snapshotRead.isError) {
        return false;
      }

      final snapshot = snapshotRead.value!;
      final storyboardRead = await _reader.loadStoryboard(project);
      if (storyboardRead.isError) {
        return false;
      }

      final storyboardSnapshot = storyboardRead.value!;
      final floorPlanRead = await _reader.loadFloorPlans(project);
      if (floorPlanRead.isError) {
        return false;
      }

      final floorPlanSnapshot = floorPlanRead.value!;
      final locations = await _reader.loadLocations(project);
      final setScopeSymbolsRead = await _reader.loadSetScopeSymbolsBySetId(project);
      if (setScopeSymbolsRead.isError) {
        return false;
      }

      final setScopeSymbolsBySetId = setScopeSymbolsRead.value!;
      final screenplayCharacters = ocptScreenplayCharactersOf(screenplayText);
      final rolesRead = await _reader.loadRoles(project);
      if (rolesRead.isError) {
        return false;
      }

      final roles = rolesRead.value!;
      final suggestions = await _reader.loadSuggestions(project);

      final revealRequest = state.pendingRevealRequest;
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
        state.copyToLoaded(
          title: project.name,
          previewedVersion: previewedVersion,
          snapshot: snapshot,
          storyboardSnapshot: storyboardSnapshot,
          floorPlanSnapshot: floorPlanSnapshot,
          locations: locations,
          setScopeSymbolsBySetId: setScopeSymbolsBySetId,
          pageSetup: pageSetup,
          screenplayText: screenplayText,
          roles: roles,
          selectedSequenceId: selectedSequenceId,
          selectedShotId: firstShotId,
          selectedSetId: selectedSetId,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          visibleColumns: visibleColumns,
          lastRightDockTab: lastRightDockTab,
          centreView: effectiveCentreView,
          screenplayCharacters: screenplayCharacters,
          suggestions: suggestions,
        ),
      );
      return true;
    });
  }

  /// Select a sequence, clearing the selected shot when it actually changes sequence (the centre
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
      state.copyWithSelectedSequence(
        sequenceId: event.sequenceId,
        selectedShotId: selectedShotId,
        selectedSetId: firstSetId,
        isSameSequence: isSameSequence,
      ),
    );
  }

  /// Select a shot, together with the sequence holding it, and open the right dock on its
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

    emitter(state.copyWithSelectedShot(sequenceId: sequence.id, shotId: event.shotId));
  }

  /// Create a shot at the end of the selected scene sequence, reload the shot list and select
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
      await runSerially(() async {
        final snapshotRead = await _reader.loadSnapshot(project);
        if (snapshotRead.isError) {
          emitter(state.copyToWriteFailed());
          return;
        }

        final snapshot = snapshotRead.value!;

        await _persistLastRightDockTab(OcptShotListRightDockTab.inspector);

        emitter(
          state.copyWithCreatedShot(
            snapshot: snapshot,
            sequenceId: sequence.sceneId,
            shotId: shotId,
          ),
        );
      });
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to create a shot in the scene ${sequence.sceneId} of "
        "project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Toggle the left (sequences) dock's visibility.
  Future<void> _onSequencePanelToggled(
    OcptShotListSequencePanelToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWithSequencePanelToggled());
  }

  /// Select a tab of the right dock (the already-active tab closes the dock, any other one opens or
  /// switches to it) and record it as the tab the toolbar's toggle reopens the dock on.
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

    emitter(state.copyWithRightDockTabSelected(tab: event.tab, isAlreadyActive: isAlreadyActive));

    if (!isAlreadyActive && event.tab == OcptShotListRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Toggle the right dock from the workspace toolbar: an open dock closes, a closed one reopens
  /// on [OcptShotListState.lastRightDockTab].
  Future<void> _onRightDockToggled(
    OcptShotListRightDockToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(
      state.rightDockTab != null
          ? state.copyWithRightDockClosed()
          : state.copyWithRightDockReopened(),
    );
  }

  /// Close the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptShotListRightDockClosedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWithRightDockClosed());
  }

  /// Persist [tab] as the mode's last right dock tab, unless it already is.
  Future<void> _persistLastRightDockTab(OcptShotListRightDockTab tab) async {
    if (state.lastRightDockTab == tab) {
      return;
    }

    await _propertiesManager.shotListLastRightDockTab.store(tab);
  }

  /// Apply and persist whichever dock fraction the ended drag gesture reports.
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

    emitter(state.copyWithDockFractions(left: left, right: right));
  }

  /// Restore both dock fractions to their defaults, persisting them.
  Future<void> _onDockLayoutReset(
    OcptShotListDockLayoutResetEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _propertiesManager.shotListLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await _propertiesManager.shotListRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );

    emitter(
      state.copyWithDockFractions(
        left: OcptWorkspaceDock.leftDefaultFraction,
        right: OcptWorkspaceDock.rightDefaultFraction,
      ),
    );
  }

  /// Show or hide an optional table column, persisting the new set.
  Future<void> _onColumnToggled(
    OcptShotListColumnToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final visibleColumns = Set<OcptShotListColumn>.of(state.visibleColumns);
    if (!visibleColumns.remove(event.column)) {
      visibleColumns.add(event.column);
    }

    await _propertiesManager.shotListVisibleColumns.store(visibleColumns);
    emitter(state.copyWithVisibleColumns(visibleColumns: visibleColumns));
  }

  /// Dismiss the transient write error currently shown.
  Future<void> _onWriteErrorDismissed(
    OcptShotListWriteErrorDismissedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWithWriteErrorDismissed());
  }

  /// Leave the workspace: flushes any pending field edit, closes the current project, and
  /// navigates back to the home page.
  Future<void> _onBackRequested(
    OcptShotListBackRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushAllPendingWrites(emitter);
    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }

  /// Re-read the page setup after the project settings page changed something, so the scenario
  /// coverage export dialog pre-fills from the format actually in effect.
  Future<void> _onProjectSettingsChanged(
    OcptShotListProjectSettingsChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await runSerially(() async {
      final pageSetup = await _reader.loadPageSetup(project);
      emitter(state.copyWithPageSetup(pageSetup: pageSetup));
    });
  }

  /// Write every pending write of the mode's views immediately, through the flushers they
  /// registered.
  ///
  /// Up front of every handler that changes what shot or sequence is selected, that leaves the
  /// workspace, or that is about to read the database (an export, a preview): a pending edit is
  /// never silently dropped by one of them. A view that wrote something leaves the working copy
  /// changed, so the `Versions` tab's working-copy card is refreshed if it is the one showing.
  Future<void> _flushAllPendingWrites(Emitter<OcptShotListState> emitter) async {
    final haveViewsWritten = (await runPendingWritesFlushers()).hasWritten;

    if (haveViewsWritten && state.rightDockTab == OcptShotListRightDockTab.versions) {
      addUnlessClosing(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Delete shot `event.shotId`, reselecting the sequence's own next first shot when it was the
  /// selected one (the sequence stays selected; null only while the sequence now holds none at all
  /// — the "always a current shot" invariant). `OcptShotListService.deleteShot`'s own cascade
  /// tombstones the shot's panels and floor plan symbols alongside it, and the view blocs drop the
  /// fields, comments and labels typed into them once they see the mode read the data again.
  Future<void> _onShotDeletionRequested(
    OcptShotListShotDeletionRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final wasSelected = state.selectedShotId == event.shotId;

    try {
      await _shotListService.deleteShot(database: project.database, shotId: event.shotId);
      await runSerially(() async {
        final snapshotRead = await _reader.loadSnapshot(project);
        if (snapshotRead.isError) {
          emitter(state.copyToWriteFailed());
          return;
        }

        final snapshot = snapshotRead.value!;
        final reselectedShotId = wasSelected
            ? ocptFirstShotIdOf(snapshot: snapshot, sequenceId: state.selectedSequenceId)
            : state.selectedShotId;

        final suggestions = await _reader.loadSuggestions(project);
        final storyboardRead = await _reader.loadStoryboard(project);
        if (storyboardRead.isError) {
          emitter(state.copyToWriteFailed());
          return;
        }

        final storyboardSnapshot = storyboardRead.value!;
        final floorPlanRead = await _reader.loadFloorPlans(project);
        if (floorPlanRead.isError) {
          emitter(state.copyToWriteFailed());
          return;
        }

        final floorPlanSnapshot = floorPlanRead.value!;
        emitter(
          state.copyWithDeletedShot(
            snapshot: snapshot,
            suggestions: suggestions,
            storyboardSnapshot: storyboardSnapshot,
            // `OcptShotListService.deleteShot`'s own cascade tombstones the shot's floor plan
            // symbols and arrows alongside it
            // (`OcptFloorPlanService.tombstoneFloorPlanRowsOfShot`), so the floor plans view must
            // re-read too, exactly as the board does above.
            floorPlanSnapshot: floorPlanSnapshot,
            reselectedShotId: reselectedShotId,
            wasSelected: wasSelected,
          ),
        );
      });
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete shot ${event.shotId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Select centre view `event.view`, dispatched by `OcptShotListCentreHeader`'s own switch, and
  /// persist it so reopening the mode restores it.
  ///
  /// Keeps [OcptShotListState.selectedShotId]/`.selectedSequenceId` untouched: the two views read
  /// the same selection.
  Future<void> _onCentreViewSelected(
    OcptShotListCentreViewSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _propertiesManager.shotListLastCentreView.store(event.view);
    emitter(state.copyWithCentreView(view: event.view));
  }

  /// Select set `event.setId` on the floor plans view. A symbol only ever belongs to the set
  /// currently shown, which the canvas bloc sees in the selection's cause.
  Future<void> _onSetSelected(
    OcptShotListSetSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWithSelectedSet(setId: event.setId));
  }

  /// Select set `event.setId`, one the floor plan sets bloc just added to the selected sequence
  /// (created, linked or duplicated) and have had this bloc read the floor plans for. Moves the
  /// selection like any other set selection, saying why.
  Future<void> _onSetAdded(
    OcptShotListSetAddedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWithAddedSet(setId: event.setId));
  }

  /// Fall back to the selected sequence's own first set (null while it has none left), after the
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

    emitter(state.copyWithRemovedSetFallback(setId: nextSetId));
  }

  /// Read the floor plans again after a placement was removed or hidden, then move the selection
  /// saying why and which row (`event.cause`, `event.targetId`): the canvas clears what the gesture
  /// always cleared. Dispatched by the placements bloc once it wrote, and awaited.
  ///
  /// The selection is not moved when the read failed, which raised the transient write error
  /// instead.
  Future<void> _onFloorPlanPlacementChanged(
    OcptShotListFloorPlanPlacementChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final reloadEpoch = state.reloadEpoch;
    await reloadSerially({OcptShotListReloadScope.floorPlans}, emitter);
    if (state.reloadEpoch == reloadEpoch) {
      return;
    }

    emitter(state.copyWithMovedSelection(cause: event.cause, targetId: event.targetId));
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
