// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_spell_check_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:spell_kit/spell_kit.dart';
import '../../../ocpt_result_expectations.dart';
import 'editor_spell_check_bloc_test_doubles.dart';

/// Run the tests of the editor spell check bloc words and settings.
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_spell_check_bloc_test_");
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

  /// Builds both blocs wired to the test project, with debounces short enough to await in a test.
  ///
  /// [spellCheckManager] defaults to a fresh [FakeSpellCheckManager]: every freshly created
  /// project's screenplay language is seeded non-null (see `OcptProjectsManager.createProject`'s
  /// own doc comment) and would otherwise drive a real [OcptSpellCheckManager.useLanguage] on every
  /// test here.
  Editor buildBloc({OcptRouterManager? routerManager, OcptSpellCheckManager? spellCheckManager}) {
    final manager = spellCheckManager ?? FakeSpellCheckManager();
    final mode = OcptEditorBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: routerManager ?? RecordingRouterManager(),
      exportManager: InertExportManager(),
      parseDebounce: const Duration(milliseconds: 20),
      autosaveDebounce: const Duration(milliseconds: 60),
    );
    final spell = OcptEditorSpellCheckBloc(
      modeBloc: mode,
      spellCheckManager: manager,
      projectsManager: projectsManager,
    );

    return Editor(mode, spell);
  }

  /// Waits for [condition] to hold, for an effect that emits no state.
  Future<void> until(bool Function() condition) async {
    for (var attempt = 0; attempt < 500 && !condition(); attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(condition(), isTrue);
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<EditorStates> waitForState(
    Editor bloc,
    bool Function(EditorStates state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  group('ignoring and learning words', () {
    test('ignoring a word reaches the manager and re-issues a check over both the raw document and '
        'the last reported styled texts', () async {
      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.raw);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);
      while (manager.setLearnedWordsCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      bloc.add(
        const OcptEditorTextChangedEvent(text: "INT. HOUSE - DAY\n\nSomethign is wrong here.\n"),
      );
      await waitForState(bloc, (state) => state.rawSpellCheckRanges.isNotEmpty);

      bloc.add(
        const OcptEditorStyledSpellCheckTextsReportedEvent(
          textsByNodeId: {"node-1": "Somethign is wrong here."},
        ),
      );
      await waitForState(bloc, (state) => state.styledSpellCheckRanges.isNotEmpty);

      manager.checkCalls.clear();

      bloc.add(const OcptEditorWordIgnoredEvent(word: "Somethign"));
      while (manager.checkCalls.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(manager.ignoredWords, ["Somethign"]);
      // Neither the raw block nor the styled node was skipped as "unchanged" — the manager's own
      // generation bump (from ignoreWord) is what forces both caches to treat everything as
      // needing a fresh answer even though no text actually changed.
      final sentTexts = manager.checkCalls.expand((call) => call.values).toSet();
      expect(sentTexts, contains("Somethign is wrong here."));

      await bloc.close();
    });

    test("learning a word reaches the service and the manager, and re-issues a check over both the "
        "raw document and the last reported styled texts", () async {
      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.raw);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);
      while (manager.setLearnedWordsCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      bloc.add(
        const OcptEditorTextChangedEvent(text: "INT. HOUSE - DAY\n\nSomethign is wrong here.\n"),
      );
      await waitForState(bloc, (state) => state.rawSpellCheckRanges.isNotEmpty);

      bloc.add(
        const OcptEditorStyledSpellCheckTextsReportedEvent(
          textsByNodeId: {"node-1": "Somethign is wrong here."},
        ),
      );
      await waitForState(bloc, (state) => state.styledSpellCheckRanges.isNotEmpty);

      manager.checkCalls.clear();
      manager.setLearnedWordsCalls.clear();

      bloc.add(const OcptEditorWordLearnedEvent(word: "Somethign"));
      while (manager.setLearnedWordsCalls.isEmpty || manager.checkCalls.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }

      final persisted = await projectsManager.projectDictionaryService
          .loadWords(database: projectsManager.currentProject!.database)
          .valueOrFail;
      expect(persisted, contains("Somethign"));
      expect(manager.setLearnedWordsCalls.last, contains("Somethign"));

      final sentTexts = manager.checkCalls.expand((call) => call.values).toSet();
      expect(sentTexts, contains("Somethign is wrong here."));

      await bloc.close();
    });

    test('learning a word with no project open is a no-op', () async {
      final manager = FakeSpellCheckManager();
      final routerManager = RecordingRouterManager();
      final bloc = buildBloc(routerManager: routerManager, spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorBackRequestedEvent());
      await routerManager.onPop.timeout(const Duration(seconds: 5));
      expect(projectsManager.currentProject, isNull);

      manager.setLearnedWordsCalls.clear();
      bloc.add(const OcptEditorWordLearnedEvent(word: "anything"));
      await Future<void>.delayed(Duration.zero);

      expect(manager.setLearnedWordsCalls, isEmpty);

      await bloc.close();
    });

    test(
      'both ignoring and learning a word are refused while a version is being previewed',
      () async {
        final manager = FakeSpellCheckManager();
        await propertiesManager.spellCheckVisible.store(true);
        await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);
        final project = projectsManager.currentProject!;
        await projectsManager.screenplayService
            .saveScreenplayText(
              database: project.database,
              screenplayId: project.primaryScreenplayId,
              fountainText: "Some text.\n",
              snapshotReason: OcptSnapshotReason.manual,
            )
            .okOrFail;
        final version = await projectsManager
            .createProjectVersion(name: "v1", note: "")
            .maybeValueOrFail;
        expect(version, isNotNull);

        final bloc = buildBloc(spellCheckManager: manager);
        await waitForState(bloc, (state) => !state.isLoading);
        while (manager.setLearnedWordsCalls.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }

        bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: version!.id));
        await waitForState(bloc, (state) => state.isPreviewingVersion);
        // Entering a preview reloads from the previewed version's own database, which pushes that
        // version's own learned words too (correctly) — wait for that second, legitimate push to
        // land before clearing below, so it can't be mistaken for the ignore/learn events this test
        // is actually about.
        while (manager.setLearnedWordsCalls.length < 2) {
          await Future<void>.delayed(Duration.zero);
        }

        manager.ignoredWords.clear();
        manager.setLearnedWordsCalls.clear();

        bloc.add(const OcptEditorWordIgnoredEvent(word: "anything"));
        bloc.add(const OcptEditorWordLearnedEvent(word: "anything"));
        await Future<void>.delayed(Duration.zero);

        expect(manager.ignoredWords, isEmpty);
        expect(manager.setLearnedWordsCalls, isEmpty);

        await bloc.close();
      },
    );
  });

  group('the project settings changed event and the dictionary', () {
    test("un-learning a word directly through the service, then reporting the project settings "
        "changed event, pushes the new set into the manager and re-checks the text again — the "
        "round trip's whole point: a word removed in the settings page's dictionary dialog is "
        "underlined again on the next check pass, with nothing re-typed", () async {
      final database = projectsManager.currentProject!.database;
      await projectsManager.projectDictionaryService
          .learnWord(database: database, word: "Zorglurbe")
          .okOrFail;

      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.raw);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);
      while (manager.setLearnedWordsCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(manager.setLearnedWordsCalls.last, contains("Zorglurbe"));

      bloc.add(const OcptEditorTextChangedEvent(text: "INT. HOUSE - DAY\n\nZorglurbe is here.\n"));
      await waitForState(bloc, (state) => state.rawSpellCheckRanges.isNotEmpty);

      manager.checkCalls.clear();
      manager.setLearnedWordsCalls.clear();

      // The dictionary dialog itself never runs in this bloc; the project settings page
      // applies its report directly through the service, exactly as reproduced here — this
      // bloc only ever learns about it through the settings-changed event below.
      await projectsManager.projectDictionaryService
          .unlearnWord(database: database, word: "Zorglurbe")
          .okOrFail;

      bloc
        ..add(const OcptEditorProjectSettingsChangedEvent())
        ..add(const OcptEditorSpellCheckDictionaryRefreshRequestedEvent());
      while (manager.setLearnedWordsCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(manager.setLearnedWordsCalls.last, isNot(contains("Zorglurbe")));
      expect(manager.checkCalls, isNotEmpty);
      final sentTexts = manager.checkCalls.expand((call) => call.values).toSet();
      expect(sentTexts, contains("Zorglurbe is here."));

      await bloc.close();
    });

    test("the project settings changed event pushes nothing into the manager when the dictionary "
        "was not touched", () async {
      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.raw);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);
      while (manager.setLearnedWordsCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      manager.checkCalls.clear();
      manager.setLearnedWordsCalls.clear();

      // A real settings-page change that has nothing to do with the dictionary — the page
      // format, which this same handler does act on. Waiting for the state it emits for that is
      // what makes the assertions below mean something: without it, an assertion made one
      // microtask after the dispatch would pass just as happily against a handler that pushes
      // unconditionally, having simply not reached its dictionary read yet.
      final otherFormat = bloc.state.pageSetup.format == OcptPageFormat.usLetter
          ? OcptPageFormat.a4
          : OcptPageFormat.usLetter;
      await projectsManager.saveCurrentProjectPageFormat(otherFormat);

      bloc
        ..add(const OcptEditorProjectSettingsChangedEvent())
        ..add(const OcptEditorSpellCheckDictionaryRefreshRequestedEvent());
      await waitForState(bloc, (state) => state.pageSetup.format == otherFormat);
      // The dictionary read is the last thing that handler does, one await past the state just
      // waited for: let those remaining microtasks drain before reading the manager's calls.
      for (var turn = 0; turn < 10; turn++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(manager.setLearnedWordsCalls, isEmpty);
      expect(manager.checkCalls, isEmpty);

      await bloc.close();
    });
  });

  group('the bloc as a view of the mode', () {
    /// Names every event of the hierarchy by an exhaustive switch, so an event added to it does not
    /// compile until this list, and the test below, know it.
    String nameOf(OcptEditorSpellCheckEvent event) => switch (event) {
      OcptEditorSpellCheckRangesReportedEvent() => "raw ranges",
      OcptEditorStyledSpellCheckTextsReportedEvent() => "styled texts",
      OcptEditorStyledSpellCheckRangesReportedEvent() => "styled ranges",
      OcptEditorWordIgnoredEvent() => "ignored",
      OcptEditorWordLearnedEvent() => "learned",
      OcptEditorSpellCheckSettingsChangedEvent() => "settings",
      OcptEditorSpellCheckDictionaryRefreshRequestedEvent() => "dictionary",
    };

    test('every event of its hierarchy has a handler', () async {
      final manager = FakeSpellCheckManager()..answerFor = (requested) => {};
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.raw);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);
      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);
      bloc.add(const OcptEditorTextChangedEvent(text: "INT. HOUSE - DAY\n\nAction.\n"));
      final document = (await waitForState(
        bloc,
        (state) => state.document?.blocks.isNotEmpty ?? false,
      )).document!;

      final events = <OcptEditorSpellCheckEvent>[
        OcptEditorSpellCheckRangesReportedEvent(
          generation: manager.generation,
          checkedText: document.sourceText,
          ranges: const [SpellRange(0, 3)],
        ),
        const OcptEditorStyledSpellCheckTextsReportedEvent(textsByNodeId: {"node": "Wrongg"}),
        OcptEditorStyledSpellCheckRangesReportedEvent(
          generation: manager.generation,
          ranges: const {
            "other": [SpellRange(1, 2)],
          },
        ),
        const OcptEditorWordIgnoredEvent(word: "zorp"),
        const OcptEditorWordLearnedEvent(word: "blarg"),
        const OcptEditorSpellCheckSettingsChangedEvent(),
        const OcptEditorSpellCheckDictionaryRefreshRequestedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(7), reason: "one event per name");

      // An event nobody handles is ignored silently, so each is proven by its effect.
      bloc.add(events[0]);
      await waitForState(
        bloc,
        (state) => state.rawSpellCheckRanges.contains(const SpellRange(0, 3)),
      );

      manager.answerFor = (requested) => {
        for (final entry in requested.entries) entry.key: [SpellRange(0, entry.value.length)],
      };
      bloc.add(events[1]);
      await waitForState(bloc, (state) => state.styledSpellCheckRanges.containsKey("node"));

      bloc.add(events[2]);
      await waitForState(bloc, (state) => state.styledSpellCheckRanges.containsKey("other"));

      bloc.add(events[3]);
      await until(() => manager.ignoredWords.contains("zorp"));

      bloc.add(events[4]);
      await until(() => manager.setLearnedWordsCalls.any((w) => w.contains("blarg")));

      final callsBefore = manager.checkCalls.length;
      bloc.add(events[5]);
      await until(() => manager.checkCalls.length > callsBefore);

      final project = projectsManager.currentProject!;
      await projectsManager.projectDictionaryService
          .unlearnWord(database: project.database, word: "blarg")
          .okOrFail;
      final pushesBefore = manager.setLearnedWordsCalls.length;
      bloc.add(events[6]);
      await until(() => manager.setLearnedWordsCalls.length > pushesBefore);

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
