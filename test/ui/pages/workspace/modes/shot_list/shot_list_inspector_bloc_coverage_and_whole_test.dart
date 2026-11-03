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
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'shot_list_inspector_bloc_test_doubles.dart';

/// The fixed device id every stamping test double in this file uses.
Future<String> _testDeviceId() async => "test-device";

/// A shot coverage service whose [addRange] always fails, to exercise the bloc's coverage write
/// error path.
class _FailingShotCoverageService extends OcptShotCoverageService {
  /// Class constructor
  const _FailingShotCoverageService()
    : super(logger: const SilentLogger(), deviceId: _testDeviceId);

  /// Fail as a refused coverage write does.
  @override
  Future<OcptDatabaseResult<String>> addRange({
    required OcptProjectDatabase database,
    required String shotId,
    required String sceneId,
    required int startOffset,
    required int endOffset,
    required String sceneText,
  }) async => const OcptDatabaseResult<String>(
    status: OcptDatabaseStatus.databaseError,
    extraInfo: "coverage write intentionally failed for the test",
  );
}

/// A shot list service whose snapshot reads can be held back: while [heldReads] is positive, a read
/// takes its data from the database at once, then waits for [release] before answering, so what it
/// answers is older than the database by the time it arrives.
class _HoldingShotListService extends OcptShotListService {
  /// How many of the next reads are held back.
  int heldReads = 0;

  /// How many reads were held back so far.
  int holdCount = 0;

  /// Completes to let the held call go on.
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

  /// Load the shot list as the real service does, then hold the call while reads are to be held.
  @override
  Future<OcptDatabaseResult<OcptShotListSnapshot>> loadShotList({
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

/// Run the tests of the shot list inspector bloc coverage and whole.
void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

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
    routerManager: RecordingRouterManager(),
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
    /// Names [event] by the exhaustive switch over the sealed hierarchy: adding an event to it
    /// makes this fail to compile until the list below names it too.
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
      expect(await inspector.flushPendingWrites(), OcptPendingWritesStatus.nothingToWrite);

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
          final reloaded = await projectsManager.shotListService
              .loadShotList(
                database: project.database,
                screenplayId: project.primaryScreenplayId,
                episodeNumber: null,
              )
              .valueOrFail;
          expect(
            reloaded.shotsById[shotId]!.notes,
            "Kept",
            reason: inspectorFirst ? "inspector closed first" : "mode closed first",
          );

          // The next round starts from a project without that shot.
          await projectsManager.shotListService
              .deleteShot(database: project.database, shotId: shotId)
              .okOrFail;
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
