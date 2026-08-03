// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
    manager = OcptProjectsManager(propertiesManager: propertiesManager);
    await manager.initLifeCycle();
  });

  tearDown(() async {
    await manager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  test('createProject creates the project file, seeds it, and makes it current', () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");

    final result = await manager.createProject(name: "My Movie", filePath: filePath);

    expect(result.status, OcptProjectStatus.ok);
    expect(result.value?.name, "My Movie");
    expect(File(filePath).existsSync(), isTrue);
    expect(manager.currentProject?.path, filePath);
    expect(manager.currentProject?.name, "My Movie");

    final screenplayText = await manager.screenplayService.loadScreenplayText(
      database: manager.currentProject!.database,
      screenplayId: manager.currentProject!.primaryScreenplayId,
    );
    expect(screenplayText, "");

    final recents = await propertiesManager.recentProjects.load();
    expect(recents?.first.path, filePath);
    expect(recents?.first.name, "My Movie");
  });

  test('createProject while a project is already open closes the previous one first', () async {
    await manager.createProject(name: "First", filePath: p.join(tempDir.path, "first.ocpt"));

    final result = await manager.createProject(
      name: "Second",
      filePath: p.join(tempDir.path, "second.ocpt"),
    );

    expect(result.status, OcptProjectStatus.ok);
    expect(manager.currentProject?.name, "Second");
  });

  test('openProject opens a previously created project and makes it current', () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");
    await manager.createProject(name: "My Movie", filePath: filePath);
    await manager.closeCurrentProject();

    final result = await manager.openProject(filePath: filePath);

    expect(result.status, OcptProjectStatus.ok);
    expect(manager.currentProject?.name, "My Movie");
    expect(manager.currentProject?.path, filePath);

    final recents = await propertiesManager.recentProjects.load();
    expect(recents?.first.path, filePath);
  });

  test('closeCurrentProject clears the current project and is a no-op when none is open', () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));

    await manager.closeCurrentProject();
    expect(manager.currentProject, isNull);

    // Closing again must not throw.
    await manager.closeCurrentProject();
    expect(manager.currentProject, isNull);
  });

  test('currentProjectStream emits every time the current project changes', () async {
    // expectLater/emitsInOrder subscribes right away and awaits each expected event in turn,
    // which avoids racing the stream's (deferred) event delivery against the actions below.
    final expectation = expectLater(
      manager.currentProjectStream.map((project) => project?.name),
      emitsInOrder(<Object?>["My Movie", null]),
    );

    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    await manager.closeCurrentProject();

    await expectation;
  });

  test('openProject returns fileNotFound when the file does not exist', () async {
    final result = await manager.openProject(filePath: p.join(tempDir.path, "missing.ocpt"));

    expect(result.status, OcptProjectStatus.fileNotFound);
    expect(result.value, isNull);
    expect(manager.currentProject, isNull);
  });

  test('openProject returns corruptedFile when the file is not a valid project database', () async {
    final filePath = p.join(tempDir.path, "garbage.ocpt");
    await File(filePath).writeAsBytes(List<int>.generate(32, (i) => i));

    final result = await manager.openProject(filePath: filePath);

    expect(result.status, OcptProjectStatus.corruptedFile);
    expect(manager.currentProject, isNull);
  });

  test(
    'saveCurrentProjectPageFormat writes the format, loadCurrentProjectPageFormat reads it back',
    () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await manager.createProject(name: "My Movie", filePath: filePath);

      final initialFormat = await manager.loadCurrentProjectPageFormat();
      final otherFormat = initialFormat == OcptPageFormat.usLetter
          ? OcptPageFormat.a4
          : OcptPageFormat.usLetter;

      await manager.saveCurrentProjectPageFormat(otherFormat);

      expect(await manager.loadCurrentProjectPageFormat(), otherFormat);
    },
  );

  test('saveCurrentProjectPageFormat is a no-op when no project is open', () async {
    await expectLater(
      manager.saveCurrentProjectPageFormat(OcptPageFormat.a4),
      completes,
    );
    expect(manager.currentProject, isNull);
  });

  test('createProjectVersion captures the open project, listProjectVersions reads it back', () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));

    final created = await manager.createProjectVersion(
      name: "v1 — First read",
      note: "Before the rewrite",
    );

    expect(created?.name, "v1 — First read");
    expect(created?.isBase, isTrue);

    final versions = await manager.listProjectVersions();
    expect(versions.map((version) => version.id), [created?.id]);
    expect(versions.single.note, "Before the rewrite");

    // The manager is what fills in the facts a version records but the service can't know: the
    // replica's device id is minted through the properties manager on the way.
    expect(await propertiesManager.deviceId.load(), isNotEmpty);
  });

  test('deleteProjectVersion removes the version from the open project', () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    final created = await manager.createProjectVersion(name: "v1", note: "");

    await manager.deleteProjectVersion(created!.id);

    expect(await manager.listProjectVersions(), isEmpty);
  });

  test('renameProjectVersion renames a version of the open project', () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    final created = await manager.createProjectVersion(name: "v1", note: "First cut");

    await manager.renameProjectVersion(versionId: created!.id, name: "v1 bis", note: "Renamed");

    final versions = await manager.listProjectVersions();
    expect(versions.single.name, "v1 bis");
    expect(versions.single.note, "Renamed");
  });

  test('captureWorkingCopyState reads the open project, null with none open', () async {
    expect(await manager.captureWorkingCopyState(), isNull);

    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    final version = await manager.createProjectVersion(name: "v1", note: "");

    final clean = await manager.captureWorkingCopyState();
    expect(clean?.baseVersionId, version?.id);
    expect(clean?.isModifiedSinceBase, isFalse);
  });

  test('the version operations are no-ops when no project is open', () async {
    expect(await manager.listProjectVersions(), isEmpty);
    expect(await manager.createProjectVersion(name: "v1", note: ""), isNull);
    await expectLater(manager.deleteProjectVersion("no-such-version"), completes);
    await expectLater(
      manager.renameProjectVersion(versionId: "no-such-version", name: "v1", note: ""),
      completes,
    );
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
}
