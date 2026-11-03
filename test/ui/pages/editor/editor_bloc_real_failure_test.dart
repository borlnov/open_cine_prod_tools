// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../ocpt_result_expectations.dart';
import 'editor_bloc_test_doubles.dart';

/// An export manager that hands the editor a screenplay file to import.
class _ImportingExportManager extends OcptExportManager {
  /// Class constructor
  _ImportingExportManager() : super(fileSelectorManager: const FileSelectorManager());

  /// Answer with a screenplay file whatever the dialog would have said.
  @override
  Future<ResultWithStatus<OcptScreenplayImportStatus, OcptImportedFountainModel>>
  pickAndReadScreenplay({required String fileTypeLabel}) async => const ResultWithStatus(
    status: OcptScreenplayImportStatus.ok,
    value: OcptImportedFountainModel(
      fountainText: "INT. OFFICE - DAY\n\nA new script.\n",
      sourceFileName: "draft.fountain",
    ),
  );
}

/// What the editor does when the database really fails, a SQLite refusal and not a double: the
/// save shows its error and keeps the text dirty, the load stops where it was, the flush when
/// leaving the page only goes unreported, and the same event goes through once the refusal is
/// lifted.
void main() {
  const savedText = "INT. HOUSE - DAY\n\nAction.\n";
  const typedText = "INT. CABIN - DAY\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_real_failure_test_");
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
    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: savedText,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Build a bloc wired to the test project, with debounces short enough to await in a test.
  OcptEditorBloc buildBloc() => OcptEditorBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: RecordingRouterManager(),
    exportManager: InertExportManager(),
    parseDebounce: const Duration(milliseconds: 20),
    autosaveDebounce: const Duration(milliseconds: 60),
  );

  /// Wait for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptEditorState> waitForState(
    OcptEditorBloc bloc,
    bool Function(OcptEditorState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Refuse every update of the screenplays.
  Future<void> refuseTheTextWrites() => projectsManager.currentProject!.database.customStatement(
    "CREATE TRIGGER refuse_text BEFORE UPDATE ON screenplays "
    "BEGIN SELECT RAISE(ABORT, 'refused'); END",
  );

  /// Lift the refusal of [refuseTheTextWrites].
  Future<void> allowTheTextWrites() =>
      projectsManager.currentProject!.database.customStatement("DROP TRIGGER refuse_text");

  /// Read the stored text of the project's screenplay.
  Future<String> storedText() async {
    final project = projectsManager.currentProject!;
    final row = await project.database.select(project.database.ocptScreenplaysTable).getSingle();

    return row.fountainText;
  }

  /// Count the snapshots of the project's screenplay.
  Future<int> snapshotCount() async {
    final database = projectsManager.currentProject!.database;

    return (await database.select(database.ocptScreenplaySnapshotsTable).get()).length;
  }

  test(
    "a refused save raises the save error and keeps the text dirty and stored as it was",
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final snapshotsBefore = await snapshotCount();
      await refuseTheTextWrites();

      bloc.add(const OcptEditorTextChangedEvent(text: typedText));
      await waitForState(bloc, (state) => state.isDirty);
      bloc.add(const OcptEditorSaveRequestedEvent(isManual: true));

      final failed = await waitForState(bloc, (state) => state.hasSaveError);
      expect(failed.isDirty, isTrue);
      expect(failed.isSaving, isFalse);
      expect(failed.lastSavedAt, isNull);
      expect(await storedText(), savedText);
      expect(await snapshotCount(), snapshotsBefore, reason: "the snapshot was rolled back");

      await allowTheTextWrites();
      bloc.add(const OcptEditorSaveErrorDismissedEvent());
      await waitForState(bloc, (state) => !state.hasSaveError);
      bloc.add(const OcptEditorSaveRequestedEvent(isManual: true));

      final saved = await waitForState(
        bloc,
        (state) => !state.isDirty && state.lastSavedAt != null,
      );
      expect(saved.hasSaveError, isFalse);
      expect(await storedText(), typedText);

      await bloc.close();
    },
  );

  test("a refused autosave raises the save error too", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    await refuseTheTextWrites();

    bloc.add(const OcptEditorTextChangedEvent(text: typedText));

    final failed = await waitForState(bloc, (state) => state.hasSaveError);
    expect(failed.isDirty, isTrue);
    expect(await storedText(), savedText);

    await bloc.close();
  });

  test(
    "a flush that cannot save leaves the page without reporting it, and writes nothing",
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      bloc.add(const OcptEditorTextChangedEvent(text: typedText));
      await waitForState(bloc, (state) => state.isDirty);
      await refuseTheTextWrites();

      await bloc.close();

      expect(await storedText(), savedText);
    },
  );

  test(
    "a refused import says so, keeps the text and the notice, and goes through once lifted",
    () async {
      final exportManager = _ImportingExportManager();
      final mode = OcptEditorBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: RecordingRouterManager(),
        exportManager: exportManager,
        parseDebounce: const Duration(milliseconds: 20),
        autosaveDebounce: const Duration(milliseconds: 60),
      );
      final io = OcptEditorIoBloc(
        modeBloc: mode,
        projectsManager: projectsManager,
        exportManager: exportManager,
      );
      addTearDown(() async {
        await io.close();
        await mode.close();
      });
      await waitForState(mode, (state) => !state.isLoading);
      await refuseTheTextWrites();

      io.add(const OcptEditorImportRequestedEvent(fileTypeLabel: "Screenplay"));
      await io.stream
          .firstWhere((state) => state.ioNotice != null)
          .timeout(const Duration(seconds: 5));
      await pumpEventQueue(times: 200);

      expect(io.state.ioNotice!.kind, OcptEditorIoNoticeKind.importFailed);
      expect(mode.state.text, savedText);
      expect(await storedText(), savedText);

      await allowTheTextWrites();
      io.add(const OcptEditorIoNoticeDismissedEvent());
      await pumpEventQueue(times: 200);
      io.add(const OcptEditorImportRequestedEvent(fileTypeLabel: "Screenplay"));
      await io.stream
          .firstWhere((state) => state.ioNotice?.kind == OcptEditorIoNoticeKind.importSucceeded)
          .timeout(const Duration(seconds: 5));

      expect(await storedText(), contains("A new script."));
    },
  );

  test(
    "a screenplay that cannot be read leaves the editor loading, and loads once it can",
    () async {
      final database = projectsManager.currentProject!.database;
      await database.customStatement("ALTER TABLE screenplays RENAME TO screenplays_gone");
      final bloc = buildBloc();
      await pumpEventQueue(times: 200);

      expect(bloc.state.isLoading, isTrue);

      await database.customStatement("ALTER TABLE screenplays_gone RENAME TO screenplays");
      bloc.add(const AsyncInitEvent());
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      expect(loaded.text, savedText);

      await bloc.close();
    },
  );
}
