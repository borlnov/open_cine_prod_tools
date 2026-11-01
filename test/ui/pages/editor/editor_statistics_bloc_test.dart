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
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_statistics_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_statistics_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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

/// An export manager that is never asked for anything: these tests do not export.
class _InertExportManager extends OcptExportManager {
  /// Class constructor
  _InertExportManager() : super(fileSelectorManager: const FileSelectorManager());
}

/// The fields of both blocs these tests read, each answered by the bloc that owns it.
class _EditorStates {
  /// The mode bloc's state.
  final OcptEditorState mode;

  /// The statistics bloc's state.
  final OcptEditorStatisticsState counters;

  /// Class constructor
  const _EditorStates(this.mode, this.counters);

  bool get isLoading => mode.isLoading;
  OcptPageSetup get pageSetup => mode.pageSetup;
  FountainDocument? get document => mode.document;
  int? get currentSceneIndex => mode.currentSceneIndex;
  List<FountainSceneHeading> get scenes => mode.scenes;
  FountainScriptStatistics get statistics => counters.statistics;
  FountainSceneStatistics? get sceneStatistics => counters.sceneStatistics;
}

/// The mode bloc and the statistics bloc built together, the way the editor page builds them: an
/// event goes to the bloc that handles it, and a state is read off the bloc that owns it.
class _Editor {
  /// The mode bloc.
  final OcptEditorBloc mode;

  /// The statistics bloc.
  final OcptEditorStatisticsBloc counters;

  /// Class constructor
  _Editor(this.mode, this.counters);

  /// Both blocs' current states.
  _EditorStates get state => _EditorStates(mode.state, counters.state);

  /// Both blocs' states, one per emit of either.
  Stream<_EditorStates> get stream => Stream.multi((controller) {
    final subscriptions = [
      mode.stream.listen((_) => controller.add(state)),
      counters.stream.listen((_) => controller.add(state)),
    ];
    controller.onCancel = () {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    };
  }, isBroadcast: true);

  /// Sends [event] to the bloc that handles it.
  void add(BlocEventForMixin event) =>
      event is OcptEditorStatisticsEvent ? counters.add(event) : mode.add(event);

  /// Closes both blocs, the statistics one first as the tree does.
  Future<void> close() async {
    await counters.close();
    await mode.close();
  }
}

void main() {
  const editedText = "INT. HOUSE - DAY\n\nAction.\n";
  // Scene headings start at line 0 and line 4; the two scenes are deliberately given different
  // word counts (6 and 7) so a test can tell "the first scene's stats" and "the second scene's
  // stats" apart just by comparing counts.
  const twoSceneText =
      "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two here.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's save error paths)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_bloc_test_");
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
  _Editor buildBloc() {
    final mode = OcptEditorBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _RecordingRouterManager(),
      exportManager: _InertExportManager(),
      parseDebounce: const Duration(milliseconds: 20),
      autosaveDebounce: const Duration(milliseconds: 60),
    );
    final counters = OcptEditorStatisticsBloc(
      modeBloc: mode,
      statisticsDebounce: const Duration(milliseconds: 30),
    );

    return _Editor(mode, counters);
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

  test(
    'statistics are populated from the screenplay already on disk once the load completes',
    () async {
      final project = projectsManager.currentProject!;
      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: editedText,
        snapshotReason: OcptSnapshotReason.manual,
      );

      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final state = await waitForState(bloc, (state) => state.statistics.sceneCount != 0);

      expect(state.statistics.sceneCount, 1);
      expect(state.statistics.pageCount, 1);
      expect(state.statistics.wordCount, greaterThan(0));

      await bloc.close();
    },
  );

  test('statistics recompute, on their own debounce, once the parsed document changes', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.statistics, FountainScriptStatistics.empty);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    // The document already reflects the edit, but the statistics debounce hasn't elapsed yet.
    expect(bloc.state.statistics, FountainScriptStatistics.empty);

    final state = await waitForState(bloc, (state) => state.statistics.sceneCount == 1);
    expect(state.statistics.pageCount, 1);
    expect(state.statistics.wordCount, greaterThan(0));

    await bloc.close();
  });

  test(
    'sceneStatistics is recomputed on the parse debounce, for the scene under the caret',
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      expect(bloc.state.sceneStatistics, isNull);

      bloc.add(const OcptEditorTextChangedEvent(text: twoSceneText));
      // The scene's counters follow the mode's parsed document by a turn of the event loop: they
      // piggyback on the same parse tick, not a separate, earlier one.
      final parsedState = await waitForState(
        bloc,
        (state) => state.scenes.length == 2 && state.sceneStatistics != null,
      );
      expect(parsedState.sceneStatistics, isNotNull);
      expect(parsedState.sceneStatistics!.wordCount, greaterThan(0));

      await bloc.close();
    },
  );

  test(
    'sceneStatistics is recomputed immediately when the caret crosses into a different scene',
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: twoSceneText));
      await waitForState(bloc, (state) => state.scenes.length == 2);
      final firstSceneWords = bloc.state.sceneStatistics!.wordCount;

      bloc.add(const OcptEditorCaretMovedEvent(line: 6));
      final secondSceneState = await waitForState(
        bloc,
        (state) =>
            state.currentSceneIndex == 1 && state.sceneStatistics!.wordCount != firstSceneWords,
      );
      // "EXT. GARDEN - NIGHT" (4) + "Action two here." (3).
      expect(secondSceneState.sceneStatistics!.wordCount, 4 + 3);

      await bloc.close();
    },
  );

  test('sceneStatistics goes back to null once the caret moves back before every scene', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: "\n\n$twoSceneText"));
    await waitForState(bloc, (state) => state.scenes.length == 2);
    // The caret (still on line 0) precedes the first heading, now pushed to line 2.
    expect(bloc.state.sceneStatistics, isNull);

    bloc.add(const OcptEditorCaretMovedEvent(line: 2));
    final withinFirstScene = await waitForState(bloc, (state) => state.sceneStatistics != null);
    expect(withinFirstScene.currentSceneIndex, 0);

    bloc.add(const OcptEditorCaretMovedEvent(line: 0));
    final beforeEveryScene = await waitForState(bloc, (state) => state.sceneStatistics == null);
    expect(beforeEveryScene.currentSceneIndex, isNull);

    await bloc.close();
  });

  test('changing the page setup recomputes statistics for the new format immediately', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.statistics.sceneCount == 1);

    const newSetup = OcptPageSetup(
      format: OcptPageFormat.a4,
      margins: FountainPageMargins(
        leftInches: 2,
        rightInches: 0.5,
        topInches: 0.75,
        bottomInches: 0.75,
      ),
    );
    bloc.add(const OcptEditorPageSetupChangedEvent(pageSetup: newSetup));

    final state = await waitForState(bloc, (state) => state.pageSetup == newSetup);
    expect(state.statistics, FountainScriptStatistics.of(state.document!, newSetup.toMetrics()));

    await bloc.close();
  });

  test('the project settings changed event re-reads the page format and repaginates', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    final otherFormat = bloc.state.pageSetup.format == OcptPageFormat.usLetter
        ? OcptPageFormat.a4
        : OcptPageFormat.usLetter;
    // Written directly through the manager, the way the project settings page itself writes it
    // — this bloc never sees the new value on an event, only the fact that something changed.
    await projectsManager.saveCurrentProjectPageFormat(otherFormat);

    bloc.add(const OcptEditorProjectSettingsChangedEvent());
    final state = await waitForState(bloc, (state) => state.pageSetup.format == otherFormat);

    expect(
      state.statistics,
      FountainScriptStatistics.of(state.document!, state.pageSetup.toMetrics()),
    );

    await bloc.close();
  });

  test('starts empty, and stays so while nothing is parsed', () async {
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.statistics, FountainScriptStatistics.empty);
    expect(state.sceneStatistics, isNull);

    await bloc.close();
  });

  test('an imported text recomputes the counters at once, not after the typing debounce', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    await bloc.mode.addAndWait(const OcptEditorImportedTextAppliedEvent(text: editedText));
    final state = await waitForState(bloc, (state) => state.statistics.sceneCount != 0);

    expect(state.statistics.sceneCount, 1);
    expect(state.statistics.pageCount, 1);

    await bloc.close();
  });

  group('the bloc as a view of the mode', () {
    /// Names every event of the hierarchy by an exhaustive switch, so an event added to it does not
    /// compile until this list, and the test below, know it.
    String nameOf(OcptEditorStatisticsEvent event) => switch (event) {
      OcptEditorStatisticsRecomputeRequestedEvent() => "recompute",
      OcptEditorStatisticsSceneRefreshRequestedEvent() => "scene refresh",
    };

    test('every event of its hierarchy has a handler', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      await bloc.mode.addAndWait(const OcptEditorImportedTextAppliedEvent(text: twoSceneText));
      await waitForState(bloc, (state) => state.statistics.sceneCount == 2);

      const events = <OcptEditorStatisticsEvent>[
        OcptEditorStatisticsRecomputeRequestedEvent(),
        OcptEditorStatisticsSceneRefreshRequestedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(2), reason: "one event per name");

      // An event nobody handles is ignored silently, so each is proven by its effect. The bloc
      // dispatches both to itself when the mode's state moves: the caret crossing into the second
      // scene brings that scene's counters, and typing brings the script-wide ones after the
      // debounce, which is the only way the scene count can fall back to one.
      final firstSceneWords = bloc.state.sceneStatistics!.wordCount;
      bloc.add(const OcptEditorCaretMovedEvent(line: 4));
      await waitForState(
        bloc,
        (state) =>
            state.currentSceneIndex == 1 && state.sceneStatistics!.wordCount != firstSceneWords,
      );

      bloc.add(const OcptEditorTextChangedEvent(text: editedText));
      await waitForState(bloc, (state) => state.statistics.sceneCount == 1);

      // And the two are also accepted when sent directly.
      bloc
        ..add(events[0])
        ..add(events[1]);

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
