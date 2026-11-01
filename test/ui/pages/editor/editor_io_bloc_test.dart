// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_pdf_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_notice.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The app language every projects manager built here is given, so a created project's own
/// screenplay language never depends on the machine the tests run on.
String _testAppLanguageCode() => "en";

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
///
/// [onPop] lets a test await the exact moment [pop] is called, rather than racing on an unrelated
/// state emitted earlier in the same event handler (the emitted state and the handler's own
/// completion are not ordered with respect to a stream listener in the test).
class _RecordingRouterManager extends OcptRouterManager {
  final _popCompleter = Completer<void>();

  /// Whether [pop] was called.
  bool get popped => _popCompleter.isCompleted;

  /// Completes the moment [pop] is called.
  Future<void> get onPop => _popCompleter.future;

  /// Records the call instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {
    if (!_popCompleter.isCompleted) {
      _popCompleter.complete();
    }
  }
}

/// An export manager whose export/import calls are recorded and stubbed, to exercise the bloc's
/// export and import-and-replace paths without any real file dialog.
class _FakeExportManager extends OcptExportManager {
  /// Class constructor
  _FakeExportManager({
    this.exportResult,
    this.importResult,
    this.exportPdfResult,
    this.importStatus = OcptScreenplayImportStatus.cancelled,
  }) : super(fileSelectorManager: const FileSelectorManager());

  /// The path [exportFountain] returns, or null to simulate a cancelled save dialog.
  final String? exportResult;

  /// The model [pickAndReadScreenplay] returns, or null to return no value at all.
  final OcptImportedFountainModel? importResult;

  /// The status [pickAndReadScreenplay] returns when [importResult] is null, defaulting to a
  /// cancelled open dialog.
  final OcptScreenplayImportStatus importStatus;

  /// The path [exportPdf] returns, or null to simulate a cancelled save dialog.
  final String? exportPdfResult;

  /// The text of the last [exportFountain] call.
  String? lastExportedText;

  /// The project name of the last [exportFountain] call.
  String? lastExportedProjectName;

  /// The file type label of the last [exportFountain] call.
  String? lastExportedFileTypeLabel;

  /// The episode tag of the last [exportFountain] call.
  String? lastExportedEpisodeTag;

  /// The file type label of the last [pickAndReadScreenplay] call.
  String? lastImportFileTypeLabel;

  /// The document of the last [exportPdf] call.
  FountainDocument? lastExportedPdfDocument;

  /// The page setup of the last [exportPdf] call.
  OcptPageSetup? lastExportedPdfPageSetup;

  /// The project name of the last [exportPdf] call.
  String? lastExportedPdfProjectName;

  /// The "include scene numbers" flag of the last [exportPdf] call.
  bool? lastExportedPdfIncludeSceneNumbers;

  /// The "include title page" flag of the last [exportPdf] call.
  bool? lastExportedPdfIncludeTitlePage;

  /// The file type label of the last [exportPdf] call.
  String? lastExportedPdfFileTypeLabel;

  /// The episode tag of the last [exportPdf] call.
  String? lastExportedPdfEpisodeTag;

  @override
  Future<OcptExportOutcome?> exportFountain({
    required String fountainText,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    lastExportedText = fountainText;
    lastExportedProjectName = projectName;
    lastExportedFileTypeLabel = fileTypeLabel;
    lastExportedEpisodeTag = episodeTag;
    final result = exportResult;
    return result == null ? null : OcptExportSaved(result);
  }

  @override
  Future<OcptExportOutcome?> exportPdf({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    lastExportedPdfDocument = document;
    lastExportedPdfPageSetup = pageSetup;
    lastExportedPdfProjectName = projectName;
    lastExportedPdfIncludeSceneNumbers = includeSceneNumbers;
    lastExportedPdfIncludeTitlePage = includeTitlePage;
    lastExportedPdfFileTypeLabel = fileTypeLabel;
    lastExportedPdfEpisodeTag = episodeTag;
    final result = exportPdfResult;
    return result == null ? null : OcptExportSaved(result);
  }

  @override
  Future<ResultWithStatus<OcptScreenplayImportStatus, OcptImportedFountainModel>>
  pickAndReadScreenplay({required String fileTypeLabel}) async {
    lastImportFileTypeLabel = fileTypeLabel;

    final result = importResult;
    if (result == null) {
      return ResultWithStatus(status: importStatus);
    }

    return ResultWithStatus(status: OcptScreenplayImportStatus.ok, value: result);
  }
}

/// An export manager whose [exportPdf] always throws, to exercise the bloc's PDF export failure
/// path.
class _ThrowingPdfExportManager extends OcptExportManager {
  /// Class constructor
  _ThrowingPdfExportManager() : super(fileSelectorManager: const FileSelectorManager());

  @override
  Future<OcptExportOutcome?> exportPdf({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async => throw StateError("PDF export intentionally failed for the test");
}

/// The fields of both blocs these tests read, each answered by the bloc that owns it.
class _EditorStates {
  /// The mode bloc's state.
  final OcptEditorState mode;

  /// The file exchange bloc's state.
  final OcptEditorIoState io;

  /// Class constructor
  const _EditorStates(this.mode, this.io);

  bool get isLoading => mode.isLoading;
  bool get isDirty => mode.isDirty;
  String get text => mode.text;
  int get currentLine => mode.currentLine;
  OcptPageSetup get pageSetup => mode.pageSetup;
  List<FountainSceneHeading> get scenes => mode.scenes;
  OcptEditorIoNotice? get ioNotice => io.ioNotice;
}

/// The mode bloc and the file exchange bloc built together, the way the editor page builds them: an
/// event goes to the bloc that handles it, and a state is read off the bloc that owns it.
class _Editor {
  /// The mode bloc.
  final OcptEditorBloc mode;

  /// The file exchange bloc.
  final OcptEditorIoBloc io;

  /// Class constructor
  _Editor(this.mode, this.io);

  /// Both blocs' current states.
  _EditorStates get state => _EditorStates(mode.state, io.state);

  /// Both blocs' states, one per emit of either.
  Stream<_EditorStates> get stream => Stream.multi((controller) {
    final subscriptions = [
      mode.stream.listen((_) => controller.add(state)),
      io.stream.listen((_) => controller.add(state)),
    ];
    controller.onCancel = () {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    };
  }, isBroadcast: true);

  /// Sends [event] to the bloc that handles it.
  void add(BlocEventForMixin event) => event is OcptEditorIoEvent ? io.add(event) : mode.add(event);

  /// Closes both blocs, the file exchange one first as the tree does.
  Future<void> close() async {
    await io.close();
    await mode.close();
  }
}

void main() {
  const editedText = "INT. HOUSE - DAY\n\nAction.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's save error paths)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_bloc_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: _testAppLanguageCode,
    );
    await projectsManager.initLifeCycle();

    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Builds both blocs wired to the test project, with debounces short enough to await in a test.
  ///
  /// [exportManager] defaults to a [_FakeExportManager] whose export/import calls both cancel
  /// (return null): a test not exercising a particular outcome never touches a real file dialog.
  _Editor buildBloc({OcptExportManager? exportManager}) {
    final manager = exportManager ?? _FakeExportManager();
    final mode = OcptEditorBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _RecordingRouterManager(),
      exportManager: manager,
      parseDebounce: const Duration(milliseconds: 20),
      autosaveDebounce: const Duration(milliseconds: 60),
    );
    final io = OcptEditorIoBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      exportManager: manager,
    );

    return _Editor(mode, io);
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<_EditorStates> waitForState(
    _Editor bloc,
    bool Function(_EditorStates state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Reads the screenplay snapshots of the test project, oldest first.
  Future<List<OcptScreenplaySnapshotRow>> readSnapshots() {
    final database = projectsManager.currentProject!.database;

    return (database.select(
      database.ocptScreenplaySnapshotsTable,
    )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).get();
  }

  test('exporting a dirty screenplay saves it with the "export" reason and hands the current text '
      'to the manager', () async {
    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie.fountain");
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.isDirty);

    bloc.add(
      const OcptEditorExportRequestedEvent(fileTypeLabel: "Screenplay", episodeTag: "ep. 2"),
    );
    final state = await waitForState(
      bloc,
      (state) => state.ioNotice?.kind == OcptEditorIoNoticeKind.exportSucceeded,
    );

    expect(state.isDirty, isFalse);
    expect(state.ioNotice?.path, "/tmp/My Movie.fountain");
    expect(exportManager.lastExportedText, editedText);
    expect(exportManager.lastExportedProjectName, "My Movie");
    expect(exportManager.lastExportedFileTypeLabel, "Screenplay");
    expect(exportManager.lastExportedEpisodeTag, "ep. 2");

    final snapshots = await readSnapshots();
    expect(snapshots.last.reason, OcptSnapshotReason.export);

    await bloc.close();
  });

  test('a cancelled export dialog raises no notice', () async {
    final exportManager = _FakeExportManager();
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorExportRequestedEvent(fileTypeLabel: "Screenplay"));
    // No state change to wait for on a cancelled dialog: give the handler a beat to run.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.ioNotice, isNull);

    await bloc.close();
  });

  test('exporting a dirty screenplay to PDF saves it with the "export" reason and hands the '
      'manager a document parsed from the current text, the project name, and the pageSetup built '
      'from the event options', () async {
    final exportManager = _FakeExportManager(exportPdfResult: "/tmp/My Movie.pdf");
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    final formatBefore = await projectsManager.loadCurrentProjectPageFormat();
    final marginsBefore = await propertiesManager.pageMargins.load();

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.isDirty);

    // A format/margins deliberately different from `bloc.state.pageSetup`, to prove they're
    // taken from the event's options rather than the live state.
    const options = OcptPdfExportOptions(
      format: OcptPageFormat.a4,
      margins: FountainPageMargins(
        leftInches: 2,
        rightInches: 0.5,
        topInches: 0.75,
        bottomInches: 0.75,
      ),
      includeSceneNumbers: false,
      includeTitlePage: false,
    );
    bloc.add(
      const OcptEditorExportPdfRequestedEvent(
        options: options,
        fileTypeLabel: "PDF document",
        episodeTag: "ep. 2",
      ),
    );
    final state = await waitForState(
      bloc,
      (state) => state.ioNotice?.kind == OcptEditorIoNoticeKind.pdfExportSucceeded,
    );

    expect(state.isDirty, isFalse);
    expect(state.ioNotice?.path, "/tmp/My Movie.pdf");
    expect(exportManager.lastExportedPdfProjectName, "My Movie");
    expect(exportManager.lastExportedPdfDocument?.scenes.single.headingText, "INT. HOUSE - DAY");
    expect(
      exportManager.lastExportedPdfPageSetup,
      OcptPageSetup(format: options.format, margins: options.margins),
    );
    expect(exportManager.lastExportedPdfIncludeSceneNumbers, isFalse);
    expect(exportManager.lastExportedPdfIncludeTitlePage, isFalse);
    expect(exportManager.lastExportedPdfFileTypeLabel, "PDF document");
    expect(exportManager.lastExportedPdfEpisodeTag, "ep. 2");

    final snapshots = await readSnapshots();
    expect(snapshots.last.reason, OcptSnapshotReason.export);

    // The PDF export's format/options choice is a one-off, export-time setting: it must never
    // persist the project's page format or the app-wide margins.
    expect(await projectsManager.loadCurrentProjectPageFormat(), formatBefore);
    expect(await propertiesManager.pageMargins.load(), marginsBefore);

    await bloc.close();
  });

  test('a cancelled PDF export dialog raises no notice', () async {
    final exportManager = _FakeExportManager();
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptEditorExportPdfRequestedEvent(
        options: OcptPdfExportOptions(
          format: OcptPageFormat.usLetter,
          margins: FountainPageMargins.standard(),
          includeSceneNumbers: true,
          includeTitlePage: true,
        ),
        fileTypeLabel: "PDF document",
      ),
    );
    // No state change to wait for on a cancelled dialog: give the handler a beat to run.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.ioNotice, isNull);

    await bloc.close();
  });

  test('a failed PDF export raises the transient PDF export error', () async {
    final exportManager = _ThrowingPdfExportManager();
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptEditorExportPdfRequestedEvent(
        options: OcptPdfExportOptions(
          format: OcptPageFormat.usLetter,
          margins: FountainPageMargins.standard(),
          includeSceneNumbers: true,
          includeTitlePage: true,
        ),
        fileTypeLabel: "PDF document",
      ),
    );
    final failedState = await waitForState(
      bloc,
      (state) => state.ioNotice?.kind == OcptEditorIoNoticeKind.pdfExportFailed,
    );
    expect(failedState.ioNotice?.path, isNull);

    await bloc.close();
  });

  test('importing replaces the text, tags the snapshot "import", leaves isDirty false and '
      're-parses', () async {
    const importedText = "INT. OFFICE - DAY\n\nA new script.\n";
    final exportManager = _FakeExportManager(
      importResult: const OcptImportedFountainModel(
        fountainText: importedText,
        sourceFileName: "draft.fountain",
      ),
    );
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorImportRequestedEvent(fileTypeLabel: "Screenplay"));
    // The text/dirty change and the re-parse are separate emissions of the mode, and the notice is
    // the file exchange bloc's own, emitted once the mode holds the text: wait for the re-parse, the
    // last of the mode's two, and for the notice.
    final state = await waitForState(
      bloc,
      (state) => state.scenes.isNotEmpty && state.ioNotice != null,
    );

    expect(state.text, importedText);
    expect(state.isDirty, isFalse);
    expect(state.currentLine, 0);
    expect(state.ioNotice?.kind, OcptEditorIoNoticeKind.importSucceeded);
    expect(state.scenes, hasLength(1));
    expect(state.scenes.single.headingText, "INT. OFFICE - DAY");
    expect(exportManager.lastImportFileTypeLabel, "Screenplay");

    final snapshots = await readSnapshots();
    expect(snapshots.last.reason, OcptSnapshotReason.import);

    await bloc.close();
  });

  test('a cancelled import dialog changes nothing', () async {
    final exportManager = _FakeExportManager();
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.isDirty);

    bloc.add(const OcptEditorImportRequestedEvent(fileTypeLabel: "Screenplay"));
    // No state change to wait for on a cancelled dialog: give the handler a beat to run.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.text, editedText);
    expect(bloc.state.isDirty, isTrue);
    expect(bloc.state.ioNotice, isNull);

    await bloc.close();
  });

  test('an unreadable imported file is stated and replaces nothing', () async {
    final exportManager = _FakeExportManager(
      importStatus: OcptScreenplayImportStatus.unreadableFile,
    );
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.isDirty);

    bloc.add(const OcptEditorImportRequestedEvent(fileTypeLabel: "Screenplay"));
    final state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice?.kind, OcptEditorIoNoticeKind.importUnreadable);
    // The screenplay on screen is untouched, and its unsaved edits are still unsaved.
    expect(state.text, editedText);
    expect(state.isDirty, isTrue);

    final snapshots = await readSnapshots();
    expect(snapshots.where((row) => row.reason == OcptSnapshotReason.import), isEmpty);

    await bloc.close();
  });

  group('the bloc as a view of the mode', () {
    /// Names every event of the hierarchy by an exhaustive switch, so an event added to it does not
    /// compile until this list, and the test below, know it.
    String nameOf(OcptEditorIoEvent event) => switch (event) {
      OcptEditorExportRequestedEvent() => "fountain",
      OcptEditorExportPdfRequestedEvent() => "pdf",
      OcptEditorImportRequestedEvent() => "import",
      OcptEditorIoNoticeDismissedEvent() => "dismiss",
    };

    test('every event of its hierarchy has a handler', () async {
      final exportManager = _FakeExportManager(
        exportResult: "/tmp/out.fountain",
        exportPdfResult: "/tmp/out.pdf",
        importResult: const OcptImportedFountainModel(
          fountainText: "INT. OFFICE - DAY\n\nA new script.\n",
          sourceFileName: "draft.fountain",
        ),
      );
      final bloc = buildBloc(exportManager: exportManager);
      await waitForState(bloc, (state) => !state.isLoading);

      final events = <OcptEditorIoEvent>[
        const OcptEditorExportRequestedEvent(fileTypeLabel: "Fountain"),
        const OcptEditorExportPdfRequestedEvent(
          options: OcptPdfExportOptions(
            format: OcptPageFormat.a4,
            margins: FountainPageMargins.standard(),
            includeSceneNumbers: false,
            includeTitlePage: false,
          ),
          fileTypeLabel: "PDF",
        ),
        const OcptEditorImportRequestedEvent(fileTypeLabel: "Screenplay"),
        const OcptEditorIoNoticeDismissedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(4), reason: "one event per name");

      // An event nobody handles is ignored silently, so each is proven by its effect: an exchange
      // leaves a notice, and the dismissal takes it away again.
      bloc.add(events[0]);
      final fountain = await waitForState(bloc, (state) => state.ioNotice != null);
      expect(fountain.ioNotice!.kind, OcptEditorIoNoticeKind.exportSucceeded);
      bloc.add(events[3]);
      await waitForState(bloc, (state) => state.ioNotice == null);

      bloc.add(events[1]);
      final pdf = await waitForState(bloc, (state) => state.ioNotice != null);
      expect(pdf.ioNotice!.kind, OcptEditorIoNoticeKind.pdfExportSucceeded);
      bloc.add(events[3]);
      await waitForState(bloc, (state) => state.ioNotice == null);

      bloc.add(events[2]);
      final imported = await waitForState(
        bloc,
        (state) => state.ioNotice?.kind == OcptEditorIoNoticeKind.importSucceeded,
      );
      expect(imported.text, "INT. OFFICE - DAY\n\nA new script.\n");

      await bloc.close();
    });

    test(
      'importing over typed text saves it first, so the snapshot of the replaced text holds it',
      () async {
        const importedText = "INT. OFFICE - DAY\n\nA new script.\n";
        final bloc = buildBloc(
          exportManager: _FakeExportManager(
            importResult: const OcptImportedFountainModel(
              fountainText: importedText,
              sourceFileName: "draft.fountain",
            ),
          ),
        );
        await waitForState(bloc, (state) => !state.isLoading);

        bloc.add(const OcptEditorTextChangedEvent(text: editedText));
        await waitForState(bloc, (state) => state.isDirty);
        bloc.add(const OcptEditorImportRequestedEvent(fileTypeLabel: "Screenplay"));
        await waitForState(bloc, (state) => state.ioNotice != null && state.text == importedText);

        final snapshots = await readSnapshots();
        expect(snapshots.map((snapshot) => snapshot.reason), [
          OcptSnapshotReason.manual,
          OcptSnapshotReason.import,
        ]);
        expect(snapshots.last.fountainText, editedText);

        await bloc.close();
      },
    );

    test('an import whose write fails says so and leaves the text alone', () async {
      const importedText = "INT. OFFICE - DAY\n\nA new script.\n";
      final exportManager = _FakeExportManager(
        importResult: const OcptImportedFountainModel(
          fountainText: importedText,
          sourceFileName: "draft.fountain",
        ),
      );
      final bloc = buildBloc(exportManager: exportManager);
      await waitForState(bloc, (state) => !state.isLoading);
      // The episode's row is tombstoned, which the service reads as a screenplay that is no longer
      // there: every write of its text fails.
      final project = projectsManager.currentProject!;
      await (project.database.update(project.database.ocptScreenplaysTable)
            ..where((table) => table.id.equals(project.primaryScreenplayId)))
          .write(const OcptScreenplaysTableCompanion(isDeleted: Value(true)));

      bloc.add(const OcptEditorImportRequestedEvent(fileTypeLabel: "Screenplay"));
      final state = await waitForState(bloc, (state) => state.ioNotice != null);

      expect(state.ioNotice!.kind, OcptEditorIoNoticeKind.importFailed);
      expect(state.text, "");

      await bloc.close();
    });

    test('is registered with the mode as a flusher, without any widget having read it', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.mode.pendingWritesFlusherCount, 1);

      await bloc.close();
    });
  });
}
