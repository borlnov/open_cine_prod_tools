// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';

/// This is the bloc class for the shot list mode's shot inspector: the selected shot's typed
/// fields, difficulty, characters and scenario coverage, and the cast-wide role changes the shared
/// role alert banner offers.
///
/// The shots, the roles and the screenplay text are the mode's data, in `OcptShotListState`. This
/// bloc owns what the inspector does with them: the text typed into a field and not yet written
/// ([OcptShotListInspectorState.pendingFieldEdits]), the anchor of the coverage range being drawn
/// ([OcptShotListInspectorState.pendingCoverageAnchor]) and its own write error.
///
/// **Writing.** Most of a shot's fields are authored one discrete action at a time (a difficulty
/// dot, a character chip, a coverage click): each is written to the project database immediately
/// through the services, then this bloc waits for the mode to read the data again
/// (`OcptShotListBloc.reload`), so every derived aggregate the UI shows (a sequence's shot count,
/// its average difficulty, a shot's code) stays exactly what the database says, and only then emits
/// its own state. The typed free-text fields are the exception: an edit is held in the pending map
/// and written [OcptShotListBloc.defaultFieldEditDebounce] after the last keystroke, on a timer of
/// this bloc's own, mirroring `OcptEditorBloc`'s own autosave convention. The mode flushes it
/// immediately ahead of anything that needs the database to be up to date (selecting another shot
/// or sequence, an export, a version preview, leaving the workspace), and the mode's own
/// `deactivate()` writes it directly when the mode leaves the widget tree for any other reason, so
/// a pending edit is never silently dropped. Committing a shot size additionally deduces the shot's
/// abbreviation from it while the shot has none of its own ([_deduceAbbreviationIfEmpty]), which is
/// the only write this bloc performs that the user didn't type themselves.
///
/// A shot's scenario coverage ranges are a further set of discrete, immediately-written actions:
/// [_onCoverageWordClicked] resolves a word click against
/// [OcptShotListInspectorState.pendingCoverageAnchor] into adding, removing, or simply moving where
/// the next click would close a range (see that handler's own doc comment for the three-state
/// interaction) — a range being added also attaches the characters it covers to the shot, see
/// [_attachCharactersCoveredBy] —, [_onCoverageClearRequested] drops every range of a shot, and
/// [_onShotMarkedAsChecked] clears a shot's `needsCheck` flag and re-stamps its ranges' digests.
/// [_onCoverageAnchorCancelled] is the odd one out: it never touches a range at all, only the
/// pending anchor a first click opened, so the coverage dialog can be backed out of without
/// recording anything.
///
/// **Reacting.** When the mode moves its selection, this bloc clears the coverage anchor, as the
/// mode bloc itself did before the inspector had a bloc of its own: a different or the same
/// sequence, a selected or created or deleted shot and a fresh load clear it; selecting a set does
/// not. When the mode reads its data again, a typed edit whose shot is gone from the shot list is
/// dropped.
class OcptShotListInspectorBloc
    extends AbsOcptViewBloc<OcptShotListInspectorState, OcptShotListState, OcptShotListBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "shot_list_inspector_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to read and write the shot list.
  final OcptShotListService _shotListService;

  /// The service used to merge/delete/keep an orphaned or collided role.
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read and write a shot's scenario coverage ranges.
  final OcptShotCoverageService _shotCoverageService;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// {@macro open_cine_prod_tools.viewBlocConstructorWithDebounce}
  OcptShotListInspectorBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptShotListService? shotListService,
    OcptRoleIndexService? roleIndexService,
    OcptShotCoverageService? shotCoverageService,
    Duration fieldEditDebounce = OcptShotListBloc.defaultFieldEditDebounce,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _shotListService =
           shotListService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).shotListService,
       _roleIndexService =
           roleIndexService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).roleIndexService,
       _shotCoverageService =
           shotCoverageService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).shotCoverageService,
       _fieldEditDebounce = fieldEditDebounce,
       super(const OcptShotListInspectorState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptShotListShotFieldChangedEvent>(_onShotFieldChanged);
    on<OcptShotListInspectorFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptShotListShotDifficultyChangedEvent>(_onShotDifficultyChanged);
    on<OcptShotListShotCharacterToggledEvent>(_onShotCharacterToggled);
    on<OcptShotListCharacterAddRequestedEvent>(_onCharacterAddRequested);
    on<OcptShotListOrphanedRoleDeleteRequestedEvent>(_onOrphanedRoleDeleteRequested);
    on<OcptShotListOrphanedRoleKeptEvent>(_onOrphanedRoleKept);
    on<OcptShotListRoleMergeRequestedEvent>(_onRoleMergeRequested);
    on<OcptShotListCoverageWordClickedEvent>(_onCoverageWordClicked);
    on<OcptShotListCoverageClearRequestedEvent>(_onCoverageClearRequested);
    on<OcptShotListCoverageAnchorCancelledEvent>(_onCoverageAnchorCancelled);
    on<OcptShotListShotMarkedAsCheckedEvent>(_onShotMarkedAsChecked);
    on<OcptShotListInspectorWriteErrorDismissedEvent>(_onWriteErrorDismissed);
  }

  /// Clear what the mode's selection move invalidates, and drop what the mode's fresh data no
  /// longer holds.
  ///
  /// Reads the shot list from [modeBloc]'s current state — the latest data — but the cause of the
  /// selection move from the state that moved it (`event.modeState`), so two quick moves are each
  /// reacted to for what they were. Waits for nothing: the mode's change and this reaction must
  /// land in the same turn of the event loop.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptShotListState> event,
    Emitter<OcptShotListInspectorState> emitter,
  ) async {
    final isAnchorCleared =
        event.hasSelectionMoved &&
        switch (event.modeState.selectionCause) {
          OcptShotListSelectionCause.sequence ||
          OcptShotListSelectionCause.sequenceReselected ||
          OcptShotListSelectionCause.shot ||
          OcptShotListSelectionCause.shotCreated ||
          OcptShotListSelectionCause.shotDeleted ||
          OcptShotListSelectionCause.load => true,
          // Selecting a set has never touched the coverage anchor: it belongs to the shot.
          OcptShotListSelectionCause.set ||
          OcptShotListSelectionCause.setAdded ||
          OcptShotListSelectionCause.setRemoved ||
          OcptShotListSelectionCause.symbolRemoved ||
          OcptShotListSelectionCause.symbolHidden ||
          OcptShotListSelectionCause.arrowRemoved ||
          OcptShotListSelectionCause.none => false,
        };

    final snapshot = modeBloc.state.snapshot;
    var pending = state.pendingFieldEdits;
    if (event.hasReloaded && snapshot != null) {
      pending = Map<OcptShotListPendingEditKey, String>.of(pending)
        ..removeWhere(
          (key, _) => switch (key) {
            OcptShotListShotFieldEditKey(:final shotId) => !snapshot.shotsById.containsKey(shotId),
            OcptShotListPanelCommentEditKey() => false,
            OcptShotListAnnotationTextEditKey() => false,
            OcptShotListSetNameEditKey() => false,
            OcptShotListSymbolLabelEditKey() => false,
          },
        );
      if (pending.isEmpty) {
        cancelDebounce();
      }
    }

    emitter(
      state.copyWithPrunedFieldEdits(
        pendingFieldEdits: pending.length == state.pendingFieldEdits.length ? null : pending,
        isAnchorCleared: isAnchorCleared,
      ),
    );
  }

  /// Write every pending field edit immediately: cancels the debounce timer (a no-op if it already
  /// fired or there was none), writes each one through `OcptShotListService.updateShot`, then has
  /// the mode read the shot list and the suggestion lists again, so every derived aggregate and
  /// every field's suggestions reflect what the database now says, and only then forgets them, so
  /// what a field shows never falls back to a stale stored value between the two. A no-op while
  /// nothing is pending. Answers `nothingToWrite` when nothing was pending.
  ///
  /// Called by the debounce firing, and by the mode ahead of every action that needs the database
  /// to be up to date.
  @override
  Future<OcptPendingWritesStatus> onFlushRequested(
    Emitter<OcptShotListInspectorState> emitter,
  ) async {
    cancelDebounce();

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return OcptPendingWritesStatus.nothingToWrite;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWithFieldEditsCleared());
      return OcptPendingWritesStatus.ok;
    }

    try {
      await _writeAllPendingFields(project: project, pending: pending);
      await modeBloc.reload({
        OcptShotListReloadScope.snapshot,
        OcptShotListReloadScope.suggestions,
      });
      emitter(
        state.copyWithFlushedFieldEdits(
          pendingFieldEdits: ocptPendingEditsAfterWrite(
            current: state.pendingFieldEdits,
            written: pending,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending shot list field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyToFlushFailed(
          pendingFieldEdits: ocptPendingEditsAfterWrite(
            current: state.pendingFieldEdits,
            written: pending,
          ),
        ),
      );
    }

    return OcptPendingWritesStatus.ok;
  }

  /// Write every pending field edit directly to the database, bypassing the debounce timer, the
  /// bloc's own event queue and its state.
  ///
  /// Called by the mode's own `deactivate()` (through the flushers it registered), mirroring
  /// `OcptStyledScreenplayEditor.deactivate()`: `deactivate()` runs before `dispose()` for every
  /// removal from the tree (a mode switch swaps this whole subtree out, and so does the
  /// workspace's own back navigation), so triggering the write here — rather than dispatching an
  /// event, which would only be processed on a later microtask this widget might not survive to
  /// see — is what guarantees the last [OcptShotListBloc.defaultFieldEditDebounce] worth of typing
  /// isn't lost, and by the bloc closing.
  ///
  /// Unlike [onFlushRequested], this never touches [state]: `emit` may only be called from inside
  /// a registered `on<Event>` handler (the package's own rule, enforced by the analyzer's
  /// `visible_for_testing` lint on `Bloc.emit`), and by the time this runs the widget tree that
  /// would show a fresh state is already gone anyway. Like `OcptEditorBloc.disposeLifeCycle`'s own
  /// flush, a failure here is only logged.
  @override
  Future<void> flushPendingWritesWithoutState() async {
    cancelDebounce();

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await flushEditsWithoutStateUntilConverted(
        pending,
        (edits) => _writeAllPendingFields(project: project, pending: edits),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending shot list field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }
  }

  /// Record the raw text just typed into `event.field` of shot `event.shotId` as a pending edit,
  /// visible immediately, and (re)starts the field-edit debounce that eventually writes it.
  Future<void> _onShotFieldChanged(
    OcptShotListShotFieldChangedEvent event,
    Emitter<OcptShotListInspectorState> emitter,
  ) async {
    final pending = Map<OcptShotListPendingEditKey, String>.of(state.pendingFieldEdits)
      ..[OcptShotListShotFieldEditKey(shotId: event.shotId, field: event.field)] = event.rawValue;
    emitter(state.copyWithTypedFieldEdits(pendingFieldEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptShotListInspectorFieldEditFlushRequestedEvent());
  }

  /// Write every pending field edit once the debounce elapses with no further typing.
  ///
  /// When something was written and the `Versions` tab is the one showing, also asks the mode to
  /// refresh its working-copy card, as the mode itself does when a flush it runs lands.
  Future<void> _onFieldEditFlushRequested(
    OcptShotListInspectorFieldEditFlushRequestedEvent event,
    Emitter<OcptShotListInspectorState> emitter,
  ) async {
    final status = await onFlushRequested(emitter);

    if (status == OcptPendingWritesStatus.ok &&
        modeBloc.state.rightDockTab == OcptShotListRightDockTab.versions) {
      addToMode(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Write every entry of [pending] that is a shot field through
  /// `OcptShotListService.updateShot` (translating it into the matching named argument, see
  /// `OcptShotListEditableField`'s own doc comment for the mapping, and deducing an abbreviation
  /// alongside every shot size committed here, see [_deduceAbbreviationIfEmpty]).
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
        case OcptShotListPanelCommentEditKey() ||
            OcptShotListAnnotationTextEditKey() ||
            OcptShotListSetNameEditKey() ||
            OcptShotListSymbolLabelEditKey():
          // The other kinds of edit are the other views' own and are never recorded here.
          break;
      }
    }
  }

  /// Write onto shot [shotId] the abbreviation [ocptDeduceShotAbbreviation] reads out of the
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
    final stored = modeBloc.state.snapshot?.shotsById[shotId]?.abbreviation ?? "";
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

  /// Write a single field edit through `OcptShotListService.updateShot`.
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

  /// Set one difficulty axis of shot `event.shotId` to `event.value`, written immediately.
  Future<void> _onShotDifficultyChanged(
    OcptShotListShotDifficultyChangedEvent event,
    Emitter<OcptShotListInspectorState> emitter,
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
      await modeBloc.reload({OcptShotListReloadScope.snapshot});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to change the difficulty of shot ${event.shotId} of "
        "project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Attach role `event.roleId` to shot `event.shotId` if it isn't already, detach it
  /// otherwise, written immediately.
  Future<void> _onShotCharacterToggled(
    OcptShotListShotCharacterToggledEvent event,
    Emitter<OcptShotListInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final shot = modeBloc.state.snapshot?.shotsById[event.shotId];
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
      await modeBloc.reload({OcptShotListReloadScope.snapshot});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to toggle role ${event.roleId} on shot ${event.shotId} "
        "of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Resolve `event.characterName` to a live role, or **creates** a hand-added silent one linked to
  /// the selected episode (decision 1), then attach it to shot `event.shotId`: the inspector's
  /// `＋ Add` field, dispatched once submitted. Written immediately, and reads both the shot list
  /// and the whole cast again, since this is the one shot list action that can mint a fresh role.
  Future<void> _onCharacterAddRequested(
    OcptShotListCharacterAddRequestedEvent event,
    Emitter<OcptShotListInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final roleId = await _shotListService.resolveOrCreateRoleId(
        database: project.database,
        screenplayId: modeBloc.screenplayIdOf(project),
        name: event.characterName,
      );
      if (roleId != null) {
        await _shotListService.attachCharacter(
          database: project.database,
          shotId: event.shotId,
          roleId: roleId,
        );
        await modeBloc.reload({OcptShotListReloadScope.snapshot, OcptShotListReloadScope.roles});
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to add a character to shot "
        "${event.shotId} of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Delete orphaned role `event.roleId` for good, written immediately: the shared role alert
  /// banner's orphaned variant's `Delete the role` action, dispatched once the mode's own
  /// `OcptConfirmDialog` has already confirmed it.
  Future<void> _onOrphanedRoleDeleteRequested(
    OcptShotListOrphanedRoleDeleteRequestedEvent event,
    Emitter<OcptShotListInspectorState> emitter,
  ) => _writeRoleChange(
    emitter: emitter,
    action: (project) =>
        _roleIndexService.deleteRole(database: project.database, roleId: event.roleId),
  );

  /// Keep orphaned role `event.roleId` as a hand-added silent role, written immediately: the
  /// shared role alert banner's orphaned variant's `Keep as silent` action — not destructive, so
  /// reached with no confirmation dialog.
  Future<void> _onOrphanedRoleKept(
    OcptShotListOrphanedRoleKeptEvent event,
    Emitter<OcptShotListInspectorState> emitter,
  ) => _writeRoleChange(
    emitter: emitter,
    action: (project) => _roleIndexService.keepOrphanedRoleAsSilent(
      database: project.database,
      roleId: event.roleId,
    ),
  );

  /// Merge role `event.sourceRoleId` into role `event.targetRoleId`, written immediately: the
  /// shared role alert banner's merge affordance — either variant — dispatched once the mode's own
  /// `OcptConfirmDialog` has already confirmed it.
  Future<void> _onRoleMergeRequested(
    OcptShotListRoleMergeRequestedEvent event,
    Emitter<OcptShotListInspectorState> emitter,
  ) => _writeRoleChange(
    emitter: emitter,
    action: (project) => _roleIndexService.mergeRole(
      database: project.database,
      sourceRoleId: event.sourceRoleId,
      targetRoleId: event.targetRoleId,
    ),
  );

  /// Write a cast-wide role change through [action], a service call that answers an outcome, and
  /// have the mode read both the shot list and the whole cast again, so every view derived from
  /// either (the shared role alert banner, a shot's own chips, the table's characters column)
  /// reflects what the database now says. A failed outcome raises the write error and reads
  /// nothing. Serves the three actions the shared role alert banner offers.
  Future<void> _writeRoleChange({
    required Emitter<OcptShotListInspectorState> emitter,
    required Future<OcptDatabaseOutcome> Function(OcptOpenProjectModel project) action,
  }) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final written = await action(project);
    if (written.isError) {
      emitter(state.copyToWriteFailed());
      return;
    }

    await modeBloc.reload({OcptShotListReloadScope.snapshot, OcptShotListReloadScope.roles});
  }

  /// Resolve a click on a scenario coverage word, exactly as
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
  /// same [_writeCoverageChange] action so both land before the shot list is read again: see
  /// [_attachCharactersCoveredBy].
  Future<void> _onCoverageWordClicked(
    OcptShotListCoverageWordClickedEvent event,
    Emitter<OcptShotListInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final modeState = modeBloc.state;
    final layout = modeState.buildSelectedCoverageLayout();
    if (project == null || layout == null || modeState.selectedShotId != event.shotId) {
      return;
    }

    final anchor = state.pendingCoverageAnchor;

    if (anchor == null) {
      final coveringRange = layout.rangeAt(
        event.wordStartOffset,
        modeState.selectedShot?.coverageRanges ?? const [],
      );
      if (coveringRange == null) {
        emitter(
          state.copyWithCoverageAnchor(
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
        final added = await _shotCoverageService.addRange(
          database: project.database,
          shotId: event.shotId,
          sceneId: layout.sceneId,
          startOffset: range.startOffset,
          endOffset: range.endOffset,
          sceneText: layout.sceneText,
        );
        if (added.isError) {
          return OcptDatabaseOutcome(status: added.status, extraInfo: added.extraInfo);
        }

        await _attachCharactersCoveredBy(
          project: project,
          shotId: event.shotId,
          layout: layout,
          range: range,
        );

        return const OcptDatabaseOutcome(status: OcptDatabaseStatus.ok);
      },
    );
  }

  /// Attach to shot [shotId] every character the range just recorded covers, so selecting a
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
    final modeState = modeBloc.state;
    final attachedRoleIds =
        modeState.snapshot?.shotsById[shotId]?.characterRoleIds ?? const <String>[];
    final covered = layout.charactersCoveredBy(
      startOffset: range.startOffset,
      endOffset: range.endOffset,
    );

    for (final characterName in covered) {
      final role = modeState.roles.firstWhereOrNull((role) => role.name == characterName);
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

  /// Remove every scenario coverage range of shot `event.shotId`, written immediately: the
  /// inspector's `Clear all` action.
  Future<void> _onCoverageClearRequested(
    OcptShotListCoverageClearRequestedEvent event,
    Emitter<OcptShotListInspectorState> emitter,
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

  /// Clear the pending coverage anchor, exactly as `OcptShotListCoverageAnchorCancelledEvent`
  /// documents: dispatched by the coverage dialog's `Escape`, a click on empty space in its script
  /// area, or the dialog closing. Leaves the selected shot's own coverage ranges untouched.
  Future<void> _onCoverageAnchorCancelled(
    OcptShotListCoverageAnchorCancelledEvent event,
    Emitter<OcptShotListInspectorState> emitter,
  ) async {
    emitter(state.copyWithCoverageAnchorCleared());
  }

  /// Clear shot `event.shotId`'s `needsCheck` flag and re-stamp every one of its scenario
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
    Emitter<OcptShotListInspectorState> emitter,
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
        currentFountainText: modeBloc.state.screenplayText,
      ),
    );
  }

  /// Write a scenario coverage change through [action], have the mode read the shot list again so
  /// every dependent aggregate (the `modified` badge, the "also covered by" wash, a shot's
  /// `needsCheck`) reflects what the database now says, and clear the pending coverage anchor — a
  /// coverage write always leaves the interaction back at its initial, no-anchor state. Mirrors
  /// `_onShotDifficultyChanged`/`_onShotCharacterToggled`'s own try/catch shape.
  ///
  /// A failed outcome of [action] and an exception it raises (the characters it attaches are not
  /// written through a status yet) end the same way: nothing is read again and the coverage write
  /// error is raised.
  Future<void> _writeCoverageChange({
    required Emitter<OcptShotListInspectorState> emitter,
    required OcptOpenProjectModel project,
    required String shotId,
    required Future<OcptDatabaseOutcome> Function() action,
  }) async {
    var hasFailed = false;
    try {
      final written = await action();
      if (written.isError) {
        hasFailed = true;
      } else {
        await modeBloc.reload({OcptShotListReloadScope.snapshot});
        emitter(state.copyWithCoverageAnchorCleared());
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to change the scenario coverage of shot $shotId of "
        "project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      hasFailed = true;
    }

    if (hasFailed) {
      emitter(state.copyToCoverageWriteFailed());
    }
  }

  /// Dismiss the transient write error currently shown.
  Future<void> _onWriteErrorDismissed(
    OcptShotListInspectorWriteErrorDismissedEvent event,
    Emitter<OcptShotListInspectorState> emitter,
  ) async {
    emitter(state.copyWithWriteErrorDismissed());
  }
}
