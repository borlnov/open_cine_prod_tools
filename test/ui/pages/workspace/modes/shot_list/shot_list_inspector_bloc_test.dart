// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The app language every projects manager built here is given, so a created project's own
/// screenplay language never depends on the machine the tests run on.
String _testAppLanguageCode() => "en";

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

/// The fixed device id every stamping test double in this file uses.
Future<String> _testDeviceId() async => "test-device";

/// A shot coverage service whose [addRange] always fails, to exercise the bloc's coverage write
/// error path.
class _FailingShotCoverageService extends OcptShotCoverageService {
  /// Class constructor
  const _FailingShotCoverageService()
    : super(logger: const SilentLogger(), deviceId: _testDeviceId);

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

/// A shot list service whose snapshot reads can be held back: while [heldReads] is positive, a read
/// takes its data from the database at once, then waits for [release] before answering, so what it
/// answers is older than the database by the time it arrives.
class _HoldingShotListService extends OcptShotListService {
  /// How many of the next reads are held back.
  int heldReads = 0;

  /// How many reads were held back so far.
  int holdCount = 0;

  final Completer<void> _release = Completer<void>();

  /// Class constructor
  _HoldingShotListService(OcptShotListService source)
    : super(
        logger: const SilentLogger(),
        roleIndexService: source.roleIndexService,
        storyboardService: source.storyboardService,
        floorPlanService: source.floorPlanService,
        deviceId: source.deviceId,
      );

  /// Lets every held read answer.
  void release() => _release.complete();

  @override
  Future<OcptShotListSnapshot> loadShotList({
    required OcptProjectDatabase database,
    required String screenplayId,
    required int? episodeNumber,
  }) async {
    final snapshot = await super.loadShotList(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: episodeNumber,
    );
    if (heldReads > 0) {
      heldReads--;
      holdCount++;
      await _release.future;
    }
    return snapshot;
  }
}

void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";
  const dialogueText =
      "INT. HOUSE - DAY\n\nAction one.\n\nLÉA\nHello there.\n\n"
      "EXT. GARDEN - NIGHT\n\nAction two.\n";
  const twoCharactersText =
      "INT. HOUSE - DAY\n\nAction one.\n\nLÉA\nHello there.\n\n"
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
    await propertiesManager.shotListVisibleColumns.store(OcptShotListColumn.defaultVisibleColumns);
    await propertiesManager.shotListLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await propertiesManager.shotListRightDockFraction.store(OcptWorkspaceDock.rightDefaultFraction);
    await propertiesManager.shotListLastRightDockTab.store(OcptShotListRightDockTab.inspector);

    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_inspector_bloc_test_");
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

  /// Builds the mode bloc wired to the test project. Its export manager is a plain one nothing ever
  /// exports through: the exports are the export bloc's own, tested apart.
  OcptShotListBloc buildBloc({OcptShotListService? shotListService}) => OcptShotListBloc(
    projectsManager: projectsManager,
    shotListService: shotListService,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the inspector bloc of [modeBloc]. [fieldEditDebounce] defaults to a short duration so
  /// tests exercising the field-edit debounce don't have to wait out the real 2 s one.
  OcptShotListInspectorBloc buildInspector(
    OcptShotListBloc modeBloc, {
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
    OcptShotCoverageService? shotCoverageService,
  }) => OcptShotListInspectorBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
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

  /// Waits for the first state of [inspector] matching [predicate] (the current one included): for
  /// a state that is only there for a moment, like a pending edit while its short debounce runs,
  /// which polling could step over.
  Future<OcptShotListInspectorState> waitForInspector(
    OcptShotListInspectorBloc inspector,
    bool Function(OcptShotListInspectorState state) predicate,
  ) async {
    if (predicate(inspector.state)) {
      return inspector.state;
    }

    return inspector.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Waits until [isDone] holds, looking again every few milliseconds: for a condition that spans
  /// the mode bloc and the inspector bloc, whose states change in an order a test must not depend
  /// on.
  Future<void> waitUntil(bool Function() isDone) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!isDone()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException("The awaited condition never held");
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// Creates a set on the selected sequence of [mode] through a floor plan sets bloc, which it
  /// closes again, waiting for the mode to select the set.
  Future<void> createSet(OcptShotListBloc mode) async {
    final sets = OcptShotListFloorPlanSetsBloc(modeBloc: mode, projectsManager: projectsManager);
    final epoch = mode.state.selectionEpoch;
    sets.add(const OcptShotListSetCreationRequestedEvent());
    await waitUntil(() => mode.state.selectionEpoch > epoch);
    await sets.close();
  }

  /// Closes the inspector and the mode, in the order the widget tree does.
  Future<void> closeAll(OcptShotListInspectorBloc inspector, OcptShotListBloc mode) async {
    await inspector.close();
    await mode.close();
  }

  /// Dispatches the two word clicks that draw a scenario coverage range across every word of
  /// [block] on shot [shotId] (first word opens the anchor, last word closes it), waiting for the
  /// anchor to land after the first click and for the range to land, and the anchor to be gone,
  /// after the second.
  Future<void> drawCoverageRange(
    OcptShotListBloc mode,
    OcptShotListInspectorBloc inspector, {
    required String shotId,
    required OcptScriptWordBlock block,
  }) async {
    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: block.words.first.startOffset,
        wordEndOffset: block.words.first.endOffset,
      ),
    );
    await waitUntil(() => inspector.state.pendingCoverageAnchor != null);

    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: block.words.last.startOffset,
        wordEndOffset: block.words.last.endOffset,
      ),
    );
    await waitUntil(
      () =>
          mode.state.snapshot!.shotsById[shotId]!.coverageRanges.isNotEmpty &&
          inspector.state.pendingCoverageAnchor == null,
    );
  }

  test(
    'a typed field edit is visible as a pending value and writes once after the debounce',
    () async {
      await writeScreenplay(twoSceneText);

      final mode = buildBloc();
      final inspector = buildInspector(mode);
      await waitForState(mode, (state) => !state.isLoading);
      mode.add(const OcptShotListShotCreationRequestedEvent());
      final created = await waitForState(mode, (state) => state.totalShotCount == 1);
      final shotId = created.selectedShotId!;

      inspector.add(
        OcptShotListShotFieldChangedEvent(
          shotId: shotId,
          field: OcptShotListEditableField.shotSize,
          rawValue: "W",
        ),
      );
      await waitForInspector(
        inspector,
        (state) =>
            state.pendingFieldEdits[OcptShotListShotFieldEditKey(
              shotId: shotId,
              field: OcptShotListEditableField.shotSize,
            )] ==
            "W",
      );
      // Not written yet: still the field's default empty value.
      expect(mode.state.selectedShot!.shotSize, isEmpty);

      // A second keystroke before the debounce elapses restarts it rather than firing twice: only
      // the last value typed is ever written.
      inspector.add(
        OcptShotListShotFieldChangedEvent(
          shotId: shotId,
          field: OcptShotListEditableField.shotSize,
          rawValue: "Wide",
        ),
      );
      await waitForInspector(
        inspector,
        (state) =>
            state.pendingFieldEdits[OcptShotListShotFieldEditKey(
              shotId: shotId,
              field: OcptShotListEditableField.shotSize,
            )] ==
            "Wide",
      );
      expect(mode.state.selectedShot!.shotSize, isEmpty);

      await waitForState(mode, (state) => state.selectedShot!.shotSize == "Wide");
      // The inspector forgets what it wrote once the mode holds it, one turn later.
      await pumpEventQueue();
      expect(inspector.state.pendingFieldEdits, isEmpty);

      await closeAll(inspector, mode);
    },
  );

  test('committing a shot size deduces the abbreviation once, then never again', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Plan moyen",
      ),
    );
    var state = await waitForState(mode, (state) => state.selectedShot!.shotSize == "Plan moyen");
    expect(state.selectedShot!.abbreviation, "PM");

    // A later shot size never overwrites the abbreviation the shot already carries.
    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Gros plan",
      ),
    );
    state = await waitForState(mode, (state) => state.selectedShot!.shotSize == "Gros plan");
    expect(state.selectedShot!.abbreviation, "PM");

    await closeAll(inspector, mode);
  });

  test('an abbreviation typed in the same flush wins over the deduced one', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Plan moyen",
      ),
    );
    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.abbreviation,
        rawValue: "PMS",
      ),
    );

    final state = await waitForState(mode, (state) => state.selectedShot!.shotSize == "Plan moyen");
    expect(state.selectedShot!.abbreviation, "PMS");

    await closeAll(inspector, mode);
  });

  test('selecting another shot flushes a pending field edit immediately', () async {
    await writeScreenplay(twoSceneText);

    // A debounce long enough that the assertions below could only pass through the flush the
    // selection change performs, never through the debounce elapsing on its own.
    final mode = buildBloc();
    final inspector = buildInspector(mode, fieldEditDebounce: const Duration(seconds: 5));
    await waitForState(mode, (state) => !state.isLoading);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final firstShotId = state.selectedShotId!;

    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: firstShotId,
        field: OcptShotListEditableField.notes,
        rawValue: "Handheld",
      ),
    );
    await waitUntil(
      () =>
          inspector.state.pendingFieldEdits[OcptShotListShotFieldEditKey(
            shotId: firstShotId,
            field: OcptShotListEditableField.notes,
          )] ==
          "Handheld",
    );

    mode.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(mode, (state) => state.totalShotCount == 2);

    expect(inspector.state.pendingFieldEdits, isEmpty);
    expect(state.snapshot!.shotsById[firstShotId]!.notes, "Handheld");

    await closeAll(inspector, mode);
  });

  test('flushPendingFieldEdits writes a pending edit directly, without touching state', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode, fieldEditDebounce: const Duration(seconds: 5));
    await waitForState(mode, (state) => !state.isLoading);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.sound,
        rawValue: "Wind noise",
      ),
    );
    await waitUntil(
      () =>
          inspector.state.pendingFieldEdits[OcptShotListShotFieldEditKey(
            shotId: shotId,
            field: OcptShotListEditableField.sound,
          )] ==
          "Wind noise",
    );

    await mode.flushPendingFieldEdits();

    // This flush never touches the inspector's own state...
    expect(inspector.state.pendingFieldEdits, isNotEmpty);
    // ...but the database already has the write.
    final reloaded = await projectsManager.shotListService.loadShotList(
      database: projectsManager.currentProject!.database,
      screenplayId: projectsManager.currentProject!.primaryScreenplayId,
      episodeNumber: null,
    );
    expect(reloaded.shotsById[shotId]!.sound, "Wind noise");

    await closeAll(inspector, mode);
  });

  test('a difficulty axis and a character toggle each write immediately', () async {
    await writeScreenplay(dialogueText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    inspector.add(
      OcptShotListShotDifficultyChangedEvent(
        shotId: shotId,
        axis: OcptShotDifficultyAxis.sound,
        value: 4,
      ),
    );
    state = await waitForState(mode, (state) => state.selectedShot!.difficultySound == 4);

    final leaRoleId = state.roles.firstWhere((role) => role.name == "LÉA").id;
    inspector.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, roleId: leaRoleId));
    state = await waitForState(mode, (state) => state.selectedShot!.characters.contains("LÉA"));

    inspector.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, roleId: leaRoleId));
    state = await waitForState(mode, (state) => state.selectedShot!.characters.isEmpty);

    await closeAll(inspector, mode);
  });

  /// Attaches [characterNames] to a freshly created shot of the first sequence, then closes the
  /// blocs that did it, and returns the new shot's derived code.
  ///
  /// The deleted-character tests all need the same starting point: a shot carrying characters the
  /// screenplay is then edited to no longer speak. The mode bloc reads the screenplay's speaking
  /// characters once, on entry, so a fresh bloc is what sees the edited screenplay — which is also
  /// what happens in the app, where the shot list mode is mounted anew every time it is switched
  /// to.
  Future<String> createShotWithCharacters(List<String> characterNames) async {
    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    for (final characterName in characterNames) {
      final roleId = state.roles.firstWhere((role) => role.name == characterName).id;
      inspector.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, roleId: roleId));
      state = await waitForState(
        mode,
        (state) => state.selectedShot!.characters.contains(characterName),
      );
    }

    final code = state.selectedShot!.code;
    await closeAll(inspector, mode);

    return code;
  }

  test('an orphaned role is reported, then deletable everywhere', () async {
    await writeScreenplay(twoCharactersText);
    await createShotWithCharacters(["LÉA", "MARC"]);

    await writeScreenplay(oneCharacterLeftText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    var state = await waitForState(mode, (state) => !state.isLoading);

    expect(state.orphanedRoleAlerts, hasLength(1));
    expect(state.orphanedRoleAlerts.single.characterName, "LÉA");
    final leaRoleId = state.orphanedRoleAlerts.single.roleId;

    inspector.add(OcptShotListOrphanedRoleDeleteRequestedEvent(roleId: leaRoleId));
    state = await waitForState(mode, (state) => state.orphanedRoleAlerts.isEmpty);

    // The character still spoken is left untouched by the deletion, and the role's own cascade
    // drops it from the shot rather than leaving a dangling attachment.
    expect(state.snapshot!.shotsById.values.single.characters, ["MARC"]);

    await closeAll(inspector, mode);
  });

  test(
    'an orphaned role can be merged into a still-speaking one, carrying its shots along',
    () async {
      await writeScreenplay(twoCharactersText);
      await createShotWithCharacters(["LÉA"]);

      await writeScreenplay(oneCharacterLeftText);

      final mode = buildBloc();
      final inspector = buildInspector(mode);
      var state = await waitForState(mode, (state) => !state.isLoading);
      expect(state.orphanedRoleAlerts, hasLength(1));
      final leaRoleId = state.orphanedRoleAlerts.single.roleId;
      final marcRoleId = state.roles.firstWhere((role) => role.name == "MARC").id;

      inspector.add(
        OcptShotListRoleMergeRequestedEvent(sourceRoleId: leaRoleId, targetRoleId: marcRoleId),
      );
      state = await waitForState(mode, (state) => state.orphanedRoleAlerts.isEmpty);

      expect(state.snapshot!.shotsById.values.single.characters, ["MARC"]);

      await closeAll(inspector, mode);
    },
  );

  test('an orphaned role can be kept as silent, its casting untouched and its shot kept', () async {
    await writeScreenplay(twoCharactersText);
    await createShotWithCharacters(["LÉA", "MARC"]);

    await writeScreenplay(oneCharacterLeftText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    var state = await waitForState(mode, (state) => !state.isLoading);
    expect(state.orphanedRoleAlerts, hasLength(1));
    final leaRoleId = state.orphanedRoleAlerts.single.roleId;

    inspector.add(OcptShotListOrphanedRoleKeptEvent(roleId: leaRoleId));
    state = await waitForState(mode, (state) => state.orphanedRoleAlerts.isEmpty);

    final leaRole = state.roles.firstWhere((role) => role.id == leaRoleId);
    expect(leaRole.isFromScreenplay, isFalse);
    expect(leaRole.kind, OcptRoleKind.silent);
    // Kept, not dropped: the shot still carries both characters.
    expect(state.snapshot!.shotsById.values.single.characters, ["LÉA", "MARC"]);

    await closeAll(inspector, mode);
  });

  test('a first coverage click sets the pending anchor and writes nothing', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    final state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    final firstWord = actionBlock.words.first;

    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: firstWord.startOffset,
        wordEndOffset: firstWord.endOffset,
      ),
    );
    await waitUntil(() => inspector.state.pendingCoverageAnchor != null);

    expect(inspector.state.pendingCoverageAnchor!.wordStartOffset, actionBlock.startOffset);
    expect(inspector.state.pendingCoverageAnchor!.wordStartOffset, firstWord.startOffset);
    expect(mode.state.selectedShot!.coverageRanges, isEmpty);

    await closeAll(inspector, mode);
  });

  test('cancelling the pending anchor clears it without recording a range', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    final state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    final firstWord = actionBlock.words.first;

    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: firstWord.startOffset,
        wordEndOffset: firstWord.endOffset,
      ),
    );
    await waitUntil(() => inspector.state.pendingCoverageAnchor != null);

    inspector.add(const OcptShotListCoverageAnchorCancelledEvent());
    await waitUntil(() => inspector.state.pendingCoverageAnchor == null);

    expect(inspector.state.pendingCoverageAnchor, isNull);
    expect(mode.state.selectedShot!.coverageRanges, isEmpty);

    await closeAll(inspector, mode);
  });

  test('a second click in the same block writes a range covering both words', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    await drawCoverageRange(mode, inspector, shotId: shotId, block: actionBlock);
    state = mode.state;

    expect(inspector.state.pendingCoverageAnchor, isNull);
    final range = state.selectedShot!.coverageRanges.single;
    expect(range.sceneId, layout.sceneId);
    expect(range.startOffset, actionBlock.words.first.startOffset);
    expect(range.endOffset, actionBlock.words.last.endOffset);

    await closeAll(inspector, mode);
  });

  test('closing a range over dialogue attaches the characters it covers', () async {
    await writeScreenplay(dialogueText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;
    expect(state.selectedShot!.characters, isEmpty);

    final layout = state.buildSelectedCoverageLayout()!;
    final dialogueBlock = layout.blocks.firstWhere((block) => block.text == "Hello there.");

    await drawCoverageRange(mode, inspector, shotId: shotId, block: dialogueBlock);
    state = await waitForState(mode, (state) => state.selectedShot!.characters.isNotEmpty);

    // The cue itself is outside the range: the speaker is named by their dialogue alone.
    expect(state.selectedShot!.characters, ["LÉA"]);

    await closeAll(inspector, mode);
  });

  test('a range covering no dialogue attaches nobody', () async {
    await writeScreenplay(dialogueText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    await drawCoverageRange(mode, inspector, shotId: shotId, block: actionBlock);
    state = mode.state;

    expect(state.selectedShot!.coverageRanges, hasLength(1));
    expect(state.selectedShot!.characters, isEmpty);

    await closeAll(inspector, mode);
  });

  test('removing a range keeps the characters it had attached', () async {
    await writeScreenplay(dialogueText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final dialogueBlock = layout.blocks.firstWhere((block) => block.text == "Hello there.");

    await drawCoverageRange(mode, inspector, shotId: shotId, block: dialogueBlock);
    await waitForState(mode, (state) => state.selectedShot!.characters.isNotEmpty);

    inspector.add(OcptShotListCoverageClearRequestedEvent(shotId: shotId));
    state = await waitForState(mode, (state) => state.selectedShot!.coverageRanges.isEmpty);

    // Attaching is one-way: only the user takes a character off a shot.
    expect(state.selectedShot!.characters, ["LÉA"]);

    await closeAll(inspector, mode);
  });

  test('a click on a covered word with no anchor removes that range', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    await drawCoverageRange(mode, inspector, shotId: shotId, block: actionBlock);

    final firstWord = actionBlock.words.first;
    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: firstWord.startOffset,
        wordEndOffset: firstWord.endOffset,
      ),
    );
    state = await waitForState(mode, (state) => state.selectedShot!.coverageRanges.isEmpty);
    // The inspector forgets the anchor once the mode holds the change, one turn later.
    await pumpEventQueue();
    expect(inspector.state.pendingCoverageAnchor, isNull);

    await closeAll(inspector, mode);
  });

  test("a second click in another block closes a range spanning both", () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final headingBlock = layout.blocks.firstWhere((block) => block.text == "INT. HOUSE - DAY");
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: headingBlock.words.first.startOffset,
        wordEndOffset: headingBlock.words.first.endOffset,
      ),
    );
    await waitUntil(() => inspector.state.pendingCoverageAnchor != null);

    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: actionBlock.words.last.startOffset,
        wordEndOffset: actionBlock.words.last.endOffset,
      ),
    );
    state = await waitForState(mode, (state) => state.selectedShot!.coverageRanges.isNotEmpty);
    // The inspector forgets the anchor once the mode holds the range, one turn later.
    await pumpEventQueue();

    final range = state.selectedShot!.coverageRanges.single;
    expect(range.startOffset, headingBlock.words.first.startOffset);
    expect(range.endOffset, actionBlock.words.last.endOffset);
    // The range genuinely runs through both blocks, blank line included.
    expect(layout.blocksSpannedBy(range), [headingBlock, actionBlock]);
    expect(inspector.state.pendingCoverageAnchor, isNull);

    await closeAll(inspector, mode);
  });

  test("a range drawn next to an existing one merges with it", () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final heading = layout.blocks.firstWhere((block) => block.text == "INT. HOUSE - DAY");

    Future<void> drawWord(OcptScriptWord word) async {
      for (var click = 0; click < 2; click++) {
        inspector.add(
          OcptShotListCoverageWordClickedEvent(
            shotId: shotId,
            wordStartOffset: word.startOffset,
            wordEndOffset: word.endOffset,
          ),
        );
      }
      await waitUntil(
        () =>
            inspector.state.pendingCoverageAnchor == null &&
            mode.state.selectedShot!.coverageRanges.any(
              (range) => range.endOffset == word.endOffset,
            ),
      );
      state = mode.state;
    }

    // Two one-word ranges, drawn separately on two words a single space apart.
    await drawWord(heading.words[0]);
    await drawWord(heading.words[1]);

    final range = state.selectedShot!.coverageRanges.single;
    expect(layout.sceneText.substring(range.startOffset, range.endOffset), "INT. HOUSE");

    await closeAll(inspector, mode);
  });

  test("clearing coverage drops only the cleared shot's ranges", () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotAId = state.selectedShotId!;
    var layout = state.buildSelectedCoverageLayout()!;
    var actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    await drawCoverageRange(mode, inspector, shotId: shotAId, block: actionBlock);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(mode, (state) => state.totalShotCount == 2);
    final shotBId = state.selectedShotId!;
    layout = state.buildSelectedCoverageLayout()!;
    actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    await drawCoverageRange(mode, inspector, shotId: shotBId, block: actionBlock);

    inspector.add(OcptShotListCoverageClearRequestedEvent(shotId: shotAId));
    state = await waitForState(
      mode,
      (state) => state.snapshot!.shotsById[shotAId]!.coverageRanges.isEmpty,
    );

    expect(state.snapshot!.shotsById[shotBId]!.coverageRanges, isNotEmpty);

    await closeAll(inspector, mode);
  });

  test('marking a shot as checked clears needsCheck and re-stamps digests so a following '
      'staleness pass stays quiet', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    final layout = created.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    await drawCoverageRange(mode, inspector, shotId: shotId, block: actionBlock);
    await closeAll(inspector, mode);

    // Changing the scene's body (its heading is untouched, so the scene keeps its own id) makes
    // the recorded range's digest disagree with the text under it, raising needsCheck on save.
    const modifiedText =
        "INT. HOUSE - DAY\n\nAction one revised.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";
    await writeScreenplay(modifiedText);

    final reopenedMode = buildBloc();
    final reopenedInspector = buildInspector(reopenedMode);
    var state = await waitForState(reopenedMode, (state) => !state.isLoading);
    var shot = state.snapshot!.shotsById[shotId]!;
    expect(shot.needsCheck, isTrue);
    expect(shot.checkReason, OcptShotCheckReason.coveredTextChanged);

    reopenedInspector.add(OcptShotListShotMarkedAsCheckedEvent(shotId: shotId));
    state = await waitForState(
      reopenedMode,
      (state) => !state.snapshot!.shotsById[shotId]!.needsCheck,
    );
    expect(reopenedInspector.state.pendingCoverageAnchor, isNull);

    await closeAll(reopenedInspector, reopenedMode);

    // Saving the very same (already stale-inducing) text again re-runs the staleness pass; the
    // digests were just re-stamped to it, so it stays quiet this time.
    await writeScreenplay(modifiedText);
    final finalMode = buildBloc();
    final finalInspector = buildInspector(finalMode);
    final finalState = await waitForState(finalMode, (state) => !state.isLoading);
    shot = finalState.snapshot!.shotsById[shotId]!;
    expect(shot.needsCheck, isFalse);
    expect(shot.checkReason, isNull);

    await closeAll(finalInspector, finalMode);
  });

  test('the pending coverage anchor is cleared when another shot is selected', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final firstShotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: firstShotId,
        wordStartOffset: actionBlock.words.first.startOffset,
        wordEndOffset: actionBlock.words.first.endOffset,
      ),
    );
    await waitUntil(() => inspector.state.pendingCoverageAnchor != null);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(mode, (state) => state.totalShotCount == 2);
    // The inspector reacts to the mode's selection move one turn after the mode emits it.
    await pumpEventQueue();

    expect(inspector.state.pendingCoverageAnchor, isNull);
    expect(state.selectedShotId, isNot(firstShotId));

    await closeAll(inspector, mode);
  });

  test('a coverage write failure surfaces as the transient write error', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(
      mode,
      shotCoverageService: const _FailingShotCoverageService(),
    );
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    final state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: actionBlock.words.first.startOffset,
        wordEndOffset: actionBlock.words.first.endOffset,
      ),
    );
    await waitUntil(() => inspector.state.pendingCoverageAnchor != null);

    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: actionBlock.words.last.startOffset,
        wordEndOffset: actionBlock.words.last.endOffset,
      ),
    );
    await waitUntil(() => inspector.state.hasWriteError);
    expect(inspector.state.pendingCoverageAnchor, isNull);
    expect(mode.state.selectedShot!.coverageRanges, isEmpty);

    await closeAll(inspector, mode);
  });

  group("the bloc as a whole", () {
    /// Names [event] by the exhaustive switch over the sealed hierarchy: adding an event to it makes
    /// this fail to compile until the list below names it too.
    String nameOf(OcptShotListInspectorEvent event) => switch (event) {
      OcptShotListShotFieldChangedEvent() => "field",
      OcptShotListInspectorFieldEditFlushRequestedEvent() => "flush",
      OcptShotListShotDifficultyChangedEvent() => "difficulty",
      OcptShotListShotCharacterToggledEvent() => "character toggled",
      OcptShotListCharacterAddRequestedEvent() => "character added",
      OcptShotListOrphanedRoleDeleteRequestedEvent() => "role deletion",
      OcptShotListOrphanedRoleKeptEvent() => "role kept",
      OcptShotListRoleMergeRequestedEvent() => "role merge",
      OcptShotListCoverageWordClickedEvent() => "coverage click",
      OcptShotListCoverageClearRequestedEvent() => "coverage clear",
      OcptShotListCoverageAnchorCancelledEvent() => "anchor cancelled",
      OcptShotListShotMarkedAsCheckedEvent() => "marked as checked",
      OcptShotListInspectorWriteErrorDismissedEvent() => "dismiss",
    };

    test("every event of its hierarchy has a handler", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final inspector = buildInspector(mode);
      await waitForState(mode, (state) => !state.isLoading);

      const events = <OcptShotListInspectorEvent>[
        OcptShotListShotFieldChangedEvent(
          shotId: "s",
          field: OcptShotListEditableField.notes,
          rawValue: "",
        ),
        OcptShotListInspectorFieldEditFlushRequestedEvent(),
        OcptShotListShotDifficultyChangedEvent(
          shotId: "s",
          axis: OcptShotDifficultyAxis.sound,
          value: 1,
        ),
        OcptShotListShotCharacterToggledEvent(shotId: "s", roleId: "r"),
        OcptShotListCharacterAddRequestedEvent(shotId: "s", characterName: "N"),
        OcptShotListOrphanedRoleDeleteRequestedEvent(roleId: "r"),
        OcptShotListOrphanedRoleKeptEvent(roleId: "r"),
        OcptShotListRoleMergeRequestedEvent(sourceRoleId: "a", targetRoleId: "b"),
        OcptShotListCoverageWordClickedEvent(shotId: "s", wordStartOffset: 0, wordEndOffset: 1),
        OcptShotListCoverageClearRequestedEvent(shotId: "s"),
        OcptShotListCoverageAnchorCancelledEvent(),
        OcptShotListShotMarkedAsCheckedEvent(shotId: "s"),
        OcptShotListInspectorWriteErrorDismissedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(13));

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => inspector.add(event), returnsNormally, reason: nameOf(event));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await closeAll(inspector, mode);
    });

    test("the mode moving its selection clears the coverage anchor, by what moved it", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final inspector = buildInspector(mode);
      await waitForState(mode, (state) => !state.isLoading);
      mode.add(const OcptShotListShotCreationRequestedEvent());
      final created = await waitForState(mode, (state) => state.totalShotCount == 1);
      final shotId = created.selectedShotId!;
      final firstSequenceId = created.selectedSequenceId!;
      final secondSequenceId = created.sequences.last.id;
      final actionBlock = created.buildSelectedCoverageLayout()!.blocks.firstWhere(
        (block) => block.text == "Action one.",
      );

      Future<void> openAnchor() async {
        inspector.add(
          OcptShotListCoverageWordClickedEvent(
            shotId: shotId,
            wordStartOffset: actionBlock.words.first.startOffset,
            wordEndOffset: actionBlock.words.first.endOffset,
          ),
        );
        await waitUntil(() => inspector.state.pendingCoverageAnchor != null);
      }

      // A set selected: the anchor stays, a set is not what the anchor belongs to.
      await openAnchor();
      await createSet(mode);
      mode.add(OcptShotListSetSelectedEvent(setId: mode.state.selectedSetId!));
      await waitUntil(() => mode.state.selectionCause == OcptShotListSelectionCause.set);
      await pumpEventQueue();
      expect(inspector.state.pendingCoverageAnchor, isNotNull);

      // The sequence already shown, selected again: cleared.
      mode.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
      await waitUntil(() => inspector.state.pendingCoverageAnchor == null);
      expect(mode.state.selectionCause, OcptShotListSelectionCause.sequenceReselected);

      // The shot already selected, selected again: cleared.
      await openAnchor();
      mode.add(OcptShotListShotSelectedEvent(shotId: shotId));
      await waitUntil(() => inspector.state.pendingCoverageAnchor == null);
      expect(mode.state.selectionCause, OcptShotListSelectionCause.shot);

      // A different sequence: cleared.
      await openAnchor();
      mode.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
      await waitUntil(() => inspector.state.pendingCoverageAnchor == null);
      expect(mode.state.selectionCause, OcptShotListSelectionCause.sequence);

      await closeAll(inspector, mode);
    });

    test("no frame can be drawn between the mode's selection change and the inspector's", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final inspector = buildInspector(mode);
      await waitForState(mode, (state) => !state.isLoading);
      mode.add(const OcptShotListShotCreationRequestedEvent());
      final created = await waitForState(mode, (state) => state.totalShotCount == 1);
      final shotId = created.selectedShotId!;
      final word = created
          .buildSelectedCoverageLayout()!
          .blocks
          .firstWhere((block) => block.text == "Action one.")
          .words
          .first;
      inspector.add(
        OcptShotListCoverageWordClickedEvent(
          shotId: shotId,
          wordStartOffset: word.startOffset,
          wordEndOffset: word.endOffset,
        ),
      );
      await waitUntil(() => inspector.state.pendingCoverageAnchor != null);

      // A frame is drawn in a task of the event loop of its own, so a task scheduled the moment the
      // mode's state is delivered stands for the next frame: what the inspector holds in it is what
      // that frame would draw. A reaction that waited for a timer, or for anything but microtasks,
      // would not have happened yet.
      final anchorInTheNextTask = Completer<bool>();
      final subscription = mode.stream.listen((state) {
        if (state.selectionCause == OcptShotListSelectionCause.shot &&
            !anchorInTheNextTask.isCompleted) {
          Timer.run(
            () => anchorInTheNextTask.complete(inspector.state.pendingCoverageAnchor == null),
          );
        }
      });

      mode.add(OcptShotListShotSelectedEvent(shotId: shotId));

      expect(await anchorInTheNextTask.future.timeout(const Duration(seconds: 5)), isTrue);

      await subscription.cancel();
      await closeAll(inspector, mode);
    });

    test("a coverage write waits for the mode to hold the range before the anchor goes", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final inspector = buildInspector(mode);
      await waitForState(mode, (state) => !state.isLoading);
      mode.add(const OcptShotListShotCreationRequestedEvent());
      final created = await waitForState(mode, (state) => state.totalShotCount == 1);
      final shotId = created.selectedShotId!;
      final block = created.buildSelectedCoverageLayout()!.blocks.firstWhere(
        (block) => block.text == "Action one.",
      );

      inspector.add(
        OcptShotListCoverageWordClickedEvent(
          shotId: shotId,
          wordStartOffset: block.words.first.startOffset,
          wordEndOffset: block.words.first.endOffset,
        ),
      );
      await waitUntil(() => inspector.state.pendingCoverageAnchor != null);

      // How many ranges the mode held at the very moment the anchor went.
      final rangeCountWhenCleared = inspector.stream
          .firstWhere((state) => state.pendingCoverageAnchor == null)
          .then((_) => mode.state.selectedShot!.coverageRanges.length);

      inspector.add(
        OcptShotListCoverageWordClickedEvent(
          shotId: shotId,
          wordStartOffset: block.words.last.startOffset,
          wordEndOffset: block.words.last.endOffset,
        ),
      );

      expect(await rangeCountWhenCleared.timeout(const Duration(seconds: 5)), 1);

      await closeAll(inspector, mode);
    });

    test("deleting the shot drops the field still being typed into it", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final inspector = buildInspector(mode, fieldEditDebounce: const Duration(days: 1));
      await waitForState(mode, (state) => !state.isLoading);
      mode.add(const OcptShotListShotCreationRequestedEvent());
      final created = await waitForState(mode, (state) => state.totalShotCount == 1);
      final shotId = created.selectedShotId!;

      inspector.add(
        OcptShotListShotFieldChangedEvent(
          shotId: shotId,
          field: OcptShotListEditableField.notes,
          rawValue: "Typed into a shot about to go",
        ),
      );
      await waitUntil(() => inspector.state.pendingFieldEdits.isNotEmpty);

      mode.add(OcptShotListShotDeletionRequestedEvent(shotId: shotId));
      await waitForState(mode, (state) => state.totalShotCount == 0);
      await waitUntil(() => inspector.state.pendingFieldEdits.isEmpty);

      // Nothing is left to write: a flush is a no-op rather than a write to a deleted shot.
      expect(await inspector.flushPendingWrites(), isFalse);

      await closeAll(inspector, mode);
    });

    test(
      "a version preview writes the field still being typed before it swaps the database",
      () async {
        await writeScreenplay(twoSceneText);
        final mode = buildBloc();
        final inspector = buildInspector(mode, fieldEditDebounce: const Duration(days: 1));
        await waitForState(mode, (state) => !state.isLoading);
        mode.add(const OcptShotListShotCreationRequestedEvent());
        final created = await waitForState(mode, (state) => state.totalShotCount == 1);
        final shotId = created.selectedShotId!;

        inspector.add(
          OcptShotListShotFieldChangedEvent(
            shotId: shotId,
            field: OcptShotListEditableField.notes,
            rawValue: "Typed",
          ),
        );
        await waitUntil(() => inspector.state.pendingFieldEdits.isNotEmpty);

        mode.add(const OcptProjectVersionCreationRequestedEvent(name: "Typing", note: ""));
        await waitForState(mode, (state) => state.projectVersions.isNotEmpty);

        // The working copy holds the field: the flush went through the mode, to the inspector.
        expect(inspector.state.pendingFieldEdits, isEmpty);
        expect(mode.state.snapshot!.shotsById[shotId]!.notes, "Typed");

        await closeAll(inspector, mode);
      },
    );

    test("a flush asked while a reload is in flight writes the field and settles", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final inspector = buildInspector(mode, fieldEditDebounce: const Duration(days: 1));
      await waitForState(mode, (state) => !state.isLoading);
      mode.add(const OcptShotListShotCreationRequestedEvent());
      final created = await waitForState(mode, (state) => state.totalShotCount == 1);
      final shotId = created.selectedShotId!;

      inspector.add(
        OcptShotListShotFieldChangedEvent(
          shotId: shotId,
          field: OcptShotListEditableField.notes,
          rawValue: "Both",
        ),
      );
      await waitUntil(() => inspector.state.pendingFieldEdits.isNotEmpty);

      final reload = mode.reload({OcptShotListReloadScope.snapshot});
      final flush = mode.flushAllPendingWrites();
      await Future.wait([reload, flush]).timeout(const Duration(seconds: 5));

      expect(inspector.state.pendingFieldEdits, isEmpty);
      expect(mode.state.snapshot!.shotsById[shotId]!.notes, "Both");

      await closeAll(inspector, mode);
    });

    test("a field typed while the inspector's flush is in flight is kept and written", () async {
      await writeScreenplay(twoSceneText);
      final service = _HoldingShotListService(projectsManager.shotListService);
      final mode = buildBloc(shotListService: service);
      final inspector = buildInspector(mode, fieldEditDebounce: const Duration(days: 1));
      await waitForState(mode, (state) => !state.isLoading);
      mode.add(const OcptShotListShotCreationRequestedEvent());
      final created = await waitForState(mode, (state) => state.totalShotCount == 1);
      final shotId = created.selectedShotId!;

      OcptShotListShotFieldChangedEvent typed(String text) => OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.lens,
        rawValue: text,
      );

      inspector.add(typed("5"));
      await waitUntil(() => inspector.state.pendingFieldEdits.isNotEmpty);

      // The flush writes "5" and is held while the mode reads it back.
      service.heldReads = 1;
      final flush = inspector.flushPendingWrites();
      await waitUntil(() => service.holdCount == 1);

      inspector.add(typed("50"));
      await waitUntil(() => inspector.state.pendingFieldEdits.values.contains("50"));
      service.release();
      await flush;

      expect(inspector.state.pendingFieldEdits.values, ["50"], reason: 'the keystroke is not lost');
      await inspector.flushPendingWrites();
      expect(inspector.state.pendingFieldEdits, isEmpty);
      expect(mode.state.snapshot!.shotsById[shotId]!.lens, "50");

      await closeAll(inspector, mode);
    });

    test(
      "a field still being typed is written whichever of the inspector and the mode closes first",
      () async {
        for (final inspectorFirst in [true, false]) {
          await writeScreenplay(twoSceneText);
          final mode = buildBloc();
          final inspector = buildInspector(mode, fieldEditDebounce: const Duration(days: 1));
          await waitForState(mode, (state) => !state.isLoading);
          mode.add(const OcptShotListShotCreationRequestedEvent());
          final created = await waitForState(mode, (state) => state.totalShotCount == 1);
          final shotId = created.selectedShotId!;

          inspector.add(
            OcptShotListShotFieldChangedEvent(
              shotId: shotId,
              field: OcptShotListEditableField.notes,
              rawValue: "Kept",
            ),
          );
          await waitUntil(() => inspector.state.pendingFieldEdits.isNotEmpty);

          if (inspectorFirst) {
            await inspector.close();
            await mode.close();
          } else {
            await mode.close();
            await inspector.close();
          }

          final project = projectsManager.currentProject!;
          final reloaded = await projectsManager.shotListService.loadShotList(
            database: project.database,
            screenplayId: project.primaryScreenplayId,
            episodeNumber: null,
          );
          expect(
            reloaded.shotsById[shotId]!.notes,
            "Kept",
            reason: inspectorFirst ? "inspector closed first" : "mode closed first",
          );

          // The next round starts from a project without that shot.
          await projectsManager.shotListService.deleteShot(
            database: project.database,
            shotId: shotId,
          );
        }
      },
    );

    test(
      "a failing write raises the inspector's own write error, which can be dismissed",
      () async {
        await writeScreenplay(twoSceneText);
        final mode = buildBloc();
        final inspector = buildInspector(
          mode,
          shotCoverageService: const _FailingShotCoverageService(),
        );
        await waitForState(mode, (state) => !state.isLoading);
        mode.add(const OcptShotListShotCreationRequestedEvent());
        final created = await waitForState(mode, (state) => state.totalShotCount == 1);

        final shotId = created.selectedShotId!;
        final block = created.buildSelectedCoverageLayout()!.blocks.firstWhere(
          (block) => block.text == "Action one.",
        );
        for (final word in [block.words.first, block.words.last]) {
          inspector.add(
            OcptShotListCoverageWordClickedEvent(
              shotId: shotId,
              wordStartOffset: word.startOffset,
              wordEndOffset: word.endOffset,
            ),
          );
          await pumpEventQueue();
        }
        await waitUntil(() => inspector.state.hasWriteError);
        expect(mode.state.hasWriteError, isFalse, reason: "the error is the inspector's own");

        inspector.add(const OcptShotListInspectorWriteErrorDismissedEvent());
        await waitUntil(() => !inspector.state.hasWriteError);

        await closeAll(inspector, mode);
      },
    );
  });
}
