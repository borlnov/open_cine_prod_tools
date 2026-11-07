// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_result.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'schedule_export_bloc_test_doubles.dart';

/// Run the tests of the schedule export bloc call sheets.
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

    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: text,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
  }

  /// Writes a one-scene screenplay, creates a shot in it, a shooting day with its default slot,
  /// and places the shot on that slot — the fixture every selection test below shares.
  Future<({String shotId, String dayId, String slotId, String blockId})> writePlacedShot() async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(
      project.database.ocptScenesTable,
    )).get()).single.id;

    final shotId = await projectsManager.shotListService
        .createShot(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          sceneId: sceneId,
        )
        .maybeValueOrFail;
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

  group("exporting the general call sheets", () {
    test("hands the plan and the options to the manager and raises the succeeded notice", () async {
      final fixture = await writePlacedShot();
      final exportManager = FakeScheduleExportManager(
        generalCallSheetsResult: const OcptCallSheetExportResult(
          folderPath: "/tmp/call-sheets",
          writtenFileNames: ["FDS-D1.pdf"],
          failedFileNames: [],
        ),
      );
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

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
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(exportManager.lastGeneralDayIds, [fixture.dayId]);
      expect(exportManager.lastGeneralConfirmButtonText, "Choose");
      expect(exportManager.lastGeneralPlan?.schedule.days, hasLength(1));
      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.folderExportSucceeded);
      expect(state.ioNotice?.folderPath, "/tmp/call-sheets");
      expect(state.ioNotice?.writtenCount, 1);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the partial notice rather than the success one when some files failed", () async {
      final fixture = await writePlacedShot();
      final exportManager = FakeScheduleExportManager(
        generalCallSheetsResult: const OcptCallSheetExportResult(
          folderPath: "/tmp/call-sheets",
          writtenFileNames: ["FDS-D1.pdf"],
          failedFileNames: ["FDS-D2.pdf"],
        ),
      );
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

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
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.folderExportPartiallySucceeded);
      expect(state.ioNotice?.writtenCount, 1);
      expect(state.ioNotice?.failedCount, 1);

      await exportBloc.close();
      await bloc.close();
    });

    test("is a silent no-op when the folder dialog is cancelled", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: FakeScheduleExportManager());

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
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: FakeScheduleExportManager(generalCallSheetsFails: true),
      );

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
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });

  group("exporting the named call sheets", () {
    test("hands the day and the selected convocation keys to the manager", () async {
      final fixture = await writePlacedShot();
      final project = projectsManager.currentProject!;
      final personId = await projectsManager.peopleService
          .createPerson(database: project.database)
          .maybeValueOrFail;
      expect(personId, isNotNull);

      final snapshot = await projectsManager.scheduleService
          .loadSchedule(database: project.database)
          .valueOrFail;
      final slotId = snapshot.slotsByDayId[fixture.dayId]!.single.id;
      await projectsManager.scheduleService
          .addSlotCrewMember(database: project.database, slotId: slotId, personId: personId!)
          .maybeValueOrFail;

      final exportManager = FakeScheduleExportManager(
        namedCallSheetsResult: const OcptCallSheetExportResult(
          folderPath: "/tmp/named",
          writtenFileNames: ["FDS-D1-Someone.pdf"],
          failedFileNames: [],
        ),
      );
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      exportBloc.add(
        OcptScheduleNamedCallSheetsExportRequestedEvent(
          options: OcptCallSheetExportOptions(
            format: OcptPageFormat.a4,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
            selectedConvocationKeys: {personId},
          ),
          labels: callSheetLabels,
          confirmButtonText: "Choose",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(exportManager.lastNamedDayIds, [fixture.dayId]);
      expect(exportManager.lastNamedConvocationKeys, {personId});
      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.folderExportSucceeded);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: FakeScheduleExportManager(namedCallSheetsFails: true),
      );

      exportBloc.add(
        OcptScheduleNamedCallSheetsExportRequestedEvent(
          options: OcptCallSheetExportOptions(
            format: OcptPageFormat.a4,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
            selectedConvocationKeys: const {"whoever"},
          ),
          labels: callSheetLabels,
          confirmButtonText: "Choose",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });

  group("exporting the shooting plan", () {
    test(
      "hands the plan and the options to the manager and raises the file-succeeded notice",
      () async {
        final fixture = await writePlacedShot();
        final exportManager = FakeScheduleExportManager(shootingPlanResult: "/tmp/plan.pdf");
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

        exportBloc.add(
          OcptScheduleShootingPlanExportRequestedEvent(
            options: OcptShootingPlanExportOptions(
              format: OcptPageFormat.usLetter,
              margins: const FountainPageMargins.standard(),
              dayIds: [fixture.dayId],
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
        );
        final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

        expect(exportManager.lastShootingPlanDayIds, [fixture.dayId]);
        expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.fileExportSucceeded);
        expect(state.ioNotice?.path, "/tmp/plan.pdf");

        await exportBloc.close();
        await bloc.close();
      },
    );

    test("is a silent no-op when the save dialog is cancelled", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: FakeScheduleExportManager());

      exportBloc.add(
        OcptScheduleShootingPlanExportRequestedEvent(
          options: OcptShootingPlanExportOptions(
            format: OcptPageFormat.usLetter,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
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
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: FakeScheduleExportManager(shootingPlanFails: true),
      );

      exportBloc.add(
        OcptScheduleShootingPlanExportRequestedEvent(
          options: OcptShootingPlanExportOptions(
            format: OcptPageFormat.usLetter,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
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
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });
}
