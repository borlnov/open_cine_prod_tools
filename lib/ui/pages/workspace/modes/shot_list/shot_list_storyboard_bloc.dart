// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/constants/ocpt_asset_file_types.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_state.dart';

/// This is the bloc class for the shot list mode's storyboard: the board centre view and the
/// inspector's Panels group, which edit the very same panels.
///
/// The panels are the mode's data, in `OcptShotListState.storyboardSnapshot`. This bloc owns what
/// the board does with them: which panel and which mark are selected, which annotation tool is on,
/// how tall the frames are drawn, and the comments and mark texts typed and not yet written
/// ([OcptShotListStoryboardState.pendingFieldEdits]).
///
/// **Writing.** A write calls [OcptStoryboardService], then waits for the mode to read the
/// storyboard again (`OcptShotListBloc.reload`), and only then emits the board's own selection: the
/// mode's state already holds the panel this bloc is about to select, so no widget ever sees a
/// selection naming a panel the data does not have. A typed comment is held in the pending map and
/// written [OcptShotListBloc.defaultFieldEditDebounce] after the last keystroke, on a timer of its
/// own; the mode flushes it ahead of anything that needs the database to be up to date.
///
/// **Reacting.** When the mode moves its selection this bloc clears what was scoped to the previous
/// one, as the mode bloc itself did before the board had a bloc of its own: a different sequence,
/// a selected shot (the same one again included) and a fresh load clear the panel, the tool and the
/// mark; selecting the sequence already shown, or a set, clears nothing. When the mode reads its
/// data again, a typed edit whose panel or mark no longer exists is dropped, and so is a selected
/// panel that is gone.
class OcptShotListStoryboardBloc
    extends AbsOcptViewBloc<OcptShotListStoryboardState, OcptShotListState, OcptShotListBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "shot_list_storyboard_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to read and write the board's panels: `addPanel`, `replacePanelImage`,
  /// `reorderPanel`, `updatePanelComment`, `deletePanel` and the marks' own CRUD.
  final OcptStoryboardService _storyboardService;

  /// The manager used to pick a panel's frame through the native "open" dialog, mirroring
  /// `OcptResourcesBloc`'s own `_pickFilePath`.
  final FileSelectorManager? _fileSelectorManager;

  /// The delay between the last comment edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by
  /// tests, to keep it fast and deterministic.
  OcptShotListStoryboardBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptStoryboardService? storyboardService,
    FileSelectorManager? fileSelectorManager,
    Duration fieldEditDebounce = OcptShotListBloc.defaultFieldEditDebounce,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _storyboardService =
           storyboardService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).storyboardService,
       _fileSelectorManager = fileSelectorManager,
       _fieldEditDebounce = fieldEditDebounce,
       super(const OcptShotListStoryboardState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
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
    on<OcptShotListStoryboardFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptShotListStoryboardWriteErrorDismissedEvent>(_onWriteErrorDismissed);
  }

  /// Clear what the mode's selection move invalidates, and drop what the mode's fresh data no
  /// longer holds.
  ///
  /// Reads the storyboard from [modeBloc]'s current state — the latest data — but the cause of the
  /// selection move from the state that moved it (`event.modeState`), so two quick moves are each
  /// reacted to for what they were. Waits for nothing: the mode's change and this reaction must
  /// land in the same turn of the event loop, or a frame could draw a selection that names a panel
  /// of the previous shot.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptShotListState> event,
    Emitter<OcptShotListStoryboardState> emitter,
  ) async {
    final isSelectionCleared =
        event.hasSelectionMoved &&
        switch (event.modeState.selectionCause) {
          OcptShotListSelectionCause.sequence ||
          OcptShotListSelectionCause.shot ||
          OcptShotListSelectionCause.shotDeleted ||
          OcptShotListSelectionCause.load => true,
          // Creating a shot selects it without clearing the panel selection: the board has always
          // behaved so, and it is kept as it is.
          OcptShotListSelectionCause.shotCreated ||
          OcptShotListSelectionCause.sequenceReselected ||
          OcptShotListSelectionCause.set ||
          OcptShotListSelectionCause.setAdded ||
          OcptShotListSelectionCause.setRemoved ||
          OcptShotListSelectionCause.symbolRemoved ||
          OcptShotListSelectionCause.symbolHidden ||
          OcptShotListSelectionCause.arrowRemoved ||
          OcptShotListSelectionCause.none => false,
        };

    final storyboardSnapshot = modeBloc.state.storyboardSnapshot;
    var isPanelGone = false;
    var pending = state.pendingFieldEdits;
    if (event.hasReloaded && storyboardSnapshot != null) {
      final panels = storyboardSnapshot.panelsByShotId.values.expand((panels) => panels);
      final panelIds = {for (final panel in panels) panel.id};
      final annotationIds = {
        for (final panel in panels)
          for (final annotation in panel.annotations) annotation.id,
      };

      isPanelGone = state.selectedPanelId != null && !panelIds.contains(state.selectedPanelId);
      pending = Map<OcptShotListPendingEditKey, String>.of(pending)
        ..removeWhere(
          (key, _) => switch (key) {
            OcptShotListPanelCommentEditKey(:final panelId) => !panelIds.contains(panelId),
            OcptShotListAnnotationTextEditKey(:final annotationId) => !annotationIds.contains(
              annotationId,
            ),
            OcptShotListShotFieldEditKey() => false,
            OcptShotListSetNameEditKey() => false,
            OcptShotListSymbolLabelEditKey() => false,
          },
        );
      if (pending.isEmpty) {
        cancelDebounce();
      }
    }

    final isCleared = isSelectionCleared || isPanelGone;
    emitter(
      state.copyWithPrunedPanels(
        pendingFieldEdits: pending.length == state.pendingFieldEdits.length ? null : pending,
        isCleared: isCleared,
      ),
    );
  }

  /// Write every pending edit immediately: cancels the debounce timer (a no-op if it already fired
  /// or there was none), writes each one, then has the mode read the storyboard again and only then
  /// forgets them, so what a field shows never falls back to a stale stored value between the two.
  /// A no-op while nothing is pending.
  ///
  /// Called by the debounce firing, and by the mode ahead of every action that needs the database
  /// to be up to date.
  @override
  Future<bool> onFlushRequested(Emitter<OcptShotListStoryboardState> emitter) async {
    cancelDebounce();

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return false;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWithFieldEditsCleared());
      return true;
    }

    try {
      await _writeAllPendingEdits(project: project, pending: pending);
      await modeBloc.reload({OcptShotListReloadScope.storyboard});
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
        "A problem occurred when tried to flush a pending storyboard edit of project "
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

    return true;
  }

  /// Write every pending edit directly to the database, bypassing the debounce timer, the bloc's
  /// own event queue and its state — for the moments no handler can emit from (the mode leaving the
  /// tree, this bloc closing). A failure is only logged.
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
      await flushEditsWithoutState(
        pending,
        (edits) => _writeAllPendingEdits(project: project, pending: edits),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending storyboard edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }
  }

  /// Select panel `event.panelId` on the board, dispatched by a click on one of the selected
  /// shot's own panel frames. Clears the annotation tool and mark selection: both are scoped to
  /// the panel that was selected before this one
  /// (`OcptShotListStoryboardState.activeAnnotationTool`'s own doc comment).
  Future<void> _onPanelSelected(
    OcptShotListPanelSelectedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
  ) async {
    emitter(state.copyWithSelectedPanel(panelId: event.panelId));
  }

  /// Set the board's common panel height, a view preference held for the session alone.
  Future<void> _onPanelSizeChanged(
    OcptShotListPanelSizeChangedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
  ) async {
    emitter(state.copyWithBoardPanelSize(size: event.size));
  }

  /// Pick a frame through the native "open" dialog, filtered to JPEG and PNG
  /// (`ocptStoryboardPanelImageFileExtensions`), append a new panel of shot `event.shotId` and
  /// point it at the file picked, then select the new panel once the mode holds it. A cancelled
  /// dialog changes nothing at all.
  Future<void> _onPanelImportRequested(
    OcptShotListPanelImportRequestedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
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
      if (panelId != null) {
        await _storyboardService.replacePanelImage(
          database: project.database,
          panelId: panelId,
          path: path,
        );
        if (await modeBloc.reload({OcptShotListReloadScope.storyboard})) {
          emitter(state.copyWithSelectedPanel(panelId: panelId));
        }
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to import a storyboard frame onto shot ${event.shotId} "
        "of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Pick a fresh frame the same way [_onPanelImportRequested] does and re-point panel
  /// `event.panelId` at it, dispatched by its frame's own `Replace image` action. A cancelled
  /// dialog leaves the panel's current image untouched.
  Future<void> _onPanelReplaceRequested(
    OcptShotListPanelReplaceRequestedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
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
      await modeBloc.reload({OcptShotListReloadScope.storyboard});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to replace the image of panel ${event.panelId} of "
        "project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Show the native "open" dialog filtered to [ocptStoryboardPanelImageFileExtensions] and return
  /// the path picked, or null when the user cancelled it, when it failed, or when the
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

  /// Move panel `event.panelId` of shot `event.shotId` to `event.newPosition`, writing exactly one
  /// row (`OcptStoryboardService.reorderPanel`), dispatched by the strip's own drag-to-reorder
  /// gesture.
  Future<void> _onPanelReordered(
    OcptShotListPanelReorderedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
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
      await modeBloc.reload({OcptShotListReloadScope.storyboard});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to reorder panel ${event.panelId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Record the raw text just typed into panel `event.panelId`'s comment as a pending edit, and
  /// (re)starts the field-edit debounce shared with [_onAnnotationTextChanged].
  Future<void> _onPanelCommentChanged(
    OcptShotListPanelCommentChangedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
  ) async {
    _recordPendingEdit(
      emitter: emitter,
      key: OcptShotListPanelCommentEditKey(panelId: event.panelId),
      rawValue: event.rawValue,
    );
  }

  /// Delete panel `event.panelId` for good, dispatched once the inspector's Panels group's own
  /// `Delete panel` action has already been confirmed through `OcptConfirmDialog`, by the mode.
  /// Clears the panel selection (and, with it, the annotation tool and selection — see
  /// `OcptShotListStoryboardState.activeAnnotationTool`'s own doc comment) and drops any pending
  /// comment or mark-text edit that still targeted it or one of its own marks —
  /// `OcptStoryboardService.deletePanel`'s own cascade tombstones them alongside it.
  Future<void> _onPanelDeletionRequested(
    OcptShotListPanelDeletionRequestedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final wasSelected = state.selectedPanelId == event.panelId;
    final annotationIds =
        (modeBloc.state.storyboardSnapshot?.panelsByShotId.values
                    .expand((panels) => panels)
                    .firstWhereOrNull((panel) => panel.id == event.panelId)
                    ?.annotations ??
                const [])
            .map((annotation) => annotation.id)
            .toSet();
    bool isOfPanel(OcptShotListPendingEditKey key) => switch (key) {
      OcptShotListPanelCommentEditKey(:final panelId) => panelId == event.panelId,
      OcptShotListAnnotationTextEditKey(:final annotationId) => annotationIds.contains(
        annotationId,
      ),
      OcptShotListShotFieldEditKey() => false,
      OcptShotListSetNameEditKey() => false,
      OcptShotListSymbolLabelEditKey() => false,
    };

    try {
      await _storyboardService.deletePanel(database: project.database, panelId: event.panelId);
      if (await modeBloc.reload({OcptShotListReloadScope.storyboard})) {
        emitter(
          state.copyWithDeletedPanelEdits(
            // Taken now, not before the delete: a keystroke typed meanwhile is not the panel's.
            pendingFieldEdits: Map.of(state.pendingFieldEdits)
              ..removeWhere((key, _) => isOfPanel(key)),
            wasSelected: wasSelected,
          ),
        );
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete panel ${event.panelId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Set the board's active annotation tool, dispatched by the inspector's own `Annotate`
  /// control — `event.tool` is null both for "turn it off" and for the control's own toggle-off
  /// gesture (picking the tool already on again), so this always writes through
  /// `forceActiveAnnotationToolValue` rather than leaning on `copyWith`'s `??` fallback, which
  /// could never move a nullable field back to null.
  Future<void> _onAnnotationToolSelected(
    OcptShotListAnnotationToolSelectedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
  ) async {
    final tool = event.tool;
    emitter(state.copyWithActiveAnnotationTool(tool: tool));
  }

  /// Add a mark of `event.kind` to panel `event.panelId` at the normalised tail/head just dragged
  /// out on its own frame, then select the freshly minted mark once the mode holds it
  /// (`OcptStoryboardService.addAnnotation`).
  Future<void> _onAnnotationDrawn(
    OcptShotListAnnotationDrawnEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
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
      if (annotationId != null) {
        if (await modeBloc.reload({OcptShotListReloadScope.storyboard})) {
          emitter(state.copyWithSelectedAnnotation(annotationId: annotationId));
        }
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to draw a ${event.kind} mark onto panel ${event.panelId} "
        "of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Place a label on panel `event.panelId` at the normalised point just clicked, then select
  /// the freshly minted mark so its own text field opens ready for typing
  /// (`OcptStoryboardService.addAnnotation`).
  Future<void> _onAnnotationPlaced(
    OcptShotListAnnotationPlacedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
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
      if (annotationId != null) {
        if (await modeBloc.reload({OcptShotListReloadScope.storyboard})) {
          emitter(state.copyWithSelectedAnnotation(annotationId: annotationId));
        }
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to place a label onto panel ${event.panelId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Select mark `event.annotationId`, dispatched by a click on it — on its own frame's overlay,
  /// or on its row of the inspector Panels group's annotation section.
  Future<void> _onAnnotationSelected(
    OcptShotListAnnotationSelectedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
  ) async {
    emitter(state.copyWithSelectedAnnotation(annotationId: event.annotationId));
  }

  /// Record the raw text just typed into mark `event.annotationId`'s own text as a pending edit,
  /// and (re)starts the field-edit debounce shared with [_onPanelCommentChanged].
  Future<void> _onAnnotationTextChanged(
    OcptShotListAnnotationTextChangedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
  ) async {
    _recordPendingEdit(
      emitter: emitter,
      key: OcptShotListAnnotationTextEditKey(annotationId: event.annotationId),
      rawValue: event.rawValue,
    );
  }

  /// Delete mark `event.annotationId` for good, dispatched once the annotation section's own
  /// remove action has already been confirmed through `OcptConfirmDialog`, by the mode. Clears the
  /// mark's own selection and drops any pending text edit that still targeted it.
  Future<void> _onAnnotationDeletionRequested(
    OcptShotListAnnotationDeletionRequestedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final wasSelected = state.selectedAnnotationId == event.annotationId;
    bool isOfAnnotation(OcptShotListPendingEditKey key) =>
        key is OcptShotListAnnotationTextEditKey && key.annotationId == event.annotationId;

    try {
      await _storyboardService.deleteAnnotation(
        database: project.database,
        annotationId: event.annotationId,
      );
      if (await modeBloc.reload({OcptShotListReloadScope.storyboard})) {
        emitter(
          state.copyWithDeletedAnnotationEdits(
            // Taken now, not before the delete: a keystroke typed meanwhile is not the mark's.
            pendingFieldEdits: Map.of(state.pendingFieldEdits)
              ..removeWhere((key, _) => isOfAnnotation(key)),
            wasSelected: wasSelected,
          ),
        );
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete mark ${event.annotationId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Dismiss the transient write error currently shown.
  Future<void> _onWriteErrorDismissed(
    OcptShotListStoryboardWriteErrorDismissedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
  ) async {
    emitter(state.copyWithWriteErrorDismissed());
  }

  /// Record [rawValue] as the pending edit of [key], visible immediately, and (re)starts the
  /// field-edit debounce that eventually writes it — the body [_onPanelCommentChanged] and
  /// [_onAnnotationTextChanged] share, since both ride the very same debounce.
  void _recordPendingEdit({
    required Emitter<OcptShotListStoryboardState> emitter,
    required OcptShotListPendingEditKey key,
    required String rawValue,
  }) {
    final pending = Map<OcptShotListPendingEditKey, String>.of(state.pendingFieldEdits)
      ..[key] = rawValue;
    emitter(state.copyWithTypedFieldEdits(pendingFieldEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptShotListStoryboardFieldEditFlushRequestedEvent());
  }

  /// Write every pending edit once the debounce elapses with no further typing.
  ///
  /// When something was written and the `Versions` tab is the one showing, also asks the mode to
  /// refresh its working-copy card, as the mode itself does when a flush it runs lands.
  Future<void> _onFieldEditFlushRequested(
    OcptShotListStoryboardFieldEditFlushRequestedEvent event,
    Emitter<OcptShotListStoryboardState> emitter,
  ) async {
    final hasWritten = await onFlushRequested(emitter);

    if (hasWritten && modeBloc.state.rightDockTab == OcptShotListRightDockTab.versions) {
      addToMode(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Write every entry of [pending], switching on its key's own kind: a panel comment through
  /// `OcptStoryboardService.updatePanelComment`, or a mark's own text through
  /// `OcptStoryboardService.updateAnnotation`.
  Future<void> _writeAllPendingEdits({
    required OcptOpenProjectModel project,
    required Map<OcptShotListPendingEditKey, String> pending,
  }) async {
    for (final entry in pending.entries) {
      switch (entry.key) {
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
        case OcptShotListShotFieldEditKey() ||
            OcptShotListSetNameEditKey() ||
            OcptShotListSymbolLabelEditKey():
          // The other kinds of edit are the mode's own and are never recorded here.
          break;
      }
    }
  }
}
