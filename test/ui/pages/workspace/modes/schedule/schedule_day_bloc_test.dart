// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_day_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_day_state.dart';
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

/// The fixed device id [_CountingScheduleService] stamps its writes with.
Future<String> _testDeviceId() async => "test-device";

/// A schedule service that records every slot write it is asked for, then makes it.
class _CountingScheduleService extends OcptScheduleService {
  /// The label of each slot write, in the order they were made.
  final List<String?> slotLabelWrites = [];

  /// Whether [loadSchedule] answers a failure.
  bool loadFails = false;

  /// Class constructor
  _CountingScheduleService() : super(logger: const SilentLogger(), deviceId: _testDeviceId);

  /// Fail when told to, otherwise load the schedule as the real service does.
  @override
  Future<OcptDatabaseResult<OcptScheduleSnapshot>> loadSchedule({
    required OcptProjectDatabase database,
  }) async {
    if (loadFails) {
      return const OcptDatabaseResult(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "schedule read intentionally failed for the test",
      );
    }

    return super.loadSchedule(database: database);
  }

  /// Remember the label written, then update the slot as the real service does.
  @override
  Future<OcptDatabaseOutcome> updateSlot({
    required OcptProjectDatabase database,
    required String slotId,
    Value<String> label = const Value.absent(),
    Value<String?> locationId = const Value.absent(),
    Value<String?> setId = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) {
    slotLabelWrites.add(label.present ? label.value : null);
    return super.updateSlot(
      database: database,
      slotId: slotId,
      label: label,
      locationId: locationId,
      setId: setId,
      notes: notes,
    );
  }
}

/// How long a day bloc waits before it writes what was typed, for the tests that wait for it.
const _shortDebounce = Duration(milliseconds: 60);

/// A debounce no test waits out, for the tests that must find an edit still pending.
const _neverDebounce = Duration(days: 1);

/// Run the tests of [OcptScheduleDayBloc].
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_schedule_day_bloc_test_");
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
  /// and places the shot on that slot.
  Future<({String shotId, String dayId, String slotId, String blockId})> writePlacedShot() async {
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

    return (shotId: shotId, dayId: dayId!, slotId: slotId, blockId: blockId!);
  }

  /// Reads the schedule straight from the database.
  Future<OcptScheduleSnapshot> readSchedule() => projectsManager.scheduleService
      .loadSchedule(database: projectsManager.currentProject!.database)
      .valueOrFail;

  /// Builds the mode bloc wired to the test project.
  OcptScheduleBloc buildBloc() => OcptScheduleBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the day bloc of [modeBloc], writing what is typed after [fieldEditDebounce].
  OcptScheduleDayBloc buildDay(
    OcptScheduleBloc modeBloc, {
    Duration fieldEditDebounce = _shortDebounce,
  }) => OcptScheduleDayBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    fieldEditDebounce: fieldEditDebounce,
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

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptScheduleDayState> waitForDayState(
    OcptScheduleDayBloc bloc,
    bool Function(OcptScheduleDayState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Types [value] into the label of slot [slotId].
  void typeSlotLabel(OcptScheduleDayBloc dayBloc, String slotId, String value) => dayBloc.add(
    OcptScheduleFieldChangedEvent(
      targetId: slotId,
      field: OcptScheduleField.slotLabel,
      rawValue: value,
    ),
  );

  group("planning an audition", () {
    /// A part, somebody seen for it, and a day with one slot: what an audition is planned on.
    /// Returns the slot and the candidacy.
    Future<(String slotId, String roleCandidateId)> seedCastingDay() async {
      final project = projectsManager.currentProject!;

      final roleId = await projectsManager.roleIndexService
          .addRole(
            database: project.database,
            screenplayId: project.primaryScreenplayId,
            name: "MARIE",
            kind: OcptRoleKind.silent,
          )
          .maybeValueOrFail;
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

    test(
      "an audition block is created in place, and its candidacies named onto it after",
      () async {
        final (slotId, roleCandidateId) = await seedCastingDay();

        final bloc = buildBloc();
        final dayBloc = buildDay(bloc);
        await waitForState(bloc, (state) => !state.isLoading);

        // Created like every other block that names no row of another table: nothing is asked at
        // creation, and an audition naming nobody yet is an ordinary state.
        dayBloc.add(
          OcptScheduleBlockCreatedEvent(slotId: slotId, kind: OcptShootingBlockKind.audition),
        );
        final created = await waitForState(bloc, (state) => state.selectedDayBlocks.isNotEmpty);
        final block = created.selectedDayBlocks.single;
        expect(block.kind, OcptShootingBlockKind.audition);
        expect(block.candidates, isEmpty);

        // Then the row's own picker says who is seen at that hour, and for which part.
        dayBloc.add(
          OcptScheduleBlockCandidateAddedEvent(blockId: block.id, roleCandidateId: roleCandidateId),
        );
        final named = await waitForState(
          bloc,
          (state) => state.selectedDayBlocks.single.candidates.isNotEmpty,
        );
        final link = named.selectedDayBlocks.single.candidates.single;
        expect(link.roleCandidateId, roleCandidateId);

        // And taking them back off leaves the audition exactly where it is.
        dayBloc.add(OcptScheduleBlockCandidateRemovedEvent(blockCandidateId: link.id));
        final emptied = await waitForState(
          bloc,
          (state) => state.selectedDayBlocks.single.candidates.isEmpty,
        );
        expect(emptied.selectedDayBlocks.single.kind, OcptShootingBlockKind.audition);

        await dayBloc.close();
        await bloc.close();
      },
    );
  });

  group("writing the day", () {
    test("creating a slot writes it and has the mode read the schedule again", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc);
      var state = await waitForState(bloc, (state) => !state.isLoading);
      expect(state.selectedDaySlots, hasLength(1));
      final reloadEpoch = state.reloadEpoch;
      final selectionEpoch = state.selectionEpoch;

      dayBloc.add(OcptScheduleSlotCreatedEvent(dayId: fixture.dayId));
      state = await waitForState(bloc, (state) => state.selectedDaySlots.length == 2);

      expect(state.reloadEpoch, reloadEpoch + 1);
      expect(state.selectionEpoch, selectionEpoch, reason: 'writing a slot selects nothing');
      expect((await readSchedule()).slotsByDayId[fixture.dayId], hasLength(2));

      await dayBloc.close();
      await bloc.close();
    });

    test("changing a shot's status writes it and has the mode read the shot lists again", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc);
      var state = await waitForState(bloc, (state) => !state.isLoading);
      expect(state.shotById(fixture.shotId)!.status, OcptShotStatus.toShoot);
      final reloadEpoch = state.reloadEpoch;

      dayBloc.add(
        OcptScheduleShotStatusChangedEvent(shotId: fixture.shotId, status: OcptShotStatus.shot),
      );
      state = await waitForState(
        bloc,
        (state) => state.shotById(fixture.shotId)!.status == OcptShotStatus.shot,
      );

      expect(state.reloadEpoch, reloadEpoch + 1);

      await dayBloc.close();
      await bloc.close();
    });

    test("deleting the selected block leaves the day selected and the block gone", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      bloc.add(OcptScheduleBlockSelectedEvent(blockId: fixture.blockId, dayId: fixture.dayId));
      var state = await waitForState(bloc, (state) => state.selectedBlockId != null);
      final selectionEpoch = state.selectionEpoch;

      dayBloc.add(OcptScheduleBlockDeletionConfirmedEvent(blockId: fixture.blockId));
      state = await waitForState(bloc, (state) => state.selectedBlockId == null);

      expect(state.selectedDayId, fixture.dayId);
      expect(state.selectionEpoch, selectionEpoch + 1);
      expect(state.selectionCause, OcptScheduleSelectionCause.dropped);

      await dayBloc.close();
      await bloc.close();
    });

    test("a write while the Versions tab is open makes the working copy card read again", () async {
      final fixture = await writePlacedShot();
      expect(await projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      bloc.add(const OcptScheduleRightDockTabSelectedEvent(tab: OcptScheduleRightDockTab.versions));
      var state = await waitForState(bloc, (state) => state.workingCopy != null);
      expect(state.workingCopy!.isModifiedSinceBase, isFalse);

      // The working copy is captured at most once every two real seconds.
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      dayBloc.add(OcptScheduleSlotCreatedEvent(dayId: fixture.dayId));
      state = await waitForState(bloc, (state) => state.workingCopy?.isModifiedSinceBase == true);

      expect(state.selectedDaySlots, hasLength(2));

      await dayBloc.close();
      await bloc.close();
    });
  });

  group("the typed fields", () {
    test("a typed field shows at once, is written after its debounce and forgotten then", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      typeSlotLabel(dayBloc, fixture.slotId, "Cave");
      var dayState = await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.isNotEmpty);
      expect(dayState.fieldValueOf(fixture.slotId, OcptScheduleField.slotLabel, ""), "Cave");

      dayState = await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.isEmpty);

      expect((await readSchedule()).slotsByDayId[fixture.dayId]!.single.label, "Cave");
      expect(bloc.state.selectedDaySlots.single.label, "Cave");
      expect(dayState.fieldValueOf(fixture.slotId, OcptScheduleField.slotLabel, "x"), "x");

      await dayBloc.close();
      await bloc.close();
    });

    test("selecting another day, a block or a shot flushes nothing", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      typeSlotLabel(dayBloc, fixture.slotId, "Cave");
      await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      bloc.add(OcptScheduleBlockSelectedEvent(blockId: fixture.blockId, dayId: fixture.dayId));
      await waitForState(bloc, (state) => state.selectedBlockId != null);
      bloc.add(OcptScheduleShotSelectedEvent(shotId: fixture.shotId));
      await waitForState(bloc, (state) => state.selectedShotId != null);
      bloc.add(OcptScheduleDaySelectedEvent(dayId: fixture.dayId));
      await waitForState(bloc, (state) => state.selectedShotId == null);
      bloc.add(const OcptScheduleCentreViewSelectedEvent(view: OcptScheduleCentreView.agenda));
      await waitForState(bloc, (state) => state.centreView == OcptScheduleCentreView.agenda);
      await pumpEventQueue();

      expect(dayBloc.state.pendingFieldEdits, isNotEmpty);
      expect((await readSchedule()).slotsByDayId[fixture.dayId]!.single.label, isEmpty);

      await dayBloc.close();
      await bloc.close();
    });

    test("a flush whose re-read fails after the write stops what it was for", () async {
      final fixture = await writePlacedShot();
      final service = _CountingScheduleService();
      // A failed read is answered, not raised: nothing may reach the zone as an uncaught error.
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        final bloc = OcptScheduleBloc(
          projectsManager: projectsManager,
          propertiesManager: propertiesManager,
          routerManager: _RecordingRouterManager(),
          exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
          scheduleService: service,
        );
        final dayBloc = OcptScheduleDayBloc(
          modeBloc: bloc,
          projectsManager: projectsManager,
          scheduleService: service,
          fieldEditDebounce: _neverDebounce,
        );
        await waitForState(bloc, (state) => !state.isLoading);
        typeSlotLabel(dayBloc, fixture.slotId, "Cave");
        await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.isNotEmpty);

        service.loadFails = true;
        expect(await bloc.flushAllPendingWrites(), isFalse);

        // The write landed, but the mode could not read it back: nothing may go on as if it had.
        service.loadFails = false;
        expect((await readSchedule()).slotsByDayId[fixture.dayId]!.single.label, "Cave");
        expect(dayBloc.state.pendingFieldEdits, isNotEmpty);

        expect(await bloc.flushAllPendingWrites(), isTrue);
        expect(dayBloc.state.pendingFieldEdits, isEmpty);

        await dayBloc.close();
        await bloc.close();
      }, (error, stackTrace) => uncaught.add(error));

      expect(uncaught, isEmpty);
    });

    test("a debounced edit whose re-read fails stays pending and is written again", () async {
      final fixture = await writePlacedShot();
      final service = _CountingScheduleService();
      // A failed read is answered, not raised: this test is about the edit.
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        final bloc = OcptScheduleBloc(
          projectsManager: projectsManager,
          propertiesManager: propertiesManager,
          routerManager: _RecordingRouterManager(),
          exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
          scheduleService: service,
        );
        final dayBloc = OcptScheduleDayBloc(
          modeBloc: bloc,
          projectsManager: projectsManager,
          scheduleService: service,
          fieldEditDebounce: _shortDebounce,
        );
        await waitForState(bloc, (state) => !state.isLoading);

        // The timer fires, the write lands and the read after it fails.
        service.loadFails = true;
        typeSlotLabel(dayBloc, fixture.slotId, "Cave");
        while (service.slotLabelWrites.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await pumpEventQueue();

        service.loadFails = false;
        expect((await readSchedule()).slotsByDayId[fixture.dayId]!.single.label, "Cave");
        expect(
          dayBloc.state.pendingFieldEdits,
          isNotEmpty,
          reason: "what is on screen is still the older data",
        );

        expect(await bloc.flushAllPendingWrites(), isTrue);
        expect(dayBloc.state.pendingFieldEdits, isEmpty);
        expect(service.slotLabelWrites, ["Cave", "Cave"]);

        await dayBloc.close();
        await bloc.close();
      }, (error, stackTrace) => uncaught.add(error));

      expect(uncaught, isEmpty);
    });

    test("flushing every pending write writes the edit and has the mode read it back", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      typeSlotLabel(dayBloc, fixture.slotId, "Cave");
      await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.isNotEmpty);
      final reloadEpoch = bloc.state.reloadEpoch;

      await bloc.flushAllPendingWrites();

      expect((await readSchedule()).slotsByDayId[fixture.dayId]!.single.label, "Cave");
      expect(bloc.state.selectedDaySlots.single.label, "Cave");
      expect(bloc.state.reloadEpoch, reloadEpoch + 1);
      expect(dayBloc.state.pendingFieldEdits, isEmpty);

      await dayBloc.close();
      await bloc.close();
    });

    test(
      "an edit written when the widget leaves is not written again when the bloc closes",
      () async {
        final fixture = await writePlacedShot();
        final bloc = buildBloc();
        final service = _CountingScheduleService();
        final dayBloc = OcptScheduleDayBloc(
          modeBloc: bloc,
          projectsManager: projectsManager,
          scheduleService: service,
          fieldEditDebounce: _neverDebounce,
        );
        await waitForState(bloc, (state) => !state.isLoading);
        typeSlotLabel(dayBloc, fixture.slotId, "Cave");
        await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.isNotEmpty);

        // What the widget leaving the tree does: the flush starts, and the bloc closes in the same
        // frame, before the write is done.
        final flushing = bloc.flushPendingFieldEdits();
        await dayBloc.close();
        await bloc.close();
        await flushing;

        expect(service.slotLabelWrites, ["Cave"], reason: "one edit, one write, one row stamp");
        expect(dayBloc.state.pendingFieldEdits, isNotEmpty, reason: "nothing could be emitted");
      },
    );

    test("an edit changed after the widget left is written again when the bloc closes", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      final service = _CountingScheduleService();
      final dayBloc = OcptScheduleDayBloc(
        modeBloc: bloc,
        projectsManager: projectsManager,
        scheduleService: service,
        fieldEditDebounce: _neverDebounce,
      );
      await waitForState(bloc, (state) => !state.isLoading);
      typeSlotLabel(dayBloc, fixture.slotId, "Cave");
      await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.isNotEmpty);
      await bloc.flushPendingFieldEdits();

      typeSlotLabel(dayBloc, fixture.slotId, "Forest");
      await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.values.contains("Forest"));
      await dayBloc.close();
      await bloc.close();

      expect(service.slotLabelWrites, ["Cave", "Forest"]);
      expect((await readSchedule()).slotsByDayId[fixture.dayId]!.single.label, "Forest");
    });

    test("flushing with nothing pending reads nothing", () async {
      await writePlacedShot();
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final reloadEpoch = bloc.state.reloadEpoch;

      await bloc.flushAllPendingWrites();

      expect(bloc.state.reloadEpoch, reloadEpoch);

      await dayBloc.close();
      await bloc.close();
    });

    test("the leaving flush writes straight to the database and touches no state", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      typeSlotLabel(dayBloc, fixture.slotId, "Cave");
      await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      await bloc.flushPendingFieldEdits();

      expect((await readSchedule()).slotsByDayId[fixture.dayId]!.single.label, "Cave");
      expect(dayBloc.state.pendingFieldEdits, isNotEmpty, reason: 'no state was emitted');

      await dayBloc.close();
      await bloc.close();
    });

    test("the mode reading everything again drops what was typed", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      typeSlotLabel(dayBloc, fixture.slotId, "Cave");
      await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      bloc.add(const OcptScheduleProjectSettingsChangedEvent());
      await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.isEmpty);

      expect((await readSchedule()).slotsByDayId[fixture.dayId]!.single.label, isEmpty);

      await dayBloc.close();
      await bloc.close();
    });

    test("an edit typed into a row that was deleted goes, the others stay", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      dayBloc.add(OcptScheduleSlotCreatedEvent(dayId: fixture.dayId));
      final state = await waitForState(bloc, (state) => state.selectedDaySlots.length == 2);
      final secondSlotId = state.selectedDaySlots.last.id;
      typeSlotLabel(dayBloc, fixture.slotId, "Cave");
      typeSlotLabel(dayBloc, secondSlotId, "Roof");
      await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.length == 2);

      dayBloc.add(OcptScheduleSlotDeletionConfirmedEvent(slotId: secondSlotId));
      final dayState = await waitForDayState(
        dayBloc,
        (state) => state.pendingFieldEdits.length == 1,
      );

      expect(dayState.pendingFieldEdits.keys.single.$1, fixture.slotId);

      await dayBloc.close();
      await bloc.close();
    });

    test(
      "a pending edit is written even when the day it was typed on is no longer shown",
      () async {
        final fixture = await writePlacedShot();
        final project = projectsManager.currentProject!;
        final otherDayId = await projectsManager.scheduleService
            .createDay(database: project.database, date: DateTime(2026, 8, 20))
            .maybeValueOrFail;
        final bloc = buildBloc();
        final dayBloc = buildDay(bloc);
        await waitForState(bloc, (state) => !state.isLoading);
        bloc.add(OcptScheduleDaySelectedEvent(dayId: fixture.dayId));
        await waitForState(bloc, (state) => state.selectedDayId == fixture.dayId);

        typeSlotLabel(dayBloc, fixture.slotId, "Cave");
        bloc.add(OcptScheduleDaySelectedEvent(dayId: otherDayId!));
        await waitForState(bloc, (state) => state.selectedDayId == otherDayId);
        await waitForDayState(dayBloc, (state) => state.pendingFieldEdits.isEmpty);

        expect((await readSchedule()).slotsByDayId[fixture.dayId]!.single.label, "Cave");

        await dayBloc.close();
        await bloc.close();
      },
    );
  });

  group("the bloc as a whole", () {
    /// Names [event] by the exhaustive switch over the four sealed hierarchies the bloc handles:
    /// adding an event to one makes this fail to compile until the list below names it too.
    String nameOf(OcptScheduleEvent event) => switch (event) {
      final OcptScheduleSlotsEvent slot => switch (slot) {
        OcptScheduleSlotCreatedEvent() => "slot created",
        OcptScheduleSlotPlaceChangedEvent() => "slot place",
        OcptScheduleSlotAnchorChangedEvent() => "slot anchor",
        OcptScheduleSlotReorderedEvent() => "slot reordered",
        OcptScheduleSlotDeletionConfirmedEvent() => "slot deleted",
        OcptScheduleSlotCrewMemberAddedEvent() => "crew added",
        OcptScheduleSlotCrewMemberPositionChangedEvent() => "crew position",
        OcptScheduleSlotCrewMemberRemovedEvent() => "crew removed",
        OcptScheduleSlotCastRoleAddedEvent() => "cast added",
        OcptScheduleSlotCastRoleRemovedEvent() => "cast removed",
        OcptScheduleSlotGuestAddedEvent() => "guest added",
        OcptScheduleSlotGuestRemovedEvent() => "guest removed",
      },
      final OcptScheduleBlocksEvent block => switch (block) {
        OcptScheduleBlockCandidateAddedEvent() => "candidate added",
        OcptScheduleBlockCandidateRemovedEvent() => "candidate removed",
        OcptScheduleShotStatusChangedEvent() => "shot status",
        OcptScheduleBlockCreatedEvent() => "block created",
        OcptScheduleShotBlockCreatedEvent() => "shot block created",
        OcptScheduleBlockDurationChangedEvent() => "block duration",
        OcptScheduleBlockAnchorChangedEvent() => "block anchor",
        OcptScheduleBlockSequenceChangedEvent() => "block sequence",
        OcptScheduleBlockReorderedEvent() => "block reordered",
        OcptScheduleBlockMovedToSlotEvent() => "block moved",
        OcptScheduleBlockDeletionConfirmedEvent() => "block deleted",
      },
      final OcptScheduleDayEventsEvent dayEvent => switch (dayEvent) {
        OcptScheduleDayEventCreatedEvent() => "event created",
        OcptScheduleDayEventMinuteChangedEvent() => "event minute",
        OcptScheduleDayEventDeletionConfirmedEvent() => "event deleted",
      },
      final OcptScheduleFieldsEvent field => switch (field) {
        OcptScheduleFieldChangedEvent() => "field changed",
        OcptScheduleFieldEditFlushRequestedEvent() => "field flush",
      },
      _ => throw StateError("not an event of the day bloc"),
    };

    test("every event of its hierarchies has a handler", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      final events = <OcptScheduleEvent>[
        OcptScheduleSlotCreatedEvent(dayId: fixture.dayId),
        OcptScheduleSlotPlaceChangedEvent(slotId: fixture.slotId, locationId: null, setId: null),
        OcptScheduleSlotAnchorChangedEvent(
          slotId: fixture.slotId,
          edge: OcptShootingSlotAnchorEdge.start,
          minute: 480,
          sourceSlotId: null,
        ),
        OcptScheduleSlotReorderedEvent(
          dayId: fixture.dayId,
          slotId: fixture.slotId,
          newPosition: 0,
        ),
        const OcptScheduleSlotDeletionConfirmedEvent(slotId: "s"),
        const OcptScheduleSlotCrewMemberAddedEvent(slotId: "s", personId: "p"),
        const OcptScheduleSlotCrewMemberPositionChangedEvent(
          crewMemberId: "c",
          positionId: "",
          customLabel: "Grip",
        ),
        const OcptScheduleSlotCrewMemberRemovedEvent(crewMemberId: "c"),
        const OcptScheduleSlotCastRoleAddedEvent(slotId: "s", roleId: "r"),
        const OcptScheduleSlotCastRoleRemovedEvent(castRoleId: "c"),
        const OcptScheduleSlotGuestAddedEvent(slotId: "s", personId: "p"),
        const OcptScheduleSlotGuestRemovedEvent(guestId: "g"),
        const OcptScheduleBlockCandidateAddedEvent(blockId: "b", roleCandidateId: "r"),
        const OcptScheduleBlockCandidateRemovedEvent(blockCandidateId: "c"),
        const OcptScheduleShotStatusChangedEvent(shotId: "s", status: OcptShotStatus.shot),
        OcptScheduleBlockCreatedEvent(slotId: fixture.slotId, kind: OcptShootingBlockKind.meal),
        const OcptScheduleShotBlockCreatedEvent(slotId: "s", shotId: "x"),
        const OcptScheduleBlockDurationChangedEvent(blockId: "b", durationMinutes: 30),
        const OcptScheduleBlockAnchorChangedEvent(blockId: "b", anchorMinute: null),
        const OcptScheduleBlockSequenceChangedEvent(blockId: "b", sceneId: null),
        const OcptScheduleBlockReorderedEvent(blockId: "b", newPosition: 0),
        const OcptScheduleBlockMovedToSlotEvent(blockId: "b", targetSlotId: "s"),
        const OcptScheduleBlockDeletionConfirmedEvent(blockId: "b"),
        OcptScheduleDayEventCreatedEvent(dayId: fixture.dayId, minute: 600),
        const OcptScheduleDayEventMinuteChangedEvent(eventId: "e", minute: 600),
        const OcptScheduleDayEventDeletionConfirmedEvent(eventId: "e"),
        const OcptScheduleFieldChangedEvent(
          targetId: "t",
          field: OcptScheduleField.slotNotes,
          rawValue: "",
        ),
        const OcptScheduleFieldEditFlushRequestedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(28));

      // With no project open every write handler returns at its first line: the handlers are
      // reached without any of the rows the events name having to exist.
      await projectsManager.closeCurrentProject();

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => dayBloc.add(event), returnsNormally, reason: nameOf(event));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await dayBloc.close();
      await bloc.close();
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.pendingWritesFlusherCount, 1);

      await dayBloc.close();
      await bloc.close();
    });

    test("a flush asked just as the mode closes neither hangs nor throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      final dayBloc = buildDay(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      typeSlotLabel(dayBloc, fixture.slotId, "Cave");

      unawaited(bloc.flushAllPendingWrites());
      await bloc.close().timeout(const Duration(seconds: 5));
      await dayBloc.close().timeout(const Duration(seconds: 5));
    });
  });
}
