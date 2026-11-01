// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_roles_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';

/// This is the bloc class for the resources mode's roles tab: the cast's role sheet and its
/// candidates card.
///
/// The catalogue is the mode's data, in `OcptResourcesState.snapshot`, and which role is selected
/// is the mode's too. This bloc owns what the role sheet does with them: every write (the service,
/// then `await modeBloc.reload(…)` for the snapshot, and only then the selection of the role it
/// created) and the edits typed into the role's name and casting notes and into each candidacy's
/// note and not yet written ([OcptResourcesRolesState]), which it writes
/// [OcptResourcesBloc.defaultFieldEditDebounce] after the last keystroke, on a timer of its own
/// shared by the two maps; the mode flushes them ahead of anything that needs the database to be up
/// to date.
///
/// A role's cast member, kind and episodes, the removed-role banner's actions and a candidacy's
/// status and audition date are written the moment they change. A role's name is never written
/// here for an `isFromScreenplay` role — `OcptRoleIndexService`'s own reconciliation owns it, and
/// would overwrite a hand-typed name right back on the next save; withholding that field is the
/// widgets' job, not a special case here.
///
/// **Failing.** A write that fails raises the mode's write error (`OcptResourcesWriteFailedEvent`).
/// A flush that fails drops every edit typed into **any** sheet, not only this one's, through
/// `OcptResourcesPendingEditsLostEvent`: the mode shows the one error, and every view reacts by
/// emptying what it holds ([onModeStateChanged]).
class OcptResourcesRolesBloc
    extends AbsOcptViewBloc<OcptResourcesRolesState, OcptResourcesState, OcptResourcesBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "resources_roles_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger = buildOcptLogsHelper(_loggerCategory);

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to read, and write, the cast, reconciled against the project's episodes.
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read, and write, the people seen for each role.
  final OcptRoleCandidatesService _roleCandidatesService;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// The `lostEditsEpoch` of the mode state this bloc last reacted to.
  int _lastLostEditsEpoch;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by
  /// tests, to keep it fast and deterministic.
  OcptResourcesRolesBloc({
    required OcptResourcesBloc modeBloc,
    OcptProjectsManager? projectsManager,
    OcptRoleIndexService? roleIndexService,
    OcptRoleCandidatesService? roleCandidatesService,
    Duration fieldEditDebounce = OcptResourcesBloc.defaultFieldEditDebounce,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _roleIndexService =
           roleIndexService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).roleIndexService,
       _roleCandidatesService =
           roleCandidatesService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).roleCandidatesService,
       _fieldEditDebounce = fieldEditDebounce,
       _lastLostEditsEpoch = modeBloc.state.lostEditsEpoch,
       super(const OcptResourcesRolesState.init(), modeBloc: modeBloc);

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptResourcesRoleCreationRequestedEvent>(_onRoleCreationRequested);
    on<OcptResourcesRoleFieldChangedEvent>(_onRoleFieldChanged);
    on<OcptResourcesRoleDeletionRequestedEvent>(_onRoleDeletionRequested);
    on<OcptResourcesRoleCandidateFieldChangedEvent>(_onRoleCandidateFieldChanged);
    on<OcptResourcesRoleCandidateRemovedEvent>(_onRoleCandidateRemoved);
    on<OcptResourcesRolesFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptResourcesRoleCastChangedEvent>(_onRoleCastChanged);
    on<OcptResourcesRoleKindChangedEvent>(_onRoleKindChanged);
    on<OcptResourcesRoleEpisodesChangedEvent>(_onRoleEpisodesChanged);
    on<OcptResourcesOrphanedRoleKeptEvent>(_onOrphanedRoleKept);
    on<OcptResourcesRoleMergeRequestedEvent>(_onRoleMergeRequested);
    on<OcptResourcesRoleCandidateAddedEvent>(_onRoleCandidateAdded);
    on<OcptResourcesRoleCandidateStatusChangedEvent>(_onRoleCandidateStatusChanged);
    on<OcptResourcesRoleCandidateAuditionDateChangedEvent>(_onRoleCandidateAuditionDateChanged);
  }

  /// Drops the edits this bloc holds when the mode says writing them failed somewhere (see
  /// `OcptResourcesPendingEditsLostEvent`): the fields fall back to the stored values.
  ///
  /// Nothing else is scoped to the selection or to the data here: a pending edit survives the user
  /// selecting another role, since it is written by its own debounce or by the flush the selection
  /// starts, and the mode reading the catalogue again after a write changes nothing about what was
  /// typed. Waits for nothing, as the mode's change and this reaction must land in the same turn of
  /// the event loop.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptResourcesState> event,
    Emitter<OcptResourcesRolesState> emitter,
  ) async {
    final lostEditsEpoch = event.modeState.lostEditsEpoch;
    if (lostEditsEpoch <= _lastLostEditsEpoch) {
      return;
    }

    _lastLostEditsEpoch = lostEditsEpoch;
    cancelDebounce();
    if (state.pendingRoleFieldEdits.isNotEmpty || state.pendingCandidateFieldEdits.isNotEmpty) {
      emitter(state.copyWithFieldEditsCleared());
    }
  }

  /// Adds a hand-added role of `event.kind` at the end of the cast, reads the catalogue again and
  /// selects the new role so it can be named straight away.
  ///
  /// Writes whatever is pending first, so adding a role right after typing never loses it.
  Future<void> _onRoleCreationRequested(
    OcptResourcesRoleCreationRequestedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final roleId = await _roleIndexService.addRole(
        database: project.database,
        screenplayId: modeBloc.screenplayIdOf(project),
        name: "",
        kind: event.kind,
      );
      if (roleId == null) {
        // The write was refused (a version is being previewed read-only); the shell already
        // withholds the button that dispatches this event, so this is only ever a race.
        return;
      }

      if (!await modeBloc.reload({OcptResourcesReloadScope.snapshot})) {
        return;
      }

      await addToModeAndWait(
        OcptResourcesRecordCreatedEvent(tab: OcptResourcesTab.roles, recordId: roleId),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to create a role in project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      addToMode(const OcptResourcesWriteFailedEvent());
    }
  }

  /// Records the raw text just typed into `event.field` of role `event.roleId` as a pending edit,
  /// visible immediately, and (re)starts the field-edit debounce that eventually writes it: a role's
  /// and a candidacy's pending edits are always flushed together, by the very same timer.
  Future<void> _onRoleFieldChanged(
    OcptResourcesRoleFieldChangedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) async {
    final pending = Map<(String, OcptRoleField), String>.of(state.pendingRoleFieldEdits)
      ..[(event.roleId, event.field)] = event.rawValue;
    emitter(state.copyWithRoleFieldEditTyped(pendingRoleFieldEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptResourcesRolesFieldEditFlushRequestedEvent());
  }

  /// Records the raw text just typed into `event.field` of candidacy `event.candidateId` as a
  /// pending edit, visible immediately, and (re)starts the same field-edit debounce
  /// [_onRoleFieldChanged] does.
  Future<void> _onRoleCandidateFieldChanged(
    OcptResourcesRoleCandidateFieldChangedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) async {
    final pending = Map<(String, OcptRoleCandidateField), String>.of(
      state.pendingCandidateFieldEdits,
    )..[(event.candidateId, event.field)] = event.rawValue;
    emitter(state.copyWithCandidateFieldEditTyped(pendingCandidateFieldEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptResourcesRolesFieldEditFlushRequestedEvent());
  }

  /// Deletes role `event.roleId`, clearing the selection when it was the selected role, and
  /// dropping any pending field edit of the role that still targeted it.
  Future<void> _onRoleDeletionRequested(
    OcptResourcesRoleDeletionRequestedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    if (_pendingWithoutRole(event.roleId).isEmpty && state.pendingCandidateFieldEdits.isEmpty) {
      cancelDebounce();
    }

    try {
      await _roleIndexService.deleteRole(database: project.database, roleId: event.roleId);
      if (!await modeBloc.reload({OcptResourcesReloadScope.snapshot})) {
        return;
      }

      emitter(state.copyWithRoleDeleted(pendingRoleFieldEdits: _pendingWithoutRole(event.roleId)));
      await addToModeAndWait(
        OcptResourcesRecordDroppedEvent(tab: OcptResourcesTab.roles, recordId: event.roleId),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete role ${event.roleId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      addToMode(const OcptResourcesWriteFailedEvent());
    }
  }

  /// The pending role field edits of this bloc without those that target role [roleId].
  Map<(String, OcptRoleField), String> _pendingWithoutRole(String roleId) =>
      Map<(String, OcptRoleField), String>.of(state.pendingRoleFieldEdits)
        ..removeWhere((key, _) => key.$1 == roleId);

  /// Removes candidacy `event.candidateId`, dropping any pending field edit that still targeted
  /// it. The confirmation dialog is the mode's, this only runs once it has already confirmed.
  Future<void> _onRoleCandidateRemoved(
    OcptResourcesRoleCandidateRemovedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    if (_pendingWithoutCandidate(event.candidateId).isEmpty &&
        state.pendingRoleFieldEdits.isEmpty) {
      cancelDebounce();
    }

    try {
      await _roleCandidatesService.removeCandidate(
        database: project.database,
        candidateId: event.candidateId,
      );
      if (!await modeBloc.reload({OcptResourcesReloadScope.snapshot})) {
        return;
      }

      emitter(
        state.copyWithCandidateRemoved(
          pendingCandidateFieldEdits: _pendingWithoutCandidate(event.candidateId),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to remove candidacy ${event.candidateId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      addToMode(const OcptResourcesWriteFailedEvent());
    }
  }

  /// The pending candidacy field edits of this bloc without those that target candidacy
  /// [candidateId].
  Map<(String, OcptRoleCandidateField), String> _pendingWithoutCandidate(String candidateId) =>
      Map<(String, OcptRoleCandidateField), String>.of(state.pendingCandidateFieldEdits)
        ..removeWhere((key, _) => key.$1 == candidateId);

  /// Fired by the field-edit debounce timer: writes every pending field edit.
  Future<void> _onFieldEditFlushRequested(
    OcptResourcesRolesFieldEditFlushRequestedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) async {
    await onFlushRequested(emitter);
  }

  /// Writes every pending field edit immediately: cancels the debounce timer (a no-op if it already
  /// fired or there was none), writes each role field through `OcptRoleIndexService.updateRole` and
  /// each candidacy field through `OcptRoleCandidatesService.updateCandidate`, then has the mode
  /// read the catalogue again so every derived aggregate reflects what the database now says, and
  /// only then forgets what it wrote, so what a field shows never falls back to a stale stored
  /// value between the two. A no-op while nothing is pending. Answers whether there was anything
  /// pending.
  ///
  /// A write that fails drops **every** edit of the mode and raises the one write error (see
  /// [_loseEdits]); the snapshot is not read again, so the fields show the value they had. A read
  /// after a write that landed which fails only raises the write error: what was written is
  /// forgotten and the other views keep what they hold, to be written in their turn. When the write landed and the `Versions` tab is the one showing, also asks the mode
  /// to refresh its working-copy card.
  ///
  /// Called by the debounce firing, and by the mode ahead of every action that needs the database
  /// to be up to date.
  @override
  Future<bool> onFlushRequested(Emitter<OcptResourcesRolesState> emitter) async {
    cancelDebounce();

    final pendingRoleEdits = state.pendingRoleFieldEdits;
    final pendingCandidateEdits = state.pendingCandidateFieldEdits;
    if (pendingRoleEdits.isEmpty && pendingCandidateEdits.isEmpty) {
      return false;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWithFieldEditsCleared());
      return true;
    }

    try {
      await _writeAllPendingRoleFields(database: project.database, pending: pendingRoleEdits);
      await _writeAllPendingCandidateFields(
        database: project.database,
        pending: pendingCandidateEdits,
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending resources field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      await _loseEdits(emitter);
      return true;
    }

    // A read that fails changes nothing here: the write landed, so what was written is forgotten
    // all the same, and the mode has already raised the write error. Dropping the edits of the
    // other views as well would lose what no write failure has touched.
    await modeBloc.reload({OcptResourcesReloadScope.snapshot});

    emitter(
      state.copyWithFieldEditsWritten(
        pendingRoleFieldEdits: ocptPendingEditsAfterWrite(
          current: state.pendingRoleFieldEdits,
          written: pendingRoleEdits,
        ),
        pendingCandidateFieldEdits: ocptPendingEditsAfterWrite(
          current: state.pendingCandidateFieldEdits,
          written: pendingCandidateEdits,
        ),
      ),
    );

    // The other of the two moments the working-copy card needs a fresh read for (see
    // `OcptResourcesBloc._onRightDockTabSelected`): a field edit landing while the tab showing it
    // is already open.
    if (modeBloc.state.rightDockTab == OcptResourcesRightDockTab.versions) {
      addToMode(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }

    return true;
  }

  /// Tells the mode that writing the typed edits failed, which raises its write error and makes
  /// every view drop what it holds, this one included; waits for that, so the flush goes on to the
  /// other views with nothing left for them to write.
  ///
  /// This bloc empties its own maps as well, for the mode that is closing and no longer answers.
  Future<void> _loseEdits(Emitter<OcptResourcesRolesState> emitter) async {
    await addToModeAndWait(const OcptResourcesPendingEditsLostEvent());
    emitter(state.copyWithFieldEditsCleared());
  }

  /// Writes every pending field edit directly to the database, bypassing the debounce timer, the
  /// bloc's own event queue and its state.
  ///
  /// Called by the mode's own `deactivate()` (through the flushers it registered), mirroring
  /// `OcptShotListBloc.flushPendingFieldEdits`: `deactivate()` runs before `dispose()` for every
  /// removal from the tree (a mode switch swaps this whole subtree out, and so does the workspace's
  /// own back navigation), so triggering the write here — rather than dispatching an event, which
  /// would only be processed on a later microtask this widget might not survive to see — is what
  /// guarantees the last [OcptResourcesBloc.defaultFieldEditDebounce] worth of typing isn't lost.
  ///
  /// Unlike [onFlushRequested], this never touches [state]: `emit` may only be called from inside
  /// a registered `on<Event>` handler, and by the time this runs the widget tree that would show a
  /// fresh state is already gone anyway. A failure here is only logged.
  @override
  Future<void> flushPendingWritesWithoutState() async {
    cancelDebounce();

    final pendingRoleEdits = state.pendingRoleFieldEdits;
    final pendingCandidateEdits = state.pendingCandidateFieldEdits;
    if (pendingRoleEdits.isEmpty && pendingCandidateEdits.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await flushEditsWithoutState(
        pendingRoleEdits,
        (edits) => _writeAllPendingRoleFields(database: project.database, pending: edits),
      );
      await flushEditsWithoutState(
        pendingCandidateEdits,
        (edits) => _writeAllPendingCandidateFields(database: project.database, pending: edits),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending resources field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }
  }

  /// Writes a discrete change to the cast through [action] and has the mode read the catalogue
  /// again, so every derived aggregate (the roles tab's pill and counts, the status bar) reflects
  /// what the database now says. A no-op while no project is open; a failure raises the mode's
  /// write error.
  Future<void> _writeCatalogueChange({
    required String logContext,
    required Future<void> Function(OcptOpenProjectModel project) action,
  }) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await action(project);
      await modeBloc.reload({OcptResourcesReloadScope.snapshot});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to $logContext of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      addToMode(const OcptResourcesWriteFailedEvent());
    }
  }

  /// Casts `event.personId` to role `event.roleId` (or uncasts it, when null), written
  /// immediately.
  Future<void> _onRoleCastChanged(
    OcptResourcesRoleCastChangedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) => _writeCatalogueChange(
    logContext: "cast a person to role ${event.roleId}",
    action: (project) => _roleIndexService.updateRole(
      database: project.database,
      roleId: event.roleId,
      personId: Value(event.personId),
    ),
  );

  /// Sets role `event.roleId`'s kind, written immediately.
  Future<void> _onRoleKindChanged(
    OcptResourcesRoleKindChangedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) => _writeCatalogueChange(
    logContext: "change the kind of role ${event.roleId}",
    action: (project) => _roleIndexService.updateRole(
      database: project.database,
      roleId: event.roleId,
      kind: Value(event.kind),
    ),
  );

  /// Sets role `event.roleId`'s episodes to `event.episodeIds`, written immediately — the sheet's
  /// own gesture write, `OcptRoleIndexService.setRoleEpisodes` (gating this to a hand-added role is
  /// the sheet's job, not this handler's, exactly as `_onRoleFieldChanged` leaves a
  /// `isFromScreenplay` role's name to `OcptRoleIndexService.reconcile` to overwrite back).
  Future<void> _onRoleEpisodesChanged(
    OcptResourcesRoleEpisodesChangedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) => _writeCatalogueChange(
    logContext: "change the episodes of role ${event.roleId}",
    action: (project) => _roleIndexService.setRoleEpisodes(
      database: project.database,
      roleId: event.roleId,
      screenplayIds: event.episodeIds,
    ),
  );

  /// The removed-role banner's "keep it" action for role `event.roleId`, written immediately.
  Future<void> _onOrphanedRoleKept(
    OcptResourcesOrphanedRoleKeptEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) => _writeCatalogueChange(
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
    OcptResourcesRoleMergeRequestedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) => _writeCatalogueChange(
    logContext: "merge role ${event.sourceRoleId} into ${event.targetRoleId}",
    action: (project) => _roleIndexService.mergeRole(
      database: project.database,
      sourceRoleId: event.sourceRoleId,
      targetRoleId: event.targetRoleId,
    ),
  );

  /// Records that person `event.personId` is a candidate for role `event.roleId`, written
  /// immediately — the candidates card's own person picker.
  Future<void> _onRoleCandidateAdded(
    OcptResourcesRoleCandidateAddedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) => _writeCatalogueChange(
    logContext: "add a candidate to role ${event.roleId}",
    action: (project) async {
      await _roleCandidatesService.addCandidate(
        database: project.database,
        roleId: event.roleId,
        personId: event.personId,
      );
    },
  );

  /// Sets candidacy `event.candidateId`'s status to `event.status`, written immediately.
  ///
  /// **The single event behind every status gesture the candidates card offers**, `Retain` and
  /// `Drop` included: retaining is `setStatus(retained)`, dropping is `setStatus(seen)`. The rule
  /// keeping `roles.personId` in step with the retained candidacy lives in
  /// `OcptRoleCandidatesService.setStatus` alone — a second event here could only ever disagree
  /// with it.
  Future<void> _onRoleCandidateStatusChanged(
    OcptResourcesRoleCandidateStatusChangedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) => _writeCatalogueChange(
    logContext: "change the status of candidacy ${event.candidateId}",
    action: (project) => _roleCandidatesService.setStatus(
      database: project.database,
      candidateId: event.candidateId,
      status: event.status,
    ),
  );

  /// Sets candidacy `event.candidateId`'s audition date to `event.auditionedOn`, written
  /// immediately: picking a date is a single discrete action, not typing.
  Future<void> _onRoleCandidateAuditionDateChanged(
    OcptResourcesRoleCandidateAuditionDateChangedEvent event,
    Emitter<OcptResourcesRolesState> emitter,
  ) => _writeCatalogueChange(
    logContext: "change the audition date of candidacy ${event.candidateId}",
    action: (project) => _roleCandidatesService.updateCandidate(
      database: project.database,
      candidateId: event.candidateId,
      auditionedOn: Value(event.auditionedOn),
    ),
  );

  /// Writes every entry of [pending] through [_writeRoleField].
  Future<void> _writeAllPendingRoleFields({
    required OcptProjectDatabase database,
    required Map<(String, OcptRoleField), String> pending,
  }) async {
    for (final entry in pending.entries) {
      final (roleId, field) = entry.key;
      await _writeRoleField(
        database: database,
        roleId: roleId,
        field: field,
        rawValue: entry.value,
      );
    }
  }

  /// Writes a single role field edit through `OcptRoleIndexService.updateRole`, translating
  /// [field] into the matching named argument (see `OcptRoleField`'s own doc comment for the
  /// mapping).
  ///
  /// Writes [rawValue] as-is even for an `isFromScreenplay` role's [OcptRoleField.name]: the
  /// widgets are what withhold that field from being typed into in the first place, since
  /// `OcptRoleIndexService.reconcile` would overwrite it right back on the next save.
  Future<void> _writeRoleField({
    required OcptProjectDatabase database,
    required String roleId,
    required OcptRoleField field,
    required String rawValue,
  }) async {
    switch (field) {
      case OcptRoleField.name:
        await _roleIndexService.updateRole(
          database: database,
          roleId: roleId,
          name: Value(rawValue),
        );
      case OcptRoleField.castingNotes:
        await _roleIndexService.updateRole(
          database: database,
          roleId: roleId,
          castingNotes: Value(rawValue),
        );
    }
  }

  /// Writes every entry of [pending] through [_writeCandidateField].
  Future<void> _writeAllPendingCandidateFields({
    required OcptProjectDatabase database,
    required Map<(String, OcptRoleCandidateField), String> pending,
  }) async {
    for (final entry in pending.entries) {
      final (candidateId, field) = entry.key;
      await _writeCandidateField(
        database: database,
        candidateId: candidateId,
        field: field,
        rawValue: entry.value,
      );
    }
  }

  /// Writes a single candidacy field edit through `OcptRoleCandidatesService.updateCandidate`,
  /// translating [field] into the matching named argument (see `OcptRoleCandidateField`'s own doc
  /// comment for the mapping — [OcptRoleCandidateField.notes] is its only entry).
  Future<void> _writeCandidateField({
    required OcptProjectDatabase database,
    required String candidateId,
    required OcptRoleCandidateField field,
    required String rawValue,
  }) async {
    switch (field) {
      case OcptRoleCandidateField.notes:
        await _roleCandidatesService.updateCandidate(
          database: database,
          candidateId: candidateId,
          notes: Value(rawValue),
        );
    }
  }
}
