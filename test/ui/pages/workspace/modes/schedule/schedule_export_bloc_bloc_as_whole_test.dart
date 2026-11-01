// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_result.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_sides_presentation.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_day_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'schedule_export_bloc_test_doubles.dart';

/// A schedule service whose slot writes always fail, as a full disk would.
class _FailingScheduleService extends OcptScheduleService {
  /// Class constructor
  _FailingScheduleService() : super(logger: const SilentLogger(), deviceId: _testDeviceId);

  @override
  Future<void> updateSlot({
    required OcptProjectDatabase database,
    required String slotId,
    Value<String> label = const Value.absent(),
    Value<String?> locationId = const Value.absent(),
    Value<String?> setId = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async => throw StateError("slot write intentionally failed for the test");
}

/// The fixed device id [_FailingScheduleService] stamps its writes with.
Future<String> _testDeviceId() async => "test-device";

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

    final dayId = await projectsManager.scheduleService.createDay(
      database: project.database,
      date: DateTime(2026, 8, 10),
    );
    expect(dayId, isNotNull);

    final snapshot = await projectsManager.scheduleService.loadSchedule(database: project.database);
    final slotId = snapshot.slotsByDayId[dayId]!.single.id;

    final blockId = await projectsManager.scheduleService.placeShot(
      database: project.database,
      slotId: slotId,
      shotId: shotId!,
    );
    expect(blockId, isNotNull);

    return (shotId: shotId, dayId: dayId!, slotId: slotId, blockId: blockId!);
  }

  /// Builds a bloc wired to the test project, defaulting [exportManager] to a
  /// [FakeScheduleExportManager] with every one of its four methods returning null (a cancelled
  /// dialog), so a test not about exporting never has to think about it.
  OcptScheduleBloc buildBloc() => OcptScheduleBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: RecordingRouterManager(),
    exportManager: FakeScheduleExportManager(),
  );

  /// Builds the export bloc of [modeBloc], wired to the test project and to [exportManager].
  OcptScheduleExportBloc buildExportBloc(
    OcptScheduleBloc modeBloc, {
    required OcptExportManager exportManager,
  }) => OcptScheduleExportBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    exportManager: exportManager,
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
  Future<OcptScheduleExportState> waitForExportState(
    OcptScheduleExportBloc bloc,
    bool Function(OcptScheduleExportState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// One request per export the bloc offers, each over [dayId], in the order of the sealed hierarchy.
  List<OcptScheduleExportEvent> everyExportRequest(String dayId) {
    final pageSetup = (format: OcptPageFormat.a4, margins: const FountainPageMargins.standard());
    return <OcptScheduleExportEvent>[
      OcptScheduleCallSheetsExportRequestedEvent(
        options: OcptCallSheetExportOptions(
          format: pageSetup.format,
          margins: pageSetup.margins,
          dayIds: [dayId],
        ),
        labels: callSheetLabels,
        confirmButtonText: "Choose",
      ),
      OcptScheduleNamedCallSheetsExportRequestedEvent(
        options: OcptCallSheetExportOptions(
          format: pageSetup.format,
          margins: pageSetup.margins,
          dayIds: [dayId],
          selectedConvocationKeys: const {"whoever"},
        ),
        labels: callSheetLabels,
        confirmButtonText: "Choose",
      ),
      OcptScheduleShootingPlanExportRequestedEvent(
        options: OcptShootingPlanExportOptions(
          format: pageSetup.format,
          margins: pageSetup.margins,
          dayIds: [dayId],
          includeTitlePage: true,
          includeLocationsGrid: true,
          includeSequencesGrid: true,
          includePeopleGrid: true,
          includeTenMinuteGrid: true,
          includeElementsGrid: true,
        ),
        labels: shootingPlanLabels,
        fileTypeLabel: "PDF document",
      ),
      OcptScheduleShootingPlanXlsxExportRequestedEvent(
        options: OcptShootingPlanXlsxExportOptions(dayIds: [dayId]),
        labels: shootingPlanXlsxLabels,
        fileTypeLabel: "Excel workbook",
      ),
      OcptScheduleDayOutOfDaysExportRequestedEvent(
        options: OcptDayOutOfDaysExportOptions(
          format: pageSetup.format,
          margins: pageSetup.margins,
          dayIds: [dayId],
          includeTitlePage: true,
        ),
        labels: dayOutOfDaysLabels,
        fileTypeLabel: "PDF document",
      ),
      OcptScheduleOneLineScheduleExportRequestedEvent(
        options: OcptOneLineScheduleExportOptions(
          format: pageSetup.format,
          margins: pageSetup.margins,
          dayIds: [dayId],
          includeTitlePage: true,
        ),
        labels: oneLineScheduleLabels,
        fileTypeLabel: "PDF document",
      ),
      OcptScheduleSidesExportRequestedEvent(
        options: OcptSidesExportOptions(
          format: pageSetup.format,
          margins: pageSetup.margins,
          dayId: dayId,
          includeSceneNumbers: true,
          presentation: OcptSidesPresentation.scriptPages,
        ),
        labels: sidesLabels,
        fileTypeLabel: "PDF document",
      ),
    ];
  }

  group("the bloc as a whole", () {
    /// Names [event] by the exhaustive switch over the sealed hierarchy: adding an event to it makes
    /// this fail to compile until the list below names it too.
    String nameOf(OcptScheduleExportEvent event) => switch (event) {
      OcptScheduleCallSheetsExportRequestedEvent() => "call sheets",
      OcptScheduleNamedCallSheetsExportRequestedEvent() => "named call sheets",
      OcptScheduleShootingPlanExportRequestedEvent() => "shooting plan",
      OcptScheduleShootingPlanXlsxExportRequestedEvent() => "shooting plan workbook",
      OcptScheduleDayOutOfDaysExportRequestedEvent() => "day out of days",
      OcptScheduleOneLineScheduleExportRequestedEvent() => "one-line schedule",
      OcptScheduleSidesExportRequestedEvent() => "sides",
      OcptScheduleIoNoticeDismissedEvent() => "dismiss",
    };

    test("every event of its hierarchy has a handler", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: FakeScheduleExportManager(
          generalCallSheetsResult: const OcptCallSheetExportResult(
            folderPath: "/tmp/sheets",
            writtenFileNames: ["a.pdf"],
            failedFileNames: [],
          ),
          namedCallSheetsResult: const OcptCallSheetExportResult(
            folderPath: "/tmp/sheets",
            writtenFileNames: ["a.pdf"],
            failedFileNames: [],
          ),
          shootingPlanResult: "/tmp/plan.pdf",
          shootingPlanXlsxResult: "/tmp/plan.xlsx",
          dayOutOfDaysResult: "/tmp/dood.pdf",
          oneLineScheduleResult: "/tmp/one-line.pdf",
          sidesResult: "/tmp/sides.pdf",
        ),
      );

      final exports = everyExportRequest(fixture.dayId);
      const dismissal = OcptScheduleIoNoticeDismissedEvent();
      expect(
        [...exports, dismissal].map(nameOf).toSet(),
        hasLength(8),
        reason: 'one event per name of the hierarchy',
      );

      // An event nobody handles is ignored silently, so each is proven by its effect: a notice
      // appears for every export, and the dismissal takes it away.
      for (final event in exports) {
        exportBloc.add(event);
        await waitForExportState(exportBloc, (state) => state.ioNotice != null);
        exportBloc.add(dismissal);
        await waitForExportState(exportBloc, (state) => state.ioNotice == null);
      }

      await exportBloc.close();
      await bloc.close();
    });

    test("an export writes what is pending first, so the plan it prints holds it", () async {
      final fixture = await writePlacedShot();
      final exportManager = FakeScheduleExportManager(
        generalCallSheetsResult: const OcptCallSheetExportResult(
          folderPath: "/tmp/sheets",
          writtenFileNames: ["a.pdf"],
          failedFileNames: [],
        ),
      );
      final bloc = buildBloc();
      final dayBloc = OcptScheduleDayBloc(
        modeBloc: bloc,
        projectsManager: projectsManager,
        fieldEditDebounce: const Duration(days: 1),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);
      dayBloc.add(
        OcptScheduleFieldChangedEvent(
          targetId: fixture.slotId,
          field: OcptScheduleField.slotLabel,
          rawValue: "Cave",
        ),
      );
      await dayBloc.stream.first;

      exportBloc.add(
        OcptScheduleCallSheetsExportRequestedEvent(
          options: OcptCallSheetExportOptions(
            format: OcptPageFormat.a4,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
          ),
          labels: callSheetLabels,
          confirmButtonText: "Choose",
        ),
      );
      await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(
        exportManager.lastGeneralPlan?.schedule.slotsByDayId[fixture.dayId]?.single.label,
        "Cave",
      );

      await exportBloc.close();
      await dayBloc.close();
      await bloc.close();
    });

    test("an export is not made while a typed edit could not be written", () async {
      final fixture = await writePlacedShot();
      final exportManager = FakeScheduleExportManager(
        generalCallSheetsResult: const OcptCallSheetExportResult(
          folderPath: "/tmp/sheets",
          writtenFileNames: ["a.pdf"],
          failedFileNames: [],
        ),
        namedCallSheetsResult: const OcptCallSheetExportResult(
          folderPath: "/tmp/sheets",
          writtenFileNames: ["a.pdf"],
          failedFileNames: [],
        ),
        shootingPlanResult: "/tmp/plan.pdf",
        shootingPlanXlsxResult: "/tmp/plan.xlsx",
        dayOutOfDaysResult: "/tmp/dood.pdf",
        oneLineScheduleResult: "/tmp/one-line.pdf",
        sidesResult: "/tmp/sides.pdf",
      );
      final bloc = buildBloc();
      final dayBloc = OcptScheduleDayBloc(
        modeBloc: bloc,
        projectsManager: projectsManager,
        scheduleService: _FailingScheduleService(),
        fieldEditDebounce: const Duration(days: 1),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);
      dayBloc.add(
        OcptScheduleFieldChangedEvent(
          targetId: fixture.slotId,
          field: OcptScheduleField.slotLabel,
          rawValue: "Cave",
        ),
      );
      await dayBloc.stream.first;

      everyExportRequest(fixture.dayId).forEach(exportBloc.add);
      await pumpEventQueue(times: 200);

      expect(exportBloc.state.ioNotice, isNull);
      expect(exportManager.lastGeneralDayIds, isNull);
      expect(exportManager.lastNamedDayIds, isNull);
      expect(exportManager.lastShootingPlanDayIds, isNull);
      expect(exportManager.lastShootingPlanXlsxDayIds, isNull);
      expect(exportManager.lastDayOutOfDaysDayIds, isNull);
      expect(exportManager.lastOneLineScheduleDayIds, isNull);
      expect(exportManager.lastSidesDayId, isNull);
      expect(dayBloc.state.pendingFieldEdits, isNotEmpty);

      await exportBloc.close();
      await dayBloc.close();
      await bloc.close();
    });

    test("an export asked just as the mode closes neither hangs nor throws", () async {
      await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: FakeScheduleExportManager());

      exportBloc.add(
        const OcptScheduleShootingPlanXlsxExportRequestedEvent(
          options: OcptShootingPlanXlsxExportOptions(dayIds: []),
          labels: shootingPlanXlsxLabels,
          fileTypeLabel: "Excel workbook",
        ),
      );
      await bloc.close().timeout(const Duration(seconds: 5));
      await exportBloc.close().timeout(const Duration(seconds: 5));
    });
  });
}
