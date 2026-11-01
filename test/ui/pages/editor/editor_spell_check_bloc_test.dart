// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_spell_check_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_spell_check_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:spell_kit/spell_kit.dart';

/// The app language every projects manager built here is given, so a created project's own
/// screenplay language never depends on the machine the tests run on.
String _testAppLanguageCode() => "en";

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
///
/// [onPop] lets a test await the exact moment [pop] is called, rather than racing on an unrelated
/// state emitted earlier in the same event handler (the emitted state and the handler's own
/// completion are not ordered with respect to a stream listener in the test).
class _RecordingRouterManager extends OcptRouterManager {
  final _popCompleter = Completer<void>();

  /// Whether [pop] was called.
  bool get popped => _popCompleter.isCompleted;

  /// Completes the moment [pop] is called.
  Future<void> get onPop => _popCompleter.future;

  /// Records the call instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {
    if (!_popCompleter.isCompleted) {
      _popCompleter.complete();
    }
  }
}

/// An export manager that is never asked for anything: the mode bloc needs one, these tests do not
/// export.
class _InertExportManager extends OcptExportManager {
  /// Class constructor
  _InertExportManager() : super(fileSelectorManager: const FileSelectorManager());
}

class _FakeSpellCheckManager extends OcptSpellCheckManager {
  OcptScreenplayLanguage? _loadedLanguage;
  int _generation = 0;

  /// Every [check] call's requested texts, keyed the same way the bloc addresses them (a raw-mode
  /// block index, or a styled-mode node id), in call order.
  final List<Map<Object, String>> checkCalls = [];

  /// Computes [check]'s answer for a request; overridable per test.
  Map<Object, List<SpellRange>> Function(Map<Object, String> requested) answerFor = (requested) => {
    for (final entry in requested.entries) entry.key: [SpellRange(0, entry.value.length)],
  };

  /// When set, [check] awaits this before resolving — a test's way of holding an isolate round
  /// trip open long enough to change something (the language, most plainly) out from under it, to
  /// exercise the "a stale generation's answer is dropped" path.
  Completer<void>? gate;

  @override
  OcptScreenplayLanguage? get loadedLanguage => _loadedLanguage;

  @override
  int get generation => _generation;

  @override
  Future<void> useLanguage(OcptScreenplayLanguage? language) async {
    if (language == _loadedLanguage) {
      return;
    }
    _loadedLanguage = language;
    _generation++;
  }

  @override
  Future<Map<K, List<SpellRange>>> check<K>(Map<K, String> textsByKey) async {
    final requested = <Object, String>{
      for (final entry in textsByKey.entries) entry.key as Object: entry.value,
    };
    checkCalls.add(requested);

    final pendingGate = gate;
    if (pendingGate != null) {
      await pendingGate.future;
    }

    final answer = answerFor(requested);
    return {
      for (final entry in textsByKey.entries)
        if (answer[entry.key as Object] != null) entry.key: answer[entry.key as Object]!,
    };
  }

  /// Every [suggestionsFor] call's requested word, in call order.
  final List<String> suggestionsForCalls = [];

  /// Computes [suggestionsFor]'s answer for a word; overridable per test.
  List<String> Function(String word) suggestionsAnswer = (word) => const [];

  @override
  Future<List<String>> suggestionsFor(String word) async {
    suggestionsForCalls.add(word);
    return suggestionsAnswer(word);
  }

  /// Every [ignoreWords] call's whole replacement set, in call order.
  final List<Set<String>> ignoreWordsCalls = [];

  @override
  void ignoreWords(Set<String> words) {
    ignoreWordsCalls.add(words);
    _generation++;
  }

  /// Every word [ignoreWord] was called with, in call order — this fake's own accumulation,
  /// mirroring the real manager's (`docs/architecture/screenplay.md`), so a test can assert both
  /// that the manager was reached and that the accumulation actually happened.
  final List<String> ignoredWords = [];

  @override
  void ignoreWord(String word) {
    ignoredWords.add(word);
    _generation++;
  }

  /// Every [setLearnedWords] call's whole replacement set, in call order.
  final List<Set<String>> setLearnedWordsCalls = [];

  @override
  void setLearnedWords(Set<String> words) {
    setLearnedWordsCalls.add(words);
    _generation++;
  }
}

/// The fields of both blocs these tests read, each answered by the bloc that owns it.
class _EditorStates {
  /// The mode bloc's state.
  final OcptEditorState mode;

  /// The spell-check bloc's state.
  final OcptEditorSpellCheckState spell;

  /// Class constructor
  const _EditorStates(this.mode, this.spell);

  bool get isLoading => mode.isLoading;
  bool get isPreviewingVersion => mode.isPreviewingVersion;
  bool get isSpellCheckVisible => mode.isSpellCheckVisible;
  OcptScreenplayLanguage? get screenplayLanguage => mode.screenplayLanguage;
  FountainDocument? get document => mode.document;
  OcptPageSetup get pageSetup => mode.pageSetup;
  List<FountainSceneHeading> get scenes => mode.scenes;
  List<SpellRange> get rawSpellCheckRanges => spell.rawSpellCheckRanges;
  Map<String, List<SpellRange>> get styledSpellCheckRanges => spell.styledSpellCheckRanges;
}

/// The mode bloc and the spell-check bloc built together, the way the editor page builds them:
/// an event goes to the bloc that handles it, and a state is read off the bloc that owns it.
class _Editor {
  /// The mode bloc.
  final OcptEditorBloc mode;

  /// The spell-check bloc.
  final OcptEditorSpellCheckBloc spell;

  /// Class constructor
  _Editor(this.mode, this.spell);

  /// Both blocs' current states.
  _EditorStates get state => _EditorStates(mode.state, spell.state);

  /// Both blocs' states, one per emit of either.
  Stream<_EditorStates> get stream => Stream.multi((controller) {
    final subscriptions = [
      mode.stream.listen((_) => controller.add(state)),
      spell.stream.listen((_) => controller.add(state)),
    ];
    controller.onCancel = () {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    };
  }, isBroadcast: true);

  /// Sends [event] to the bloc that handles it.
  void add(BlocEventForMixin event) =>
      event is OcptEditorSpellCheckEvent ? spell.add(event) : mode.add(event);

  /// Answers the styled editor's context menu, see `OcptEditorSpellCheckBloc.spellingSuggestionsFor`.
  Future<List<String>> spellingSuggestionsFor(String word) => spell.spellingSuggestionsFor(word);

  /// Closes both blocs, the spell-check one first as the tree does.
  Future<void> close() async {
    await spell.close();
    await mode.close();
  }
}

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
      appLanguageCode: _testAppLanguageCode,
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
  /// [spellCheckManager] defaults to a fresh [_FakeSpellCheckManager]: every freshly created
  /// project's screenplay language is seeded non-null (see `OcptProjectsManager.createProject`'s
  /// own doc comment) and would otherwise drive a real [OcptSpellCheckManager.useLanguage] on every
  /// test here.
  _Editor buildBloc({OcptRouterManager? routerManager, OcptSpellCheckManager? spellCheckManager}) {
    final manager = spellCheckManager ?? _FakeSpellCheckManager();
    final mode = OcptEditorBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: routerManager ?? _RecordingRouterManager(),
      exportManager: _InertExportManager(),
      parseDebounce: const Duration(milliseconds: 20),
      autosaveDebounce: const Duration(milliseconds: 60),
      statisticsDebounce: const Duration(milliseconds: 30),
    );
    final spell = OcptEditorSpellCheckBloc(
      modeBloc: mode,
      spellCheckManager: manager,
      projectsManager: projectsManager,
    );

    return _Editor(mode, spell);
  }

  /// Waits for [condition] to hold, for an effect that emits no state.
  Future<void> until(bool Function() condition) async {
    for (var attempt = 0; attempt < 500 && !condition(); attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(condition(), isTrue);
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<_EditorStates> waitForState(
    _Editor bloc,
    bool Function(_EditorStates state) predicate,
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
        final manager = _FakeSpellCheckManager();
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
        // The spell-check bloc clears the underlines as it sees the switch move, a microtask after the
        // mode's emit.
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
      final manager = _FakeSpellCheckManager();
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
      final manager = _FakeSpellCheckManager();
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
      final manager = _FakeSpellCheckManager();
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
      final manager = _FakeSpellCheckManager();
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
      final manager = _FakeSpellCheckManager();
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
      final manager = _FakeSpellCheckManager();
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
      final manager = _FakeSpellCheckManager();
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
      final manager = _FakeSpellCheckManager();
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
      final manager = _FakeSpellCheckManager();
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
      final manager = _FakeSpellCheckManager();
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
      final manager = _FakeSpellCheckManager();
      await projectsManager.projectDictionaryService.learnWord(
        database: projectsManager.currentProject!.database,
        word: 'Zorglurbe',
      );

      final bloc = buildBloc(spellCheckManager: manager);
      await waitForState(bloc, (state) => !state.isLoading);
      while (manager.setLearnedWordsCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(manager.setLearnedWordsCalls.last, {'Zorglurbe'});

      await bloc.close();
    });

    test('pushes an empty set when the project has no learned words yet', () async {
      final manager = _FakeSpellCheckManager();

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
        final manager = _FakeSpellCheckManager()..suggestionsAnswer = (word) => ['world'];
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
        final manager = _FakeSpellCheckManager()..suggestionsAnswer = (word) => ['world'];
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
        final manager = _FakeSpellCheckManager()..suggestionsAnswer = (word) => ['world'];
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
        final manager = _FakeSpellCheckManager()..suggestionsAnswer = (word) => ['world'];
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

  group('ignoring and learning words', () {
    test('ignoring a word reaches the manager and re-issues a check over both the raw document and '
        'the last reported styled texts', () async {
      final manager = _FakeSpellCheckManager();
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
      final manager = _FakeSpellCheckManager();
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

      final persisted = await projectsManager.projectDictionaryService.loadWords(
        database: projectsManager.currentProject!.database,
      );
      expect(persisted, contains("Somethign"));
      expect(manager.setLearnedWordsCalls.last, contains("Somethign"));

      final sentTexts = manager.checkCalls.expand((call) => call.values).toSet();
      expect(sentTexts, contains("Somethign is wrong here."));

      await bloc.close();
    });

    test('learning a word with no project open is a no-op', () async {
      final manager = _FakeSpellCheckManager();
      final routerManager = _RecordingRouterManager();
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
        final manager = _FakeSpellCheckManager();
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
      await projectsManager.projectDictionaryService.learnWord(
        database: database,
        word: "Zorglurbe",
      );

      final manager = _FakeSpellCheckManager();
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
      await projectsManager.projectDictionaryService.unlearnWord(
        database: database,
        word: "Zorglurbe",
      );

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
      final manager = _FakeSpellCheckManager();
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
      final manager = _FakeSpellCheckManager()..answerFor = (requested) => {};
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
      await projectsManager.projectDictionaryService.unlearnWord(
        database: project.database,
        word: "blarg",
      );
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
