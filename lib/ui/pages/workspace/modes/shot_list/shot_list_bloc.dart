// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// This is the bloc class for the shot list (découpage technique) production mode.
///
/// It loads the current project's whole shot list from [OcptShotListService] on entry — sequences
/// are built in memory by joining the scene index with the shots referencing it, so the mode
/// always shows the screenplay as it stands rather than a duplicated copy of it — and holds the
/// selection, the dock geometry and the visible table columns on top of it.
///
/// Unlike the screenplay editor, this bloc has no debounce and no dirty state: a shot list is
/// authored one discrete action at a time (creating a shot, picking a status, toggling a
/// character), and each of those is written to the project database immediately, then the
/// snapshot is re-read so every derived aggregate the UI shows (a sequence's shot count, its
/// average difficulty, a shot's code) stays exactly what the database says. The free-text fields
/// of the shot inspector will need a typing debounce of their own; nothing this bloc owns today
/// does.
class OcptShotListBloc extends BlocForMixin<OcptShotListState> {
  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's dock fractions, visible columns and last
  /// right dock tab.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The service used to read and write the shot list.
  final OcptShotListService _shotListService;

  /// Class constructor
  ///
  /// Every dependency can be overridden, which is what the tests do; in the app they all resolve
  /// through [globalGetIt].
  OcptShotListBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptShotListService? shotListService,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _shotListService =
           shotListService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).shotListService,
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
    on<OcptShotListBackRequestedEvent>(_onBackRequested);
  }

  /// Loads the persisted preferences and the current project's shot list, selecting its first
  /// sequence.
  ///
  /// The workspace route is guarded by the router manager, so a project is normally always open
  /// here; if none is (e.g. the bloc is built directly in a test), the state simply stops loading
  /// with no snapshot at all.
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

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(
        state.copyWith(
          isLoading: false,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          visibleColumns: visibleColumns,
          lastRightDockTab: lastRightDockTab,
        ),
      );
      return;
    }

    final snapshot = await _loadSnapshot(project);

    emitter(
      state.copyWith(
        isLoading: false,
        title: project.name,
        snapshot: snapshot,
        selectedSequenceId: snapshot.sequences.isEmpty ? null : snapshot.sequences.first.id,
        clearSelectedSequenceId: snapshot.sequences.isEmpty,
        clearSelectedShotId: true,
        leftDockFraction: leftDockFraction,
        rightDockFraction: rightDockFraction,
        visibleColumns: visibleColumns,
        lastRightDockTab: lastRightDockTab,
      ),
    );
  }

  /// Reads the whole shot list of [project]'s primary screenplay.
  Future<OcptShotListSnapshot> _loadSnapshot(OcptOpenProjectModel project) =>
      _shotListService.loadShotList(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
      );

  /// Selects a sequence, clearing the selected shot when it actually changes sequence (the centre
  /// table then lists shots the previous selection isn't among).
  Future<void> _onSequenceSelected(
    OcptShotListSequenceSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final isSameSequence = state.selectedSequenceId == event.sequenceId;

    emitter(
      state.copyWith(
        selectedSequenceId: event.sequenceId,
        clearSelectedShotId: !isSameSequence,
      ),
    );
  }

  /// Selects a shot, together with the sequence holding it, and opens the right dock on its
  /// inspector tab.
  ///
  /// A shot id that no longer exists in the current snapshot (a stale click on a list rebuilt
  /// underneath) is ignored rather than selecting nothing.
  Future<void> _onShotSelected(
    OcptShotListShotSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final sequence = _sequenceHolding(event.shotId);
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
    final project = _projectsManager.currentProject;
    final sequence = state.selectedSequence;
    if (project == null || sequence is! OcptSceneShotSequence) {
      return;
    }

    try {
      final shotId = await _shotListService.createShot(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
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

  /// Leaves the workspace: closes the current project and navigates back to the home page.
  Future<void> _onBackRequested(
    OcptShotListBackRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }
}
