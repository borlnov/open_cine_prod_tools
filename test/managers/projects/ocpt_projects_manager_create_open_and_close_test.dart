// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../ocpt_result_expectations.dart';

/// Run the tests of the projects manager create open and close.
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

  test('createProject creates the project file, seeds it, and makes it current', () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");

    final result = await manager.createProject(name: "My Movie", filePath: filePath);

    expect(result.status, OcptProjectStatus.ok);
    expect(result.value?.name, "My Movie");
    expect(File(filePath).existsSync(), isTrue);
    expect(manager.currentProject?.path, filePath);
    expect(manager.currentProject?.name, "My Movie");

    final screenplayText = await manager.screenplayService
        .loadScreenplayText(
          database: manager.currentProject!.database,
          screenplayId: manager.currentProject!.primaryScreenplayId,
        )
        .valueOrFail;
    expect(screenplayText, "");

    final recents = await propertiesManager.recentProjects.load();
    expect(recents?.first.path, filePath);
    expect(recents?.first.name, "My Movie");
    // A fresh project holds exactly one episode — no need to read it back.
    expect(recents?.first.episodeCount, 1);
  });

  test(
    "createProject stamps project_info.migratedByAppVersion with the manager's own app version",
    () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await manager.createProject(name: "My Movie", filePath: filePath);

      final info = await manager.currentProject!.database
          .select(manager.currentProject!.database.ocptProjectInfoTable)
          .getSingle();

      // Under `flutter test` no `--dart-define=APP_VERSION=...` is passed, so this is the
      // manager's own local/dev fallback — see `OcptProjectsManager._appVersion`.
      expect(info.migratedByAppVersion, "0.3.1");
      expect(info.appVersionAtCreation, info.migratedByAppVersion);
    },
  );

  test('createProject while a project is already open closes the previous one first', () async {
    await manager.createProject(name: "First", filePath: p.join(tempDir.path, "first.ocpt"));

    final result = await manager.createProject(
      name: "Second",
      filePath: p.join(tempDir.path, "second.ocpt"),
    );

    expect(result.status, OcptProjectStatus.ok);
    expect(manager.currentProject?.name, "Second");
  });

  group("createProject never overwrites an existing file", () {
    test("returns fileAlreadyExists and leaves the file's own bytes untouched", () async {
      final filePath = p.join(tempDir.path, "existing.ocpt");
      await File(filePath).writeAsString("not a project");

      final result = await manager.createProject(name: "My Movie", filePath: filePath);

      expect(result.status, OcptProjectStatus.fileAlreadyExists);
      expect(result.status.isSuccess, isFalse);
      expect(await File(filePath).readAsString(), "not a project");
      expect(manager.currentProject, isNull);
    });

    test("leaves a currently open project open rather than closing it first", () async {
      await manager.createProject(name: "First", filePath: p.join(tempDir.path, "first.ocpt"));

      final blockedPath = p.join(tempDir.path, "blocked.ocpt");
      await File(blockedPath).writeAsString("not a project");

      final result = await manager.createProject(name: "Second", filePath: blockedPath);

      expect(result.status, OcptProjectStatus.fileAlreadyExists);
      expect(manager.currentProject?.name, "First");
    });
  });

  test('openProject opens a previously created project and makes it current', () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");
    await manager.createProject(name: "My Movie", filePath: filePath);
    await manager.closeCurrentProject().okOrFail;

    final result = await manager.openProject(filePath: filePath);

    expect(result.status, OcptProjectStatus.ok);
    expect(manager.currentProject?.name, "My Movie");
    expect(manager.currentProject?.path, filePath);

    final recents = await propertiesManager.recentProjects.load();
    expect(recents?.first.path, filePath);
  });

  test("openProject records the project's own live episode count, not a stale one", () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");
    await manager.createProject(name: "My Movie", filePath: filePath);
    await manager.screenplayService
        .createEpisode(database: manager.currentProject!.database)
        .maybeValueOrFail;
    await manager.closeCurrentProject().okOrFail;

    // Tamper with what's stored, so the assertion below can only pass if openProject reads the
    // file's own episodes afresh rather than trusting whatever the list already says.
    final recents = await propertiesManager.recentProjects.load();
    await propertiesManager.recentProjects.store([recents!.first.copyWith(episodeCount: 99)]);

    await manager.openProject(filePath: filePath);

    final updated = await propertiesManager.recentProjects.load();
    expect(updated?.first.episodeCount, 2);
  });

  test('closeCurrentProject clears the current project and is a no-op when none is open', () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));

    await manager.closeCurrentProject().okOrFail;
    expect(manager.currentProject, isNull);

    // Closing again must not throw.
    await manager.closeCurrentProject().okOrFail;
    expect(manager.currentProject, isNull);
  });

  test('closeCurrentProject records the episode count the project ended with, not the one it '
      'opened with', () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");
    await manager.createProject(name: "My Movie", filePath: filePath);

    await manager.screenplayService
        .createEpisode(database: manager.currentProject!.database)
        .maybeValueOrFail;
    await manager.closeCurrentProject().okOrFail;

    final recents = await propertiesManager.recentProjects.load();
    expect(recents?.first.episodeCount, 2);
  });

  test('recordCurrentProjectEpisodeCount writes the live count without closing the project, and is '
      'a no-op when none is open', () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");
    await manager.createProject(name: "My Movie", filePath: filePath);

    await manager.screenplayService
        .createEpisode(database: manager.currentProject!.database)
        .maybeValueOrFail;
    await manager.recordCurrentProjectEpisodeCount().okOrFail;

    // What an app quit from inside the project would leave behind: the project is still open,
    // and the recent-projects entry already knows about the second episode.
    expect(manager.currentProject, isNotNull);
    final recents = await propertiesManager.recentProjects.load();
    expect(recents?.first.episodeCount, 2);

    await manager.closeCurrentProject().okOrFail;

    // Calling it with no project open must not throw, nor touch what's stored.
    await manager.recordCurrentProjectEpisodeCount().okOrFail;
    final unchanged = await propertiesManager.recentProjects.load();
    expect(unchanged?.first.episodeCount, 2);
  });

  test("recordCurrentProjectEpisodeCount mid-preview records the working copy's episode count, "
      "never the previewed version's", () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");
    await manager.createProject(name: "My Movie", filePath: filePath);
    final version = await manager.createProjectVersion(name: "v1", note: "").maybeValueOrFail;

    // The working copy grows a second episode after the version was captured.
    await manager.screenplayService
        .createEpisode(database: manager.currentProject!.database)
        .maybeValueOrFail;

    await manager.previewVersion(version!.id).maybeValueOrFail;
    await manager.recordCurrentProjectEpisodeCount().okOrFail;

    final recents = await propertiesManager.recentProjects.load();
    expect(recents?.first.episodeCount, 2);
  });

  test("closeCurrentProject mid-preview records the working copy's episode count, never the "
      "previewed version's", () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");
    await manager.createProject(name: "My Movie", filePath: filePath);
    final version = await manager.createProjectVersion(name: "v1", note: "").maybeValueOrFail;

    // The working copy grows a second episode after the version was captured.
    await manager.screenplayService
        .createEpisode(database: manager.currentProject!.database)
        .maybeValueOrFail;

    await manager.previewVersion(version!.id).maybeValueOrFail;
    expect(manager.currentProject!.isReadOnly, isTrue);

    await manager.closeCurrentProject().okOrFail;

    final recents = await propertiesManager.recentProjects.load();
    // The previewed version only ever held one episode; the working copy — read through
    // fileDatabase, never the in-memory database the preview reads through — held two by the
    // time it closed.
    expect(recents?.first.episodeCount, 2);
  });

  test('currentProjectStream emits every time the current project changes', () async {
    // expectLater/emitsInOrder subscribes right away and awaits each expected event in turn,
    // which avoids racing the stream's (deferred) event delivery against the actions below.
    final expectation = expectLater(
      manager.currentProjectStream.map((project) => project?.name),
      emitsInOrder(<Object?>["My Movie", null]),
    );

    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    await manager.closeCurrentProject().okOrFail;

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

      final initialFormat = await manager.loadCurrentProjectPageFormat().maybeValueOrFail;
      final otherFormat = initialFormat == OcptPageFormat.usLetter
          ? OcptPageFormat.a4
          : OcptPageFormat.usLetter;

      await manager.saveCurrentProjectPageFormat(otherFormat).okOrFail;

      expect(await manager.loadCurrentProjectPageFormat().maybeValueOrFail, otherFormat);
    },
  );

  test('saveCurrentProjectPageFormat is a no-op when no project is open', () async {
    await expectLater(manager.saveCurrentProjectPageFormat(OcptPageFormat.a4).okOrFail, completes);
    expect(manager.currentProject, isNull);
  });

  test(
    'saveCurrentProjectCurrencyCode writes the code, loadCurrentProjectCurrencyCode reads it back',
    () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await manager.createProject(name: "My Movie", filePath: filePath);

      final initialCode = await manager.loadCurrentProjectCurrencyCode().maybeValueOrFail;
      final otherCode = initialCode == "USD" ? "GBP" : "USD";

      await manager.saveCurrentProjectCurrencyCode(otherCode).okOrFail;

      expect(await manager.loadCurrentProjectCurrencyCode().maybeValueOrFail, otherCode);
    },
  );

  test('saveCurrentProjectCurrencyCode is a no-op when no project is open', () async {
    await expectLater(manager.saveCurrentProjectCurrencyCode("USD").okOrFail, completes);
    expect(manager.currentProject, isNull);
  });

  test('loadCurrentProjectCurrencyCode returns null when no project is open', () async {
    expect(await manager.loadCurrentProjectCurrencyCode().maybeValueOrFail, isNull);
  });

  test('saveCurrentProjectMinimumRestMinutes writes the minutes, '
      'loadCurrentProjectMinimumRestMinutes reads them back', () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");
    await manager.createProject(name: "My Movie", filePath: filePath);

    // Nobody has recorded a minimum yet — not "no minimum required".
    expect(await manager.loadCurrentProjectMinimumRestMinutes().maybeValueOrFail, isNull);

    await manager.saveCurrentProjectMinimumRestMinutes(660).okOrFail;

    expect(await manager.loadCurrentProjectMinimumRestMinutes().maybeValueOrFail, 660);
  });

  test('saveCurrentProjectMinimumRestMinutes can clear a minimum already recorded', () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    await manager.saveCurrentProjectMinimumRestMinutes(660).okOrFail;

    await manager.saveCurrentProjectMinimumRestMinutes(null).okOrFail;

    expect(await manager.loadCurrentProjectMinimumRestMinutes().maybeValueOrFail, isNull);
  });

  test('saveCurrentProjectMinimumRestMinutes is a no-op when no project is open', () async {
    await expectLater(manager.saveCurrentProjectMinimumRestMinutes(660).okOrFail, completes);
    expect(manager.currentProject, isNull);
  });

  test('loadCurrentProjectMinimumRestMinutes returns null when no project is open', () async {
    expect(await manager.loadCurrentProjectMinimumRestMinutes().maybeValueOrFail, isNull);
  });

  test("createProject seeds the screenplay language from the app's own language", () async {
    final frenchManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "fr",
    );
    await frenchManager.initLifeCycle();
    addTearDown(frenchManager.disposeLifeCycle);

    await frenchManager.createProject(
      name: "Mon Film",
      filePath: p.join(tempDir.path, "mon_film.ocpt"),
    );

    expect(
      await frenchManager.loadCurrentProjectScreenplayLanguage().maybeValueOrFail,
      OcptScreenplayLanguage.fr,
    );
  });

  test('createProject leaves the screenplay language unset when no dictionary matches', () async {
    final germanManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "de",
    );
    await germanManager.initLifeCycle();
    addTearDown(germanManager.disposeLifeCycle);

    await germanManager.createProject(
      name: "Mein Film",
      filePath: p.join(tempDir.path, "mein_film.ocpt"),
    );

    // No dictionary is bundled for German, so nothing is guessed: no language means no
    // spell-check underlines, rather than every word underlined against the wrong one.
    expect(await germanManager.loadCurrentProjectScreenplayLanguage().maybeValueOrFail, isNull);
  });

  test('saveCurrentProjectScreenplayLanguage writes the language, '
      'loadCurrentProjectScreenplayLanguage reads it back', () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");
    await manager.createProject(name: "My Movie", filePath: filePath);

    final initialLanguage = await manager.loadCurrentProjectScreenplayLanguage().maybeValueOrFail;
    final otherLanguage = initialLanguage == OcptScreenplayLanguage.fr
        ? OcptScreenplayLanguage.enGb
        : OcptScreenplayLanguage.fr;

    await manager.saveCurrentProjectScreenplayLanguage(otherLanguage).okOrFail;

    expect(await manager.loadCurrentProjectScreenplayLanguage().maybeValueOrFail, otherLanguage);
  });

  test('saveCurrentProjectScreenplayLanguage can clear a language already recorded', () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    await manager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.fr).okOrFail;

    await manager.saveCurrentProjectScreenplayLanguage(null).okOrFail;

    expect(await manager.loadCurrentProjectScreenplayLanguage().maybeValueOrFail, isNull);
  });

  test('saveCurrentProjectScreenplayLanguage is a no-op when no project is open', () async {
    await expectLater(
      manager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.fr).okOrFail,
      completes,
    );
    expect(manager.currentProject, isNull);
  });

  test('loadCurrentProjectScreenplayLanguage returns null when no project is open', () async {
    expect(await manager.loadCurrentProjectScreenplayLanguage().maybeValueOrFail, isNull);
  });

  test(
    'createProjectVersion captures the open project, listProjectVersions reads it back',
    () async {
      await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));

      final created = await manager
          .createProjectVersion(name: "v1 — First read", note: "Before the rewrite")
          .maybeValueOrFail;

      expect(created?.name, "v1 — First read");
      expect(created?.isBase, isTrue);

      final versions = await manager.listProjectVersions().valueOrFail;
      expect(versions.map((version) => version.id), [created?.id]);
      expect(versions.single.note, "Before the rewrite");

      // The manager is what fills in the facts a version records but the service can't know: the
      // replica's device id is minted through the properties manager on the way.
      expect(await propertiesManager.deviceId.load(), isNotEmpty);
    },
  );

  test('deleteProjectVersion removes the version from the open project', () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    final created = await manager.createProjectVersion(name: "v1", note: "").maybeValueOrFail;

    await manager.deleteProjectVersion(created!.id).okOrFail;

    expect(await manager.listProjectVersions().valueOrFail, isEmpty);
  });

  test('renameProjectVersion renames a version of the open project', () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    final created = await manager
        .createProjectVersion(name: "v1", note: "First cut")
        .maybeValueOrFail;

    await manager
        .renameProjectVersion(versionId: created!.id, name: "v1 bis", note: "Renamed")
        .okOrFail;

    final versions = await manager.listProjectVersions().valueOrFail;
    expect(versions.single.name, "v1 bis");
    expect(versions.single.note, "Renamed");
  });

  test('captureWorkingCopyState reads the open project, null with none open', () async {
    expect(await manager.captureWorkingCopyState().maybeValueOrFail, isNull);

    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    final version = await manager.createProjectVersion(name: "v1", note: "").maybeValueOrFail;

    final clean = await manager.captureWorkingCopyState().valueOrFail;
    expect(clean.baseVersionId, version?.id);
    expect(clean.isModifiedSinceBase, isFalse);
  });

  test('the version operations are no-ops when no project is open', () async {
    expect(await manager.listProjectVersions().valueOrFail, isEmpty);
    expect(await manager.createProjectVersion(name: "v1", note: "").maybeValueOrFail, isNull);
    await expectLater(manager.deleteProjectVersion("no-such-version").okOrFail, completes);
    await expectLater(
      manager.renameProjectVersion(versionId: "no-such-version", name: "v1", note: "").okOrFail,
      completes,
    );
  });
}
