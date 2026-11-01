// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_file_verdict.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_event.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart';
import 'home_bloc_test_doubles.dart';

/// A projects manager that closes the database of every project it creates, so the first write
/// into that project fails.
class _ClosedAfterCreateProjectsManager extends TestProjectsManager {
  /// Class constructor
  _ClosedAfterCreateProjectsManager({
    required super.directory,
    super.propertiesManager,
    super.appLanguageCode,
  });

  @override
  Future<ResultWithStatus<OcptProjectStatus, OcptOpenProjectModel>> createProject({
    required String name,
    required String filePath,
  }) async {
    final result = await super.createProject(name: name, filePath: filePath);
    await result.value?.database.close();

    return result;
  }
}

void main() {
  late OcptPropertiesManager propertiesManager;

  late OcptProjectsManager projectsManager;

  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's own error paths)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    tempDir = await Directory.systemTemp.createTemp("ocpt_home_bloc_test_");
    projectsManager = TestProjectsManager(
      directory: tempDir,
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Builds a bloc wired to the test project manager, defaulting every dialog-facing dependency
  /// to a fake that cancels (returns null), so a test not exercising the import flow never
  /// touches a real file dialog.
  OcptHomeBloc buildBloc({
    OcptExportManager? exportManager,
    FileSelectorManager? fileSelectorManager,
    OcptRouterManager? routerManager,
  }) => OcptHomeBloc(
    propertiesManager: propertiesManager,
    projectsManager: projectsManager,
    routerManager: routerManager ?? RecordingRouterManager(),
    fileSelectorManager: fileSelectorManager ?? const FileSelectorManager(),
    exportManager: exportManager ?? FakeExportManager(),
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptHomeState> waitForState(
    OcptHomeBloc bloc,
    bool Function(OcptHomeState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test("refreshes the recent projects list once the workspace pops back", () async {
    final filePath = p.join(tempDir.path, "Series.ocpt");
    final routerManager = RecordingRouterManager(
      whilePushed: () async {
        // What a session in the workspace does: the settings page's Episodes card adds one, and
        // closing the project is what writes the new count onto the recent projects entry.
        final project = projectsManager.currentProject!;
        expect(
          await projectsManager.screenplayService.createEpisode(database: project.database),
          isNotNull,
        );
        await projectsManager.closeCurrentProject();
      },
    );

    final bloc = buildBloc(routerManager: routerManager);

    bloc.add(const OcptHomeCreateProjectRequestedEvent(name: "Series", fileTypeLabel: "Project"));
    final state = await waitForState(
      bloc,
      (state) =>
          state.recentProjects.length == 1 && state.recentProjects.single.project.episodeCount == 2,
    );

    expect(
      state.recentProjects.single.project.path,
      filePath,
      reason:
          "the card the user comes back to must carry the count the project ended with, not "
          "the one it was created with",
    );

    await bloc.close();
  });

  test("shows a project added to the list from outside its own navigation", () async {
    // Joining a shared project is the case: the join opens the freshly written project — which adds
    // it to the recent list — then replaces the Rejoindre screen with the workspace, so the home
    // page, alive underneath the whole time, never gets the return-from-push it would refresh on.
    // The bloc must react to the list changing on its own to put the new card on the grid.
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.recentProjects.isEmpty);

    final filePath = p.join(tempDir.path, "Joined.ocpt");
    await File(filePath).writeAsBytes(Uint8List(0));
    await propertiesManager.addRecentProject(
      OcptRecentProjectModel(
        path: filePath,
        name: "Joined",
        lastOpenedAt: DateTime.now(),
        episodeCount: 1,
      ),
    );

    final state = await waitForState(
      bloc,
      (state) => state.recentProjects.any((entry) => entry.project.path == filePath),
    );
    expect(state.recentProjects.single.project.name, "Joined");

    await bloc.close();
  });

  test('an import whose text cannot be written into the new project fails with ioError', () async {
    final failingManager = _ClosedAfterCreateProjectsManager(
      directory: tempDir,
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await failingManager.initLifeCycle();
    final routerManager = RecordingRouterManager();
    final bloc = OcptHomeBloc(
      propertiesManager: propertiesManager,
      projectsManager: failingManager,
      routerManager: routerManager,
      fileSelectorManager: const FileSelectorManager(),
      exportManager: FakeExportManager(
        importResult: const OcptImportedFountainModel(
          fountainText: "INT. HOUSE - DAY\n\nAction.\n",
          sourceFileName: "draft.fountain",
        ),
      ),
    );

    bloc.add(
      const OcptHomeImportScreenplayRequestedEvent(
        screenplayFileTypeLabel: "Screenplay",
        projectFileTypeLabel: "Project",
      ),
    );
    await waitForState(bloc, (state) => state.isBusy);
    final state = await waitForState(bloc, (state) => !state.isBusy);

    expect(state.error, OcptProjectStatus.ioError);
    expect(routerManager.pushedRoute, isNull);

    await bloc.close();
  });

  test('imports a picked fountain file into a new project and navigates to the editor', () async {
    const importedText = "Title: My Movie\n\nINT. HOUSE - DAY\n\nAction.\n";
    final exportManager = FakeExportManager(
      importResult: const OcptImportedFountainModel(
        fountainText: importedText,
        sourceFileName: "draft.fountain",
      ),
    );
    final savedPath = p.join(tempDir.path, "My Movie.ocpt");
    final routerManager = RecordingRouterManager();

    final bloc = buildBloc(exportManager: exportManager, routerManager: routerManager);

    bloc.add(
      const OcptHomeImportScreenplayRequestedEvent(
        screenplayFileTypeLabel: "Screenplay",
        projectFileTypeLabel: "Project",
      ),
    );
    await waitForState(bloc, (state) => state.isBusy);
    final state = await waitForState(bloc, (state) => !state.isBusy);

    expect(state.error, isNull);
    expect(exportManager.lastFileTypeLabel, "Screenplay");
    expect(routerManager.pushedRoute, OcptRoute.workspace);

    final project = projectsManager.currentProject!;
    // The project's name — and, through freeNewProjectFilePath, its file's own name — comes
    // from the imported file's title page.
    expect(project.name, "My Movie");
    expect(project.path, savedPath);

    final storedText = await projectsManager.screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    expect(storedText, importedText);

    final snapshots = await (project.database.select(
      project.database.ocptScreenplaySnapshotsTable,
    )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).get();
    expect(snapshots.last.reason, OcptSnapshotReason.import);

    await bloc.close();
  });

  test('a cancelled screenplay file picker leaves the bloc idle and creates no project', () async {
    final exportManager = FakeExportManager();
    final bloc = buildBloc(exportManager: exportManager);

    bloc.add(
      const OcptHomeImportScreenplayRequestedEvent(
        screenplayFileTypeLabel: "Screenplay",
        projectFileTypeLabel: "Project",
      ),
    );
    await waitForState(bloc, (state) => state.isBusy);
    final state = await waitForState(bloc, (state) => !state.isBusy);

    expect(state.error, isNull);
    expect(projectsManager.currentProject, isNull);

    await bloc.close();
  });

  test('an unreadable screenplay file is stated and creates no project', () async {
    final exportManager = FakeExportManager(
      importStatus: OcptScreenplayImportStatus.unreadableFile,
    );
    final bloc = buildBloc(exportManager: exportManager);

    bloc.add(
      const OcptHomeImportScreenplayRequestedEvent(
        screenplayFileTypeLabel: "Screenplay",
        projectFileTypeLabel: "Project",
      ),
    );
    await waitForState(bloc, (state) => state.isBusy);
    final state = await waitForState(bloc, (state) => !state.isBusy);

    expect(state.screenplayImportError, OcptScreenplayImportStatus.unreadableFile);
    expect(state.error, isNull);
    // Nothing was read to seed a project with, so no project was ever created.
    expect(projectsManager.currentProject, isNull);

    bloc.add(const OcptHomeScreenplayImportErrorDismissedEvent());
    final dismissed = await waitForState(bloc, (state) => state.screenplayImportError == null);
    expect(dismissed.screenplayImportError, isNull);

    await bloc.close();
  });

  test('on mobile, a project named after a file that already exists gets "(2)" appended, and the '
      'existing file is left untouched', () async {
    final existingPath = p.join(tempDir.path, "Movie.ocpt");
    await File(existingPath).writeAsString("not a project");

    final bloc = buildBloc();

    bloc.add(const OcptHomeCreateProjectRequestedEvent(name: "Movie", fileTypeLabel: "Project"));
    await waitForState(bloc, (state) => state.isBusy);
    final state = await waitForState(bloc, (state) => !state.isBusy);

    expect(state.error, isNull);
    expect(await File(existingPath).readAsString(), "not a project");

    final project = projectsManager.currentProject!;
    expect(project.path, p.join(tempDir.path, "Movie (2).ocpt"));

    await bloc.close();
  });

  group("on desktop", () {
    test(
      "New project shows the save dialog and creates the project where the user picked",
      () async {
        final pickedPath = p.join(tempDir.path, "Wherever I Want.ocpt");
        final saveLocationService = RecordingSaveLocationService(saveLocationAnswer: pickedPath);
        final bloc = buildBloc(
          exportManager: FakeExportManager(
            isMobile: false,
            saveLocationService: saveLocationService,
          ),
        );

        bloc.add(
          const OcptHomeCreateProjectRequestedEvent(name: "Movie", fileTypeLabel: "Project"),
        );
        await waitForState(bloc, (state) => state.isBusy);
        final state = await waitForState(bloc, (state) => !state.isBusy);

        expect(state.error, isNull);
        expect(saveLocationService.askCount, 1);
        expect(saveLocationService.lastSuggestedFileName, "Movie.ocpt");
        expect(saveLocationService.lastInitialDirectory, isNotNull);
        final project = projectsManager.currentProject!;
        // The project's own name is what the user typed, not whichever file name they saved it
        // under.
        expect(project.name, "Movie");
        expect(project.path, pickedPath);

        await bloc.close();
      },
    );

    test("cancelling the New project save dialog creates nothing", () async {
      final saveLocationService = RecordingSaveLocationService();
      final bloc = buildBloc(
        exportManager: FakeExportManager(isMobile: false, saveLocationService: saveLocationService),
      );

      bloc.add(const OcptHomeCreateProjectRequestedEvent(name: "Movie", fileTypeLabel: "Project"));
      await waitForState(bloc, (state) => state.isBusy);
      final state = await waitForState(bloc, (state) => !state.isBusy);

      expect(state.error, isNull);
      expect(saveLocationService.askCount, 1);
      expect(projectsManager.currentProject, isNull);

      await bloc.close();
    });

    test(
      "importing a screenplay names the project after the file name saved in the dialog, not the "
      "screenplay's own suggested name",
      () async {
        const importedText = "Title: My Movie\n\nINT. HOUSE - DAY\n\nAction.\n";
        final pickedPath = p.join(tempDir.path, "Renamed On The Way Out.ocpt");
        final saveLocationService = RecordingSaveLocationService(saveLocationAnswer: pickedPath);
        final exportManager = FakeExportManager(
          importResult: const OcptImportedFountainModel(
            fountainText: importedText,
            sourceFileName: "draft.fountain",
          ),
          isMobile: false,
          saveLocationService: saveLocationService,
        );
        final bloc = buildBloc(exportManager: exportManager);

        bloc.add(
          const OcptHomeImportScreenplayRequestedEvent(
            screenplayFileTypeLabel: "Screenplay",
            projectFileTypeLabel: "Project",
          ),
        );
        await waitForState(bloc, (state) => state.isBusy);
        final state = await waitForState(bloc, (state) => !state.isBusy);

        expect(state.error, isNull);
        // Suggested from the title page ("My Movie"), but the save dialog's own picked file name
        // ("Renamed On The Way Out") is what the user actually chose to call it.
        expect(saveLocationService.lastSuggestedFileName, "My Movie.ocpt");
        final project = projectsManager.currentProject!;
        expect(project.name, "Renamed On The Way Out");
        expect(project.path, pickedPath);

        await bloc.close();
      },
    );

    test("cancelling the import's save dialog creates nothing", () async {
      const importedText = "Title: My Movie\n\nINT. HOUSE - DAY\n\nAction.\n";
      final saveLocationService = RecordingSaveLocationService();
      final exportManager = FakeExportManager(
        importResult: const OcptImportedFountainModel(
          fountainText: importedText,
          sourceFileName: "draft.fountain",
        ),
        isMobile: false,
        saveLocationService: saveLocationService,
      );
      final bloc = buildBloc(exportManager: exportManager);

      bloc.add(
        const OcptHomeImportScreenplayRequestedEvent(
          screenplayFileTypeLabel: "Screenplay",
          projectFileTypeLabel: "Project",
        ),
      );
      await waitForState(bloc, (state) => state.isBusy);
      final state = await waitForState(bloc, (state) => !state.isBusy);

      expect(state.error, isNull);
      expect(saveLocationService.askCount, 1);
      expect(projectsManager.currentProject, isNull);

      await bloc.close();
    });
  });

  group("a project file from another build", () {
    // The older-file migration flow could not be exercised at schema version 1: ADR 0029 squashed
    // the pre-stable chain, so no schema below the current one existed then (currentSchemaVersion -
    // 1 was 0, which reads as an unreadable/foreign file, not an older one). Schema version 2
    // (`OcptSyncRelayCursorsTable`) is the first real `onUpgrade` step since, which is what
    // reactivates the two tests below: `createProjectAtPreviousFormat` undoes exactly that step's
    // own addition, so whichever schema step is newest has to keep this helper in sync with what it
    // actually adds, or these tests fail loudly instead of proving anything. The same limitation is
    // why the pre-release "at your own risk" migration wording has no test here: it only replaces
    // the migration message, which these two skips already keep untested.
    const olderFileFlowSkip = OcptProjectDatabase.currentSchemaVersion < 2;

    /// The format a file one step behind this build states.
    final previousSchemaVersion = OcptProjectDatabase.currentSchemaVersion - 1;

    /// Creates a project at [filePath] and hands it back as the previous build would have left
    /// it: the latest schema step's own additions taken back out, and the format number with
    /// them.
    ///
    /// The additions really are undone rather than the number merely relabelled, so the migration
    /// the user is about to confirm is one that actually runs.
    Future<void> createProjectAtPreviousFormat(String filePath) async {
      await projectsManager.createProject(name: "My Movie", filePath: filePath);
      await projectsManager.closeCurrentProject();

      final database = sqlite3.open(filePath);
      database
        // Schema version 3's own addition undoes `shot_characters`' reshape from
        // `{shotId, characterName}` to `{shotId, roleId}`
        // (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`); the table is empty on
        // a freshly created project, so a plain drop-and-recreate loses nothing.
        ..execute("DROP TABLE shot_characters")
        ..execute(
          'CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), '
          '"character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, '
          '"sort_key" TEXT NOT NULL DEFAULT \'\', '
          '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), '
          'PRIMARY KEY ("shot_id", "character_name"))',
        )
        ..execute("PRAGMA user_version = $previousSchemaVersion")
        ..dispose();
    }

    /// Creates a project at [filePath] and stamps a format no build of this app writes yet onto
    /// it, which is all a file from the future has to state to be refused.
    Future<void> createProjectFromTheFuture(String filePath) async {
      await projectsManager.createProject(name: "My Movie", filePath: filePath);
      await projectsManager.closeCurrentProject();

      final database = sqlite3.open(filePath);
      database
        ..execute("PRAGMA user_version = ${OcptProjectDatabase.currentSchemaVersion + 1}")
        ..dispose();
    }

    test("an older one raises the migration question instead of opening", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await createProjectAtPreviousFormat(filePath);
      final bloc = buildBloc();

      bloc.add(OcptHomeOpenProjectRequestedEvent(filePath: filePath, fileTypeLabel: "Project"));
      final state = await waitForState(bloc, (state) => state.pendingFileCompatibility != null);

      final compatibility = state.pendingFileCompatibility!;
      expect(compatibility.verdict, OcptProjectFileVerdict.older);
      expect(compatibility.filePath, filePath);
      expect(compatibility.suggestedBackupPath, isNotNull);
      expect(state.isBusy, isFalse);
      expect(state.error, isNull);
      expect(projectsManager.currentProject, isNull);

      await bloc.close();
    }, skip: olderFileFlowSkip);

    test(
      "answering the question opens it, and the copy is where it was promised",
      () async {
        final filePath = p.join(tempDir.path, "movie.ocpt");
        await createProjectAtPreviousFormat(filePath);
        final routerManager = RecordingRouterManager();
        final bloc = buildBloc(routerManager: routerManager);

        bloc.add(OcptHomeOpenProjectRequestedEvent(filePath: filePath, fileTypeLabel: "Project"));
        final asked = await waitForState(bloc, (state) => state.pendingFileCompatibility != null);
        final backupPath = asked.pendingFileCompatibility!.suggestedBackupPath!;

        // What the page dispatches once the user has confirmed the dialog.
        bloc.add(
          OcptHomeOpenProjectRequestedEvent(
            filePath: filePath,
            fileTypeLabel: "Project",
            allowMigration: true,
          ),
        );
        await waitForState(bloc, (state) => state.isBusy);
        await waitForState(bloc, (state) => !state.isBusy);

        expect(projectsManager.currentProject?.path, filePath);
        expect(routerManager.pushedRoute, OcptRoute.workspace);
        expect(File(backupPath).existsSync(), isTrue);

        await bloc.close();
      },
      skip: olderFileFlowSkip,
    );

    test("a newer one is raised as a refusal, and nothing is opened", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await createProjectFromTheFuture(filePath);
      await propertiesManager.deleteAll();
      final routerManager = RecordingRouterManager();
      final bloc = buildBloc(routerManager: routerManager);

      bloc.add(OcptHomeOpenProjectRequestedEvent(filePath: filePath, fileTypeLabel: "Project"));
      final state = await waitForState(bloc, (state) => state.pendingFileCompatibility != null);

      expect(state.pendingFileCompatibility!.verdict, OcptProjectFileVerdict.newer);
      expect(state.error, isNull, reason: "a refusal is stated by the dialog, not by a SnackBar");
      expect(projectsManager.currentProject, isNull);
      expect(routerManager.pushedRoute, isNull);

      await bloc.close();
    });

    /// Creates a project at [filePath], then stamps a different development build's version onto
    /// its writer identity column, leaving the schema version exactly at this build's own — which
    /// is all a file written by another pre-release has to state to be refused. This does not need
    /// an older schema to exist, unlike the two tests above.
    Future<void> createProjectWrittenByAnotherDevBuild(String filePath) async {
      await projectsManager.createProject(name: "My Movie", filePath: filePath);
      await projectsManager.closeCurrentProject();

      final database = sqlite3.open(filePath);
      database
        ..execute("UPDATE project_info SET migrated_by_app_version = ?", ["0.9.0-alpha.7"])
        ..dispose();
    }

    test("a foreign development build is raised as a refusal naming it", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await createProjectWrittenByAnotherDevBuild(filePath);
      await propertiesManager.deleteAll();
      final routerManager = RecordingRouterManager();
      final bloc = buildBloc(routerManager: routerManager);

      bloc.add(OcptHomeOpenProjectRequestedEvent(filePath: filePath, fileTypeLabel: "Project"));
      final state = await waitForState(bloc, (state) => state.pendingFileCompatibility != null);

      final compatibility = state.pendingFileCompatibility!;
      expect(compatibility.verdict, OcptProjectFileVerdict.foreignDevBuild);
      expect(compatibility.migratedByAppVersion, "0.9.0-alpha.7");
      expect(state.error, isNull, reason: "a refusal is stated by the dialog, not by a SnackBar");
      expect(projectsManager.currentProject, isNull);
      expect(routerManager.pushedRoute, isNull);

      await bloc.close();
    });

    test(
      "the manager's own re-check reports the foreign-dev-build status rather than migrating it",
      () async {
        final filePath = p.join(tempDir.path, "movie.ocpt");
        await createProjectWrittenByAnotherDevBuild(filePath);
        final bloc = buildBloc();

        // `allowMigration: true` is what the page dispatches once a genuinely *older* file's
        // migration has been confirmed; the bloc's own gate only stands in front of a plain open,
        // so this is what exercises `OcptProjectsManager.openProject`'s own re-check for a file
        // that turns out to be a foreign development build instead — feasible without an actually
        // older schema, unlike the migration wording itself (still gated by `olderFileFlowSkip`
        // above).
        bloc.add(
          OcptHomeOpenProjectRequestedEvent(
            filePath: filePath,
            fileTypeLabel: "Project",
            allowMigration: true,
          ),
        );
        final state = await waitForState(bloc, (state) => state.error != null);

        expect(state.error, OcptProjectStatus.foreignDevBuildFormat);
        expect(projectsManager.currentProject, isNull);

        await bloc.close();
      },
    );

    test("the question is cleared once the page has stated it", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await createProjectFromTheFuture(filePath);
      final bloc = buildBloc();

      bloc.add(OcptHomeOpenProjectRequestedEvent(filePath: filePath, fileTypeLabel: "Project"));
      await waitForState(bloc, (state) => state.pendingFileCompatibility != null);

      bloc.add(const OcptHomeFileCompatibilityStatedEvent());
      final state = await waitForState(bloc, (state) => state.pendingFileCompatibility == null);

      expect(state.pendingFileCompatibility, isNull);

      await bloc.close();
    });

    test(
      "the recent projects list carries each entry's own probed verdict, for the card badge",
      () async {
        final currentPath = p.join(tempDir.path, "current.ocpt");
        await projectsManager.createProject(name: "Current", filePath: currentPath);
        await projectsManager.closeCurrentProject();

        final olderPath = p.join(tempDir.path, "older.ocpt");
        await createProjectAtPreviousFormat(olderPath);

        final newerPath = p.join(tempDir.path, "newer.ocpt");
        await createProjectFromTheFuture(newerPath);

        final foreignDevBuildPath = p.join(tempDir.path, "foreign-dev-build.ocpt");
        await createProjectWrittenByAnotherDevBuild(foreignDevBuildPath);

        final missingPath = p.join(tempDir.path, "gone.ocpt");
        await propertiesManager.addRecentProject(
          OcptRecentProjectModel(path: missingPath, name: "Gone", lastOpenedAt: DateTime.utc(2026)),
        );

        final bloc = buildBloc();
        final state = await waitForState(bloc, (state) => state.recentProjects.length == 5);

        OcptHomeRecentProjectEntry entryFor(String path) =>
            state.recentProjects.singleWhere((entry) => entry.project.path == path);

        expect(entryFor(currentPath).verdict, OcptProjectFileVerdict.current);
        expect(entryFor(newerPath).verdict, OcptProjectFileVerdict.newer);
        expect(entryFor(foreignDevBuildPath).verdict, OcptProjectFileVerdict.foreignDevBuild);
        expect(entryFor(missingPath).exists, isFalse);
        expect(entryFor(missingPath).verdict, isNull);

        await bloc.close();
      },
    );

    test(
      "an older file's verdict is carried too, though it draws no badge on the card itself",
      () async {
        final olderPath = p.join(tempDir.path, "older.ocpt");
        await createProjectAtPreviousFormat(olderPath);

        final bloc = buildBloc();
        final state = await waitForState(bloc, (state) => state.recentProjects.isNotEmpty);

        expect(state.recentProjects.single.verdict, OcptProjectFileVerdict.older);

        await bloc.close();
      },
      skip: olderFileFlowSkip,
    );
  });

  group("a project card's Partager / Synchroniser…", () {
    test("opens the project and pushes the Partager screen instead of the workspace", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await projectsManager.createProject(name: "My Movie", filePath: filePath);
      await projectsManager.closeCurrentProject();

      final routerManager = RecordingRouterManager();
      final bloc = buildBloc(routerManager: routerManager);

      bloc.add(OcptHomeShareProjectRequestedEvent(filePath: filePath));
      await waitForState(bloc, (state) => state.isBusy);
      final state = await waitForState(bloc, (state) => !state.isBusy);

      expect(state.error, isNull);
      expect(projectsManager.currentProject?.path, filePath);
      expect(routerManager.pushedRoute, OcptRoute.sharing);

      await bloc.close();
    });

    test("a project that fails to open raises the error and navigates nowhere", () async {
      final filePath = p.join(tempDir.path, "does-not-exist.ocpt");
      final routerManager = RecordingRouterManager();
      final bloc = buildBloc(routerManager: routerManager);

      bloc.add(OcptHomeShareProjectRequestedEvent(filePath: filePath));
      await waitForState(bloc, (state) => state.isBusy);
      final state = await waitForState(bloc, (state) => !state.isBusy);

      expect(state.error, isNotNull);
      expect(projectsManager.currentProject, isNull);
      expect(routerManager.pushedRoute, isNull);

      await bloc.close();
    });
  });
}
