// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:meta/meta.dart' show useResult;
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_display_number.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// This is the bloc class for the breakdown production mode (dépouillement du scénario).
///
/// It loads the current project's title, the two dock fractions, the last right dock tab, and the
/// mode's own read on entry — the screenplay's Fountain text (kept in state for
/// `OcptBreakdownScriptView` to slice scene by scene), the page setup the script view is typeset
/// with, and one [OcptBreakdownSnapshot] joining [_breakdownService]'s scenes and tags with
/// [_elementsService]/[_roleIndexService]/[_locationsService]/[_peopleService]'s four catalogues,
/// the way `OcptResourcesBloc` builds its own `OcptResourcesSnapshot` — and holds the selected
/// scene, the selected target, the legend's hidden keys, the left dock's visibility, the right dock
/// tab and the two fractions on top of it. Selecting a target or a scene, and hiding a legend key,
/// write nothing to the project database, so none of the three is ever flushed by
/// [flushPendingProjectWrites] and all three live only in this bloc's own state.
///
/// What the right dock's `Inspector` tab does with them belongs to `OcptBreakdownInspectorBloc`:
/// the selected target's four free-text fields (`OcptElementField.name`/`.subCategory`/
/// `.quantity`/`.notes`), the selected scene's own breakdown notes and a set's name ride a
/// debounce of its own, and every single pick (a status, a category, an owner, a link, a tag
/// removal) is written by its own event. It writes through the services and then asks this bloc to
/// read the snapshot again ([reload]). This bloc writes every pending edit of its views
/// ([flushAllPendingWrites]) on a target or scene selection change, a right dock tab change, a
/// version preview ([flushPendingProjectWrites]) and the mode leaving the tree
/// ([flushPendingFieldEdits], called by the mode's own `deactivate()`).
///
/// The script view's range interaction belongs to `OcptBreakdownTaggingBloc`: the anchor, the
/// range, the popover's three ways of answering it and the suggestions accepted from the target
/// inspector. It writes through [_breakdownService], then asks this bloc to read the snapshot again
/// ([reload]) and to select the linked or newly created target on the `Inspector` tab.
///
/// The two exports belong to `OcptBreakdownExportBloc`, which asks this bloc to write every pending
/// edit ([flushAllPendingWrites]) and then reads the snapshot this bloc holds.
///
/// It also mixes in [MixinOcptProjectVersionsBloc], which owns everything the right dock's
/// `Versions` tab does. The two hooks the mixin needs are answered by [flushPendingProjectWrites]
/// and [reloadFromProjectDatabase]. [_onRightDockTabSelected] dispatches
/// [OcptProjectWorkingCopyRefreshRequestedEvent] on opening the `Versions` tab, exactly as the
/// other two modes do, and so does the inspector bloc when a field edit lands while that tab is
/// already open — the two moments the mixin's working-copy card is worth a fresh, throttled read.
///
/// It mixes in [MixinOcptProjectPackageBloc] too, which writes the whole project out as a portable
/// package from the `Export` panel's own standing card. That mixin reuses
/// [flushPendingProjectWrites] — what a colleague receives is the project *file*, so a debounced
/// edit has to reach it first — and asks [exportManager] where to write, exactly as this mode's
/// own exports do.
class OcptBreakdownBloc extends BlocForMixin<OcptBreakdownState>
    with
        MixinAsyncInitBloc<OcptBreakdownState>,
        MixinOcptProjectVersionsBloc<OcptBreakdownState>,
        MixinOcptProjectPackageBloc<OcptBreakdownState>,
        MixinOcptModeBloc<OcptBreakdownState, OcptBreakdownReloadScope> {
  /// The default delay between the last field edit and its autosave write, for the inspector bloc.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

  /// The logger category linked to this BLoC.
  static const _loggerCategory = "breakdown_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's dock fractions and last right dock tab.
  final OcptPropertiesManager _propertiesManager;

  /// The last right dock tab this bloc stored itself, so a tab persisted ahead of its selection is
  /// not stored a second time when the selection runs: the state only carries it after the emit.
  OcptBreakdownRightDockTab? _storedLastRightDockTab;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The manager the breakdown sheets export goes through.
  final OcptExportManager _exportManager;

  /// The service used to read the breakdown scenes and tags, and to remove one.
  final OcptBreakdownService _breakdownService;

  /// The service used to read the physical elements catalogue, and to write the selected target's
  /// own fields.
  final OcptElementsService _elementsService;

  /// The service used to read the cast, reconciled against the project's episodes.
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read locations and their sets.
  final OcptLocationsService _locationsService;

  /// The service used to read the address book the target inspector's owner and who-brings-it
  /// pickers offer.
  final OcptPeopleService _peopleService;

  /// The episode this bloc reads and writes, handed down by `OcptBreakdownMode` from
  /// `OcptWorkspaceBloc.state.selectedEpisodeId` at construction time — safe to capture once rather
  /// than watch, since `OcptWorkspacePage` remounts this whole bloc on every episode switch (see
  /// `OcptWorkspacePage._buildActiveMode`'s own doc comment), so the field can never go stale.
  ///
  /// Null only for a project holding no episode at all: `OcptWorkspaceBloc` lands on the first one
  /// before it clears `isLoading`, and a mode is never built before that, so [_screenplayIdOf]'s
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

  /// {@template open_cine_prod_tools.modeBlocConstructor}
  /// Class constructor
  ///
  /// Every dependency can be overridden, which is what the tests do; in the app they all resolve
  /// through [globalGetIt].
  /// {@endtemplate}
  OcptBreakdownBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
    OcptBreakdownService? breakdownService,
    OcptElementsService? elementsService,
    OcptRoleIndexService? roleIndexService,
    OcptLocationsService? locationsService,
    OcptPeopleService? peopleService,
    String? selectedEpisodeId,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _selectedEpisodeId = selectedEpisodeId,
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _breakdownService =
           breakdownService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).breakdownService,
       _elementsService =
           elementsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).elementsService,
       _roleIndexService =
           roleIndexService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).roleIndexService,
       _locationsService =
           locationsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).locationsService,
       _peopleService =
           peopleService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).peopleService,
       super(OcptBreakdownState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBreakdownBackRequestedEvent>(_onBackRequested);
    on<OcptBreakdownProjectSettingsChangedEvent>(_onProjectSettingsChanged);
    on<OcptBreakdownSceneSelectedEvent>(_onSceneSelected);
    on<OcptBreakdownSceneHeadingSelectedEvent>(_onSceneHeadingSelected);
    on<OcptBreakdownLeftPanelToggledEvent>(_onLeftPanelToggled);
    on<OcptBreakdownRightDockTabSelectedEvent>(_onRightDockTabSelected);
    on<OcptBreakdownRightDockToggledEvent>(_onRightDockToggled);
    on<OcptBreakdownRightDockClosedEvent>(_onRightDockClosed);
    on<OcptBreakdownDockFractionsChangedEvent>(_onDockFractionsChanged);
    on<OcptBreakdownDockLayoutResetEvent>(_onDockLayoutReset);
    on<OcptBreakdownLegendEntryToggledEvent>(_onLegendEntryToggled);
    on<OcptBreakdownLegendShowAllRequestedEvent>(_onLegendShowAllRequested);
    on<OcptBreakdownCentreViewSelectedEvent>(_onCentreViewSelected);
    on<OcptBreakdownSearchQueryChangedEvent>(_onSearchQueryChanged);
    onAwaited<OcptBreakdownTargetSelectedEvent>(_onTargetSelected);
    onAwaited<OcptBreakdownAnchorSceneSelectedEvent>(_onAnchorSceneSelected);
    on<OcptBreakdownTargetSelectionClearedEvent>(_onTargetSelectionCleared);
    on<OcptBreakdownOccurrenceSelectedEvent>(_onOccurrenceSelected);
  }

  /// Write every pending edit of the views directly to the database, without touching [state].
  ///
  /// Called by the mode's own `deactivate()`: `deactivate()` runs before `dispose()` for every
  /// removal from the tree (a mode switch swaps this whole subtree out, and so does the workspace's
  /// own back navigation), so triggering the write here — rather than dispatching an event, which
  /// would only be processed on a later microtask this widget might not survive to see — is what
  /// guarantees the last [defaultFieldEditDebounce] worth of typing isn't lost.
  Future<void> flushPendingFieldEdits() => runPendingWritesFlushersWithoutState();

  /// Write whatever target field edit, scene notes edit or set rename is still sitting in the
  /// inspector's field-edit debounce, so a preview about to swap the database can't send it into
  /// the previewed version instead.
  ///
  /// Always true: an edit that cannot be written is logged and dropped by the inspector, and the
  /// action behind the flush (a preview, a restore, a saved version, a package) goes ahead on the
  /// value the database still holds, as it always did.
  @protected
  @override
  Future<bool> flushPendingProjectWrites(Emitter<OcptBreakdownState> emitter) async {
    await runPendingWritesFlushers();
    return true;
  }

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.flushAllPendingWritesIn}
  ///
  /// Always true, for the reason [flushPendingProjectWrites] gives: a typed edit that cannot be
  /// written is logged and dropped, and the action goes ahead on the value the database holds.
  @protected
  @override
  Future<bool> flushAllPendingWritesIn(Emitter<OcptBreakdownState> emitter) async {
    await runPendingWritesFlushers();
    return true;
  }

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.reloadScopesIn}
  ///
  /// A read that fails is logged and answers false, which stops the view that asked: it must not
  /// select a row the state may not hold.
  @protected
  @override
  Future<bool> reloadScopesIn(
    Set<OcptBreakdownReloadScope> scopes,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return false;
    }

    var isReloaded = false;
    try {
      OcptBreakdownSnapshot? snapshot;
      var isRead = true;

      // A switch statement over an enum must name every value: a scope added to the enum does not
      // compile until it is read here.
      for (final scope in scopes) {
        switch (scope) {
          case OcptBreakdownReloadScope.snapshot:
            final read = await _loadSnapshot(project);
            isRead = !read.isError;
            snapshot = read.value;
        }

        if (!isRead) {
          break;
        }
      }

      if (isRead) {
        emitter(state.copyWithReloadedSnapshot(snapshot: snapshot));
      }

      isReloaded = isRead;
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to read again the $scopes of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }

    return isReloaded;
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<bool> reloadFromProjectDatabase(Emitter<OcptBreakdownState> emitter) => _load(emitter);

  /// {@macro act_flutter_utility.MixinAsyncInitBloc.initAsyncBloc}
  ///
  /// Loads the mode for the first time, see [_load]; adding an [AsyncInitEvent] again loads it
  /// again.
  @protected
  @override
  Future<void> initAsyncBloc({required Emitter<OcptBreakdownState> emit}) async {
    await super.initAsyncBloc(emit: emit);
    final _ = await _load(emit);
  }

  /// Persist the `Inspector` tab as the last right dock tab ahead of a selection of a target that
  /// will land the user on it, for a caller that reads the snapshot again before it makes that
  /// selection: the store is awaited here, so nothing is left to wait for between the read and the
  /// selection, and the state they emit is not split by it.
  Future<void> persistInspectorAsLastRightDockTab() =>
      _persistLastRightDockTab(OcptBreakdownRightDockTab.inspector);

  /// Get the screenplay this bloc reads and writes: [_selectedEpisodeId], or [project]'s own
  /// [OcptOpenProjectModel.primaryScreenplayId] on the one path that can reach here with none
  /// selected (see [_selectedEpisodeId]'s own doc comment).
  String _screenplayIdOf(OcptOpenProjectModel project) =>
      _selectedEpisodeId ?? project.primaryScreenplayId;

  /// Load the persisted dock fractions and the current project's whole breakdown read.
  ///
  /// The workspace route is guarded by the router manager, so a project is normally always open
  /// here; if none is (e.g. the bloc is built directly in a test), the state simply stops loading
  /// with no snapshot at all.
  ///
  /// This is also [MixinOcptProjectVersionsBloc]'s [reloadFromProjectDatabase] hook, so it emits
  /// which version is being previewed alongside the read it just performed: what it read comes from
  /// that very version's in-memory database, and the two must reach the mode together (see the
  /// hook's own doc comment). The selected scene and the selected target are always cleared on a
  /// (re)load, mirroring `OcptResourcesBloc`'s own selection reset: a preview or a restore changes
  /// the whole database underneath, so a stale selection is dropped rather than trusted to still
  /// mean the same thing — and so is any tag-removal confirmation the previous selection was asking
  /// for, and any element field edit or scene notes edit still sitting in the debounce (the caller
  /// flushes it through [flushPendingProjectWrites] first whenever losing it here would matter; a
  /// bare page-format reload never reaches this method at all, see [_onProjectSettingsChanged]).
  ///
  /// Answers false when the breakdown could not be read, in which case nothing is emitted.
  @useResult
  Future<bool> _load(Emitter<OcptBreakdownState> emitter) async {
    final leftDockFraction =
        await _propertiesManager.breakdownLeftDockFraction.load() ??
        OcptWorkspaceDock.leftDefaultFraction;
    final rightDockFraction =
        await _propertiesManager.breakdownRightDockFraction.load() ??
        OcptWorkspaceDock.rightDefaultFraction;
    final lastRightDockTab =
        await _propertiesManager.breakdownLastRightDockTab.load() ??
        OcptBreakdownRightDockTab.inspector;

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(
        state.copyToLoadedWithoutProject(
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          lastRightDockTab: lastRightDockTab,
        ),
      );
      return true;
    }

    // Queued with the views' reloads: a read made here but emitted after a newer one would put
    // older data over it.
    return runSerially(() async {
      final previewedVersion = project.previewedVersion;
      final screenplayText = await _loadScreenplayText(project);
      final pageSetup = await _loadPageSetup(project);
      final snapshotRead = await _loadSnapshot(project);
      if (snapshotRead.isError) {
        return false;
      }

      final snapshot = snapshotRead.value!;

      emitter(
        state.copyToLoaded(
          title: project.name,
          previewedVersionId: previewedVersion?.id,
          screenplayText: screenplayText,
          pageSetup: pageSetup,
          snapshot: snapshot,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          lastRightDockTab: lastRightDockTab,
        ),
      );
      return true;
    });
  }

  /// Read the selected episode's current Fountain source text, kept in
  /// `OcptBreakdownState.screenplayText` for the script view to slice scene by scene.
  Future<String> _loadScreenplayText(OcptOpenProjectModel project) => _projectsManager
      .screenplayService
      .loadScreenplayText(database: project.database, screenplayId: _screenplayIdOf(project));

  /// Read the page setup the script view is typeset with: the open project's own page format,
  /// paired with the app-wide margins preference, exactly as `OcptShotListBloc`'s own scenario
  /// coverage dialog pairs them.
  ///
  /// A version being previewed is laid out with the setup it was written against instead, which
  /// travels on the open project model and is never written anywhere.
  Future<OcptPageSetup> _loadPageSetup(OcptOpenProjectModel project) async =>
      project.previewedPageSetup ??
      OcptPageSetup(
        format: await _projectsManager.loadCurrentProjectPageFormat() ?? OcptPageFormat.usLetter,
        margins:
            await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
      );

  /// Read the whole breakdown of the selected episode's screenplay, joining [_breakdownService]'s
  /// scenes and tag with [_elementsService]/[_roleIndexService]/
  /// [_locationsService]/[_peopleService]'s four catalogues into one [OcptBreakdownSnapshot].
  ///
  /// The scenes are numbered with their episode's own prefix: this bloc reads the project's live
  /// episodes through [_projectsManager]'s own `screenplayService` (never through
  /// [_breakdownService], which `OcptScreenplayService` already depends on) and resolves the
  /// selected episode's number with `ocptEpisodePrefixNumberOf`, null on a single-episode project.
  ///
  /// Answers the failure of the scenes, tags, elements, roles or locations read, in place of the
  /// snapshot: the people read still raises when the database fails.
  @useResult
  Future<OcptDatabaseResult<OcptBreakdownSnapshot>> _loadSnapshot(
    OcptOpenProjectModel project,
  ) async {
    final database = project.database;
    final screenplayId = _screenplayIdOf(project);

    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: database);
    final episodeNumber = ocptEpisodePrefixNumberOf(episodes: episodes, screenplayId: screenplayId);

    final scenesRead = await _breakdownService.loadScenes(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: episodeNumber,
    );
    if (scenesRead.isError) {
      return OcptDatabaseResult(status: scenesRead.status, extraInfo: scenesRead.extraInfo);
    }

    final tagsRead = await _breakdownService.loadTags(
      database: database,
      screenplayId: screenplayId,
    );
    if (tagsRead.isError) {
      return OcptDatabaseResult(status: tagsRead.status, extraInfo: tagsRead.extraInfo);
    }

    final elementsRead = await _elementsService.loadElements(database: database);
    if (elementsRead.isError) {
      return OcptDatabaseResult(status: elementsRead.status, extraInfo: elementsRead.extraInfo);
    }

    final scenes = scenesRead.value!;
    final tagRows = tagsRead.value!;
    final elements = elementsRead.value!;
    final rolesRead = await _roleIndexService.loadRoles(database: database);
    if (rolesRead.isError) {
      return OcptDatabaseResult(status: rolesRead.status, extraInfo: rolesRead.extraInfo);
    }

    final roles = rolesRead.value!;
    final locationsRead = await _locationsService.loadLocations(database: database);
    if (locationsRead.isError) {
      return OcptDatabaseResult(status: locationsRead.status, extraInfo: locationsRead.extraInfo);
    }

    final locations = locationsRead.value!;
    final people = await _peopleService.loadPeople(database: database);

    return OcptDatabaseResult(
      status: OcptDatabaseStatus.ok,
      value: OcptBreakdownSnapshot.build(
        screenplayId: screenplayId,
        scenes: scenes,
        tags: [for (final row in tagRows) OcptBreakdownTag.fromRow(row)],
        elements: elements,
        roles: roles,
        sets: [for (final location in locations) ...location.sets],
        locations: locations,
        people: people,
      ),
    );
  }

  /// Leave the workspace: closes the current project and navigates back to the home page.
  Future<void> _onBackRequested(
    OcptBreakdownBackRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }

  /// Re-read the page setup after the project settings page changed something.
  ///
  /// Nothing in the snapshot itself depends on the page format, but reloading it here too is what
  /// keeps this mode from being the one place a change made on the project settings page is
  /// silently missed, mirroring `OcptShotListBloc._onProjectSettingsChanged`.
  Future<void> _onProjectSettingsChanged(
    OcptBreakdownProjectSettingsChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await runSerially(() async {
      final pageSetup = await _loadPageSetup(project);
      emitter(state.copyWithReloadedPageSetup(pageSetup: pageSetup));
    });
  }

  /// Select scene `event.sceneId`, touching neither the selected target nor the right dock — the
  /// left dock's own list, and the target inspector's occurrence jump, both mean only this much.
  /// [_onSceneHeadingSelected] is the louder sibling the script view's headings use.
  ///
  /// A scene id that no longer exists in the current snapshot (a stale click on a panel rebuilt
  /// underneath) is ignored rather than selecting nothing. Flushes any pending field edit
  /// first, and drops whatever tag-removal confirmation the previous selection was showing: both
  /// belonged to the sheet this selection is about to replace.
  Future<void> _onSceneSelected(
    OcptBreakdownSceneSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await runPendingWritesFlushers();

    final exists = state.scenes.any((scene) => scene.id == event.sceneId);
    if (!exists) {
      return;
    }

    emitter(state.copyWithSelectedScene(sceneId: event.sceneId));
  }

  /// Select scene `event.sceneId` **and shows its own breakdown sheet**, dispatched by a click on
  /// one of the script view's heading rows.
  ///
  /// Everything [_onSceneSelected] does, plus the two things that make the sheet actually appear:
  /// the selected target is dropped — the scene inspector is what the `Inspector` tab shows
  /// precisely while none is selected — and the right dock is opened on that tab, a closed one
  /// opening there and one already showing `Versions` switching. This is
  /// [_onTargetSelected]'s own hand-off, applied to a scene: a click in the centre lands the user
  /// on the sheet of whatever they clicked. The left dock's scene list deliberately keeps the
  /// quieter [_onSceneSelected] instead.
  Future<void> _onSceneHeadingSelected(
    OcptBreakdownSceneHeadingSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await runPendingWritesFlushers();

    final exists = state.scenes.any((scene) => scene.id == event.sceneId);
    if (!exists) {
      return;
    }

    await _persistLastRightDockTab(OcptBreakdownRightDockTab.inspector);

    emitter(state.copyWithSelectedSceneHeading(sceneId: event.sceneId));
  }

  /// Select the scene of one of the selected target's occurrences, dispatched by a row of
  /// `OcptBreakdownTargetInspector`'s own occurrences section.
  ///
  /// Delegates straight to [_onSceneSelected]: an occurrence's click means the same thing a scene
  /// panel row's does, jumping the script view and the left dock to that scene, and it is kept as
  /// its own event only because it is asked from a different place — there is no scroll-to-passage
  /// yet, so the target inspector itself stays exactly where it was.
  Future<void> _onOccurrenceSelected(
    OcptBreakdownOccurrenceSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) => _onSceneSelected(OcptBreakdownSceneSelectedEvent(sceneId: event.sceneId), emitter);

  /// Toggle the left (scene) dock's visibility.
  Future<void> _onLeftPanelToggled(
    OcptBreakdownLeftPanelToggledEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(state.copyWithToggledListPanel());
  }

  /// Select a tab of the right dock (the already-active tab closes the dock, any other one opens or
  /// switches to it) and record it as the tab the toolbar's toggle reopens the dock on.
  ///
  /// Flushes any pending field edit first — the inspector tab this may be leaving is the
  /// one place they are shown — mirroring `OcptShotListBloc._onRightDockTabSelected`. Opening the
  /// `Versions` tab is one of the two moments `MixinOcptProjectVersionsBloc`'s working-copy card
  /// needs a fresh read for: the other is a field edit flushing while it is already the one showing
  /// (see `OcptBreakdownInspectorBloc.onFlushRequested`).
  Future<void> _onRightDockTabSelected(
    OcptBreakdownRightDockTabSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await runPendingWritesFlushers();

    final isAlreadyActive = state.rightDockTab == event.tab;
    await _persistLastRightDockTab(event.tab);

    emitter(state.copyWithToggledRightDockTab(tab: event.tab, isAlreadyActive: isAlreadyActive));

    if (!isAlreadyActive && event.tab == OcptBreakdownRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Toggle the right dock from the workspace toolbar: an open dock closes, a closed one reopens
  /// on [OcptBreakdownState.lastRightDockTab], and that reopening is the moment the working-copy
  /// card needs a fresh read for whenever it lands on `Versions`.
  Future<void> _onRightDockToggled(
    OcptBreakdownRightDockToggledEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    if (state.rightDockTab != null) {
      emitter(state.copyWithRightDockClosed());
      return;
    }

    emitter(state.copyWithRightDockReopened());

    if (state.lastRightDockTab == OcptBreakdownRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Close the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptBreakdownRightDockClosedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(state.copyWithRightDockClosed());
  }

  /// Persist [tab] as the mode's last right dock tab, unless it already is.
  Future<void> _persistLastRightDockTab(OcptBreakdownRightDockTab tab) async {
    if (state.lastRightDockTab == tab || _storedLastRightDockTab == tab) {
      return;
    }

    await _propertiesManager.breakdownLastRightDockTab.store(tab);
    _storedLastRightDockTab = tab;
  }

  /// Apply and persist whichever dock fraction the ended drag gesture reports.
  Future<void> _onDockFractionsChanged(
    OcptBreakdownDockFractionsChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final left = event.left;
    final right = event.right;

    if (left != null) {
      await _propertiesManager.breakdownLeftDockFraction.store(left);
    }
    if (right != null) {
      await _propertiesManager.breakdownRightDockFraction.store(right);
    }

    emitter(state.copyWithDockFractions(left: left, right: right));
  }

  /// Restore both dock fractions to their defaults, persisting them.
  Future<void> _onDockLayoutReset(
    OcptBreakdownDockLayoutResetEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _propertiesManager.breakdownLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await _propertiesManager.breakdownRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );

    emitter(
      state.copyWithDockFractions(
        left: OcptWorkspaceDock.leftDefaultFraction,
        right: OcptWorkspaceDock.rightDefaultFraction,
      ),
    );
  }

  /// Toggle whether `event.key` is hidden from the script view's own highlighting.
  Future<void> _onLegendEntryToggled(
    OcptBreakdownLegendEntryToggledEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final hiddenLegendKeys = Set<OcptBreakdownLegendKey>.from(state.hiddenLegendKeys);
    if (!hiddenLegendKeys.remove(event.key)) {
      hiddenLegendKeys.add(event.key);
    }

    emitter(state.copyWithHiddenLegendKeys(hiddenLegendKeys: hiddenLegendKeys));
  }

  /// Reveal every legend key currently hidden from the script view's own highlighting.
  Future<void> _onLegendShowAllRequested(
    OcptBreakdownLegendShowAllRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(state.copyWithAllLegendKeysShown());
  }

  /// Select which of the two views (script or recap) the centre shows, dispatched by the header's
  /// own `Script`/`Recap` switch.
  ///
  /// Moves the selection epoch with the `centreView` cause, which has `OcptBreakdownTaggingBloc`
  /// clear any pending tag anchor and pending range: the popover they might be driving has no
  /// script sheet left to close over once the centre leaves it.
  Future<void> _onCentreViewSelected(
    OcptBreakdownCentreViewSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(state.copyWithCentreView(view: event.view));
  }

  /// Record the header's own search field text as typed.
  ///
  /// The moment `event.query` turns non-empty while the script view is active, switches the centre
  /// to the recap in the same emitted state — carrying the just-typed text into the view that
  /// actually answers it — and moves the selection epoch for the same reason
  /// [_onCentreViewSelected] does. Clearing the field back to empty afterward does **not** switch
  /// back to the script view, per [OcptBreakdownSearchQueryChangedEvent]'s own doc comment.
  Future<void> _onSearchQueryChanged(
    OcptBreakdownSearchQueryChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final switchesToRecap =
        event.query.isNotEmpty && state.centreView == OcptBreakdownCentreView.script;

    emitter(state.copyWithSearchQuery(query: event.query, switchesToRecap: switchesToRecap));
  }

  /// Select target `event.targetKind`/`event.targetId`, and the scene the click happened in — so
  /// the left dock and the sheet stay in step, exactly as a click on a scene panel row already does
  /// on its own — and open the right dock on the `Inspector` tab: a closed dock opens there, one
  /// already showing `Versions` switches, so a tagged word's click always lands the user on its
  /// sheet without a second gesture. Mirrors [_onSceneSelected]'s own defensive check: a scene id
  /// no longer in the current snapshot (a stale click on a sheet rebuilt underneath) is ignored for
  /// the scene selection alone, the target selection itself is still applied.
  ///
  /// Flushes any pending field edit first, and drops whatever tag-removal confirmation the
  /// previous selection was showing, exactly as [_onSceneSelected] does.
  Future<void> _onTargetSelected(
    OcptBreakdownTargetSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await runPendingWritesFlushers();
    await _persistLastRightDockTab(OcptBreakdownRightDockTab.inspector);

    final sceneExists = state.scenes.any((scene) => scene.id == event.sceneId);

    emitter(
      state.copyWithSelectedTarget(
        targetKind: event.targetKind,
        targetId: event.targetId,
        sceneId: event.sceneId,
        sceneExists: sceneExists,
      ),
    );
  }

  /// Select the scene a first click of the script opened a tag anchor in, dispatched by
  /// `OcptBreakdownTaggingBloc`: a tag belongs to one scene, so an anchor spanning two would mean
  /// nothing.
  ///
  /// Unlike [_onSceneSelected], a scene id that no longer exists in the current snapshot drops the
  /// scene selection rather than being ignored, and the selected target and the right dock are left
  /// alone. Has every view write what it holds first, like every selection move.
  Future<void> _onAnchorSceneSelected(
    OcptBreakdownAnchorSceneSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await runPendingWritesFlushers();

    final sceneExists = state.scenes.any((scene) => scene.id == event.sceneId);
    emitter(state.copyWithAnchoredScene(sceneId: event.sceneId, sceneExists: sceneExists));
  }

  /// Clear the currently selected target. Flushes any pending field edit first, and drops
  /// whatever tag-removal confirmation was showing, exactly as [_onSceneSelected] does.
  Future<void> _onTargetSelectionCleared(
    OcptBreakdownTargetSelectionClearedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await runPendingWritesFlushers();
    emitter(state.copyWithTargetSelectionCleared());
  }
}
