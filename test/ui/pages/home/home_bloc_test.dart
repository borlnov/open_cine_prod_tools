// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_file_verdict.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_event.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart';

/// An export manager whose [pickAndReadScreenplay] is stubbed, to exercise the bloc's import flow
/// without any real file dialog. [fountainIoService] is left as the real, pure implementation.
class _FakeExportManager extends OcptExportManager {
  /// Class constructor
  _FakeExportManager({
    this.importResult,
    this.importStatus = OcptScreenplayImportStatus.cancelled,
  }) : super(fileSelectorManager: const FileSelectorManager());

  /// The model [pickAndReadScreenplay] returns, or null to return no value at all.
  final OcptImportedFountainModel? importResult;

  /// The status [pickAndReadScreenplay] returns when [importResult] is null, defaulting to a
  /// cancelled open dialog.
  final OcptScreenplayImportStatus importStatus;

  /// The file type label of the last [pickAndReadScreenplay] call.
  String? lastFileTypeLabel;

  @override
  Future<ResultWithStatus<OcptScreenplayImportStatus, OcptImportedFountainModel>>
  pickAndReadScreenplay({required String fileTypeLabel}) async {
    lastFileTypeLabel = fileTypeLabel;

    final result = importResult;
    if (result == null) {
      return ResultWithStatus(status: importStatus);
    }

    return ResultWithStatus(status: OcptScreenplayImportStatus.ok, value: result);
  }
}

/// A file saver manager whose [saveFileFromBytes] is stubbed, to exercise the bloc's save-as
/// step without any real save dialog.
class _FakeFileSaverManager extends FileSaverManager {
  /// Class constructor
  _FakeFileSaverManager({this.result});

  /// The path [saveFileFromBytes] returns, or null to simulate a cancelled save dialog.
  final String? result;

  /// The file name of the last [saveFileFromBytes] call.
  String? lastFileName;

  @override
  Future<String?> saveFileFromBytes({required String fileName, required Uint8List bytes}) async {
    lastFileName = fileName;
    return result;
  }
}

/// A save location service answering [saveLocationAnswer]/[directoryAnswer] without ever showing a
/// native dialog, and recording that either was asked — used to exercise a project card's own
/// `Export…`, and a project package import's own destination folder picker, without a real dialog.
///
/// A null answer is the user cancelling the dialog, which every import/export of this app treats
/// as a silent no-op.
class _RecordingSaveLocationService extends OcptSaveLocationService {
  /// The path [pickSaveLocation] hands back, or null to answer as a cancelled dialog.
  final String? saveLocationAnswer;

  /// The path [pickDirectory] hands back, or null to answer as a cancelled dialog.
  final String? directoryAnswer;

  /// How many times a save location was asked for.
  int askCount = 0;

  /// The [pickDirectory] confirm button text of the last call, or null if it was never called.
  String? lastDirectoryConfirmButtonText;

  /// Class constructor
  _RecordingSaveLocationService({this.saveLocationAnswer, this.directoryAnswer});

  @override
  Future<String?> pickSaveLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
  }) async {
    askCount++;
    return saveLocationAnswer;
  }

  @override
  Future<String?> pickDirectory({required String confirmButtonText}) async {
    lastDirectoryConfirmButtonText = confirmButtonText;
    return directoryAnswer;
  }
}

/// A file selector manager whose [openSelector] is stubbed, to exercise the bloc's import flows
/// without any real open-file dialog.
class _FakeFileSelectorManager extends FileSelectorManager {
  /// Class constructor
  _FakeFileSelectorManager({this.result});

  /// The file [openSelector] returns, or null to simulate a cancelled dialog.
  final XFile? result;

  /// The extensions of the last [openSelector] call.
  List<String>? lastAllowedExtensions;

  @override
  Future<ResultWithBoolStatus<XFile>> openSelector({
    required List<String> allowedExtensions,
    required String label,
    bool strictOnExtensions = true,
  }) async {
    lastAllowedExtensions = allowedExtensions;
    // A cancelled native dialog reports success with no file, never a failure status — mirroring
    // FileSelectorManager.openSelector's own real behaviour.
    return ResultWithBoolStatus<XFile>(status: BoolResultStatus.success, value: result);
  }
}

/// A router manager whose [push] only records the route pushed: these bloc tests don't build a
/// real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Runs while [push] is awaited, standing in for whatever the user did in the workspace before
  /// popping back to the home page — a real push only completes once they leave it.
  final Future<void> Function()? whilePushed;

  /// Class constructor
  _RecordingRouterManager({this.whilePushed});

  /// The last route [push] was called with, or null if it never was.
  OcptRoute? pushedRoute;

  @override
  Future<Y?> push<Y extends Object?>(
    OcptRoute route, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) async {
    pushedRoute = route;
    await whilePushed?.call();
    return null;
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
    projectsManager = OcptProjectsManager(
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
    FileSaverManager? fileSaverManager,
    FileSelectorManager? fileSelectorManager,
    OcptRouterManager? routerManager,
  }) => OcptHomeBloc(
    propertiesManager: propertiesManager,
    projectsManager: projectsManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
    fileSaverManager: fileSaverManager ?? _FakeFileSaverManager(),
    fileSelectorManager: fileSelectorManager ?? const FileSelectorManager(),
    exportManager: exportManager ?? _FakeExportManager(),
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
    final routerManager = _RecordingRouterManager(
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

    final bloc = buildBloc(
      fileSaverManager: _FakeFileSaverManager(result: filePath),
      routerManager: routerManager,
    );

    bloc.add(const OcptHomeCreateProjectRequestedEvent(name: "Series"));
    final state = await waitForState(
      bloc,
      (state) =>
          state.recentProjects.length == 1 && state.recentProjects.single.project.episodeCount == 2,
    );

    expect(
      state.recentProjects.single.project.path,
      filePath,
      reason: "the card the user comes back to must carry the count the project ended with, not "
          "the one it was created with",
    );

    await bloc.close();
  });

  test(
    'imports a picked fountain file into a new project and navigates to the editor',
    () async {
      const importedText = "Title: My Movie\n\nINT. HOUSE - DAY\n\nAction.\n";
      final exportManager = _FakeExportManager(
        importResult: const OcptImportedFountainModel(
          fountainText: importedText,
          sourceFileName: "draft.fountain",
        ),
      );
      final savedPath = p.join(tempDir.path, "My Movie.ocpt");
      final fileSaverManager = _FakeFileSaverManager(result: savedPath);
      final routerManager = _RecordingRouterManager();

      final bloc = buildBloc(
        exportManager: exportManager,
        fileSaverManager: fileSaverManager,
        routerManager: routerManager,
      );

      bloc.add(
        const OcptHomeImportScreenplayRequestedEvent(screenplayFileTypeLabel: "Screenplay"),
      );
      await waitForState(bloc, (state) => state.isBusy);
      final state = await waitForState(bloc, (state) => !state.isBusy);

      expect(state.error, isNull);
      expect(exportManager.lastFileTypeLabel, "Screenplay");
      // The suggested file name comes from the imported file's title page.
      expect(fileSaverManager.lastFileName, "My Movie.ocpt");
      expect(routerManager.pushedRoute, OcptRoute.workspace);

      final project = projectsManager.currentProject!;
      expect(project.name, "My Movie");
      expect(project.path, savedPath);

      final storedText = await projectsManager.screenplayService.loadScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
      );
      expect(storedText, importedText);

      final snapshots =
          await (project.database.select(
            project.database.ocptScreenplaySnapshotsTable,
          )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).get();
      expect(snapshots.last.reason, OcptSnapshotReason.import);

      await bloc.close();
    },
  );

  test('a cancelled screenplay file picker leaves the bloc idle and creates no project', () async {
    final exportManager = _FakeExportManager();
    final fileSaverManager = _FakeFileSaverManager();
    final bloc = buildBloc(exportManager: exportManager, fileSaverManager: fileSaverManager);

    bloc.add(
      const OcptHomeImportScreenplayRequestedEvent(screenplayFileTypeLabel: "Screenplay"),
    );
    await waitForState(bloc, (state) => state.isBusy);
    final state = await waitForState(bloc, (state) => !state.isBusy);

    expect(state.error, isNull);
    expect(fileSaverManager.lastFileName, isNull);
    expect(projectsManager.currentProject, isNull);

    await bloc.close();
  });

  test('an unreadable screenplay file is stated and creates no project', () async {
    final exportManager = _FakeExportManager(
      importStatus: OcptScreenplayImportStatus.unreadableFile,
    );
    final fileSaverManager = _FakeFileSaverManager();
    final bloc = buildBloc(exportManager: exportManager, fileSaverManager: fileSaverManager);

    bloc.add(
      const OcptHomeImportScreenplayRequestedEvent(screenplayFileTypeLabel: "Screenplay"),
    );
    await waitForState(bloc, (state) => state.isBusy);
    final state = await waitForState(bloc, (state) => !state.isBusy);

    expect(state.screenplayImportError, OcptScreenplayImportStatus.unreadableFile);
    expect(state.error, isNull);
    // The save dialog is never reached: nothing was read to seed a project with.
    expect(fileSaverManager.lastFileName, isNull);
    expect(projectsManager.currentProject, isNull);

    bloc.add(const OcptHomeScreenplayImportErrorDismissedEvent());
    final dismissed = await waitForState(bloc, (state) => state.screenplayImportError == null);
    expect(dismissed.screenplayImportError, isNull);

    await bloc.close();
  });

  test('a cancelled save-as dialog leaves the bloc idle and creates no project', () async {
    const importedText = "INT. HOUSE - DAY\n\nAction.\n";
    final exportManager = _FakeExportManager(
      importResult: const OcptImportedFountainModel(
        fountainText: importedText,
        sourceFileName: "draft.fountain",
      ),
    );
    final fileSaverManager = _FakeFileSaverManager();
    final bloc = buildBloc(exportManager: exportManager, fileSaverManager: fileSaverManager);

    bloc.add(
      const OcptHomeImportScreenplayRequestedEvent(screenplayFileTypeLabel: "Screenplay"),
    );
    await waitForState(bloc, (state) => state.isBusy);
    final state = await waitForState(bloc, (state) => !state.isBusy);

    expect(state.error, isNull);
    expect(projectsManager.currentProject, isNull);

    await bloc.close();
  });

  group("a project file from another build", () {
    // The older-file migration flow could not be exercised at schema version 1: ADR 0029 squashed
    // the pre-stable chain, so no schema below the current one existed then
    // (currentSchemaVersion - 1 was 0, which reads as an unreadable/foreign file, not an older
    // one). Schema version 2 (`OcptSyncRelayCursorsTable`) is the first real `onUpgrade` step since,
    // which is what reactivates the two tests below: `createProjectAtPreviousFormat` undoes exactly
    // that step's own addition, so whichever schema step is newest has to keep this helper in sync
    // with what it actually adds, or these tests fail loudly instead of proving anything. The same
    // limitation is why the pre-release "at your own risk" migration wording has no test here: it
    // only replaces the migration message, which these two skips already keep untested.
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
        ..execute("DROP TABLE sync_relay_cursors")
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

      bloc.add(
        OcptHomeOpenProjectRequestedEvent(filePath: filePath, fileTypeLabel: "Project"),
      );
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

    test("answering the question opens it, and the copy is where it was promised", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await createProjectAtPreviousFormat(filePath);
      final routerManager = _RecordingRouterManager();
      final bloc = buildBloc(routerManager: routerManager);

      bloc.add(
        OcptHomeOpenProjectRequestedEvent(filePath: filePath, fileTypeLabel: "Project"),
      );
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
    }, skip: olderFileFlowSkip);

    test("a newer one is raised as a refusal, and nothing is opened", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await createProjectFromTheFuture(filePath);
      await propertiesManager.deleteAll();
      final routerManager = _RecordingRouterManager();
      final bloc = buildBloc(routerManager: routerManager);

      bloc.add(
        OcptHomeOpenProjectRequestedEvent(filePath: filePath, fileTypeLabel: "Project"),
      );
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
      final routerManager = _RecordingRouterManager();
      final bloc = buildBloc(routerManager: routerManager);

      bloc.add(
        OcptHomeOpenProjectRequestedEvent(filePath: filePath, fileTypeLabel: "Project"),
      );
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

      bloc.add(
        OcptHomeOpenProjectRequestedEvent(filePath: filePath, fileTypeLabel: "Project"),
      );
      await waitForState(bloc, (state) => state.pendingFileCompatibility != null);

      bloc.add(const OcptHomeFileCompatibilityStatedEvent());
      final state = await waitForState(bloc, (state) => state.pendingFileCompatibility == null);

      expect(state.pendingFileCompatibility, isNull);

      await bloc.close();
    });
  });

  group("a project card's Partager / Synchroniser…", () {
    test("opens the project and pushes the Partager screen instead of the workspace", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await projectsManager.createProject(name: "My Movie", filePath: filePath);
      await projectsManager.closeCurrentProject();

      final routerManager = _RecordingRouterManager();
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
      final routerManager = _RecordingRouterManager();
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

  group("the home toolbar's Join a shared project…", () {
    test("pushes the Rejoindre screen and opens no project", () async {
      final routerManager = _RecordingRouterManager();
      final bloc = buildBloc(routerManager: routerManager);

      bloc.add(const OcptHomeJoinSharedProjectRequestedEvent());
      await pumpEventQueue();

      expect(routerManager.pushedRoute, OcptRoute.joining);
      expect(projectsManager.currentProject, isNull);

      await bloc.close();
    });
  });

  group("a project card's Export…", () {
    /// Writes a real file under the temp directory and returns its path, so an `assets` row can
    /// point at something that is actually there.
    String writeReferencedFile(String name) {
      final path = p.join(tempDir.path, name);
      File(path).writeAsStringSync("referenced bytes");
      return path;
    }

    /// Creates a project at [filePath], adds one `assets` row labelled [label] and pointing at
    /// [assetPath] (which may or may not exist), then closes it — a project card names a file
    /// nothing has opened, exactly like this leaves the project.
    Future<void> createProjectWithAsset(
      String filePath, {
      required String assetPath,
      required String label,
    }) async {
      await projectsManager.createProject(name: "My Movie", filePath: filePath);
      final database = projectsManager.currentProject!.database;
      await database
          .into(database.ocptAssetsTable)
          .insert(
            OcptAssetsTableCompanion.insert(
              id: label,
              kind: OcptAssetKind.locationPhoto,
              path: assetPath,
              label: Value(label),
              addedAt: DateTime.utc(2026, 8, 19),
            ),
          );
      await projectsManager.closeCurrentProject();
    }

    test(
      "runs the pre-flight and asks through the state when a referenced file is missing",
      () async {
        final filePath = p.join(tempDir.path, "movie.ocpt");
        await createProjectWithAsset(
          filePath,
          assetPath: p.join(tempDir.path, "gone.jpg"),
          label: "Town hall permit",
        );

        final bloc = buildBloc();
        bloc.add(
          OcptProjectPackageExportRequestedEvent(
            fileTypeLabel: "Project package",
            target: OcptProjectPackageTarget(filePath: filePath, name: "My Movie"),
          ),
        );

        final state = await waitForState(
          bloc,
          (state) => state.projectPackagePendingExport != null,
        );

        expect(state.projectPackagePendingExport?.missingAssets.single.label, "Town hall permit");
        expect(state.projectPackageNotice, isNull);
        expect(
          projectsManager.currentProject,
          isNull,
          reason: "nothing was opened to export the card's project",
        );

        await bloc.close();
      },
    );

    test("writes to the picked save location when nothing is missing", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await createProjectWithAsset(
        filePath,
        assetPath: writeReferencedFile("headshot.jpg"),
        label: "Headshot",
      );

      final packagePath = p.join(tempDir.path, "movie.ocptz");
      final saveLocationService = _RecordingSaveLocationService(saveLocationAnswer: packagePath);
      final bloc = buildBloc(
        exportManager: OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: saveLocationService,
        ),
      );

      bloc.add(
        OcptProjectPackageExportRequestedEvent(
          fileTypeLabel: "Project package",
          target: OcptProjectPackageTarget(filePath: filePath, name: "My Movie"),
        ),
      );

      final state = await waitForState(bloc, (state) => state.projectPackageNotice != null);

      expect(state.projectPackageNotice?.kind, OcptProjectPackageNoticeKind.exportSucceeded);
      expect(File(packagePath).existsSync(), isTrue);
      expect(saveLocationService.askCount, 1);
      expect(projectsManager.currentProject, isNull);

      await bloc.close();
    });
  });

  group("importing a project package", () {
    late Directory importsParent;

    setUp(() {
      importsParent = Directory(p.join(tempDir.path, "imports"))..createSync(recursive: true);
    });

    /// Creates a project, exports it as a package at [packagePath], and returns it: the package a
    /// test picks through the (faked) open dialog.
    Future<String> exportedPackage(String packagePath) async {
      final projectFilePath = p.join(tempDir.path, "source.ocpt");
      await projectsManager.createProject(name: "Les Vagues", filePath: projectFilePath);
      await projectsManager.closeCurrentProject();

      final result = await projectsManager.exportProjectPackage(
        projectFilePath: projectFilePath,
        projectName: "Les Vagues",
        packageFilePath: packagePath,
      );
      expect(result.status.isSuccess, isTrue);
      return packagePath;
    }

    /// Rewrites the `manifest.json` entry of the package at [sourcePath] with [transform] applied
    /// to it, and returns the path of the package this produces — used to build the malformed
    /// package a newer `packageFormat` refusal is tested against, on the model of
    /// `ocpt_project_package_service_test.dart`'s own `repackagedWith`.
    Future<String> repackagedWithManifest(
      String sourcePath,
      Map<String, dynamic> Function(Map<String, dynamic> manifest) transform,
    ) async {
      final archive = ZipDecoder().decodeStream(InputFileStream(sourcePath));
      final manifestEntry = archive.files.firstWhere((entry) => entry.name == "manifest.json");
      final manifest = jsonDecode(utf8.decode(manifestEntry.readBytes()!)) as Map<String, dynamic>;
      final rewrittenManifest = utf8.encode(jsonEncode(transform(manifest)));

      final targetPath = p.join(p.dirname(sourcePath), "repackaged-${p.basename(sourcePath)}");
      final encoder = ZipFileEncoder()..create(targetPath);
      try {
        for (final entry in archive.files) {
          if (!entry.isFile) {
            continue;
          }
          final bytes = entry.name == "manifest.json" ? rewrittenManifest : entry.readBytes()!;
          encoder.addArchiveFile(ArchiveFile.bytes(entry.name, bytes));
        }
      } finally {
        await encoder.close();
      }

      return targetPath;
    }

    test(
      "imports a picked package into the picked parent folder and raises the report, without "
      "opening anything itself",
      () async {
        final packagePath = await exportedPackage(p.join(tempDir.path, "movie.ocptz"));
        final fileSelectorManager = _FakeFileSelectorManager(result: XFile(packagePath));
        final saveLocationService = _RecordingSaveLocationService(
          directoryAnswer: importsParent.path,
        );
        final bloc = buildBloc(
          fileSelectorManager: fileSelectorManager,
          exportManager: OcptExportManager(
            fileSelectorManager: const FileSelectorManager(),
            saveLocationService: saveLocationService,
          ),
        );

        bloc.add(
          const OcptHomeImportProjectPackageRequestedEvent(
            packageFileTypeLabel: "Project package",
            destinationConfirmButtonText: "Import here",
          ),
        );

        final state = await waitForState(bloc, (state) => state.projectPackageImportReport != null);

        final report = state.projectPackageImportReport!;
        expect(report.projectName, "Les Vagues");
        expect(report.skippedAssets, isEmpty);
        expect(File(report.projectFilePath).existsSync(), isTrue);
        expect(fileSelectorManager.lastAllowedExtensions, ["ocptz"]);
        expect(saveLocationService.lastDirectoryConfirmButtonText, "Import here");
        expect(
          projectsManager.currentProject,
          isNull,
          reason: "the bloc unpacks the package but never opens it itself",
        );
        expect(state.projectPackageImportError, isNull);

        await bloc.close();
      },
    );

    test(
      "an existing folder of that name comes back as destinationExists, raised through the state",
      () async {
        final packagePath = await exportedPackage(p.join(tempDir.path, "movie.ocptz"));
        Directory(p.join(importsParent.path, "Les Vagues")).createSync(recursive: true);

        final bloc = buildBloc(
          fileSelectorManager: _FakeFileSelectorManager(result: XFile(packagePath)),
          exportManager: OcptExportManager(
            fileSelectorManager: const FileSelectorManager(),
            saveLocationService: _RecordingSaveLocationService(
              directoryAnswer: importsParent.path,
            ),
          ),
        );

        bloc.add(
          const OcptHomeImportProjectPackageRequestedEvent(
            packageFileTypeLabel: "Project package",
            destinationConfirmButtonText: "Import here",
          ),
        );

        final state = await waitForState(bloc, (state) => state.projectPackageImportError != null);

        expect(state.projectPackageImportError, OcptProjectPackageStatus.destinationExists);
        expect(state.projectPackageImportReport, isNull);

        await bloc.close();
      },
    );

    test(
      "a packageFormat newer than this build's is refused with its own status rather than an "
      "exception",
      () async {
        final packagePath = await exportedPackage(p.join(tempDir.path, "movie.ocptz"));
        final futurePackagePath = await repackagedWithManifest(
          packagePath,
          (manifest) => {...manifest, "packageFormat": 999},
        );

        final bloc = buildBloc(
          fileSelectorManager: _FakeFileSelectorManager(result: XFile(futurePackagePath)),
          exportManager: OcptExportManager(
            fileSelectorManager: const FileSelectorManager(),
            saveLocationService: _RecordingSaveLocationService(
              directoryAnswer: importsParent.path,
            ),
          ),
        );

        bloc.add(
          const OcptHomeImportProjectPackageRequestedEvent(
            packageFileTypeLabel: "Project package",
            destinationConfirmButtonText: "Import here",
          ),
        );

        final state = await waitForState(bloc, (state) => state.projectPackageImportError != null);

        expect(state.projectPackageImportError, OcptProjectPackageStatus.unsupportedPackageFormat);
        expect(state.projectPackageImportReport, isNull);
        expect(importsParent.listSync(), isEmpty);

        await bloc.close();
      },
    );

    test("a cancelled open dialog does nothing at all", () async {
      final saveLocationService = _RecordingSaveLocationService(directoryAnswer: importsParent.path);
      final bloc = buildBloc(
        fileSelectorManager: _FakeFileSelectorManager(),
        exportManager: OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: saveLocationService,
        ),
      );

      bloc.add(
        const OcptHomeImportProjectPackageRequestedEvent(
          packageFileTypeLabel: "Project package",
          destinationConfirmButtonText: "Import here",
        ),
      );
      await waitForState(bloc, (state) => state.isBusy);
      final state = await waitForState(bloc, (state) => !state.isBusy);

      expect(state.projectPackageImportReport, isNull);
      expect(state.projectPackageImportError, isNull);
      expect(
        saveLocationService.lastDirectoryConfirmButtonText,
        isNull,
        reason: "the folder picker is never reached once the open dialog was cancelled",
      );

      await bloc.close();
    });

    test("a cancelled folder picker does nothing at all", () async {
      final packagePath = await exportedPackage(p.join(tempDir.path, "movie.ocptz"));
      final bloc = buildBloc(
        fileSelectorManager: _FakeFileSelectorManager(result: XFile(packagePath)),
        exportManager: OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: _RecordingSaveLocationService(),
        ),
      );

      bloc.add(
        const OcptHomeImportProjectPackageRequestedEvent(
          packageFileTypeLabel: "Project package",
          destinationConfirmButtonText: "Import here",
        ),
      );
      await waitForState(bloc, (state) => state.isBusy);
      final state = await waitForState(bloc, (state) => !state.isBusy);

      expect(state.projectPackageImportReport, isNull);
      expect(state.projectPackageImportError, isNull);
      expect(importsParent.listSync(), isEmpty);

      await bloc.close();
    });
  });
}
