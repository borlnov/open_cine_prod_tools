// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  final _popCompleter = Completer<void>();

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

/// A shot list service whose [createShot] always fails, to exercise the bloc's write error path.
class _FailingShotListService extends OcptShotListService {
  /// Class constructor
  const _FailingShotListService();

  @override
  Future<String> createShot({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String sceneId,
  }) async => throw StateError("shot creation intentionally failed for the test");
}

/// A shot coverage service whose [addRange] always fails, to exercise the bloc's coverage write
/// error path.
class _FailingShotCoverageService extends OcptShotCoverageService {
  /// Class constructor
  const _FailingShotCoverageService();

  @override
  Future<String> addRange({
    required OcptProjectDatabase database,
    required String shotId,
    required String sceneId,
    required int startOffset,
    required int endOffset,
    required String sceneText,
  }) async => throw StateError("coverage write intentionally failed for the test");
}

void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";
  const dialogueText = "INT. HOUSE - DAY\n\nAction one.\n\nLÉA\nHello there.\n\n"
      "EXT. GARDEN - NIGHT\n\nAction two.\n";
  const twoCharactersText = "INT. HOUSE - DAY\n\nAction one.\n\nLÉA\nHello there.\n\n"
      "MARC\nHello back.\n";
  const oneCharacterLeftText = "INT. HOUSE - DAY\n\nAction one.\n\nMARC\nHello back.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's write error path)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    // The in-memory preference store outlives a single test, so every test that reads a
    // preference back seeds the ones it cares about rather than assuming a pristine store.
    await propertiesManager.shotListVisibleColumns.store(
      OcptShotListColumn.defaultVisibleColumns,
    );
    await propertiesManager.shotListLeftDockFraction.store(
      OcptWorkspaceDock.leftDefaultFraction,
    );
    await propertiesManager.shotListRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );
    await propertiesManager.shotListLastRightDockTab.store(OcptShotListRightDockTab.inspector);

    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_bloc_test_");
    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager);
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

  /// Writes [text] as the project's screenplay, which reconciles its scene index and therefore
  /// gives the shot list its sequences.
  Future<void> writeScreenplay(String text) async {
    final project = projectsManager.currentProject!;

    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: text,
      snapshotReason: OcptSnapshotReason.manual,
    );
  }

  /// Builds a bloc wired to the test project. [fieldEditDebounce] defaults to a short duration so
  /// tests exercising the field-edit debounce don't have to wait out the real 2 s one.
  OcptShotListBloc buildBloc({
    OcptRouterManager? routerManager,
    OcptShotListService? shotListService,
    OcptShotCoverageService? shotCoverageService,
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
  }) => OcptShotListBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
    shotListService: shotListService,
    shotCoverageService: shotCoverageService,
    fieldEditDebounce: fieldEditDebounce,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptShotListState> waitForState(
    OcptShotListBloc bloc,
    bool Function(OcptShotListState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Dispatches the two word clicks that draw a scenario coverage range across every word of
  /// [block] on shot [shotId] (first word opens the anchor, last word closes it), waiting for the
  /// anchor to land after the first click and for the range to land after the second.
  Future<void> drawCoverageRange(
    OcptShotListBloc bloc, {
    required String shotId,
    required OcptShotCoverageBlock block,
  }) async {
    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: block.words.first.startOffset,
        wordEndOffset: block.words.first.endOffset,
      ),
    );
    await waitForState(bloc, (state) => state.pendingCoverageAnchor != null);

    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: block.words.last.startOffset,
        wordEndOffset: block.words.last.endOffset,
      ),
    );
    await waitForState(
      bloc,
      (state) => state.snapshot!.shotsById[shotId]!.coverageRanges.isNotEmpty,
    );
  }

  test('loads the screenplay scenes as sequences and selects the first one', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.title, "My Movie");
    expect(state.sequences, hasLength(2));
    expect((state.sequences.first as OcptSceneShotSequence).heading, "INT. HOUSE - DAY");
    expect(state.selectedSequenceId, state.sequences.first.id);
    expect(state.selectedShotId, isNull);
    expect(state.totalShotCount, 0);

    await bloc.close();
  });

  test('a screenplay with no scene leaves every selection empty', () async {
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.sequences, isEmpty);
    expect(state.selectedSequenceId, isNull);
    expect(state.selectedShot, isNull);

    await bloc.close();
  });

  test('creating a shot appends it to the selected sequence and selects it', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final state = await waitForState(bloc, (state) => state.totalShotCount == 1);

    final shot = state.selectedShot;
    expect(shot, isNotNull);
    expect(state.sequences.first.shots.single.id, shot!.id);
    expect(state.sequences.last.shots, isEmpty);
    // The first scene has no explicit `#N#`, so its display number is its 1-based index.
    expect(shot.code, "1/1");
    // Selecting a shot opens the right dock on its inspector.
    expect(state.rightDockTab, OcptShotListRightDockTab.inspector);

    await bloc.close();
  });

  test('shot codes follow the sequence a shot is created in', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    var state = await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: state.sequences.last.id));
    await waitForState(bloc, (state) => state.selectedSequenceId == state.sequences.last.id);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    expect(state.selectedShot!.code, "2/1");

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.totalShotCount == 2);
    expect(state.selectedShot!.code, "2/2");
    expect(state.sequences.last.shots, hasLength(2));

    await bloc.close();
  });

  test('a failing shot creation raises the transient write error', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(shotListService: const _FailingShotListService());
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(bloc, (state) => state.hasWriteError);

    bloc.add(const OcptShotListWriteErrorDismissedEvent());
    final dismissedState = await waitForState(bloc, (state) => !state.hasWriteError);
    expect(dismissedState.totalShotCount, 0);

    await bloc.close();
  });

  test('selecting another sequence clears the selected shot, reselecting it keeps it', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    var state = await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.selectedShotId != null);
    final shotId = state.selectedShotId;

    bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: state.sequences.last.id));
    state = await waitForState(bloc, (state) => state.selectedShotId == null);
    expect(state.selectedSequenceId, state.sequences.last.id);

    bloc.add(OcptShotListShotSelectedEvent(shotId: shotId!));
    state = await waitForState(bloc, (state) => state.selectedShotId != null);
    // Selecting a shot brings its own sequence back with it.
    expect(state.selectedSequenceId, state.sequences.first.id);

    // Reselecting the sequence already selected leaves the shot alone.
    bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: state.sequences.first.id));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.selectedShotId, shotId);

    await bloc.close();
  });

  test('selecting a shot that no longer exists changes nothing', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotSelectedEvent(shotId: "not-a-shot"));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.selectedShotId, isNull);
    expect(bloc.state.selectedSequenceId, state.sequences.first.id);
    expect(bloc.state.rightDockTab, isNull);

    await bloc.close();
  });

  test('the right dock toggles closed, then reopens on the last tab selected', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.rightDockTab, isNull);

    bloc.add(
      const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.metadata),
    );
    await waitForState(bloc, (state) => state.rightDockTab == OcptShotListRightDockTab.metadata);

    // Selecting the active tab again closes the dock, but still remembers it.
    bloc.add(
      const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.metadata),
    );
    await waitForState(bloc, (state) => state.rightDockTab == null);
    expect(bloc.state.lastRightDockTab, OcptShotListRightDockTab.metadata);

    bloc.add(const OcptShotListRightDockToggledEvent());
    await waitForState(bloc, (state) => state.rightDockTab != null);
    expect(bloc.state.rightDockTab, OcptShotListRightDockTab.metadata);

    bloc.add(const OcptShotListRightDockClosedEvent());
    await waitForState(bloc, (state) => state.rightDockTab == null);

    await bloc.close();
  });

  test('the last right dock tab is persisted and restored on the next entry', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(
      const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.metadata),
    );
    await waitForState(bloc, (state) => state.rightDockTab == OcptShotListRightDockTab.metadata);
    await bloc.close();

    final reopenedBloc = buildBloc();
    final state = await waitForState(reopenedBloc, (state) => !state.isLoading);

    // The dock itself starts closed on every entry; only which tab it reopens on is remembered.
    expect(state.rightDockTab, isNull);
    expect(state.lastRightDockTab, OcptShotListRightDockTab.metadata);

    await reopenedBloc.close();
  });

  test('toggling a column persists the visible set, and it is restored on the next entry',
      () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.visibleColumns, OcptShotListColumn.defaultVisibleColumns);

    bloc.add(const OcptShotListColumnToggledEvent(column: OcptShotListColumn.lens));
    await waitForState(bloc, (state) => state.visibleColumns.contains(OcptShotListColumn.lens));

    bloc.add(const OcptShotListColumnToggledEvent(column: OcptShotListColumn.status));
    await waitForState(bloc, (state) => !state.visibleColumns.contains(OcptShotListColumn.status));
    await bloc.close();

    final reopenedBloc = buildBloc();
    final state = await waitForState(reopenedBloc, (state) => !state.isLoading);

    expect(state.visibleColumns, contains(OcptShotListColumn.lens));
    expect(state.visibleColumns, isNot(contains(OcptShotListColumn.status)));
    expect(state.visibleColumns, contains(OcptShotListColumn.duration));

    await reopenedBloc.close();
  });

  test('hiding every optional column is restored as such, not as the defaults', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    for (final column in Set<OcptShotListColumn>.of(bloc.state.visibleColumns)) {
      bloc.add(OcptShotListColumnToggledEvent(column: column));
    }
    await waitForState(bloc, (state) => state.visibleColumns.isEmpty);
    await bloc.close();

    final reopenedBloc = buildBloc();
    final state = await waitForState(reopenedBloc, (state) => !state.isLoading);
    expect(state.visibleColumns, isEmpty);

    await reopenedBloc.close();
  });

  test('dock fractions are persisted per drag and restored on the next entry', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListDockFractionsChangedEvent(left: 0.3));
    await waitForState(bloc, (state) => state.leftDockFraction == 0.3);
    // The other side is left exactly where it was.
    expect(bloc.state.rightDockFraction, OcptWorkspaceDock.rightDefaultFraction);

    bloc.add(const OcptShotListDockFractionsChangedEvent(right: 0.5));
    await waitForState(bloc, (state) => state.rightDockFraction == 0.5);
    await bloc.close();

    final reopenedBloc = buildBloc();
    var state = await waitForState(reopenedBloc, (state) => !state.isLoading);
    expect(state.leftDockFraction, 0.3);
    expect(state.rightDockFraction, 0.5);

    reopenedBloc.add(const OcptShotListDockLayoutResetEvent());
    state = await waitForState(
      reopenedBloc,
      (state) => state.leftDockFraction == OcptWorkspaceDock.leftDefaultFraction,
    );
    expect(state.rightDockFraction, OcptWorkspaceDock.rightDefaultFraction);

    await reopenedBloc.close();
  });

  test('the sequence panel toggles', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.isSequencePanelVisible, isTrue);

    bloc.add(const OcptShotListSequencePanelToggledEvent());
    await waitForState(bloc, (state) => !state.isSequencePanelVisible);

    await bloc.close();
  });

  test('going back closes the current project and pops', () async {
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(routerManager: routerManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListBackRequestedEvent());
    await routerManager.onPop.timeout(const Duration(seconds: 5));

    expect(projectsManager.currentProject, isNull);

    await bloc.close();
  });

  test('loads the screenplay speaking characters and the field suggestion lists', () async {
    await writeScreenplay(dialogueText);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.speakingCharacters, ["LÉA"]);
    expect(state.suggestions.shotSizes, isEmpty);
    expect(state.suggestions.sounds, isEmpty);

    await bloc.close();
  });

  test('a typed field edit is visible as a pending value and writes once after the debounce',
      () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "W",
      ),
    );
    var state = await waitForState(
      bloc,
      (state) => state.pendingFieldEdits[(shotId, OcptShotListEditableField.shotSize)] == "W",
    );
    // Not written yet: still the field's default empty value.
    expect(state.selectedShot!.shotSize, isEmpty);

    // A second keystroke before the debounce elapses restarts it rather than firing twice: only
    // the last value typed is ever written.
    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Wide",
      ),
    );
    state = await waitForState(
      bloc,
      (state) => state.pendingFieldEdits[(shotId, OcptShotListEditableField.shotSize)] == "Wide",
    );
    expect(state.selectedShot!.shotSize, isEmpty);

    state = await waitForState(bloc, (state) => state.selectedShot!.shotSize == "Wide");
    expect(state.pendingFieldEdits, isEmpty);

    await bloc.close();
  });

  test('selecting another shot flushes a pending field edit immediately', () async {
    await writeScreenplay(twoSceneText);

    // A debounce long enough that the assertions below could only pass through the flush the
    // selection change performs, never through the debounce elapsing on its own.
    final bloc = buildBloc(fieldEditDebounce: const Duration(seconds: 5));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final firstShotId = state.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: firstShotId,
        field: OcptShotListEditableField.notes,
        rawValue: "Handheld",
      ),
    );
    await waitForState(
      bloc,
      (state) =>
          state.pendingFieldEdits[(firstShotId, OcptShotListEditableField.notes)] == "Handheld",
    );

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.totalShotCount == 2);

    expect(state.pendingFieldEdits, isEmpty);
    expect(state.snapshot!.shotsById[firstShotId]!.notes, "Handheld");

    await bloc.close();
  });

  test('flushPendingFieldEdits writes a pending edit directly, without touching state', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(fieldEditDebounce: const Duration(seconds: 5));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.sound,
        rawValue: "Wind noise",
      ),
    );
    await waitForState(
      bloc,
      (state) => state.pendingFieldEdits[(shotId, OcptShotListEditableField.sound)] == "Wind noise",
    );

    await bloc.flushPendingFieldEdits();

    // This flush never touches the bloc's own state...
    expect(bloc.state.pendingFieldEdits, isNotEmpty);
    // ...but the database already has the write.
    final reloaded = await projectsManager.shotListService.loadShotList(
      database: projectsManager.currentProject!.database,
      screenplayId: projectsManager.currentProject!.primaryScreenplayId,
    );
    expect(reloaded.shotsById[shotId]!.sound, "Wind noise");

    await bloc.close();
  });

  test('a difficulty axis and a character toggle each write immediately', () async {
    await writeScreenplay(dialogueText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    bloc.add(
      OcptShotListShotDifficultyChangedEvent(
        shotId: shotId,
        axis: OcptShotDifficultyAxis.sound,
        value: 4,
      ),
    );
    state = await waitForState(bloc, (state) => state.selectedShot!.difficultySound == 4);

    bloc.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, characterName: "LÉA"));
    state = await waitForState(bloc, (state) => state.selectedShot!.characters.contains("LÉA"));

    bloc.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, characterName: "LÉA"));
    state = await waitForState(bloc, (state) => state.selectedShot!.characters.isEmpty);

    await bloc.close();
  });

  /// Attaches [characterNames] to a freshly created shot of the first sequence, then closes the
  /// bloc that did it, and returns the new shot's derived code.
  ///
  /// The deleted-character tests all need the same starting point: a shot carrying characters the
  /// screenplay is then edited to no longer speak. The bloc reads the screenplay's speaking
  /// characters once, on entry, so a fresh bloc is what sees the edited screenplay — which is also
  /// what happens in the app, where the shot list mode is mounted anew every time it is switched
  /// to.
  Future<String> createShotWithCharacters(List<String> characterNames) async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    for (final characterName in characterNames) {
      bloc.add(
        OcptShotListShotCharacterToggledEvent(shotId: shotId, characterName: characterName),
      );
      state = await waitForState(
        bloc,
        (state) => state.selectedShot!.characters.contains(characterName),
      );
    }

    final code = state.selectedShot!.code;
    await bloc.close();

    return code;
  }

  test('a character the screenplay dropped is reported, then removable everywhere', () async {
    await writeScreenplay(twoCharactersText);
    final shotCode = await createShotWithCharacters(["LÉA", "MARC"]);

    await writeScreenplay(oneCharacterLeftText);

    final bloc = buildBloc();
    var state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.removedCharacterAlerts, hasLength(1));
    expect(state.removedCharacterAlerts.single.characterName, "LÉA");
    expect(state.removedCharacterAlerts.single.shotCodes, [shotCode]);

    bloc.add(const OcptShotListRemovedCharacterDroppedEvent(characterName: "LÉA"));
    state = await waitForState(bloc, (state) => state.removedCharacterAlerts.isEmpty);

    // The character still spoken is left untouched by the removal.
    expect(state.snapshot!.shotsById.values.single.characters, ["MARC"]);

    await bloc.close();
  });

  test('a dropped character can be replaced by a still-speaking one on every shot', () async {
    await writeScreenplay(twoCharactersText);
    await createShotWithCharacters(["LÉA"]);

    await writeScreenplay(oneCharacterLeftText);

    final bloc = buildBloc();
    var state = await waitForState(bloc, (state) => !state.isLoading);
    expect(state.removedCharacterAlerts, hasLength(1));

    bloc.add(
      const OcptShotListRemovedCharacterReplacedEvent(
        characterName: "LÉA",
        replacementName: "MARC",
      ),
    );
    state = await waitForState(bloc, (state) => state.removedCharacterAlerts.isEmpty);

    expect(state.snapshot!.shotsById.values.single.characters, ["MARC"]);

    await bloc.close();
  });

  test('deleting the selected shot removes it and clears the selection', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;
    final sequenceId = state.selectedSequenceId;

    bloc.add(OcptShotListShotDeletionRequestedEvent(shotId: shotId));
    state = await waitForState(bloc, (state) => state.totalShotCount == 0);

    expect(state.selectedShotId, isNull);
    expect(state.selectedSequenceId, sequenceId);

    await bloc.close();
  });

  test('the screenplay text is loaded into the state', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.screenplayText, twoSceneText);

    await bloc.close();
  });

  test('a first coverage click sets the pending anchor and writes nothing', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    final firstWord = actionBlock.words.first;

    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: firstWord.startOffset,
        wordEndOffset: firstWord.endOffset,
      ),
    );
    state = await waitForState(bloc, (state) => state.pendingCoverageAnchor != null);

    expect(state.pendingCoverageAnchor!.wordStartOffset, actionBlock.startOffset);
    expect(state.pendingCoverageAnchor!.wordStartOffset, firstWord.startOffset);
    expect(state.selectedShot!.coverageRanges, isEmpty);

    await bloc.close();
  });

  test('a second click in the same block writes a range covering both words', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    await drawCoverageRange(bloc, shotId: shotId, block: actionBlock);
    state = bloc.state;

    expect(state.pendingCoverageAnchor, isNull);
    final range = state.selectedShot!.coverageRanges.single;
    expect(range.sceneId, layout.sceneId);
    expect(range.startOffset, actionBlock.words.first.startOffset);
    expect(range.endOffset, actionBlock.words.last.endOffset);

    await bloc.close();
  });

  test('closing a range over dialogue attaches the characters it covers', () async {
    await writeScreenplay(dialogueText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;
    expect(state.selectedShot!.characters, isEmpty);

    final layout = state.buildSelectedCoverageLayout()!;
    final dialogueBlock = layout.blocks.firstWhere((block) => block.text == "Hello there.");

    await drawCoverageRange(bloc, shotId: shotId, block: dialogueBlock);
    state = await waitForState(bloc, (state) => state.selectedShot!.characters.isNotEmpty);

    // The cue itself is outside the range: the speaker is named by their dialogue alone.
    expect(state.selectedShot!.characters, ["LÉA"]);

    await bloc.close();
  });

  test('a range covering no dialogue attaches nobody', () async {
    await writeScreenplay(dialogueText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    await drawCoverageRange(bloc, shotId: shotId, block: actionBlock);
    state = bloc.state;

    expect(state.selectedShot!.coverageRanges, hasLength(1));
    expect(state.selectedShot!.characters, isEmpty);

    await bloc.close();
  });

  test('removing a range keeps the characters it had attached', () async {
    await writeScreenplay(dialogueText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final dialogueBlock = layout.blocks.firstWhere((block) => block.text == "Hello there.");

    await drawCoverageRange(bloc, shotId: shotId, block: dialogueBlock);
    await waitForState(bloc, (state) => state.selectedShot!.characters.isNotEmpty);

    bloc.add(OcptShotListCoverageClearRequestedEvent(shotId: shotId));
    state = await waitForState(bloc, (state) => state.selectedShot!.coverageRanges.isEmpty);

    // Attaching is one-way: only the user takes a character off a shot.
    expect(state.selectedShot!.characters, ["LÉA"]);

    await bloc.close();
  });

  test('a click on a covered word with no anchor removes that range', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    await drawCoverageRange(bloc, shotId: shotId, block: actionBlock);

    final firstWord = actionBlock.words.first;
    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: firstWord.startOffset,
        wordEndOffset: firstWord.endOffset,
      ),
    );
    state = await waitForState(bloc, (state) => state.selectedShot!.coverageRanges.isEmpty);
    expect(state.pendingCoverageAnchor, isNull);

    await bloc.close();
  });

  test("a second click in another block closes a range spanning both", () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final headingBlock = layout.blocks.firstWhere((block) => block.text == "INT. HOUSE - DAY");
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: headingBlock.words.first.startOffset,
        wordEndOffset: headingBlock.words.first.endOffset,
      ),
    );
    await waitForState(bloc, (state) => state.pendingCoverageAnchor != null);

    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: actionBlock.words.last.startOffset,
        wordEndOffset: actionBlock.words.last.endOffset,
      ),
    );
    state = await waitForState(
      bloc,
      (state) => state.selectedShot!.coverageRanges.isNotEmpty,
    );

    final range = state.selectedShot!.coverageRanges.single;
    expect(range.startOffset, headingBlock.words.first.startOffset);
    expect(range.endOffset, actionBlock.words.last.endOffset);
    // The range genuinely runs through both blocks, blank line included.
    expect(layout.blocksSpannedBy(range), [headingBlock, actionBlock]);
    expect(state.pendingCoverageAnchor, isNull);

    await bloc.close();
  });

  test("a range drawn next to an existing one merges with it", () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final heading = layout.blocks.firstWhere((block) => block.text == "INT. HOUSE - DAY");

    Future<void> drawWord(OcptShotCoverageWord word) async {
      final rangeCountBefore = state.selectedShot!.coverageRanges.length;
      for (var click = 0; click < 2; click++) {
        bloc.add(
          OcptShotListCoverageWordClickedEvent(
            shotId: shotId,
            wordStartOffset: word.startOffset,
            wordEndOffset: word.endOffset,
          ),
        );
      }
      state = await waitForState(
        bloc,
        (state) =>
            state.pendingCoverageAnchor == null &&
            state.selectedShot!.coverageRanges.length != rangeCountBefore - 1,
      );
    }

    // Two one-word ranges, drawn separately on two words a single space apart.
    await drawWord(heading.words[0]);
    await drawWord(heading.words[1]);

    final range = state.selectedShot!.coverageRanges.single;
    expect(layout.sceneText.substring(range.startOffset, range.endOffset), "INT. HOUSE");

    await bloc.close();
  });

  test("clearing coverage drops only the cleared shot's ranges", () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotAId = state.selectedShotId!;
    var layout = state.buildSelectedCoverageLayout()!;
    var actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    await drawCoverageRange(bloc, shotId: shotAId, block: actionBlock);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.totalShotCount == 2);
    final shotBId = state.selectedShotId!;
    layout = state.buildSelectedCoverageLayout()!;
    actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    await drawCoverageRange(bloc, shotId: shotBId, block: actionBlock);

    bloc.add(OcptShotListCoverageClearRequestedEvent(shotId: shotAId));
    state = await waitForState(
      bloc,
      (state) => state.snapshot!.shotsById[shotAId]!.coverageRanges.isEmpty,
    );

    expect(state.snapshot!.shotsById[shotBId]!.coverageRanges, isNotEmpty);

    await bloc.close();
  });

  test(
      'marking a shot as checked clears needsCheck and re-stamps digests so a following '
      'staleness pass stays quiet', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    final layout = created.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    await drawCoverageRange(bloc, shotId: shotId, block: actionBlock);
    await bloc.close();

    // Changing the scene's body (its heading is untouched, so the scene keeps its own id) makes
    // the recorded range's digest disagree with the text under it, raising needsCheck on save.
    const modifiedText =
        "INT. HOUSE - DAY\n\nAction one revised.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";
    await writeScreenplay(modifiedText);

    final reopenedBloc = buildBloc();
    var state = await waitForState(reopenedBloc, (state) => !state.isLoading);
    var shot = state.snapshot!.shotsById[shotId]!;
    expect(shot.needsCheck, isTrue);
    expect(shot.checkReason, OcptShotCheckReason.coveredTextChanged);

    reopenedBloc.add(OcptShotListShotMarkedAsCheckedEvent(shotId: shotId));
    state = await waitForState(
      reopenedBloc,
      (state) => !state.snapshot!.shotsById[shotId]!.needsCheck,
    );
    expect(state.pendingCoverageAnchor, isNull);

    await reopenedBloc.close();

    // Saving the very same (already stale-inducing) text again re-runs the staleness pass; the
    // digests were just re-stamped to it, so it stays quiet this time.
    await writeScreenplay(modifiedText);
    final finalBloc = buildBloc();
    final finalState = await waitForState(finalBloc, (state) => !state.isLoading);
    shot = finalState.snapshot!.shotsById[shotId]!;
    expect(shot.needsCheck, isFalse);
    expect(shot.checkReason, isNull);

    await finalBloc.close();
  });

  test('the pending coverage anchor is cleared when another shot is selected', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final firstShotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: firstShotId,
        wordStartOffset: actionBlock.words.first.startOffset,
        wordEndOffset: actionBlock.words.first.endOffset,
      ),
    );
    await waitForState(bloc, (state) => state.pendingCoverageAnchor != null);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.totalShotCount == 2);

    expect(state.pendingCoverageAnchor, isNull);
    expect(state.selectedShotId, isNot(firstShotId));

    await bloc.close();
  });

  test('a coverage write failure surfaces as the transient write error', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(shotCoverageService: const _FailingShotCoverageService());
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: actionBlock.words.first.startOffset,
        wordEndOffset: actionBlock.words.first.endOffset,
      ),
    );
    await waitForState(bloc, (state) => state.pendingCoverageAnchor != null);

    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: actionBlock.words.last.startOffset,
        wordEndOffset: actionBlock.words.last.endOffset,
      ),
    );
    state = await waitForState(bloc, (state) => state.hasWriteError);
    expect(state.pendingCoverageAnchor, isNull);
    expect(state.selectedShot!.coverageRanges, isEmpty);

    await bloc.close();
  });
}
