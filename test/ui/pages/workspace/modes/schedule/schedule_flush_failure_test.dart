// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_day_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The fixed device id the failing service stamps its writes with.
Future<String> _testDeviceId() async => "test-device";

/// A router manager whose [pop] does nothing: these tests never leave the workspace.
class _SilentRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A schedule service whose slot writes fail while [isFailing] is set, as a full disk would.
class _FlakyScheduleService extends OcptScheduleService {
  /// Whether [updateSlot] throws.
  bool isFailing = true;

  /// Class constructor
  _FlakyScheduleService() : super(logger: const SilentLogger(), deviceId: _testDeviceId);

  @override
  Future<void> updateSlot({
    required OcptProjectDatabase database,
    required String slotId,
    Value<String> label = const Value.absent(),
    Value<String?> locationId = const Value.absent(),
    Value<String?> setId = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (isFailing) {
      throw StateError("slot write intentionally failed for the test");
    }
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

/// A save location service recording that it was asked, and answering [answer].
class _RecordingSaveLocationService extends OcptSaveLocationService {
  /// The path handed back.
  final String answer;

  /// How many times a save location was asked for.
  int askCount = 0;

  /// Class constructor
  _RecordingSaveLocationService({required this.answer}) : super(logger: const SilentLogger());

  @override
  Future<String?> pickSaveLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
    String? initialDirectory,
  }) async {
    askCount++;
    return answer;
  }
}

void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late _RecordingSaveLocationService saveLocationService;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_schedule_flush_failure_test_");
    saveLocationService = _RecordingSaveLocationService(answer: p.join(tempDir.path, "a.ocptz"));
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

  /// A mode bloc, its day bloc writing through [service], a slot with a slot label typed into it
  /// that the failing service refuses to write, and a saved version.
  Future<
    ({
      OcptScheduleBloc mode,
      OcptScheduleDayBloc day,
      String slotId,
      String versionId,
      Future<void> Function() close,
    })
  >
  setUpTypedEdit(_FlakyScheduleService service) async {
    final project = projectsManager.currentProject!;
    final dayId = await projectsManager.scheduleService.createDay(
      database: project.database,
      date: DateTime(2026, 8, 10),
    );
    final snapshot = await projectsManager.scheduleService.loadSchedule(database: project.database);
    final slotId = snapshot.slotsByDayId[dayId]!.single.id;
    final version = await projectsManager.createProjectVersion(name: "v1", note: "");

    final mode = OcptScheduleBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      ),
    );
    final day = OcptScheduleDayBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      scheduleService: service,
      fieldEditDebounce: const Duration(days: 1),
    );
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));

    day.add(
      OcptScheduleFieldChangedEvent(
        targetId: slotId,
        field: OcptScheduleField.slotLabel,
        rawValue: "Cave",
      ),
    );
    await day.stream.firstWhere((state) => state.pendingFieldEdits.isNotEmpty);

    return (
      mode: mode,
      day: day,
      slotId: slotId,
      versionId: version!.id,
      close: () async {
        await day.close();
        await mode.close();
      },
    );
  }

  group("a typed edit the database refuses", () {
    test("is not lost to a version preview, which does not start", () async {
      final service = _FlakyScheduleService();
      final fixture = await setUpTypedEdit(service);

      fixture.mode.add(OcptProjectVersionPreviewRequestedEvent(versionId: fixture.versionId));
      await pumpEventQueue(times: 200);

      expect(fixture.mode.state.isPreviewingVersion, isFalse);
      expect(fixture.day.state.pendingFieldEdits, isNotEmpty);

      service.isFailing = false;
      fixture.mode.add(OcptProjectVersionPreviewRequestedEvent(versionId: fixture.versionId));
      await fixture.mode.stream.firstWhere((state) => state.isPreviewingVersion);

      await fixture.close();
    });

    test("is not lost to a restore, which does not run", () async {
      final service = _FlakyScheduleService();
      final fixture = await setUpTypedEdit(service);
      final project = projectsManager.currentProject!;
      await projectsManager.scheduleService.createDay(
        database: project.database,
        date: DateTime(2026, 8, 11),
      );
      final versionCount = (await projectsManager.listProjectVersions()).length;

      fixture.mode.add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: fixture.versionId,
          safetyVersionName: "safety",
        ),
      );
      await pumpEventQueue(times: 200);

      expect(
        (await projectsManager.listProjectVersions()).length,
        versionCount,
        reason: "a restore of a changed working copy takes a safety version",
      );
      expect(fixture.day.state.pendingFieldEdits, isNotEmpty);

      await fixture.close();
    });

    test("is not lost to a version being saved, which does not run", () async {
      final service = _FlakyScheduleService();
      final fixture = await setUpTypedEdit(service);
      final versionCount = (await projectsManager.listProjectVersions()).length;

      fixture.mode.add(const OcptProjectVersionCreationRequestedEvent(name: "v2", note: ""));
      await pumpEventQueue(times: 200);

      expect((await projectsManager.listProjectVersions()).length, versionCount);
      expect(fixture.day.state.pendingFieldEdits, isNotEmpty);

      await fixture.close();
    });

    test("is not lost to a project package, which is not written", () async {
      final service = _FlakyScheduleService();
      final fixture = await setUpTypedEdit(service);

      fixture.mode.add(const OcptProjectPackageExportRequestedEvent(fileTypeLabel: "Package"));
      await pumpEventQueue(times: 200);

      expect(saveLocationService.askCount, 0);
      expect(File(saveLocationService.answer).existsSync(), isFalse);
      expect(fixture.day.state.pendingFieldEdits, isNotEmpty);

      await fixture.close();
    });

    test("is not lost to a right dock tab change, which does not happen", () async {
      final service = _FlakyScheduleService();
      final fixture = await setUpTypedEdit(service);
      final tab = fixture.mode.state.rightDockTab;

      fixture.mode.add(
        const OcptScheduleRightDockTabSelectedEvent(tab: OcptScheduleRightDockTab.versions),
      );
      await pumpEventQueue(times: 200);

      expect(fixture.mode.state.rightDockTab, tab);
      expect(fixture.day.state.pendingFieldEdits, isNotEmpty);

      await fixture.close();
    });
  });
}
