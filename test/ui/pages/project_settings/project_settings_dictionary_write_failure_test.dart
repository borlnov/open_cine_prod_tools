// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_event.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../ocpt_result_expectations.dart';

/// How long a handler that failed is given to emit anything: it must emit nothing at all.
const _quietPeriod = Duration(milliseconds: 300);

/// What the project settings bloc does when the database refuses a dictionary call: the handler
/// stops where the call failed, nothing is emitted, and nothing after the failing call is written.
void main() {
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_project_settings_dictionary_failure_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();
    await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Run [statement] on the open project's database.
  Future<void> run(String statement) =>
      projectsManager.currentProject!.database.customStatement(statement);

  /// Read the live words of the open project's dictionary.
  Future<List<String>> liveWords() => projectsManager.projectDictionaryService
      .loadWords(database: projectsManager.currentProject!.database)
      .valueOrFail;

  /// Build a bloc and wait for its first load to end, then record every state it emits from there.
  Future<(OcptProjectSettingsBloc, List<OcptProjectSettingsState>)> loadedBloc() async {
    final bloc = OcptProjectSettingsBloc(projectsManager: projectsManager);
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    final emitted = <OcptProjectSettingsState>[];
    final subscription = bloc.stream.listen(emitted.add);
    addTearDown(subscription.cancel);

    return (bloc, emitted);
  }

  test("a refused removal stops the edit: nothing is added and nothing is emitted", () async {
    await projectsManager.projectDictionaryService
        .learnWord(database: projectsManager.currentProject!.database, word: "Marie")
        .okOrFail;
    final (bloc, emitted) = await loadedBloc();
    await run(
      "CREATE TRIGGER refuse_update BEFORE UPDATE ON project_dictionary_words "
      "BEGIN SELECT RAISE(ABORT, 'refused'); END",
    );

    bloc.add(
      const OcptProjectSettingsDictionaryEditedEvent(
        addedWords: ["Zorglurbe"],
        removedWords: ["Marie"],
      ),
    );
    await Future<void>.delayed(_quietPeriod);

    expect(emitted, isEmpty);
    expect(bloc.state.dictionaryWords, ["Marie"]);
    expect(await liveWords(), ["Marie"], reason: "Zorglurbe is never learned after the failure");
  });

  test("a refused word stops the edit before the words that follow it", () async {
    final (bloc, emitted) = await loadedBloc();
    await run(
      "CREATE TRIGGER refuse_bad BEFORE INSERT ON project_dictionary_words "
      "WHEN NEW.word = 'Bad' BEGIN SELECT RAISE(ABORT, 'refused'); END",
    );

    bloc.add(
      const OcptProjectSettingsDictionaryEditedEvent(addedWords: ["Bad", "Good"], removedWords: []),
    );
    await Future<void>.delayed(_quietPeriod);

    expect(emitted, isEmpty);
    expect(await liveWords(), isEmpty);
  });

  test("a word learned before a refused one stays learned, and nothing is re-read", () async {
    final (bloc, emitted) = await loadedBloc();
    await run(
      "CREATE TRIGGER refuse_bad BEFORE INSERT ON project_dictionary_words "
      "WHEN NEW.word = 'Bad' BEGIN SELECT RAISE(ABORT, 'refused'); END",
    );

    bloc.add(
      const OcptProjectSettingsDictionaryEditedEvent(addedWords: ["Good", "Bad"], removedWords: []),
    );
    await Future<void>.delayed(_quietPeriod);

    expect(emitted, isEmpty);
    expect(bloc.state.dictionaryWords, isEmpty);
    expect(await liveWords(), ["Good"]);
  });

  test("a dictionary that cannot be read leaves the page loading", () async {
    await run("ALTER TABLE project_dictionary_words RENAME TO project_dictionary_words_gone");
    final bloc = OcptProjectSettingsBloc(projectsManager: projectsManager);
    addTearDown(bloc.close);

    await Future<void>.delayed(_quietPeriod);

    expect(bloc.state.isLoading, isTrue);
  });
}
