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
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
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

void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() resolvable; the bloc's dependencies
    // themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_schedule_bloc_test_");
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
  Future<({String shotId, String dayId, String blockId})>
  writePlacedShot() async {
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

    final dayId = await projectsManager.scheduleService.createDay(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      date: DateTime(2026, 8, 10),
    );
    expect(dayId, isNotNull);

    final snapshot = await projectsManager.scheduleService.loadSchedule(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    final slotId = snapshot.slotsByDayId[dayId]!.single.id;

    final blockId = await projectsManager.scheduleService.placeShot(
      database: project.database,
      slotId: slotId,
      shotId: shotId!,
    );
    expect(blockId, isNotNull);

    return (shotId: shotId, dayId: dayId!, blockId: blockId!);
  }

  /// Builds a bloc wired to the test project.
  OcptScheduleBloc buildBloc() => OcptScheduleBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptScheduleState> waitForState(
    OcptScheduleBloc bloc,
    bool Function(OcptScheduleState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream
        .firstWhere(predicate)
        .timeout(const Duration(seconds: 5));
  }

  group("selecting a shot", () {
    test("selects it and clears the selected block", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        OcptScheduleBlockSelectedEvent(
          blockId: fixture.blockId,
          dayId: fixture.dayId,
        ),
      );
      final withBlock = await waitForState(
        bloc,
        (state) => state.selectedBlockId != null,
      );
      expect(withBlock.selectedBlockId, fixture.blockId);

      bloc.add(OcptScheduleShotSelectedEvent(shotId: fixture.shotId));
      final withShot = await waitForState(
        bloc,
        (state) => state.selectedShotId != null,
      );

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
      final withShot = await waitForState(
        bloc,
        (state) => state.selectedShotId != null,
      );
      expect(withShot.selectedShotId, fixture.shotId);

      bloc.add(
        OcptScheduleBlockSelectedEvent(
          blockId: fixture.blockId,
          dayId: fixture.dayId,
        ),
      );
      final withBlock = await waitForState(
        bloc,
        (state) => state.selectedBlockId != null,
      );

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
      final laterDayId = await projectsManager.scheduleService.createDay(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        date: DateTime(2026, 8, 20),
      );
      expect(laterDayId, isNotNull);

      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      expect(
        loaded.days.firstWhere((day) => day.id == fixture.dayId).dayNumber,
        1,
      );
      expect(
        loaded.days.firstWhere((day) => day.id == laterDayId).dayNumber,
        2,
      );

      // Re-dating the second day to before the first flips their order: `dayNumber` is a
      // read-time rank over `date`, not a stored column, so it follows the new date.
      bloc.add(
        OcptScheduleDayDateChangedEvent(dayId: laterDayId!, date: DateTime(2026, 8)),
      );
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

      bloc.add(
        OcptScheduleBlockSelectedEvent(
          blockId: fixture.blockId,
          dayId: fixture.dayId,
        ),
      );
      await waitForState(bloc, (state) => state.selectedBlockId != null);

      bloc.add(OcptScheduleShotSelectedEvent(shotId: fixture.shotId));
      await waitForState(
        bloc,
        (state) =>
            state.selectedShotId != null && state.selectedBlockId == null,
      );

      bloc.add(OcptScheduleDaySelectedEvent(dayId: fixture.dayId));
      final withDay = await waitForState(
        bloc,
        (state) => state.selectedShotId == null,
      );

      expect(withDay.selectedDayId, fixture.dayId);
      expect(withDay.selectedBlockId, isNull);
      expect(withDay.selectedShotId, isNull);

      await bloc.close();
    });
  });
}
