// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_move_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart';

/// A projects manager whose [newProjectsDirectory] resolves to a fixed [directory] instead of
/// asking `path_provider` for the platform's real Downloads folder — `path_provider`'s desktop
/// implementations need the plugin-registrant plumbing a plain `flutter test` run doesn't reliably
/// provide, exactly the kind of pitfall `AGENTS.md`'s own "flutter test runs on the plain Dart VM"
/// note already flags elsewhere.
class _TestProjectsManager extends OcptProjectsManager {
  /// The directory [newProjectsDirectory] always resolves to.
  final Directory directory;

  /// Class constructor
  _TestProjectsManager({required this.directory, super.propertiesManager});

  @override
  Future<Directory> newProjectsDirectory() async => directory;
}

void main() {
  // OcptPropertiesManager wraps a process-wide singleton (see the properties manager test), so we
  // create it once, backed by an in-memory store, and clear it between tests.
  late OcptPropertiesManager propertiesManager;

  late Directory tempDir;

  late OcptProjectsManager manager;

  setUpAll(() async {
    // OcptRecentProjectModel and this manager both log through appLogger(), which requires a
    // global manager instance to be set; merely accessing it creates the (otherwise unused)
    // singleton.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    tempDir = await Directory.systemTemp.createTemp("ocpt_projects_manager_test_");
    manager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await manager.initLifeCycle();
  });

  tearDown(() async {
    await manager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  group("previewVersion", () {
    /// Opens a project holding [text], captures it as a version, then replaces its text with
    /// [textAfterwards] so the working copy and the version have visibly diverged.
    Future<OcptProjectVersion> createDivergedProject({
      String text = "INT. HOUSE - DAY\n\nCLARA enters.",
      String textAfterwards = "EXT. STREET - NIGHT\n\nThe rewrite.",
    }) async {
      final project = (await manager.createProject(
        name: "My Movie",
        filePath: p.join(tempDir.path, "movie.ocpt"),
      )).value!;

      await manager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: text,
        snapshotReason: OcptSnapshotReason.manual,
      );

      final version = (await manager.createProjectVersion(name: "v1 — First read", note: ""))!;

      await manager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: textAfterwards,
        snapshotReason: OcptSnapshotReason.manual,
      );

      return version;
    }

    /// The text of the open project's screenplay, read through the database the modes read
    /// through (the previewed one while a preview is up).
    Future<String> readTextThroughCurrentDatabase() async {
      final project = manager.currentProject!;
      return manager.screenplayService.loadScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
      );
    }

    /// The text of the open project's screenplay, read through the project file itself.
    Future<String> readTextThroughFile() async {
      final project = manager.currentProject!;
      return manager.screenplayService.loadScreenplayText(
        database: project.fileDatabase,
        screenplayId: project.primaryScreenplayId,
      );
    }

    test('shows the version through the project model, and emits a model of its own', () async {
      final version = await createDivergedProject();
      final workingCopy = manager.currentProject!;

      final result = await manager.previewVersion(version.id);

      expect(result.status, OcptProjectPreviewStatus.ok);

      final previewing = manager.currentProject!;
      expect(previewing.isReadOnly, isTrue);
      expect(previewing.previewedVersion, version);
      expect(previewing.previewedPageSetup, isNotNull);
      expect(await readTextThroughCurrentDatabase(), "INT. HOUSE - DAY\n\nCLARA enters.");

      // Entering a preview keeps the path, the name and the screenplay id: were the previewed
      // version left out of the equality, no mode would ever be told anything happened.
      expect(previewing == workingCopy, isFalse);
      expect(previewing.path, workingCopy.path);
      expect(previewing.name, workingCopy.name);
      expect(previewing.primaryScreenplayId, workingCopy.primaryScreenplayId);
    });

    test('leaves the project file exactly as it was over a full preview cycle', () async {
      final version = await createDivergedProject();
      final fileDatabase = manager.currentProject!.fileDatabase;

      await manager.previewVersion(version.id);

      // The file is still open, still the very same connection, and still holds the working copy
      // rather than the version being read.
      expect(manager.currentProject!.fileDatabase, same(fileDatabase));
      expect(await readTextThroughFile(), "EXT. STREET - NIGHT\n\nThe rewrite.");

      // And it is still writable: a preview is not a write lock on the project, only on what the
      // user is looking at. This is the slot the sync engine will write incoming changesets to.
      await manager.screenplayService.saveScreenplayText(
        database: fileDatabase,
        screenplayId: manager.currentProject!.primaryScreenplayId,
        fountainText: "EXT. STREET - NIGHT\n\nWritten while a version was on screen.",
        snapshotReason: OcptSnapshotReason.manual,
      );

      await manager.exitPreview();

      expect(manager.currentProject!.isReadOnly, isFalse);
      expect(manager.currentProject!.previewedVersion, isNull);
      expect(manager.currentProject!.database, same(fileDatabase));
      expect(
        await readTextThroughCurrentDatabase(),
        "EXT. STREET - NIGHT\n\nWritten while a version was on screen.",
      );
    });

    test('leaves the app-wide page margins alone over a full preview cycle', () async {
      const versionMargins = FountainPageMargins(
        leftInches: 1.75,
        rightInches: 0.75,
        topInches: 0.5,
        bottomInches: 0.5,
      );
      const workingCopyMargins = FountainPageMargins(
        leftInches: 1.5,
        rightInches: 1,
        topInches: 1,
        bottomInches: 1,
      );

      await propertiesManager.pageMargins.store(versionMargins);
      final version = await createDivergedProject();
      await propertiesManager.pageMargins.store(workingCopyMargins);

      await manager.previewVersion(version.id);

      // The version renders with the layout it was written against...
      expect(manager.currentProject!.previewedPageSetup?.margins, versionMargins);

      // ...without that ever reaching the preference the whole app paginates with. Only a restore
      // writes it back, and only once its transaction has committed.
      expect(await propertiesManager.pageMargins.load(), workingCopyMargins);

      await manager.exitPreview();

      expect(await propertiesManager.pageMargins.load(), workingCopyMargins);
    });

    test('refuses to write through the previewed database, whatever asks', () async {
      final version = await createDivergedProject();
      await manager.previewVersion(version.id);

      final project = manager.currentProject!;

      await manager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: "INT. HOUSE - DAY\n\nAn edit that must not happen.",
        snapshotReason: OcptSnapshotReason.manual,
      );
      final createdShotId = await manager.shotListService.createShot(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        sceneId: (await project.database.select(project.database.ocptScenesTable).get()).first.id,
      );
      await manager.saveCurrentProjectPageFormat(
        project.previewedPageSetup!.format == OcptPageFormat.a4
            ? OcptPageFormat.usLetter
            : OcptPageFormat.a4,
      );

      expect(createdShotId, isNull);
      expect(await readTextThroughCurrentDatabase(), "INT. HOUSE - DAY\n\nCLARA enters.");
      expect(await project.database.select(project.database.ocptShotsTable).get(), isEmpty);
      expect(await manager.loadCurrentProjectPageFormat(), project.previewedPageSetup!.format);

      // And the project file itself is untouched by any of it either.
      expect(await readTextThroughFile(), "EXT. STREET - NIGHT\n\nThe rewrite.");
    });

    test('refuses to enter while a mode still holds unsaved changes', () async {
      final version = await createDivergedProject();

      var isDirty = true;
      final unregister = manager.registerUnsavedChangesReporter(() => isDirty);

      expect(manager.hasUnsavedChanges, isTrue);
      expect(
        (await manager.previewVersion(version.id)).status,
        OcptProjectPreviewStatus.unsavedChanges,
      );
      expect(manager.currentProject!.isReadOnly, isFalse);

      // Saving is what the caller does with that refusal, and the retry then goes through.
      isDirty = false;
      expect((await manager.previewVersion(version.id)).status, OcptProjectPreviewStatus.ok);

      // An unregistered reporter is never asked again, even if it would still say yes.
      await manager.exitPreview();
      isDirty = true;
      unregister();
      expect(manager.hasUnsavedChanges, isFalse);
      expect((await manager.previewVersion(version.id)).status, OcptProjectPreviewStatus.ok);
    });

    test('refuses a version the project does not have, and any version with no project', () async {
      expect(
        (await manager.previewVersion("no-such-version")).status,
        OcptProjectPreviewStatus.noProjectOpen,
      );

      await createDivergedProject();

      expect(
        (await manager.previewVersion("no-such-version")).status,
        OcptProjectPreviewStatus.versionNotFound,
      );
      expect(manager.currentProject!.isReadOnly, isFalse);
    });

    test('previewing another version replaces the one on screen', () async {
      final first = await createDivergedProject();
      final second = (await manager.createProjectVersion(name: "v2 — Rewritten", note: ""))!;

      await manager.previewVersion(first.id);
      final firstPreviewDatabase = manager.currentProject!.database;

      await manager.previewVersion(second.id);

      expect(manager.currentProject!.previewedVersion, second);
      expect(manager.currentProject!.database, isNot(same(firstPreviewDatabase)));
      expect(await readTextThroughCurrentDatabase(), "EXT. STREET - NIGHT\n\nThe rewrite.");
    });

    test('refuses to delete the version being previewed', () async {
      final version = await createDivergedProject();
      await manager.previewVersion(version.id);

      await manager.deleteProjectVersion(version.id);

      expect((await manager.listProjectVersions()).map((entry) => entry.id), [version.id]);
      expect(manager.currentProject!.previewedVersion, version);

      // Another version, on the other hand, may go while a preview is up: the version list lives
      // in the project file, which a preview never takes over.
      final other = (await manager.createProjectVersion(name: "v2", note: ""))!;
      await manager.deleteProjectVersion(other.id);
      expect((await manager.listProjectVersions()).map((entry) => entry.id), [version.id]);
    });

    test('exitPreview is a no-op when nothing is being previewed', () async {
      await expectLater(manager.exitPreview(), completes);

      await createDivergedProject();

      await expectLater(manager.exitPreview(), completes);
      expect(manager.currentProject!.isReadOnly, isFalse);
    });

    test('restoring puts the project back on the version, and leaves the preview', () async {
      final version = await createDivergedProject();
      await manager.previewVersion(version.id);

      final status = await manager.restoreProjectVersion(
        versionId: version.id,
        safetyVersionName: "Before restoring v1 — First read",
      );

      expect(status, OcptProjectRestoreStatus.ok);
      expect(manager.currentProject!.isReadOnly, isFalse);
      expect(await readTextThroughFile(), "INT. HOUSE - DAY\n\nCLARA enters.");

      // The state the restore replaced is a version of its own, and the project descends from the
      // one it was put back on.
      final versions = await manager.listProjectVersions();
      expect(
        versions.map((entry) => entry.name),
        containsAll(["Before restoring v1 — First read", "v1 — First read"]),
      );
      expect(versions.singleWhere((entry) => entry.id == version.id).isBase, isTrue);
    });

    test('captureWorkingCopyState is null while a version is being previewed', () async {
      final version = await createDivergedProject();
      await manager.previewVersion(version.id);

      expect(await manager.captureWorkingCopyState(), isNull);
    });

    test('restoring writes the version page margins back, once it has committed', () async {
      const versionMargins = FountainPageMargins(
        leftInches: 1.75,
        rightInches: 0.75,
        topInches: 0.5,
        bottomInches: 0.5,
      );
      const workingCopyMargins = FountainPageMargins(
        leftInches: 1.5,
        rightInches: 1,
        topInches: 1,
        bottomInches: 1,
      );

      await propertiesManager.pageMargins.store(versionMargins);
      final version = await createDivergedProject();
      await propertiesManager.pageMargins.store(workingCopyMargins);

      await manager.restoreProjectVersion(versionId: version.id, safetyVersionName: "Before");

      // The margins are an app-wide preference rather than project data, so they are the one part
      // of a restore that lives outside its transaction — written only once that has committed.
      expect(await propertiesManager.pageMargins.load(), versionMargins);
    });

    test("restoring records the episode count the restored version brings back", () async {
      final version = await createDivergedProject();
      await manager.screenplayService.createEpisode(database: manager.currentProject!.database);
      await manager.recordCurrentProjectEpisodeCount();

      await manager.restoreProjectVersion(versionId: version.id, safetyVersionName: "Before");

      // The version was captured while the project held its single episode; the second one the
      // working copy grew afterwards is not part of what came back.
      final recents = await propertiesManager.recentProjects.load();
      expect(recents?.first.episodeCount, 1);
    });

    test('a restore that fails changes neither the project nor the margins', () async {
      const workingCopyMargins = FountainPageMargins(
        leftInches: 1.5,
        rightInches: 1,
        topInches: 1,
        bottomInches: 1,
      );

      await createDivergedProject();
      await propertiesManager.pageMargins.store(workingCopyMargins);

      final status = await manager.restoreProjectVersion(
        versionId: "no-such-version",
        safetyVersionName: "Before",
      );

      expect(status, OcptProjectRestoreStatus.versionNotFound);
      expect(await readTextThroughFile(), "EXT. STREET - NIGHT\n\nThe rewrite.");
      expect(await propertiesManager.pageMargins.load(), workingCopyMargins);
    });

    test('restoring with no project open reports it rather than throwing', () async {
      expect(
        await manager.restoreProjectVersion(versionId: "any", safetyVersionName: "Before"),
        OcptProjectRestoreStatus.noProjectOpen,
      );
    });

    test('closing the project while previewing disposes both of its databases', () async {
      final version = await createDivergedProject();
      await manager.previewVersion(version.id);
      final previewDatabase = manager.currentProject!.database;
      final fileDatabase = manager.currentProject!.fileDatabase;

      await manager.closeCurrentProject();

      expect(manager.currentProject, isNull);
      await expectLater(
        previewDatabase.select(previewDatabase.ocptScreenplaysTable).get(),
        throwsA(anything),
      );
      await expectLater(
        fileDatabase.select(fileDatabase.ocptScreenplaysTable).get(),
        throwsA(anything),
      );
    });
  });

  group("opening a file from another build", () {
    // No "older" file case is exercised here: while `OcptProjectDatabase.currentSchemaVersion` was
    // still `1` — the very first schema, per
    // `docs/adr/0029-schema-versions-frozen-at-stable-releases.md`'s squash —
    // `OcptProjectFileCompatibilityService.probe` had no positive schema number below the current
    // one for a test file to state (`PRAGMA user_version <= 0` reads as `unreadable`, not `older`),
    // so `older`/`migrationRequired` could not be exercised through the manager at all; now that a
    // real schema version 2 exists, `home_bloc_recent_projects_and_import_test.dart`'s "a project
    // file from another build" group is where that flow is actually driven through a bloc, and
    // `OcptProjectFileCompatibilityService`'s own tests cover the verdict in isolation, at a schema
    // number decoupled from this constant.

    /// Stamps [userVersion] onto the project file at [filePath], changing nothing else.
    void stampFormat(String filePath, int userVersion) {
      final database = sqlite3.open(filePath);
      database
        ..execute("PRAGMA user_version = $userVersion")
        ..dispose();
    }

    /// The `PRAGMA user_version` the file at [filePath] states about itself.
    int formatOf(String filePath) {
      final database = sqlite3.open(filePath, mode: OpenMode.readOnly);
      try {
        return database.select("PRAGMA user_version").first.values.first! as int;
      } finally {
        database.dispose();
      }
    }

    /// Stamps [migratedByAppVersion] onto the project file at [filePath]'s `project_info` row,
    /// changing nothing else — the writer identity a real migration would have left behind.
    void stampWriter(String filePath, String migratedByAppVersion) {
      final database = sqlite3.open(filePath);
      database
        ..execute("UPDATE project_info SET migrated_by_app_version = ?", [migratedByAppVersion])
        ..dispose();
    }

    test("a file from a newer build is refused, and comes back byte-identical", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await manager.createProject(name: "From The Future", filePath: filePath);
      await manager.closeCurrentProject();
      stampFormat(filePath, OcptProjectDatabase.currentSchemaVersion + 1);
      await propertiesManager.deleteAll();

      final bytesBefore = File(filePath).readAsBytesSync();

      final result = await manager.openProject(filePath: filePath);

      expect(result.status, OcptProjectStatus.newerFormat);
      expect(manager.currentProject, isNull);
      expect(File(filePath).readAsBytesSync(), bytesBefore);
      expect(formatOf(filePath), OcptProjectDatabase.currentSchemaVersion + 1);
      expect(
        await propertiesManager.recentProjects.load() ?? const [],
        isEmpty,
        reason: "a file that was never opened has no business in the recent projects list",
      );
    });

    test("a refusal leaves the project already open alone", () async {
      final openPath = p.join(tempDir.path, "current.ocpt");
      await manager.createProject(name: "Current", filePath: openPath);

      final futurePath = p.join(tempDir.path, "future.ocpt");
      final future = OcptProjectDatabase(File(futurePath));
      await future.close();
      stampFormat(futurePath, OcptProjectDatabase.currentSchemaVersion + 1);

      expect(
        (await manager.openProject(filePath: futurePath)).status,
        OcptProjectStatus.newerFormat,
      );
      expect(manager.currentProject?.path, openPath);
    });

    test("a file at the current schema written by a different pre-release build is refused, "
        "leaving any already-open project alone", () async {
      final openPath = p.join(tempDir.path, "current.ocpt");
      await manager.createProject(name: "Current", filePath: openPath);

      final foreignPath = p.join(tempDir.path, "foreign.ocpt");
      await manager.createProject(name: "From Another Workshop", filePath: foreignPath);
      await manager.closeCurrentProject();
      // A pre-release writer, whereas the manager's own fallback under `flutter test` is the
      // stable "0.3.0" (per `OcptProjectsManager._appVersion`): same schema, and a pre-release
      // is involved on the writer side, so the file is a foreign dev build.
      stampWriter(foreignPath, "0.2.0-alpha.99");

      // Reopen "Current" since createProject above closed it to open "foreign.ocpt".
      await manager.openProject(filePath: openPath);

      final result = await manager.openProject(filePath: foreignPath);

      expect(result.status, OcptProjectStatus.foreignDevBuildFormat);
      expect(manager.currentProject?.path, openPath);
    });

    test("a file stamped with this exact build's own version opens normally", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await manager.createProject(name: "My Movie", filePath: filePath);
      await manager.closeCurrentProject();
      // The manager's own local/dev fallback under `flutter test` — see
      // `OcptProjectsManager._appVersion`. Already stamped by createProject, but stamped again
      // explicitly here to state exactly what this test is about.
      stampWriter(filePath, "0.3.0");

      final result = await manager.openProject(filePath: filePath);

      expect(result.status, OcptProjectStatus.ok);
      expect(manager.currentProject?.path, filePath);
    });
  });

  group("freeNewProjectFilePath", () {
    test("returns the plain name when nothing is taken in newProjectsDirectory", () async {
      final testManager = _TestProjectsManager(
        directory: tempDir,
        propertiesManager: propertiesManager,
      );

      final path = await testManager.freeNewProjectFilePath("Movie");

      expect(path, p.join(tempDir.path, "Movie.ocpt"));
    });

    test("numbers up when the plain name is already taken", () async {
      await File(p.join(tempDir.path, "Movie.ocpt")).create();
      final testManager = _TestProjectsManager(
        directory: tempDir,
        propertiesManager: propertiesManager,
      );

      final path = await testManager.freeNewProjectFilePath("Movie");

      expect(path, p.join(tempDir.path, "Movie (2).ocpt"));
    });
  });

  group("moveCurrentProject", () {
    test(
      "moves the project's file, opening the new one with the same data, and deletes the old one",
      () async {
        final oldPath = p.join(tempDir.path, "movie.ocpt");
        final newPath = p.join(tempDir.path, "moved", "movie.ocpt");
        await manager.createProject(name: "My Movie", filePath: oldPath);
        await manager.screenplayService.saveScreenplayText(
          database: manager.currentProject!.database,
          screenplayId: manager.currentProject!.primaryScreenplayId,
          fountainText: "INT. HOUSE - DAY\n\nAction.\n",
          snapshotReason: OcptSnapshotReason.timer,
        );

        final result = await manager.moveCurrentProject(newFilePath: newPath);

        expect(result.status, OcptProjectMoveStatus.ok);
        expect(result.value?.path, newPath);
        expect(manager.currentProject?.path, newPath);
        expect(File(oldPath).existsSync(), isFalse);
        expect(File(newPath).existsSync(), isTrue);

        final screenplayText = await manager.screenplayService.loadScreenplayText(
          database: manager.currentProject!.database,
          screenplayId: manager.currentProject!.primaryScreenplayId,
        );
        expect(screenplayText, "INT. HOUSE - DAY\n\nAction.\n");
      },
    );

    test("updates the recent-projects entry to the new path, keeping its position", () async {
      final currentPath = p.join(tempDir.path, "movie.ocpt");
      final newPath = p.join(tempDir.path, "moved.ocpt");
      await manager.createProject(name: "My Movie", filePath: currentPath);

      // A later entry added straight through the properties manager, standing in for another
      // project opened more recently than the one under test — this is what puts the moved
      // project second in the list rather than at the front, so "keeps its position" actually
      // means something (a plain re-add through `addRecentProject` would put it back in front).
      await propertiesManager.addRecentProject(
        OcptRecentProjectModel(
          path: p.join(tempDir.path, "ghost.ocpt"),
          name: "Ghost",
          lastOpenedAt: DateTime.now(),
        ),
      );

      await manager.moveCurrentProject(newFilePath: newPath);

      final recents = await propertiesManager.recentProjects.load();
      expect(recents?.map((entry) => entry.path).toList(), [
        p.join(tempDir.path, "ghost.ocpt"),
        newPath,
      ]);
      expect(recents?.last.name, "My Movie");
    });

    test("refuses when the target already exists, leaving both files intact", () async {
      final firstPath = p.join(tempDir.path, "first.ocpt");
      final secondPath = p.join(tempDir.path, "second.ocpt");
      await manager.createProject(name: "First", filePath: firstPath);
      await manager.closeCurrentProject();
      await manager.createProject(name: "Second", filePath: secondPath);

      final result = await manager.moveCurrentProject(newFilePath: firstPath);

      expect(result.status, OcptProjectMoveStatus.fileAlreadyExists);
      expect(manager.currentProject?.path, secondPath);
      expect(File(firstPath).existsSync(), isTrue);
      expect(File(secondPath).existsSync(), isTrue);
    });

    test("moving a project to its own current path is a no-op reporting ok", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await manager.createProject(name: "My Movie", filePath: filePath);

      final result = await manager.moveCurrentProject(newFilePath: filePath);

      expect(result.status, OcptProjectMoveStatus.ok);
      expect(manager.currentProject?.path, filePath);
      expect(File(filePath).existsSync(), isTrue);
      // The database connection is still the very same one, still readable.
      final info = await manager.currentProject!.database
          .select(manager.currentProject!.database.ocptProjectInfoTable)
          .getSingle();
      expect(info.name, "My Movie");
    });

    test("refuses when no project is open", () async {
      final result = await manager.moveCurrentProject(
        newFilePath: p.join(tempDir.path, "movie.ocpt"),
      );

      expect(result.status, OcptProjectMoveStatus.noProjectOpen);
    });

    test("a relay sidecar beside the project file travels along with it", () async {
      final oldPath = p.join(tempDir.path, "movie.ocpt");
      final newPath = p.join(tempDir.path, "moved.ocpt");
      await manager.createProject(name: "My Movie", filePath: oldPath);

      final oldSidecarPath = p.join(tempDir.path, "movie.relay.sqlite");
      await File(oldSidecarPath).writeAsString("relay bytes");
      await File("$oldSidecarPath-wal").writeAsString("wal bytes");

      await manager.moveCurrentProject(newFilePath: newPath);

      final newSidecarPath = p.join(tempDir.path, "moved.relay.sqlite");
      expect(File(oldSidecarPath).existsSync(), isFalse);
      expect(File("$oldSidecarPath-wal").existsSync(), isFalse);
      expect(File(newSidecarPath).existsSync(), isTrue);
      expect(await File(newSidecarPath).readAsString(), "relay bytes");
      expect(File("$newSidecarPath-wal").existsSync(), isTrue);
      expect(await File("$newSidecarPath-wal").readAsString(), "wal bytes");
    });

    test("remembers the new folder as the next dialog's suggested one", () async {
      final oldPath = p.join(tempDir.path, "movie.ocpt");
      final movedDir = Directory(p.join(tempDir.path, "elsewhere"));
      final newPath = p.join(movedDir.path, "movie.ocpt");
      await manager.createProject(name: "My Movie", filePath: oldPath);

      await manager.moveCurrentProject(newFilePath: newPath);

      expect(await manager.suggestedProjectsDirectory(), movedDir.path);
    });
  });
}
