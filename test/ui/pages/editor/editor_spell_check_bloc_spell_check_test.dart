// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
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

/// Run the tests of the editor spell check bloc spell check.
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

  group('spell check', () {
    test('defaults to spell check visible when nothing was ever persisted', () async {
      await propertiesManager.spellCheckVisible.delete();

      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.isSpellCheckVisible, isTrue);

      await bloc.close();
    });

    test('loads the persisted spell check visibility flag on entry', () async {
      await propertiesManager.spellCheckVisible.store(false);

      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.isSpellCheckVisible, isFalse);

      await bloc.close();
    });

    test("loads the project's screenplay language on entry", () async {
      await propertiesManager.spellCheckVisible.store(true);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.fr);

      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.screenplayLanguage, OcptScreenplayLanguage.fr);

      await bloc.close();
    });

    test(
      'toggling spell check flips it, persists the new value, and clears the raw ranges at once',
      () async {
        final manager = FakeSpellCheckManager();
        await propertiesManager.spellCheckVisible.store(true);
        await propertiesManager.editorMode.store(OcptEditorMode.raw);
        await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

        final bloc = buildBloc(spellCheckManager: manager);
        await waitForState(bloc, (state) => !state.isLoading);

        bloc.add(
          const OcptEditorTextChangedEvent(text: "INT. HOUSE - DAY\n\nSomethign is wrong here.\n"),
        );
        final checkedState = await waitForState(
          bloc,
          (state) => state.rawSpellCheckRanges.isNotEmpty,
        );
        expect(checkedState.rawSpellCheckRanges, isNotEmpty);

        bloc.add(const OcptEditorSpellCheckToggledEvent());
        // The spell-check bloc clears the underlines as it sees the switch move, a microtask after
        // the mode's emit.
        final disabledState = await waitForState(
          bloc,
          (state) => !state.isSpellCheckVisible && state.rawSpellCheckRanges.isEmpty,
        );
        expect(disabledState.isSpellCheckVisible, isFalse);
        expect(disabledState.rawSpellCheckRanges, isEmpty);
        expect(await propertiesManager.spellCheckVisible.load(), isFalse);

        bloc.add(const OcptEditorSpellCheckToggledEvent());
        final enabledState = await waitForState(bloc, (state) => state.isSpellCheckVisible);
        expect(enabledState.isSpellCheckVisible, isTrue);
        expect(await propertiesManager.spellCheckVisible.load(), isTrue);

        await bloc.close();
      },
    );

    test('a scene heading, a character cue, a transition and a lyrics line produce no range, an '
        'action line and a dialogue line do', () async {
      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.raw);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);

      const text =
          "INT. HOUSE - DAY\n\n"
          "She walks across the room slowly.\n\n"
          "MARIE\n"
          "Bonjour tout le monde.\n\n"
          "CUT TO:\n\n"
          "~La la la la\n";
      bloc.add(const OcptEditorTextChangedEvent(text: text));

      final state = await waitForState(bloc, (state) => state.rawSpellCheckRanges.isNotEmpty);

      // Only the action line and the dialogue line were ever sent to the manager for checking —
      // never the scene heading, the character cue, the transition or the lyrics line.
      final sentTexts = manager.checkCalls.expand((call) => call.values).toSet();
      expect(sentTexts, {"She walks across the room slowly.", "Bonjour tout le monde."});

      // And the reported ranges land exactly on those two blocks (the fake's default answer
      // marks a requested text entirely misspelled).
      const actionText = "She walks across the room slowly.";
      const dialogueText = "Bonjour tout le monde.";
      final actionStart = text.indexOf(actionText);
      final dialogueStart = text.indexOf(dialogueText);
      expect(
        state.rawSpellCheckRanges,
        unorderedEquals([
          SpellRange(actionStart, actionStart + actionText.length),
          SpellRange(dialogueStart, dialogueStart + dialogueText.length),
        ]),
      );

      await bloc.close();
    });

    test('only changed texts are sent to the manager between two ticks', () async {
      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.raw);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);
      // The load itself already runs an (empty, nothing to check yet) pass on its own, async tail
      // — wait for it to actually have happened before clearing, rather than racing it: only what
      // the two ticks below send is under test.
      while (manager.checkCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      manager.checkCalls.clear();

      const firstText =
          "INT. HOUSE - DAY\n\n"
          "First paragraph here.\n\n"
          "Second paragraph here.\n";
      bloc.add(const OcptEditorTextChangedEvent(text: firstText));
      await waitForState(bloc, (state) => state.rawSpellCheckRanges.isNotEmpty);

      expect(manager.checkCalls, hasLength(1));
      expect(manager.checkCalls.single.values.toSet(), {
        "First paragraph here.",
        "Second paragraph here.",
      });

      manager.checkCalls.clear();

      const secondText =
          "INT. HOUSE - DAY\n\n"
          "First paragraph here.\n\n"
          "Second paragraph changed.\n";
      bloc.add(const OcptEditorTextChangedEvent(text: secondText));
      await waitForState(bloc, (state) => state.document?.sourceText == secondText);

      expect(manager.checkCalls, hasLength(1));
      // Only the second, changed, paragraph was resent; the first, unchanged, was skipped.
      expect(manager.checkCalls.single.values.toSet(), {"Second paragraph changed."});

      await bloc.close();
    });

    test('nothing is checked while both switches are off', () async {
      final manager = FakeSpellCheckManager();
      await projectsManager.saveCurrentProjectScreenplayLanguage(null);
      await propertiesManager.spellCheckVisible.store(false);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptEditorTextChangedEvent(text: "INT. HOUSE - DAY\n\nSomethign is wrong here.\n"),
      );
      await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      // Nothing more will ever be emitted for this text (no check request is even sent), so give
      // any pending async work one microtask to prove that, rather than asserting on an emission
      // that will never come.
      await Future<void>.delayed(Duration.zero);

      expect(manager.checkCalls, isEmpty);
      expect(bloc.state.rawSpellCheckRanges, isEmpty);

      await bloc.close();
      // Restores the shared properties manager's value: every other test in this group expects
      // spell-check visible by default, and this is the only one in the file that turns it off.
      await propertiesManager.spellCheckVisible.store(true);
    });

    test('nothing is checked while a project version is being previewed', () async {
      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.raw);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);
      final project = projectsManager.currentProject!;
      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: "INT. HOUSE - DAY\n\nSomethign is wrong here.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );
      final version = await projectsManager.createProjectVersion(name: "v1", note: "");
      expect(version, isNotNull);

      final bloc = buildBloc(spellCheckManager: manager);
      // Confirm checking happens normally outside of a preview first.
      await waitForState(bloc, (state) => state.rawSpellCheckRanges.isNotEmpty);
      manager.checkCalls.clear();

      bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: version!.id));
      // The underlines go in the spell-check bloc's own reaction to the load, a microtask after the
      // mode's emit that starts the preview.
      final previewState = await waitForState(
        bloc,
        (state) => state.isPreviewingVersion && state.rawSpellCheckRanges.isEmpty,
      );
      expect(previewState.rawSpellCheckRanges, isEmpty);

      // Give any pending async work a chance to run: no check request is sent at all while
      // previewing, so there's no state to wait for here either.
      await Future<void>.delayed(Duration.zero);
      expect(manager.checkCalls, isEmpty);

      await bloc.close();
    });

    test("a stale generation's answer is dropped", () async {
      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.raw);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);

      manager.gate = Completer<void>();
      bloc.add(
        const OcptEditorTextChangedEvent(text: "INT. HOUSE - DAY\n\nSomethign is wrong here.\n"),
      );
      await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      expect(manager.checkCalls, isNotEmpty);

      // The dictionary changes while the check is still in flight: the manager's generation moves
      // on before the answer comes back.
      await manager.useLanguage(OcptScreenplayLanguage.fr);
      manager.gate!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.rawSpellCheckRanges, isEmpty);

      await bloc.close();
    });
  });

  group('styled spell check', () {
    test('only changed node texts are sent to the manager, keyed by node id', () async {
      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.styled);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);
      // The load's own learned-words push (a real database read) is still settling in the
      // background right after `isLoading` flips — wait for it, so its own generation bump can't
      // land in the middle of the check this test is about to issue and drop its answer as stale.
      while (manager.setLearnedWordsCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      // Unlike the raw pass, nothing here ever fires on its own: the styled bloc event only ever
      // comes from the styled editor's own controller, which this test never mounts.
      expect(manager.checkCalls, isEmpty);

      bloc.add(
        const OcptEditorStyledSpellCheckTextsReportedEvent(
          textsByNodeId: {"node-1": "First paragraph here.", "node-2": "Second paragraph here."},
        ),
      );
      final state = await waitForState(bloc, (state) => state.styledSpellCheckRanges.isNotEmpty);

      expect(manager.checkCalls, hasLength(1));
      expect(manager.checkCalls.single.values.toSet(), {
        "First paragraph here.",
        "Second paragraph here.",
      });
      expect(state.styledSpellCheckRanges.keys, unorderedEquals(["node-1", "node-2"]));

      manager.checkCalls.clear();

      bloc.add(
        const OcptEditorStyledSpellCheckTextsReportedEvent(
          textsByNodeId: {"node-1": "First paragraph here.", "node-2": "Second paragraph changed."},
        ),
      );
      while (manager.checkCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(manager.checkCalls, hasLength(1));
      // Only the second, changed, node was resent; the first, unchanged, was skipped.
      expect(manager.checkCalls.single.values.toSet(), {"Second paragraph changed."});

      await bloc.close();
    });

    test('nothing is sent while spell-checking is off', () async {
      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(false);
      await propertiesManager.editorMode.store(OcptEditorMode.styled);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptEditorStyledSpellCheckTextsReportedEvent(
          textsByNodeId: {"node-1": "Somethign is wrong here."},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(manager.checkCalls, isEmpty);
      expect(bloc.state.styledSpellCheckRanges, isEmpty);

      await bloc.close();
      // Restores the shared properties manager's value: every other test in this file expects
      // spell-check visible by default.
      await propertiesManager.spellCheckVisible.store(true);
    });

    test('nothing is sent while the screenplay has no language', () async {
      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.styled);
      await projectsManager.saveCurrentProjectScreenplayLanguage(null);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptEditorStyledSpellCheckTextsReportedEvent(
          textsByNodeId: {"node-1": "Somethign is wrong here."},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(manager.checkCalls, isEmpty);
      expect(bloc.state.styledSpellCheckRanges, isEmpty);

      await bloc.close();
    });

    test('nothing is sent under a read-only preview', () async {
      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.styled);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);
      final project = projectsManager.currentProject!;
      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: "INT. HOUSE - DAY\n\nSomethign is wrong here.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );
      final version = await projectsManager.createProjectVersion(name: "v1", note: "");
      expect(version, isNotNull);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: version!.id));
      // The underlines go in the spell-check bloc's own reaction to the load, a microtask after the
      // mode's emit that starts the preview.
      final previewState = await waitForState(
        bloc,
        (state) => state.isPreviewingVersion && state.rawSpellCheckRanges.isEmpty,
      );
      expect(previewState.styledSpellCheckRanges, isEmpty);

      bloc.add(
        const OcptEditorStyledSpellCheckTextsReportedEvent(
          textsByNodeId: {"node-1": "Somethign is wrong here."},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(manager.checkCalls, isEmpty);

      await bloc.close();
    });

    test("a stale generation's answer is dropped", () async {
      final manager = FakeSpellCheckManager();
      await propertiesManager.spellCheckVisible.store(true);
      await propertiesManager.editorMode.store(OcptEditorMode.styled);
      await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);

      manager.gate = Completer<void>();
      bloc.add(
        const OcptEditorStyledSpellCheckTextsReportedEvent(
          textsByNodeId: {"node-1": "Somethign is wrong here."},
        ),
      );
      while (manager.checkCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      // The dictionary changes while the check is still in flight: the manager's generation moves
      // on before the answer comes back.
      await manager.useLanguage(OcptScreenplayLanguage.fr);
      manager.gate!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.styledSpellCheckRanges, isEmpty);

      await bloc.close();
    });
  });

  group('learned words on load', () {
    test("pushes the open project's already-learned words into the manager on load", () async {
      final manager = FakeSpellCheckManager();
      await projectsManager.projectDictionaryService
          .learnWord(database: projectsManager.currentProject!.database, word: 'Zorglurbe')
          .okOrFail;

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);
      while (manager.setLearnedWordsCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(manager.setLearnedWordsCalls.last, {'Zorglurbe'});

      await bloc.close();
    });

    test('pushes an empty set when the project has no learned words yet', () async {
      final manager = FakeSpellCheckManager();

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);
      while (manager.setLearnedWordsCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(manager.setLearnedWordsCalls.last, isEmpty);

      await bloc.close();
    });
  });

  group('spellingSuggestionsFor', () {
    test(
      'forwards to the manager when both switches are on and nothing is being previewed',
      () async {
        final manager = FakeSpellCheckManager()..suggestionsAnswer = (word) => ['world'];
        await propertiesManager.spellCheckVisible.store(true);
        await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

        final bloc = buildBloc(spellCheckManager: manager);
        await waitForState(bloc, (state) => !state.isLoading);

        final suggestions = await bloc.spellingSuggestionsFor('wrold');

        expect(suggestions, ['world']);
        expect(manager.suggestionsForCalls, ['wrold']);

        await bloc.close();
      },
    );

    test(
      'returns nothing, with no manager call at all, while isSpellCheckVisible is off',
      () async {
        final manager = FakeSpellCheckManager()..suggestionsAnswer = (word) => ['world'];
        await propertiesManager.spellCheckVisible.store(false);
        await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);

        final bloc = buildBloc(spellCheckManager: manager);
        await waitForState(bloc, (state) => !state.isLoading);

        expect(await bloc.spellingSuggestionsFor('wrold'), isEmpty);
        expect(manager.suggestionsForCalls, isEmpty);

        await bloc.close();
        // Restores the shared properties manager's value: every other test in this file expects
        // spell-check visible by default.
        await propertiesManager.spellCheckVisible.store(true);
      },
    );

    test(
      'returns nothing, with no manager call at all, while the screenplay has no language',
      () async {
        final manager = FakeSpellCheckManager()..suggestionsAnswer = (word) => ['world'];
        await propertiesManager.spellCheckVisible.store(true);
        await projectsManager.saveCurrentProjectScreenplayLanguage(null);

        final bloc = buildBloc(spellCheckManager: manager);
        await waitForState(bloc, (state) => !state.isLoading);

        expect(await bloc.spellingSuggestionsFor('wrold'), isEmpty);
        expect(manager.suggestionsForCalls, isEmpty);

        await bloc.close();
      },
    );

    test(
      'returns nothing, with no manager call at all, while a version is being previewed',
      () async {
        final manager = FakeSpellCheckManager()..suggestionsAnswer = (word) => ['world'];
        await propertiesManager.spellCheckVisible.store(true);
        await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb);
        final project = projectsManager.currentProject!;
        await projectsManager.screenplayService.saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: "Some text.\n",
          snapshotReason: OcptSnapshotReason.manual,
        );
        final version = await projectsManager.createProjectVersion(name: "v1", note: "");
        expect(version, isNotNull);

        final bloc = buildBloc(spellCheckManager: manager);
        await waitForState(bloc, (state) => !state.isLoading);

        bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: version!.id));
        await waitForState(bloc, (state) => state.isPreviewingVersion);

        expect(await bloc.spellingSuggestionsFor('wrold'), isEmpty);
        expect(manager.suggestionsForCalls, isEmpty);

        await bloc.close();
      },
    );
  });
}
