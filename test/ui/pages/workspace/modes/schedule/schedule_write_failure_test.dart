// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
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
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_day_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A schedule service whose read fails while [isReadFailing] is set, and whose writes are the
/// real ones.
class _ReadFailsScheduleService extends OcptScheduleService {
  /// Whether [loadSchedule] answers a failure.
  bool isReadFailing = false;

  /// Class constructor
  _ReadFailsScheduleService() : super(logger: const SilentLogger(), deviceId: _testDeviceId);

  /// Fail as a refused read does while told to, otherwise read the schedule as the real service
  /// does.
  @override
  Future<OcptDatabaseResult<OcptScheduleSnapshot>> loadSchedule({
    required OcptProjectDatabase database,
  }) async {
    if (isReadFailing) {
      return const OcptDatabaseResult(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "schedule read intentionally failed for the test",
      );
    }

    return super.loadSchedule(database: database);
  }
}

/// The fixed device id [_ReadFailsScheduleService] stamps its writes with.
Future<String> _testDeviceId() async => "test-device";

/// A debounce no test waits out, so every typed edit stays pending until a flush.
const _neverDebounce = Duration(days: 1);

/// What the schedule blocs do when the database refuses a call, with a real SQLite failure (a
/// trigger that aborts the write, a table that is gone) rather than a double: the handler stops at
/// the call that failed, nothing is read again, nothing is emitted, and what was typed stays
/// pending.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptScheduleBloc mode;
  late OcptScheduleDayBloc day;
  late String dayId;
  late String slotId;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Build the mode bloc and the day bloc, writing through [service] when given, and wait for the
  /// mode to load.
  Future<void> buildBlocs({OcptScheduleService? service}) async {
    mode = OcptScheduleBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      scheduleService: service,
    );
    day = OcptScheduleDayBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      scheduleService: service,
      fieldEditDebounce: _neverDebounce,
    );
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_schedule_write_failure_test_");
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

    final database = projectsManager.currentProject!.database;
    final service = projectsManager.scheduleService;
    dayId = await service.createDay(database: database, date: DateTime(2026, 8, 10)).valueOrFail;
    slotId =
        (await service.loadSchedule(database: database).valueOrFail).slotsByDayId[dayId]!.single.id;
  });

  tearDown(() async {
    await day.close();
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Make every [verb] on [table] fail with a database error until [allow] is called.
  Future<void> refuse(String verb, String table) =>
      projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

  /// Lift the refusal [refuse] set.
  Future<void> allow(String verb, String table) => projectsManager.currentProject!.database
      .customStatement("DROP TRIGGER refuse_${verb.toLowerCase()}_$table");

  /// Read the whole schedule back from the database.
  Future<OcptScheduleSnapshot> readSchedule() => projectsManager.scheduleService
      .loadSchedule(database: projectsManager.currentProject!.database)
      .valueOrFail;

  /// Give the blocs time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  /// Type [value] into the label of the slot, which stays pending, and wait for it to be.
  Future<void> typeSlotLabel(String value) async {
    day.add(
      OcptScheduleFieldChangedEvent(
        targetId: slotId,
        field: OcptScheduleField.slotLabel,
        rawValue: value,
      ),
    );
    await day.stream.firstWhere((state) => state.pendingFieldEdits.isNotEmpty);
  }

  group("a write the database refuses", () {
    test("abandons slot creation: nothing is read again", () async {
      await buildBlocs();
      await refuse("INSERT", "shooting_slots");
      final epoch = mode.state.reloadEpoch;

      day.add(OcptScheduleSlotCreatedEvent(dayId: dayId));
      await settle();

      expect(mode.state.reloadEpoch, epoch);
      expect((await readSchedule()).slotsByDayId[dayId], hasLength(1));
    });

    test("abandons a slot deletion: nothing is read again and the slot stays", () async {
      await buildBlocs();
      await refuse("UPDATE", "shooting_slots");
      final epoch = mode.state.reloadEpoch;

      day.add(OcptScheduleSlotDeletionConfirmedEvent(slotId: slotId));
      await settle();

      expect(mode.state.reloadEpoch, epoch);
      expect((await readSchedule()).slotsByDayId[dayId], hasLength(1));
    });

    test("abandons a block creation: nothing is read again", () async {
      await buildBlocs();
      await refuse("INSERT", "shooting_day_blocks");
      final epoch = mode.state.reloadEpoch;

      day.add(OcptScheduleBlockCreatedEvent(slotId: slotId, kind: OcptShootingBlockKind.meal));
      await settle();

      expect(mode.state.reloadEpoch, epoch);
      expect((await readSchedule()).blocksByDayId[dayId] ?? const [], isEmpty);
    });

    test("abandons the creation of a day: no day is selected", () async {
      await buildBlocs();
      await refuse("INSERT", "shooting_days");
      final selectedDayId = mode.state.selectedDayId;
      final epoch = mode.state.reloadEpoch;

      mode.add(OcptScheduleDayCreatedEvent(date: DateTime(2026, 8, 11)));
      await settle();

      expect(mode.state.reloadEpoch, epoch);
      expect(mode.state.selectedDayId, selectedDayId);
      expect((await readSchedule()).days, hasLength(1));
    });

    test("abandons the duplication of a day: no day is selected", () async {
      await buildBlocs();
      await refuse("INSERT", "shooting_days");
      final selectedDayId = mode.state.selectedDayId;
      final epoch = mode.state.reloadEpoch;

      mode.add(
        OcptScheduleDayDuplicationRequestedEvent(sourceDayId: dayId, date: DateTime(2026, 8, 11)),
      );
      await settle();

      expect(mode.state.reloadEpoch, epoch);
      expect(mode.state.selectedDayId, selectedDayId);
      expect((await readSchedule()).days, hasLength(1));
    });

    test("abandons a day date change: nothing is read again", () async {
      await buildBlocs();
      await refuse("UPDATE", "shooting_days");
      final epoch = mode.state.reloadEpoch;

      mode.add(OcptScheduleDayDateChangedEvent(dayId: dayId, date: DateTime(2026, 9, 3)));
      await settle();

      expect(mode.state.reloadEpoch, epoch);
      expect((await readSchedule()).days.single.date, DateTime(2026, 8, 10));
    });

    test("leaves a deleted day whole when its cascade fails midway", () async {
      await buildBlocs();
      await refuse("UPDATE", "shooting_slots");
      final epoch = mode.state.reloadEpoch;

      mode.add(OcptScheduleDayDeletionConfirmedEvent(dayId: dayId));
      await settle();

      expect(mode.state.reloadEpoch, epoch);
      final schedule = await readSchedule();
      expect(schedule.days, hasLength(1), reason: "the day is tombstoned with its slots or not");
      expect(schedule.slotsByDayId[dayId], hasLength(1));
    });

    test("is written once the refusal is lifted", () async {
      await buildBlocs();
      await refuse("INSERT", "shooting_slots");
      day.add(OcptScheduleSlotCreatedEvent(dayId: dayId));
      await settle();
      await allow("INSERT", "shooting_slots");

      day.add(OcptScheduleSlotCreatedEvent(dayId: dayId));
      await settle();

      expect((await readSchedule()).slotsByDayId[dayId], hasLength(2));
    });
  });

  group("a read the database refuses", () {
    test("leaves the data the mode shows as it was, and answers that it did not read", () async {
      await buildBlocs();
      await projectsManager.currentProject!.database.customStatement(
        "ALTER TABLE shooting_days RENAME TO shooting_days_gone",
      );
      final snapshot = mode.state.snapshot;
      final epoch = mode.state.reloadEpoch;

      expect(await mode.reload({OcptScheduleReloadScope.schedule}), isFalse);

      expect(mode.state.snapshot, same(snapshot));
      expect(mode.state.reloadEpoch, epoch);
    });

    test("leaves the mode loading when it cannot read at all", () async {
      await projectsManager.currentProject!.database.customStatement(
        "ALTER TABLE shooting_days RENAME TO shooting_days_gone",
      );

      mode = OcptScheduleBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _SilentRouterManager(),
        exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      );
      day = OcptScheduleDayBloc(
        modeBloc: mode,
        projectsManager: projectsManager,
        fieldEditDebounce: _neverDebounce,
      );
      await settle();

      expect(mode.state.isLoading, isTrue);
    });

    test("stops a created day from being selected when it cannot be read back", () async {
      final service = _ReadFailsScheduleService();
      await buildBlocs(service: service);
      final selectedDayId = mode.state.selectedDayId;
      service.isReadFailing = true;

      mode.add(OcptScheduleDayCreatedEvent(date: DateTime(2026, 8, 11)));
      await settle();

      service.isReadFailing = false;
      expect((await readSchedule()).days, hasLength(2), reason: "the write itself landed");
      expect(mode.state.selectedDayId, selectedDayId);
    });

    test("stops a duplicated day from being selected when it cannot be read back", () async {
      final service = _ReadFailsScheduleService();
      await buildBlocs(service: service);
      final selectedDayId = mode.state.selectedDayId;
      service.isReadFailing = true;

      mode.add(
        OcptScheduleDayDuplicationRequestedEvent(sourceDayId: dayId, date: DateTime(2026, 8, 11)),
      );
      await settle();

      service.isReadFailing = false;
      expect((await readSchedule()).days, hasLength(2), reason: "the write itself landed");
      expect(mode.state.selectedDayId, selectedDayId);
    });
  });

  group("a restore whose data the mode cannot read again", () {
    test("stops before the version list is emitted over it", () async {
      final service = _ReadFailsScheduleService();
      await buildBlocs(service: service);
      final version = await projectsManager.createProjectVersion(name: "v1", note: "");
      await projectsManager.scheduleService
          .createDay(
            database: projectsManager.currentProject!.database,
            date: DateTime(2026, 8, 12),
          )
          .maybeValueOrFail;
      mode.add(const OcptProjectVersionsRefreshRequestedEvent());
      await settle();
      final listed = mode.state.projectVersions.length;
      service.isReadFailing = true;

      mode.add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: version!.id,
          safetyVersionName: "safety",
        ),
      );
      await settle();

      expect(
        (await projectsManager.listProjectVersions()).length,
        greaterThan(listed),
        reason: "the restore ran and took its safety version",
      );
      expect(mode.state.projectVersions, hasLength(listed));
    });
  });

  group("a typed edit the database refuses", () {
    test("stays pending, and the flush answers that it failed", () async {
      await buildBlocs();
      await typeSlotLabel("Cave");
      await refuse("UPDATE", "shooting_slots");
      final epoch = mode.state.reloadEpoch;

      expect(await mode.flushAllPendingWrites(), isFalse);

      expect(day.state.pendingFieldEdits, isNotEmpty);
      expect(mode.state.reloadEpoch, epoch, reason: "nothing is read back after a failed write");
      expect((await readSchedule()).slotsByDayId[dayId]!.single.label, isEmpty);
    });

    test("is written by the next flush once the refusal is lifted", () async {
      await buildBlocs();
      await typeSlotLabel("Cave");
      await refuse("UPDATE", "shooting_slots");
      expect(await mode.flushAllPendingWrites(), isFalse);
      await allow("UPDATE", "shooting_slots");

      expect(await mode.flushAllPendingWrites(), isTrue);

      expect(day.state.pendingFieldEdits, isEmpty);
      expect((await readSchedule()).slotsByDayId[dayId]!.single.label, "Cave");
    });

    test("stops the write at the first edit that fails", () async {
      await buildBlocs();
      await typeSlotLabel("Cave");
      day.add(
        OcptScheduleFieldChangedEvent(
          targetId: dayId,
          field: OcptScheduleField.dayNotes,
          rawValue: "Rain",
        ),
      );
      await day.stream.firstWhere((state) => state.pendingFieldEdits.length == 2);
      await refuse("UPDATE", "shooting_slots");

      expect(await mode.flushAllPendingWrites(), isFalse);

      expect((await readSchedule()).days.single.notes, isEmpty, reason: "the loop stopped");
    });

    test("is written again by a flush without state after a failed one", () async {
      await buildBlocs();
      await typeSlotLabel("Cave");
      await refuse("UPDATE", "shooting_slots");

      await day.flushPendingWritesWithoutState();

      expect((await readSchedule()).slotsByDayId[dayId]!.single.label, isEmpty);

      await allow("UPDATE", "shooting_slots");
      await day.flushPendingWritesWithoutState();

      expect((await readSchedule()).slotsByDayId[dayId]!.single.label, "Cave");
    });
  });
}
