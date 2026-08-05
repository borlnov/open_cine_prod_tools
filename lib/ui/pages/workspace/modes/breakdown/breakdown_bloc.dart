// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// This is the bloc class for the breakdown production mode (dépouillement du scénario).
///
/// It loads the current project's title, the two dock fractions, and the mode's own read on
/// entry — the screenplay's Fountain text (kept in state for `OcptBreakdownScriptView` to slice
/// scene by scene), the page setup the script view is typeset with, and one
/// [OcptBreakdownSnapshot] joining [_breakdownService]'s scenes and tags with
/// [_elementsService]/[_roleIndexService]/[_locationsService]'s three catalogues, the way
/// `OcptResourcesBloc` builds its own `OcptResourcesSnapshot` — and holds the selected scene, the
/// left dock's visibility, the right dock tab and the two fractions on top of it.
///
/// It also mixes in [MixinOcptProjectVersionsBloc], which owns everything the right dock's
/// `Versions` tab does. The two hooks the mixin needs are answered by
/// [flushPendingProjectWrites] — a no-op today, see its own doc comment for why — and
/// [reloadFromProjectDatabase]. [_onRightDockTabSelected] dispatches
/// [OcptProjectWorkingCopyRefreshRequestedEvent] on opening the `Versions` tab, exactly as the
/// other two modes do; unlike them, there is no field-edit flush landing to dispatch it a second
/// time, since this milestone writes nothing.
class OcptBreakdownBloc extends BlocForMixin<OcptBreakdownState>
    with MixinOcptProjectVersionsBloc<OcptBreakdownState> {
  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's dock fractions.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The service used to read the breakdown scenes and tags.
  final OcptBreakdownService _breakdownService;

  /// The service used to read the physical elements catalogue.
  final OcptElementsService _elementsService;

  /// The service used to read the cast reconciled against the screenplay.
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read locations and their sets.
  final OcptLocationsService _locationsService;

  /// Class constructor
  ///
  /// Every dependency can be overridden, which is what the tests do; in the app they all resolve
  /// through [globalGetIt].
  OcptBreakdownBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptBreakdownService? breakdownService,
    OcptElementsService? elementsService,
    OcptRoleIndexService? roleIndexService,
    OcptLocationsService? locationsService,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
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
       super(OcptBreakdownState.init()) {
    add(const OcptBreakdownLoadRequestedEvent());
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBreakdownLoadRequestedEvent>(_onLoadRequested);
    on<OcptBreakdownBackRequestedEvent>(_onBackRequested);
    on<OcptBreakdownProjectSettingsChangedEvent>(_onProjectSettingsChanged);
    on<OcptBreakdownSceneSelectedEvent>(_onSceneSelected);
    on<OcptBreakdownLeftPanelToggledEvent>(_onLeftPanelToggled);
    on<OcptBreakdownRightDockTabSelectedEvent>(_onRightDockTabSelected);
    on<OcptBreakdownRightDockToggledEvent>(_onRightDockToggled);
    on<OcptBreakdownRightDockClosedEvent>(_onRightDockClosed);
    on<OcptBreakdownDockFractionsChangedEvent>(_onDockFractionsChanged);
    on<OcptBreakdownDockLayoutResetEvent>(_onDockLayoutReset);
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// This milestone writes nothing: the script view's words are plain text, not yet clickable, and
  /// neither a scene's breakdown notes nor a target's inspector fields exist to debounce yet. So
  /// there is nothing a preview swapping the database out could ever strand — this is a no-op, kept
  /// only to answer the mixin's hook, and it will flush the scene notes' and the inspector's own
  /// debounce once a later milestone adds them, exactly as `OcptResourcesBloc.flushPendingFieldEdits`
  /// does for its own five pending-edit maps today.
  @protected
  @override
  Future<void> flushPendingProjectWrites(Emitter<OcptBreakdownState> emitter) async {}

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<void> reloadFromProjectDatabase(Emitter<OcptBreakdownState> emitter) =>
      _onLoadRequested(const OcptBreakdownLoadRequestedEvent(), emitter);

  /// Loads the persisted dock fractions and the current project's whole breakdown read.
  ///
  /// The workspace route is guarded by the router manager, so a project is normally always open
  /// here; if none is (e.g. the bloc is built directly in a test), the state simply stops loading
  /// with no snapshot at all.
  ///
  /// This is also [MixinOcptProjectVersionsBloc]'s [reloadFromProjectDatabase] hook, so it emits
  /// which version is being previewed alongside the read it just performed: what it read comes from
  /// that very version's in-memory database, and the two must reach the mode together (see the
  /// hook's own doc comment). The selected scene is always cleared on a (re)load, mirroring
  /// `OcptResourcesBloc`'s own selection reset: a preview or a restore changes the whole database
  /// underneath, so a stale selection is dropped rather than trusted to still mean the same thing.
  Future<void> _onLoadRequested(
    OcptBreakdownLoadRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final leftDockFraction =
        await _propertiesManager.breakdownLeftDockFraction.load() ??
        OcptWorkspaceDock.leftDefaultFraction;
    final rightDockFraction =
        await _propertiesManager.breakdownRightDockFraction.load() ??
        OcptWorkspaceDock.rightDefaultFraction;

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(
        state.copyWith(
          isLoading: false,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          clearPreviewedVersionId: true,
        ),
      );
      return;
    }

    final previewedVersion = project.previewedVersion;
    final screenplayText = await _loadScreenplayText(project);
    final pageSetup = await _loadPageSetup(project);
    final snapshot = await _loadSnapshot(project);

    emitter(
      state.copyWith(
        isLoading: false,
        title: project.name,
        previewedVersionId: previewedVersion?.id,
        clearPreviewedVersionId: previewedVersion == null,
        screenplayText: screenplayText,
        pageSetup: pageSetup,
        snapshot: snapshot,
        clearSelectedSceneId: true,
        leftDockFraction: leftDockFraction,
        rightDockFraction: rightDockFraction,
      ),
    );
  }

  /// Reads [project]'s current Fountain source text, kept in `OcptBreakdownState.screenplayText` for
  /// the script view to slice scene by scene.
  Future<String> _loadScreenplayText(OcptOpenProjectModel project) =>
      _projectsManager.screenplayService.loadScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
      );

  /// Reads the page setup the script view is typeset with: the open project's own page format,
  /// paired with the app-wide margins preference, exactly as `OcptShotListBloc`'s own scenario
  /// coverage dialog pairs them.
  ///
  /// A version being previewed is laid out with the setup it was written against instead, which
  /// travels on the open project model and is never written anywhere.
  Future<OcptPageSetup> _loadPageSetup(OcptOpenProjectModel project) async =>
      project.previewedPageSetup ??
      OcptPageSetup(
        format: await _projectsManager.loadCurrentProjectPageFormat() ?? OcptPageFormat.usLetter,
        margins: await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
      );

  /// Reads the whole breakdown of [project]'s primary screenplay, joining
  /// [_breakdownService]'s scenes and tags with [_elementsService]/[_roleIndexService]/
  /// [_locationsService]'s three catalogues into one [OcptBreakdownSnapshot].
  Future<OcptBreakdownSnapshot> _loadSnapshot(OcptOpenProjectModel project) async {
    final database = project.database;
    final screenplayId = project.primaryScreenplayId;

    final scenes = await _breakdownService.loadScenes(
      database: database,
      screenplayId: screenplayId,
    );
    final tagRows = await _breakdownService.loadTags(
      database: database,
      screenplayId: screenplayId,
    );
    final elements = await _elementsService.loadElements(database: database);
    final roles = await _roleIndexService.loadRoles(
      database: database,
      screenplayId: screenplayId,
    );
    final locations = await _locationsService.loadLocations(database: database);

    return OcptBreakdownSnapshot.build(
      screenplayId: screenplayId,
      scenes: scenes,
      tags: [for (final row in tagRows) OcptBreakdownTag.fromRow(row)],
      elements: elements,
      roles: roles,
      sets: [for (final location in locations) ...location.sets],
    );
  }

  /// Leaves the workspace: closes the current project and navigates back to the home page.
  Future<void> _onBackRequested(
    OcptBreakdownBackRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }

  /// Re-reads the page setup after the project settings page changed something.
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

    final pageSetup = await _loadPageSetup(project);
    emitter(state.copyWith(pageSetup: pageSetup));
  }

  /// Selects scene `event.sceneId`.
  ///
  /// A scene id that no longer exists in the current snapshot (a stale click on a panel rebuilt
  /// underneath) is ignored rather than selecting nothing.
  Future<void> _onSceneSelected(
    OcptBreakdownSceneSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final exists = state.scenes.any((scene) => scene.id == event.sceneId);
    if (!exists) {
      return;
    }

    emitter(state.copyWith(selectedSceneId: event.sceneId));
  }

  /// Toggles the left (scene) dock's visibility.
  Future<void> _onLeftPanelToggled(
    OcptBreakdownLeftPanelToggledEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(state.copyWith(isListPanelVisible: !state.isListPanelVisible));
  }

  /// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens
  /// or switches to it).
  ///
  /// Opening the `Versions` tab is the one moment `MixinOcptProjectVersionsBloc`'s working-copy card
  /// needs a fresh read for in this mode: there is no field-edit flush to dispatch it a second time,
  /// since this milestone writes nothing.
  Future<void> _onRightDockTabSelected(
    OcptBreakdownRightDockTabSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final isAlreadyActive = state.rightDockTab == event.tab;

    emitter(
      state.copyWith(
        rightDockTab: isAlreadyActive ? null : event.tab,
        clearRightDockTab: isAlreadyActive,
      ),
    );

    if (!isAlreadyActive && event.tab == OcptBreakdownRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens
  /// on its single tab, and that reopening is the moment the working-copy card needs a fresh read
  /// for.
  Future<void> _onRightDockToggled(
    OcptBreakdownRightDockToggledEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    if (state.rightDockTab != null) {
      emitter(state.copyWith(clearRightDockTab: true));
      return;
    }

    emitter(state.copyWith(rightDockTab: OcptBreakdownRightDockTab.versions));
    add(const OcptProjectWorkingCopyRefreshRequestedEvent());
  }

  /// Closes the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptBreakdownRightDockClosedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(state.copyWith(clearRightDockTab: true));
  }

  /// Applies and persists whichever dock fraction the ended drag gesture reports.
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

    emitter(state.copyWith(leftDockFraction: left, rightDockFraction: right));
  }

  /// Restores both dock fractions to their defaults, persisting them.
  Future<void> _onDockLayoutReset(
    OcptBreakdownDockLayoutResetEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _propertiesManager.breakdownLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await _propertiesManager.breakdownRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );

    emitter(
      state.copyWith(
        leftDockFraction: OcptWorkspaceDock.leftDefaultFraction,
        rightDockFraction: OcptWorkspaceDock.rightDefaultFraction,
      ),
    );
  }
}
