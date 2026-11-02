// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Completes when [pop] is called, so a test can wait for it.
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

/// Run the tests of [OcptScheduleBloc].
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() resolvable; the bloc's dependencies
    // themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_schedule_bloc_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
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
  /// gives the schedule mode's shot list a scene to hang a shot off.
  Future<void> writeScreenplay(String text) async {
    final project = projectsManager.currentProject!;

    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: text,
      snapshotReason: OcptSnapshotReason.manual,
    );
  }

  /// Writes a one-scene screenplay, creates a shot in it, a shooting day with its default slot,
  /// and places the shot on that slot — the fixture every selection test below shares.
  Future<({String shotId, String dayId, String blockId})> writePlacedShot() async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(
      project.database.ocptScenesTable,
    )).get()).single.id;

    final shotId = await projectsManager.shotListService.createShot(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      sceneId: sceneId,
    );
    expect(shotId, isNotNull);

    final dayId = await projectsManager.scheduleService
        .createDay(database: project.database, date: DateTime(2026, 8, 10))
        .maybeValueOrFail;
    expect(dayId, isNotNull);

    final snapshot = await projectsManager.scheduleService
        .loadSchedule(database: project.database)
        .valueOrFail;
    final slotId = snapshot.slotsByDayId[dayId]!.single.id;

    final blockId = await projectsManager.scheduleService
        .placeShot(database: project.database, slotId: slotId, shotId: shotId!)
        .maybeValueOrFail;
    expect(blockId, isNotNull);

    return (shotId: shotId, dayId: dayId!, blockId: blockId!);
  }

  /// Builds a bloc wired to the test project, its export manager the plain one: no test here is
  /// about exporting.
  OcptScheduleBloc buildBloc() => OcptScheduleBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptScheduleState> waitForState(
    OcptScheduleBloc bloc,
    bool Function(OcptScheduleState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  group("loading the schedule", () {
    test("reads the project's whole elements catalogue into the state", () async {
      final project = projectsManager.currentProject!;
      final elementId = await projectsManager.elementsService.createElement(
        database: project.database,
        name: "Umbrella",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      );
      expect(elementId, isNotNull);

      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.elements.map((element) => element.id), contains(elementId));
      final loadedElement = state.elements.firstWhere((element) => element.id == elementId);
      expect(
        loadedElement.name,
        "Umbrella",
        reason:
            "the sixth read the bloc now performs alongside the schedule, the shot list and the "
            "other three catalogues",
      );

      await bloc.close();
    });

    test("a project holding two episodes reads and orders both episodes' shot lists", () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
      final project = projectsManager.currentProject!;

      final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
        database: project.database,
      );
      expect(secondEpisodeId, isNotNull);
      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: secondEpisodeId!,
        fountainText: "EXT. STREET - NIGHT\n\nAction two.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );

      final firstSceneId = (await (project.database.select(
        project.database.ocptScenesTable,
      )..where((table) => table.screenplayId.equals(project.primaryScreenplayId))).get()).single.id;
      final secondSceneId = (await (project.database.select(
        project.database.ocptScenesTable,
      )..where((table) => table.screenplayId.equals(secondEpisodeId))).get()).single.id;

      await projectsManager.shotListService.createShot(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        sceneId: firstSceneId,
      );
      await projectsManager.shotListService.createShot(
        database: project.database,
        screenplayId: secondEpisodeId,
        sceneId: secondSceneId,
      );

      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.episodes.map((episode) => episode.id), [
        project.primaryScreenplayId,
        secondEpisodeId,
      ]);
      expect(state.shotListSnapshots, hasLength(2));
      expect(
        state.shotListSnapshots.map((shotList) => shotList.screenplayId),
        [project.primaryScreenplayId, secondEpisodeId],
        reason: "episode 1's own shot list before episode 2's, the episodes' own order",
      );

      expect(
        state.unplacedGroups.map((group) => group.heading),
        ["INT. HOUSE - DAY", "EXT. STREET - NIGHT"],
        reason: "the unplaced-shots grouping lists episode 1's sequences before episode 2's",
      );

      await bloc.close();
    });
  });

  group("planning an audition", () {
    /// A part, somebody seen for it, and a day with one slot: what an audition is planned on.
    /// Returns the slot and the candidacy.
    Future<(String slotId, String roleCandidateId)> seedCastingDay() async {
      final project = projectsManager.currentProject!;

      final roleId = await projectsManager.roleIndexService.addRole(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        name: "MARIE",
        kind: OcptRoleKind.silent,
      );
      final personId = await projectsManager.peopleService.createPerson(database: project.database);
      await projectsManager.peopleService.updatePerson(
        database: project.database,
        personId: personId!,
        firstName: const Value("Camille"),
      );
      final roleCandidateId = await projectsManager.roleCandidatesService
          .addCandidate(database: project.database, roleId: roleId!, personId: personId)
          .maybeValueOrFail;

      final dayId = await projectsManager.scheduleService
          .createDay(database: project.database, date: DateTime(2026, 8, 10))
          .maybeValueOrFail;
      final schedule = await projectsManager.scheduleService
          .loadSchedule(database: project.database)
          .valueOrFail;

      return (schedule.slotsByDayId[dayId]!.single.id, roleCandidateId!);
    }

    test("reads every live candidacy of the project into the state", () async {
      final (_, roleCandidateId) = await seedCastingDay();

      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.roleCandidates.map((candidate) => candidate.id), [roleCandidateId]);
      expect(state.roleCandidateById[roleCandidateId]!.person.displayName, contains("Camille"));

      await bloc.close();
    });
  });

  group("coming back from the project settings page", () {
    test("drops an episode the settings page deleted", () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
      final project = projectsManager.currentProject!;

      final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
        database: project.database,
      );
      expect(secondEpisodeId, isNotNull);
      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: secondEpisodeId!,
        fountainText: "EXT. STREET - NIGHT\n\nAction two.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );

      final secondSceneId = (await (project.database.select(
        project.database.ocptScenesTable,
      )..where((table) => table.screenplayId.equals(secondEpisodeId))).get()).single.id;
      await projectsManager.shotListService.createShot(
        database: project.database,
        screenplayId: secondEpisodeId,
        sceneId: secondSceneId,
      );

      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      expect(bloc.state.episodes, hasLength(2));

      // What the settings page's own Episodes card writes before it pops.
      expect(
        await projectsManager.screenplayService.deleteEpisode(
          database: project.database,
          screenplayId: secondEpisodeId,
        ),
        isTrue,
      );

      bloc.add(const OcptScheduleProjectSettingsChangedEvent());
      final state = await waitForState(bloc, (state) => state.episodes.length == 1);

      expect(state.episodes.single.id, project.primaryScreenplayId);
      expect(
        state.unplacedGroups.map((group) => group.heading),
        isNot(contains("EXT. STREET - NIGHT")),
        reason:
            "a deleted episode's shots must not stay on the board — this mode shows no episode "
            "selector, so no keyed remount tells it the project lost one",
      );

      await bloc.close();
    });
  });

  group("selecting a shot", () {
    test("selects it and clears the selected block", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(OcptScheduleBlockSelectedEvent(blockId: fixture.blockId, dayId: fixture.dayId));
      final withBlock = await waitForState(bloc, (state) => state.selectedBlockId != null);
      expect(withBlock.selectedBlockId, fixture.blockId);

      bloc.add(OcptScheduleShotSelectedEvent(shotId: fixture.shotId));
      final withShot = await waitForState(bloc, (state) => state.selectedShotId != null);

      expect(withShot.selectedShotId, fixture.shotId);
      expect(
        withShot.selectedBlockId,
        isNull,
        reason:
            "the two selections are mutually exclusive: bringing the shot's own read-out up "
            "must not leave a stale block one showing underneath it",
      );

      await bloc.close();
    });

    test("is ignored when the shot id names no live shot", () async {
      await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptScheduleShotSelectedEvent(shotId: "not-a-shot"));
      // Nothing ever selects for a rejected shot id, so the selection stays unset — a short delay
      // gives the (deliberately no-op) handler a chance to run first.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.selectedShotId, isNull);
      expect(bloc.state.rightDockTab, isNull);

      await bloc.close();
    });
  });

  group("selecting a block", () {
    test("clears the selected shot", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(OcptScheduleShotSelectedEvent(shotId: fixture.shotId));
      final withShot = await waitForState(bloc, (state) => state.selectedShotId != null);
      expect(withShot.selectedShotId, fixture.shotId);

      bloc.add(OcptScheduleBlockSelectedEvent(blockId: fixture.blockId, dayId: fixture.dayId));
      final withBlock = await waitForState(bloc, (state) => state.selectedBlockId != null);

      expect(withBlock.selectedBlockId, fixture.blockId);
      expect(withBlock.selectedShotId, isNull);

      await bloc.close();
    });
  });

  group("changing a day's date", () {
    test("renumbers the days when it moves one before the first", () async {
      final fixture = await writePlacedShot();
      final project = projectsManager.currentProject!;

      // A second day, later than the fixture's own — J2 for now.
      final laterDayId = await projectsManager.scheduleService
          .createDay(database: project.database, date: DateTime(2026, 8, 20))
          .maybeValueOrFail;
      expect(laterDayId, isNotNull);

      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      expect(loaded.days.firstWhere((day) => day.id == fixture.dayId).dayNumber, 1);
      expect(loaded.days.firstWhere((day) => day.id == laterDayId).dayNumber, 2);

      // Re-dating the second day to before the first flips their order: `dayNumber` is a
      // read-time rank over `date`, not a stored column, so it follows the new date.
      bloc.add(OcptScheduleDayDateChangedEvent(dayId: laterDayId!, date: DateTime(2026, 8)));
      final redated = await waitForState(
        bloc,
        (state) => state.days.firstWhere((day) => day.id == laterDayId).dayNumber == 1,
      );

      expect(redated.days.firstWhere((day) => day.id == fixture.dayId).dayNumber, 2);

      await bloc.close();
    });
  });

  group("selecting a day", () {
    test("clears both the selected block and the selected shot", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(OcptScheduleBlockSelectedEvent(blockId: fixture.blockId, dayId: fixture.dayId));
      await waitForState(bloc, (state) => state.selectedBlockId != null);

      bloc.add(OcptScheduleShotSelectedEvent(shotId: fixture.shotId));
      await waitForState(
        bloc,
        (state) => state.selectedShotId != null && state.selectedBlockId == null,
      );

      bloc.add(OcptScheduleDaySelectedEvent(dayId: fixture.dayId));
      final withDay = await waitForState(bloc, (state) => state.selectedShotId == null);

      expect(withDay.selectedDayId, fixture.dayId);
      expect(withDay.selectedBlockId, isNull);
      expect(withDay.selectedShotId, isNull);

      await bloc.close();
    });
  });

  group("the epochs views react to", () {
    test("loading moves both, the selection with the load cause", () async {
      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.reloadEpoch, 1);
      expect(state.selectionEpoch, 1);
      expect(state.selectionCause, OcptScheduleSelectionCause.load);

      await bloc.close();
    });

    test("selecting a day, a block and a shot moves the selection epoch alone", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      var state = await waitForState(bloc, (state) => !state.isLoading);
      final reloadEpoch = state.reloadEpoch;
      var selectionEpoch = state.selectionEpoch;

      bloc.add(OcptScheduleDaySelectedEvent(dayId: fixture.dayId));
      state = await waitForState(bloc, (state) => state.selectionEpoch == selectionEpoch + 1);
      expect(state.selectionCause, OcptScheduleSelectionCause.day);
      selectionEpoch = state.selectionEpoch;

      bloc.add(OcptScheduleBlockSelectedEvent(blockId: fixture.blockId, dayId: fixture.dayId));
      state = await waitForState(bloc, (state) => state.selectionEpoch == selectionEpoch + 1);
      expect(state.selectionCause, OcptScheduleSelectionCause.block);
      selectionEpoch = state.selectionEpoch;

      bloc.add(OcptScheduleShotSelectedEvent(shotId: fixture.shotId));
      state = await waitForState(bloc, (state) => state.selectionEpoch == selectionEpoch + 1);
      expect(state.selectionCause, OcptScheduleSelectionCause.shot);
      selectionEpoch = state.selectionEpoch;

      bloc.add(OcptScheduleDaySelectedEvent(dayId: fixture.dayId));
      state = await waitForState(bloc, (state) => state.selectionEpoch == selectionEpoch + 1);
      expect(state.selectedDayId, fixture.dayId, reason: 'the same day again still moves it');
      expect(state.reloadEpoch, reloadEpoch, reason: 'selecting reads nothing again');

      await bloc.close();
    });

    test("a write that reads the schedule again moves the reload epoch alone", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      var state = await waitForState(bloc, (state) => !state.isLoading);
      final reloadEpoch = state.reloadEpoch;
      final selectionEpoch = state.selectionEpoch;

      bloc.add(OcptScheduleDayDateChangedEvent(dayId: fixture.dayId, date: DateTime(2026, 8, 12)));
      state = await waitForState(bloc, (state) => state.reloadEpoch == reloadEpoch + 1);

      expect(state.selectionEpoch, selectionEpoch);

      await bloc.close();
    });

    test("deleting the selected day drops the selection and says so", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      var state = await waitForState(bloc, (state) => !state.isLoading);
      expect(state.selectedDayId, fixture.dayId);
      final selectionEpoch = state.selectionEpoch;

      bloc.add(OcptScheduleDayDeletionConfirmedEvent(dayId: fixture.dayId));
      state = await waitForState(bloc, (state) => state.selectionEpoch == selectionEpoch + 1);

      expect(state.selectedDayId, isNull, reason: 'nothing is selected in its place');
      expect(state.selectionCause, OcptScheduleSelectionCause.dropped);

      await bloc.close();
    });

    test("creating a day selects it, with its own cause", () async {
      await writePlacedShot();
      final bloc = buildBloc();
      var state = await waitForState(bloc, (state) => !state.isLoading);
      final selectionEpoch = state.selectionEpoch;

      bloc.add(OcptScheduleDayCreatedEvent(date: DateTime(2026, 9)));
      state = await waitForState(
        bloc,
        (state) =>
            state.selectionCause == OcptScheduleSelectionCause.dayAdded &&
            state.selectionEpoch > selectionEpoch,
      );

      expect(state.selectedDay?.date, DateTime(2026, 9));

      await bloc.close();
    });
  });
}
