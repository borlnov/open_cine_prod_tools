// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_dictionary_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_spell_check_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../ocpt_result_expectations.dart';
import 'editor_spell_check_bloc_test_doubles.dart';

/// A dictionary service whose read fails while [isReadFailing] is set, and whose writes are the
/// real ones: the one way to have a word learned and then not read back.
class _ReadFailsDictionaryService extends OcptProjectDictionaryService {
  /// Whether [loadWords] answers a failure.
  bool isReadFailing = false;

  /// Class constructor
  _ReadFailsDictionaryService() : super(logger: const SilentLogger(), deviceId: _testDeviceId);

  /// Fail as a refused read does while told to, otherwise read the words as the real service does.
  @override
  Future<OcptDatabaseResult<List<String>>> loadWords({
    required OcptProjectDatabase database,
  }) async {
    if (isReadFailing) {
      return const OcptDatabaseResult(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "dictionary read intentionally failed for the test",
      );
    }

    return super.loadWords(database: database);
  }
}

/// The fixed device id [_ReadFailsDictionaryService] stamps its writes with.
Future<String> _testDeviceId() async => "test-device";

/// What the spell check does when the project's dictionary cannot be written or read, with a real
/// SQLite failure (a trigger that aborts the write, a table that is gone): a failed read is not an
/// empty dictionary, so the manager keeps the words it was given, and a failed write teaches
/// nothing and re-checks nothing.
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_dictionary_failure_test_");
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
    await propertiesManager.spellCheckVisible.store(true);
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Build both blocs on the test project with [manager] as the spell check manager, reading and
  /// writing the dictionary through [dictionaryService] when given.
  Editor buildBloc(
    FakeSpellCheckManager manager, {
    OcptProjectDictionaryService? dictionaryService,
  }) {
    final mode = OcptEditorBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: RecordingRouterManager(),
      exportManager: InertExportManager(),
      parseDebounce: const Duration(milliseconds: 20),
      autosaveDebounce: const Duration(milliseconds: 60),
    );
    final spell = OcptEditorSpellCheckBloc(
      modeBloc: mode,
      spellCheckManager: manager,
      projectsManager: projectsManager,
      projectDictionaryService: dictionaryService,
    );

    return Editor(mode, spell);
  }

  /// Wait until the editor has loaded.
  Future<void> waitLoaded(Editor bloc) async {
    if (bloc.state.isLoading) {
      await bloc.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    }
  }

  /// Give the blocs time to handle whatever was dispatched.
  Future<void> settle() async {
    await pumpEventQueue(times: 200);
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  /// Make the dictionary table unreadable.
  Future<void> loseTheDictionary() => projectsManager.currentProject!.database.customStatement(
    "ALTER TABLE project_dictionary_words RENAME TO project_dictionary_words_gone",
  );

  test("a word the database refuses to learn is neither pushed nor re-checked", () async {
    final manager = FakeSpellCheckManager();
    final bloc = buildBloc(manager);
    await waitLoaded(bloc);
    while (manager.setLearnedWordsCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await projectsManager.currentProject!.database.customStatement(
      "CREATE TRIGGER refuse_insert_words BEFORE INSERT ON project_dictionary_words "
      "BEGIN SELECT RAISE(ABORT, 'refused'); END",
    );
    manager.setLearnedWordsCalls.clear();
    manager.checkCalls.clear();

    bloc.add(const OcptEditorWordLearnedEvent(word: "Somethign"));
    await settle();

    expect(manager.setLearnedWordsCalls, isEmpty);
    expect(manager.checkCalls, isEmpty);
    expect(
      await projectsManager.projectDictionaryService
          .loadWords(database: projectsManager.currentProject!.database)
          .valueOrFail,
      isEmpty,
    );

    await bloc.close();
  });

  test("a dictionary that cannot be read again is not pushed as an empty one", () async {
    await projectsManager.projectDictionaryService
        .learnWord(database: projectsManager.currentProject!.database, word: "Zorglurbe")
        .okOrFail;
    final manager = FakeSpellCheckManager();
    final bloc = buildBloc(manager);
    await waitLoaded(bloc);
    while (manager.setLearnedWordsCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(manager.setLearnedWordsCalls.last, contains("Zorglurbe"));
    await loseTheDictionary();
    manager.setLearnedWordsCalls.clear();
    manager.checkCalls.clear();

    bloc.add(const OcptEditorSpellCheckDictionaryRefreshRequestedEvent());
    await settle();

    expect(manager.setLearnedWordsCalls, isEmpty);
    expect(manager.checkCalls, isEmpty);

    await bloc.close();
  });

  test("a word learned and then not read back is kept but not pushed as an empty set", () async {
    final dictionary = _ReadFailsDictionaryService();
    final manager = FakeSpellCheckManager();
    final bloc = buildBloc(manager, dictionaryService: dictionary);
    await waitLoaded(bloc);
    while (manager.setLearnedWordsCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    dictionary.isReadFailing = true;
    manager.setLearnedWordsCalls.clear();
    manager.checkCalls.clear();

    bloc.add(const OcptEditorWordLearnedEvent(word: "Somethign"));
    await settle();

    expect(manager.setLearnedWordsCalls, isEmpty);
    expect(manager.checkCalls, isEmpty);
    dictionary.isReadFailing = false;
    expect(
      await dictionary.loadWords(database: projectsManager.currentProject!.database).valueOrFail,
      ["Somethign"],
      reason: "the write itself landed",
    );

    await bloc.close();
  });

  test("a dictionary that cannot be read on load pushes nothing and loads no language", () async {
    await loseTheDictionary();
    final manager = FakeSpellCheckManager();

    final bloc = buildBloc(manager);
    await waitLoaded(bloc);
    await settle();

    expect(manager.setLearnedWordsCalls, isEmpty);
    expect(manager.loadedLanguage, isNull);

    await bloc.close();
  });
}
