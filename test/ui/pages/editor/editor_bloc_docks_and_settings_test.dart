// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_reload_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'editor_bloc_test_doubles.dart';

/// Run the tests of the editor bloc docks and settings.
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
      appLanguageCode: testAppLanguageCode,
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

  /// Builds a bloc wired to the test project, with debounces short enough to await in a test.
  ///
  /// [exportManager] defaults to an [InertExportManager]: no test here exports.
  /// [overrideProjectsManager] lets a test swap in a manager of its own (already holding an open
  /// project), for the one that needs to observe its calls.
  OcptEditorBloc buildBloc({
    OcptScreenplayService? screenplayService,
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
    OcptProjectsManager? overrideProjectsManager,
    String? selectedEpisodeId,
  }) => OcptEditorBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? RecordingRouterManager(),
    screenplayService: screenplayService,
    exportManager: exportManager ?? InertExportManager(),
    parseDebounce: const Duration(milliseconds: 20),
    autosaveDebounce: const Duration(milliseconds: 60),
    selectedEpisodeId: selectedEpisodeId,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptEditorState> waitForState(
    OcptEditorBloc bloc,
    bool Function(OcptEditorState state) predicate,
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

  test('loads the persisted dock fractions on entry', () async {
    await propertiesManager.editorLeftDockFraction.store(0.25);
    await propertiesManager.editorRightDockFraction.store(0.55);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.leftDockFraction, 0.25);
    expect(state.rightDockFraction, 0.55);

    await bloc.close();
  });

  test('a dock fractions changed event persists whichever side is given', () async {
    await propertiesManager.editorLeftDockFraction.delete();
    await propertiesManager.editorRightDockFraction.delete();

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorDockFractionsChangedEvent(left: 0.3));
    final leftState = await waitForState(bloc, (state) => state.leftDockFraction == 0.3);
    expect(leftState.rightDockFraction, OcptWorkspaceDock.rightDefaultFraction);
    expect(await propertiesManager.editorLeftDockFraction.load(), 0.3);
    expect(await propertiesManager.editorRightDockFraction.load(), isNull);

    bloc.add(const OcptEditorDockFractionsChangedEvent(right: 0.6));
    final rightState = await waitForState(bloc, (state) => state.rightDockFraction == 0.6);
    expect(rightState.leftDockFraction, 0.3);
    expect(await propertiesManager.editorRightDockFraction.load(), 0.6);

    await bloc.close();
  });

  test('the dock layout reset event restores and persists both defaults', () async {
    await propertiesManager.editorLeftDockFraction.store(0.3);
    await propertiesManager.editorRightDockFraction.store(0.6);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorDockLayoutResetEvent());
    final state = await waitForState(
      bloc,
      (state) => state.leftDockFraction == OcptWorkspaceDock.leftDefaultFraction,
    );

    expect(state.rightDockFraction, OcptWorkspaceDock.rightDefaultFraction);
    expect(
      await propertiesManager.editorLeftDockFraction.load(),
      OcptWorkspaceDock.leftDefaultFraction,
    );
    expect(
      await propertiesManager.editorRightDockFraction.load(),
      OcptWorkspaceDock.rightDefaultFraction,
    );

    await bloc.close();
  });

  test('changing the page setup applies it live and persists format and margins', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    const newSetup = OcptPageSetup(
      format: OcptPageFormat.a4,
      margins: FountainPageMargins(
        leftInches: 2,
        rightInches: 0.5,
        topInches: 0.75,
        bottomInches: 0.75,
      ),
    );
    bloc.add(const OcptEditorPageSetupChangedEvent(pageSetup: newSetup));

    final state = await waitForState(bloc, (state) => state.pageSetup == newSetup);
    expect(state.pageSetup, newSetup);
    expect(await projectsManager.loadCurrentProjectPageFormat(), OcptPageFormat.a4);
    expect(await propertiesManager.pageMargins.load(), newSetup.margins);

    await bloc.close();
  });

  test('the project settings changed event is a no-op when the format did not change', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final setupBefore = bloc.state.pageSetup;

    bloc.add(const OcptEditorProjectSettingsChangedEvent());
    // Nothing to wait for: assert the very next state (if any) still matches, after giving the
    // handler's async work a chance to run.
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.pageSetup, setupBefore);

    await bloc.close();
  });

  test('closing the bloc flushes the pending unsaved change', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.isDirty);

    // Close well before the autosave debounce (60 ms) elapses: the close itself must save.
    await bloc.close();

    final project = projectsManager.currentProject!;
    final storedText = await projectsManager.screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    expect(storedText, editedText);
  });

  test('going back flushes the pending change, closes the project and pops the router', () async {
    final routerManager = RecordingRouterManager();
    final bloc = buildBloc(routerManager: routerManager);
    await waitForState(bloc, (state) => !state.isLoading);

    final projectPath = projectsManager.currentProject!.path;
    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.isDirty);

    // Go back well before the autosave debounce (60 ms) elapses: the back itself must save.
    bloc.add(const OcptEditorBackRequestedEvent());
    await routerManager.onPop.timeout(const Duration(seconds: 5));

    expect(routerManager.popped, isTrue);
    expect(projectsManager.currentProject, isNull);

    // The close-flush must now be a no-op: the project is already closed, and closing the bloc
    // must not try to save through the closed database.
    await bloc.close();

    // Reopen the project file to check the pending change was flushed before it was closed.
    final reopened = await projectsManager.openProject(filePath: projectPath);
    expect(reopened.status.isSuccess, isTrue);

    final project = projectsManager.currentProject!;
    final storedText = await projectsManager.screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    expect(storedText, editedText);
  });

  test('adding title page fields to a screenplay with none inserts one, saves it "manual", and '
      're-parses', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.scenes.isNotEmpty);

    bloc.add(
      const OcptEditorTitlePageChangedEvent(
        title: 'My Screenplay',
        credit: 'written by',
        author: 'Jane Doe',
        draftDate: '',
        contact: '',
        source: '',
      ),
    );

    final state = await waitForState(bloc, (state) => state.document?.titlePage != null);
    expect(state.document!.titlePage!.title, 'My Screenplay');
    expect(state.document!.titlePage!.credit, 'written by');
    expect(state.document!.titlePage!.authors, ['Jane Doe']);
    expect(state.text, 'Title: My Screenplay\nCredit: written by\nAuthor: Jane Doe\n\n$editedText');
    expect(state.scenes.single.headingText, 'INT. HOUSE - DAY');

    final project = projectsManager.currentProject!;
    final storedText = await projectsManager.screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    expect(storedText, state.text);

    final snapshots = await readSnapshots();
    expect(snapshots.last.reason, OcptSnapshotReason.manual);

    await bloc.close();
  });

  test("editing an existing title page's fields replaces it, leaving the body unchanged", () async {
    const initialText = 'Title: Old\nCredit: written by\n\n$editedText';

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: initialText));
    await waitForState(bloc, (state) => state.document?.titlePage != null);

    bloc.add(
      const OcptEditorTitlePageChangedEvent(
        title: 'New Title',
        credit: 'written by',
        author: '',
        draftDate: '',
        contact: '',
        source: '',
      ),
    );

    final state = await waitForState(
      bloc,
      (state) => state.document?.titlePage?.title == 'New Title',
    );
    expect(state.text, 'Title: New Title\nCredit: written by\n\n$editedText');
    expect(state.scenes.single.headingText, 'INT. HOUSE - DAY');

    await bloc.close();
  });

  test(
    'clearing every field on a screenplay with a title page removes it, leaving only the body',
    () async {
      const initialText = 'Title: Old\n\n$editedText';

      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: initialText));
      await waitForState(bloc, (state) => state.document?.titlePage != null);

      bloc.add(
        const OcptEditorTitlePageChangedEvent(
          title: '',
          credit: '',
          author: '',
          draftDate: '',
          contact: '',
          source: '',
        ),
      );

      final state = await waitForState(bloc, (state) => state.document?.titlePage == null);
      expect(state.text, editedText);
      expect(state.scenes.single.headingText, 'INT. HOUSE - DAY');

      await bloc.close();
    },
  );

  group('epochs and the mode contract', () {
    test('the load moves the reload epoch once and names itself as the cause', () async {
      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.reloadEpoch, 1);
      expect(state.reloadCause, OcptEditorReloadCause.load);
      expect(state.selectionEpoch, 0);

      await bloc.close();
    });

    test('typing moves neither epoch', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: editedText));
      final state = await waitForState(bloc, (state) => state.document?.sourceText == editedText);

      expect(state.reloadEpoch, 1);
      expect(state.selectionEpoch, 0);

      await bloc.close();
    });

    test('a scene jump request moves the selection epoch, the same scene twice too', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorSceneJumpRequestedEvent(charOffset: 4));
      bloc.add(const OcptEditorSceneJumpRequestedEvent(charOffset: 4));
      final state = await waitForState(bloc, (state) => state.selectionEpoch == 2);

      expect(state.reloadEpoch, 1);

      await bloc.close();
    });

    test('a page setup change moves the reload epoch with its own cause', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptEditorPageSetupChangedEvent(
          pageSetup: OcptPageSetup(
            format: OcptPageFormat.a4,
            margins: FountainPageMargins.standard(),
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.reloadEpoch == 2);

      expect(state.reloadCause, OcptEditorReloadCause.pageSetup);

      await bloc.close();
    });

    test('a title page rewrite moves the reload epoch as a replaced text', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptEditorTitlePageChangedEvent(
          title: "My Movie",
          credit: "",
          author: "",
          draftDate: "",
          contact: "",
          source: "",
        ),
      );
      final state = await waitForState(bloc, (state) => state.reloadEpoch == 2);

      expect(state.reloadCause, OcptEditorReloadCause.textReplaced);

      await bloc.close();
    });

    test('flushAllPendingWrites saves a dirty text as manual and answers true', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: editedText));
      await waitForState(bloc, (state) => state.isDirty);

      expect(await bloc.flushAllPendingWrites(), isTrue);

      expect(bloc.state.isDirty, isFalse);
      expect((await readSnapshots()).last.reason, OcptSnapshotReason.manual);

      await bloc.close();
    });

    test('flushAllPendingWrites writes nothing when the text is clean', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      expect(await bloc.flushAllPendingWrites(), isTrue);
      expect(await readSnapshots(), isEmpty);

      await bloc.close();
    });

    test('a failing save still answers true and keeps the text dirty', () async {
      final bloc = buildBloc(screenplayService: const FailingScreenplayService());
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: editedText));
      await waitForState(bloc, (state) => state.isDirty);

      expect(await bloc.flushAllPendingWrites(), isTrue);
      expect(bloc.state.isDirty, isTrue);
      expect(bloc.state.hasSaveError, isTrue);

      await bloc.close();
    });

    test('flushAllPendingWrites and reload answer at once on a closed bloc', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      await bloc.close();

      expect(await bloc.flushAllPendingWrites(), isFalse);
      expect(await bloc.reload({}), isFalse);
    });
  });
}
