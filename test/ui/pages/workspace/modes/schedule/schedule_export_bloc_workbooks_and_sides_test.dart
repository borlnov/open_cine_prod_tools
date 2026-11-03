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
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_sides_presentation.dart';
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

/// Run the tests of the schedule export bloc workbooks and sides.
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

  group("exporting the shooting plan workbook", () {
    test(
      "hands the plan and the options to the manager and raises the file-succeeded notice",
      () async {
        final fixture = await writePlacedShot();
        final exportManager = FakeScheduleExportManager(shootingPlanXlsxResult: "/tmp/plan.xlsx");
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

        exportBloc.add(
          OcptScheduleShootingPlanXlsxExportRequestedEvent(
            options: OcptShootingPlanXlsxExportOptions(dayIds: [fixture.dayId]),
            labels: shootingPlanXlsxLabels,
            fileTypeLabel: "Excel workbook",
          ),
        );
        final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

        expect(exportManager.lastShootingPlanXlsxDayIds, [fixture.dayId]);
        expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.fileExportSucceeded);
        expect(state.ioNotice?.path, "/tmp/plan.xlsx");

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
        OcptScheduleShootingPlanXlsxExportRequestedEvent(
          options: OcptShootingPlanXlsxExportOptions(dayIds: [fixture.dayId]),
          labels: shootingPlanXlsxLabels,
          fileTypeLabel: "Excel workbook",
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
        exportManager: FakeScheduleExportManager(shootingPlanXlsxFails: true),
      );

      exportBloc.add(
        OcptScheduleShootingPlanXlsxExportRequestedEvent(
          options: OcptShootingPlanXlsxExportOptions(dayIds: [fixture.dayId]),
          labels: shootingPlanXlsxLabels,
          fileTypeLabel: "Excel workbook",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });

  group("exporting the day out of days", () {
    test(
      "hands the plan and the options to the manager and raises the file-succeeded notice",
      () async {
        final fixture = await writePlacedShot();
        final exportManager = FakeScheduleExportManager(dayOutOfDaysResult: "/tmp/dood.pdf");
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

        exportBloc.add(
          OcptScheduleDayOutOfDaysExportRequestedEvent(
            options: OcptDayOutOfDaysExportOptions(
              format: OcptPageFormat.usLetter,
              margins: const FountainPageMargins.standard(),
              dayIds: [fixture.dayId],
              includeTitlePage: true,
            ),
            labels: dayOutOfDaysLabels,
            fileTypeLabel: "PDF document",
          ),
        );
        final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

        expect(exportManager.lastDayOutOfDaysDayIds, [fixture.dayId]);
        expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.fileExportSucceeded);
        expect(state.ioNotice?.path, "/tmp/dood.pdf");

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
        OcptScheduleDayOutOfDaysExportRequestedEvent(
          options: OcptDayOutOfDaysExportOptions(
            format: OcptPageFormat.usLetter,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
            includeTitlePage: true,
          ),
          labels: dayOutOfDaysLabels,
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
        exportManager: FakeScheduleExportManager(dayOutOfDaysFails: true),
      );

      exportBloc.add(
        OcptScheduleDayOutOfDaysExportRequestedEvent(
          options: OcptDayOutOfDaysExportOptions(
            format: OcptPageFormat.usLetter,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
            includeTitlePage: true,
          ),
          labels: dayOutOfDaysLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });

  group("exporting the one-line schedule", () {
    /// The one-line schedule export request for [dayId].
    OcptScheduleOneLineScheduleExportRequestedEvent requestFor(String dayId) =>
        OcptScheduleOneLineScheduleExportRequestedEvent(
          options: OcptOneLineScheduleExportOptions(
            format: OcptPageFormat.usLetter,
            margins: const FountainPageMargins.standard(),
            dayIds: [dayId],
            includeTitlePage: true,
          ),
          labels: oneLineScheduleLabels,
          fileTypeLabel: "PDF document",
        );

    test("hands the plan's days to the manager and raises the succeeded notice", () async {
      final fixture = await writePlacedShot();
      final exportManager = FakeScheduleExportManager(oneLineScheduleResult: "/tmp/one-line.pdf");
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      exportBloc.add(requestFor(fixture.dayId));
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(exportManager.lastOneLineScheduleDayIds, [fixture.dayId]);
      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.fileExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/one-line.pdf");

      await exportBloc.close();
      await bloc.close();
    });

    test("is a silent no-op when the save dialog is cancelled", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: FakeScheduleExportManager());

      exportBloc.add(requestFor(fixture.dayId));
      await pumpEventQueue();

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the export-failed notice when the export throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: FakeScheduleExportManager(oneLineScheduleFails: true),
      );

      exportBloc.add(requestFor(fixture.dayId));
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });

  group("exporting the sides", () {
    /// The sides export request `writePlacedShot`'s own day is printed by, [presentation] aside.
    OcptScheduleSidesExportRequestedEvent requestFor(
      String dayId, {
      OcptSidesPresentation presentation = OcptSidesPresentation.scriptPages,
    }) => OcptScheduleSidesExportRequestedEvent(
      options: OcptSidesExportOptions(
        format: OcptPageFormat.usLetter,
        margins: const FountainPageMargins.standard(),
        dayId: dayId,
        includeSceneNumbers: true,
        presentation: presentation,
      ),
      labels: sidesLabels,
      fileTypeLabel: "PDF document",
    );

    test("hands the day, the presentation and the project's own screenplay to the "
        "manager", () async {
      final fixture = await writePlacedShot();
      final exportManager = FakeScheduleExportManager(sidesResult: "/tmp/sides.pdf");
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      exportBloc.add(requestFor(fixture.dayId, presentation: OcptSidesPresentation.packed));
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(exportManager.lastSidesDayId, fixture.dayId);
      expect(exportManager.lastSidesPresentation, OcptSidesPresentation.packed);
      // The handler reads the Fountain text out of the open project rather than out of its own
      // state, which holds none: what reaches the manager is the very screenplay the fixture wrote,
      // as the project's own single episode.
      final project = projectsManager.currentProject!;
      expect(exportManager.lastSidesScreenplayIds, [project.primaryScreenplayId]);
      expect(
        exportManager.lastSidesSourceTextsByScreenplayId?[project.primaryScreenplayId],
        contains("INT. HOUSE - DAY"),
      );
      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.fileExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/sides.pdf");

      await exportBloc.close();
      await bloc.close();
    });

    test(
      "a day playing two episodes hands the manager both episodes' documents, in episode order",
      () async {
        final fixture = await writePlacedShot();
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

        final secondShotId = await projectsManager.shotListService
            .createShot(
              database: project.database,
              screenplayId: secondEpisodeId,
              sceneId: secondSceneId,
            )
            .maybeValueOrFail;
        expect(secondShotId, isNotNull);

        final secondSlotId = await projectsManager.scheduleService
            .createSlot(database: project.database, shootingDayId: fixture.dayId, anchorMinute: 600)
            .maybeValueOrFail;
        expect(secondSlotId, isNotNull);
        final secondBlockId = await projectsManager.scheduleService
            .placeShot(database: project.database, slotId: secondSlotId!, shotId: secondShotId!)
            .maybeValueOrFail;
        expect(secondBlockId, isNotNull);

        final exportManager = FakeScheduleExportManager(sidesResult: "/tmp/sides.pdf");
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

        exportBloc.add(requestFor(fixture.dayId));
        await waitForExportState(exportBloc, (state) => state.ioNotice != null);

        expect(
          exportManager.lastSidesScreenplayIds,
          [project.primaryScreenplayId, secondEpisodeId],
          reason: "episode 1's own document before episode 2's, the project's own episode order",
        );
        expect(
          exportManager.lastSidesSourceTextsByScreenplayId?[project.primaryScreenplayId],
          contains("INT. HOUSE - DAY"),
        );
        expect(
          exportManager.lastSidesSourceTextsByScreenplayId?[secondEpisodeId],
          contains("EXT. STREET - NIGHT"),
        );

        await exportBloc.close();
        await bloc.close();
      },
    );

    test("is a silent no-op when the save dialog is cancelled", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: FakeScheduleExportManager());

      exportBloc.add(requestFor(fixture.dayId));
      await pumpEventQueue();

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the export-failed notice when the export throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: FakeScheduleExportManager(sidesFails: true),
      );

      exportBloc.add(requestFor(fixture.dayId));
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });
}
