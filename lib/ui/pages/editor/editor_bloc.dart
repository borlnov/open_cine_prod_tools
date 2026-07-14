// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';

/// This is the bloc class for the editor page.
///
/// It loads the current project's screenplay from [OcptProjectsManager] on entry, re-parses the
/// source text with [FountainParser] after a short debounce on every edit (parsing a full feature
/// script takes single-digit milliseconds, so it runs synchronously in the bloc), and autosaves
/// through [OcptScreenplayService] (which snapshots the previous text and reconciles the scene
/// index) after a longer debounce. Manual saves (toolbar button, Ctrl+S) go through the same save
/// path, only tagged [OcptSnapshotReason.manual] instead of [OcptSnapshotReason.timer].
///
/// When the bloc closes (the user leaves the page), any pending unsaved change is flushed with a
/// best-effort save: the debounce timers are cancelled and the save runs directly against the
/// service, so no edit is lost by navigating away right after typing.
class OcptEditorBloc extends BlocForMixin<OcptEditorState> {
  /// The default delay between the last edit and the re-parse of the source text.
  static const defaultParseDebounce = Duration(milliseconds: 150);

  /// The default delay between the last edit and the autosave.
  static const defaultAutosaveDebounce = Duration(seconds: 2);

  /// The parser used to build the [FountainDocument] shown in the preview and the scene panel.
  static const _fountainParser = FountainParser();

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the preferred editor mode.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the editor.
  final OcptRouterManager _routerManager;

  /// The service used to load and save the screenplay's text.
  final OcptScreenplayService _screenplayService;

  /// The manager used to export the screenplay to, and import it from, a `.fountain` file.
  final OcptExportManager _exportManager;

  /// The delay between the last edit and the re-parse of the source text.
  final Duration _parseDebounce;

  /// The delay between the last edit and the autosave.
  final Duration _autosaveDebounce;

  /// The running parse debounce timer, if any.
  Timer? _parseTimer;

  /// The running autosave debounce timer, if any.
  Timer? _autosaveTimer;

  /// The id given to the next [OcptEditorJumpRequest], increased after each one.
  int _nextJumpRequestId = 0;

  /// Class constructor
  ///
  /// [parseDebounce] and [autosaveDebounce] are only meant to be overridden by tests, to keep
  /// them fast and deterministic.
  OcptEditorBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptScreenplayService? screenplayService,
    OcptExportManager? exportManager,
    Duration parseDebounce = defaultParseDebounce,
    Duration autosaveDebounce = defaultAutosaveDebounce,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _screenplayService =
           screenplayService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).screenplayService,
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _parseDebounce = parseDebounce,
       _autosaveDebounce = autosaveDebounce,
       super(const OcptEditorState.init()) {
    add(const OcptEditorLoadRequestedEvent());
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptEditorLoadRequestedEvent>(_onLoadRequested);
    on<OcptEditorTextChangedEvent>(_onTextChanged);
    on<OcptEditorParseRequestedEvent>(_onParseRequested);
    on<OcptEditorSaveRequestedEvent>(_onSaveRequested);
    on<OcptEditorCaretMovedEvent>(_onCaretMoved);
    on<OcptEditorSceneJumpRequestedEvent>(_onSceneJumpRequested);
    on<OcptEditorScenePanelToggledEvent>(_onScenePanelToggled);
    on<OcptEditorPreviewToggledEvent>(_onPreviewToggled);
    on<OcptEditorModeToggledEvent>(_onModeToggled);
    on<OcptEditorSaveErrorDismissedEvent>(_onSaveErrorDismissed);
    on<OcptEditorBackRequestedEvent>(_onBackRequested);
    on<OcptEditorExportRequestedEvent>(_onExportRequested);
    on<OcptEditorImportRequestedEvent>(_onImportRequested);
    on<OcptEditorIoNoticeDismissedEvent>(_onIoNoticeDismissed);
  }

  /// Loads the current project's screenplay text, title and page format, and parses the text,
  /// together with the persisted preferred editor mode.
  ///
  /// The editor route is guarded by the router manager, so a project is normally always open
  /// here; if none is (e.g. the bloc is built directly in a test), the state simply stays in its
  /// init form with an empty document.
  Future<void> _onLoadRequested(
    OcptEditorLoadRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final mode = await _propertiesManager.editorMode.load() ?? OcptEditorMode.styled;

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWith(isLoading: false, document: _fountainParser.parse(""), mode: mode));
      return;
    }

    final text = await _screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    final pageFormat = await _projectsManager.loadCurrentProjectPageFormat();

    emitter(
      state.copyWith(
        isLoading: false,
        title: project.name,
        mode: mode,
        text: text,
        document: _fountainParser.parse(text),
        pageFormat: pageFormat ?? OcptPageFormat.usLetter,
      ),
    );
  }

  /// Stores the edited text, marks it dirty, and restarts the parse and autosave debounces.
  Future<void> _onTextChanged(
    OcptEditorTextChangedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(text: event.text, isDirty: true));

    _parseTimer?.cancel();
    _parseTimer = Timer(_parseDebounce, () {
      if (!isClosed) {
        add(const OcptEditorParseRequestedEvent());
      }
    });

    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDebounce, () {
      if (!isClosed) {
        add(const OcptEditorSaveRequestedEvent(isManual: false));
      }
    });
  }

  /// Re-parses the current text into a fresh document.
  Future<void> _onParseRequested(
    OcptEditorParseRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(document: _fountainParser.parse(state.text)));
  }

  /// Saves the current text to the project database, unless there is nothing dirty to save.
  ///
  /// Delegates to [_saveCurrentText], tagged [OcptSnapshotReason.manual] or
  /// [OcptSnapshotReason.timer] depending on [OcptEditorSaveRequestedEvent.isManual].
  Future<void> _onSaveRequested(
    OcptEditorSaveRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    if (_projectsManager.currentProject == null || !state.isDirty) {
      return;
    }

    await _saveCurrentText(
      reason: event.isManual ? OcptSnapshotReason.manual : OcptSnapshotReason.timer,
      emitter: emitter,
    );
  }

  /// Saves the current text to the project database, tagged [reason]. Does nothing if no project
  /// is open.
  ///
  /// If the text is edited again while the save is in flight, the screenplay stays dirty once the
  /// save completes (the newer text will be picked up by the next autosave). A failed save keeps
  /// the screenplay dirty and raises the transient save error.
  Future<void> _saveCurrentText({
    required OcptSnapshotReason reason,
    required Emitter<OcptEditorState> emitter,
  }) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    _autosaveTimer?.cancel();
    final textToSave = state.text;
    emitter(state.copyWith(isSaving: true));

    try {
      await _screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: textToSave,
        snapshotReason: reason,
      );

      emitter(
        state.copyWith(
          isSaving: false,
          isDirty: state.text != textToSave,
          lastSavedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to save the screenplay of the project at "
          "${project.path}: $error");
      emitter(state.copyWith(isSaving: false, hasSaveError: true));
    }
  }

  /// Records the source line the caret moved to.
  Future<void> _onCaretMoved(
    OcptEditorCaretMovedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(currentLine: event.line));
  }

  /// Emits a fresh jump request for the page to move the caret to the clicked scene's start.
  Future<void> _onSceneJumpRequested(
    OcptEditorSceneJumpRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWith(
        jumpRequest: OcptEditorJumpRequest(charOffset: event.charOffset, id: _nextJumpRequestId++),
      ),
    );
  }

  /// Toggles the scene panel's visibility.
  Future<void> _onScenePanelToggled(
    OcptEditorScenePanelToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(isScenePanelVisible: !state.isScenePanelVisible));
  }

  /// Toggles the preview panel's visibility.
  Future<void> _onPreviewToggled(
    OcptEditorPreviewToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(isPreviewVisible: !state.isPreviewVisible));
  }

  /// Toggles the editing mode between styled and raw, and persists the new mode.
  Future<void> _onModeToggled(
    OcptEditorModeToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final newMode = state.mode == OcptEditorMode.styled ? OcptEditorMode.raw : OcptEditorMode.styled;
    emitter(state.copyWith(mode: newMode));
    await _propertiesManager.editorMode.store(newMode);
  }

  /// Clears the transient save error currently shown, if any.
  Future<void> _onSaveErrorDismissed(
    OcptEditorSaveErrorDismissedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(hasSaveError: false));
  }

  /// Exports the current screenplay to a `.fountain` file.
  ///
  /// Saves the current text first (tagged [OcptSnapshotReason.export]) if it's dirty, so the
  /// exported file matches exactly what the project stores. A cancelled save dialog is a silent
  /// no-op; a failure raises the transient export-failed notice.
  Future<void> _onExportRequested(
    OcptEditorExportRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    _parseTimer?.cancel();
    _autosaveTimer?.cancel();

    if (state.isDirty) {
      await _saveCurrentText(reason: OcptSnapshotReason.export, emitter: emitter);
    }

    try {
      final path = await _exportManager.exportFountain(
        fountainText: state.text,
        projectName: state.title,
      );
      if (path == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.exportSucceeded, path: path),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the screenplay of the project at "
          "${_projectsManager.currentProject?.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Replaces the current screenplay text with the content of a picked `.fountain` file.
  ///
  /// If the editor is dirty, the current text is saved first (tagged
  /// [OcptSnapshotReason.manual]) so the pre-import snapshot holds the user's latest keystrokes
  /// rather than a stale database copy; the imported text is then saved, tagged
  /// [OcptSnapshotReason.import], which snapshots the pre-import text. A cancelled file dialog is
  /// a silent no-op; a failure raises the transient import-failed notice.
  Future<void> _onImportRequested(
    OcptEditorImportRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final imported = await _exportManager.pickAndReadFountain(fileTypeLabel: event.fileTypeLabel);
    if (imported == null) {
      // The user cancelled the dialog, or the selection failed; the latter is a soft failure
      // deliberately not surfaced as an error, since the OS dialog itself already reported it.
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      if (state.isDirty) {
        await _saveCurrentText(reason: OcptSnapshotReason.manual, emitter: emitter);
      }

      await _screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: imported.fountainText,
        snapshotReason: OcptSnapshotReason.import,
      );

      _parseTimer?.cancel();
      _autosaveTimer?.cancel();

      emitter(
        state.copyWith(
          text: imported.fountainText,
          isDirty: false,
          currentLine: 0,
          ioNotice: const OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.importSucceeded),
        ),
      );
      await _onParseRequested(const OcptEditorParseRequestedEvent(), emitter);
    } catch (error) {
      appLogger().e("A problem occurred when tried to import a fountain file into the project at "
          "${project.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.importFailed),
        ),
      );
    }
  }

  /// Clears the transient export/import notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptEditorIoNoticeDismissedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(clearIoNotice: true));
  }

  /// Leaves the editor: cancels the pending debounce timers, flushes the unsaved change if there
  /// is one, closes the current project, and navigates back to the home page.
  ///
  /// The project is closed before navigating, so [disposeLifeCycle]'s own close-flush (guarded on
  /// [OcptProjectsManager.currentProject]) finds no project any more and stays a no-op instead of
  /// trying to save through the already-closed database.
  Future<void> _onBackRequested(
    OcptEditorBackRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    _parseTimer?.cancel();
    _autosaveTimer?.cancel();

    if (state.isDirty) {
      await _onSaveRequested(const OcptEditorSaveRequestedEvent(isManual: true), emitter);
    }

    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// Cancels the debounce timers and flushes any pending unsaved change with a best-effort save,
  /// so leaving the page right after typing never loses the last edits. The flush bypasses the
  /// event queue (the bloc is closing), and a failure here is only logged: the page is already
  /// gone, so there is no UI left to surface it to.
  @override
  Future<void> disposeLifeCycle() async {
    _parseTimer?.cancel();
    _autosaveTimer?.cancel();

    final project = _projectsManager.currentProject;
    if (project != null && state.isDirty && !state.isSaving) {
      try {
        await _screenplayService.saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: state.text,
          snapshotReason: OcptSnapshotReason.timer,
        );
      } catch (error) {
        appLogger().e("A problem occurred when tried to flush the screenplay of the project at "
            "${project.path} while leaving the editor: $error");
      }
    }

    return super.disposeLifeCycle();
  }
}
