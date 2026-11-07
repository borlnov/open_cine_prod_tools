// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'shot_list_export_bloc_test_doubles.dart';

/// Run the tests of the shot list export bloc shot list and coverage.
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

    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_bloc_test_");
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

    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: text,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
  }

  /// Builds the mode bloc wired to the test project.
  OcptShotListBloc buildBloc() => OcptShotListBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the inspector bloc of [modeBloc], where a shot field is typed. [fieldEditDebounce]
  /// defaults to a short duration so tests exercising the field-edit debounce don't have to wait
  /// out the real 2 s one.
  OcptShotListInspectorBloc buildInspector(
    OcptShotListBloc modeBloc, {
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
  }) => OcptShotListInspectorBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    fieldEditDebounce: fieldEditDebounce,
  );

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

  /// Builds the export bloc of [modeBloc], exporting through [exportManager] — a
  /// [FakeExportManager] whose export cancels unless the test says otherwise, so no test ever
  /// reaches a native save dialog.
  OcptShotListExportBloc buildExportBloc(
    OcptShotListBloc modeBloc, {
    required OcptExportManager exportManager,
  }) => OcptShotListExportBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    exportManager: exportManager,
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

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptShotListExportState> waitForExportState(
    OcptShotListExportBloc bloc,
    bool Function(OcptShotListExportState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test('exporting the shot list hands the loaded snapshot to the export manager', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = FakeExportManager(exportResult: "/tmp/My Movie.xlsx");
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(bloc, (state) => state.totalShotCount == 1);

    exportBloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: exportLabels,
        fileTypeLabel: "Excel workbook",
        episodeTag: "ep. 2",
      ),
    );
    final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.xlsxExportSucceeded);
    expect(state.ioNotice!.path, "/tmp/My Movie.xlsx");
    expect(exportManager.lastExportedProjectName, "My Movie");
    expect(exportManager.lastExportedFileTypeLabel, "Excel workbook");
    expect(exportManager.lastExportedEpisodeTag, "ep. 2");
    expect(exportManager.lastExportedLabels, exportLabels);
    // The whole shot list travels, not only the selected sequence.
    expect(exportManager.lastExportedSnapshot!.sequences, hasLength(2));
    expect(exportManager.lastExportedSnapshot!.totalShotCount, 1);

    exportBloc.add(const OcptShotListIoNoticeDismissedEvent());
    await waitForExportState(exportBloc, (state) => state.ioNotice == null);
    expect(bloc.state.hasWriteError, isFalse);

    await exportBloc.close();
    await bloc.close();
  });

  test('exporting flushes a pending field edit first, so the workbook holds it', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = FakeExportManager(exportResult: "/tmp/My Movie.xlsx");
    final bloc = buildBloc();
    final inspector = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Close-up",
      ),
    );
    await waitUntil(() => inspector.state.pendingFieldEdits.isNotEmpty);

    exportBloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(inspector.state.pendingFieldEdits, isEmpty);
    expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.shotSize, "Close-up");

    await exportBloc.close();
    await inspector.close();
    await bloc.close();
  });

  test('a cancelled save dialog leaves no export notice at all', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: FakeExportManager());

    exportBloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    // Nothing to wait for: a cancellation emits no state of its own, so the assertion is that the
    // bloc settles back with no notice once the export has had time to resolve.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(exportBloc.state.ioNotice, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test('a workbook that cannot be built raises the transient export failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: FakeExportManager(buildFails: true));

    exportBloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.xlsxExportFailed);
    expect(state.ioNotice!.path, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test('a failing export raises the transient export failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: FakeExportManager(fails: true));

    exportBloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.xlsxExportFailed);
    expect(state.ioNotice!.path, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test(
    'exporting the scenario coverage hands the screenplay and its options to the manager',
    () async {
      await writeScreenplay(twoSceneText);

      final exportManager = FakeExportManager(exportResult: "/tmp/My Movie - coverage.pdf");
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      bloc.add(const OcptShotListShotCreationRequestedEvent());
      await waitForState(bloc, (state) => state.totalShotCount == 1);

      exportBloc.add(
        const OcptShotListScenarioCoverageExportRequestedEvent(
          options: coverageOptions,
          labels: coverageLabels,
          fileTypeLabel: "PDF document",
          episodeTag: "ep. 2",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.scenarioCoverageExportSucceeded);
      expect(state.ioNotice!.path, "/tmp/My Movie - coverage.pdf");
      expect(exportManager.lastExportedProjectName, "My Movie");
      expect(exportManager.lastExportedFileTypeLabel, "PDF document");
      expect(exportManager.lastExportedEpisodeTag, "ep. 2");
      expect(exportManager.lastCoverageLabels, coverageLabels);
      // The document travels alongside the very text it was parsed from: a coverage range addresses
      // that text by character offset.
      expect(exportManager.lastCoverageScreenplayText, twoSceneText);
      expect(exportManager.lastCoverageDocument!.blocks, isNotEmpty);
      // The dialog's format wins over the project's own, and its margins are carried through.
      expect(exportManager.lastCoveragePageSetup!.format, OcptPageFormat.a4);
      expect(exportManager.lastCoveragePageSetup!.margins, coverageOptions.margins);
      expect(exportManager.lastCoverageToggles, (
        sceneNumbers: true,
        titlePage: false,
        legendPage: true,
        summaryPage: false,
      ));
      expect(exportManager.lastExportedSnapshot!.totalShotCount, 1);

      await exportBloc.close();
      await bloc.close();
    },
  );

  test('exporting the scenario coverage flushes a pending field edit first', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = FakeExportManager(exportResult: "/tmp/My Movie - coverage.pdf");
    final bloc = buildBloc();
    final inspector = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Gros plan",
      ),
    );
    await waitUntil(() => inspector.state.pendingFieldEdits.isNotEmpty);

    exportBloc.add(
      const OcptShotListScenarioCoverageExportRequestedEvent(
        options: coverageOptions,
        labels: coverageLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(inspector.state.pendingFieldEdits, isEmpty);
    // The legend prints the shot size the user typed seconds ago, and the abbreviation deduced
    // from it alongside.
    expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.shotSize, "Gros plan");
    expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.abbreviation, "GP");

    await exportBloc.close();
    await inspector.close();
    await bloc.close();
  });

  test('a cancelled coverage save dialog leaves no export notice at all', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: FakeExportManager());

    exportBloc.add(
      const OcptShotListScenarioCoverageExportRequestedEvent(
        options: coverageOptions,
        labels: coverageLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    // Nothing to wait for: a cancellation emits no state of its own, so the assertion is that the
    // bloc settles back with no notice once the export has had time to resolve.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(exportBloc.state.ioNotice, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test('a failing coverage export raises its own transient failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: FakeExportManager(fails: true));

    exportBloc.add(
      const OcptShotListScenarioCoverageExportRequestedEvent(
        options: coverageOptions,
        labels: coverageLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.scenarioCoverageExportFailed);
    expect(state.ioNotice!.path, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test(
    'exporting the storyboard hands the loaded snapshots and options to the export manager',
    () async {
      await writeScreenplay(twoSceneText);

      final exportManager = FakeExportManager(exportResult: "/tmp/My Movie - storyboard.pdf");
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      bloc.add(const OcptShotListShotCreationRequestedEvent());
      await waitForState(bloc, (state) => state.totalShotCount == 1);

      exportBloc.add(
        const OcptShotListStoryboardExportRequestedEvent(
          options: storyboardOptions,
          labels: storyboardLabels,
          floorPlanLabels: testFloorPlanLabels,
          fileTypeLabel: "PDF document",
          episodeTag: "ep. 2",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.storyboardExportSucceeded);
      expect(state.ioNotice!.path, "/tmp/My Movie - storyboard.pdf");
      expect(exportManager.lastExportedProjectName, "My Movie");
      expect(exportManager.lastExportedFileTypeLabel, "PDF document");
      expect(exportManager.lastExportedEpisodeTag, "ep. 2");
      expect(exportManager.lastStoryboardLabels, storyboardLabels);
      expect(exportManager.lastStoryboardOptions, (shotsPerPage: 2, includeFloorPlans: false));
      expect(exportManager.lastStoryboardSnapshot, isNotNull);
      expect(exportManager.lastExportedSnapshot!.totalShotCount, 1);
      // The toggle is off, but the loaded floor plan snapshot still rides along on every call —
      // whether it is used is the service's own decision, not something withheld at the bloc.
      expect(exportManager.lastStoryboardFloorPlanSnapshot, isNotNull);

      await exportBloc.close();
      await bloc.close();
    },
  );

  test(
    'exporting the storyboard flushes a pending field edit first, so the document holds it',
    () async {
      await writeScreenplay(twoSceneText);

      final exportManager = FakeExportManager(exportResult: "/tmp/My Movie - storyboard.pdf");
      final bloc = buildBloc();
      final inspector = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      bloc.add(const OcptShotListShotCreationRequestedEvent());
      final state = await waitForState(bloc, (state) => state.totalShotCount == 1);
      final shotId = state.selectedShotId!;

      inspector.add(
        OcptShotListShotFieldChangedEvent(
          shotId: shotId,
          field: OcptShotListEditableField.shotSize,
          rawValue: "Close-up",
        ),
      );
      await waitUntil(() => inspector.state.pendingFieldEdits.isNotEmpty);

      exportBloc.add(
        const OcptShotListStoryboardExportRequestedEvent(
          options: storyboardOptions,
          labels: storyboardLabels,
          floorPlanLabels: testFloorPlanLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(inspector.state.pendingFieldEdits, isEmpty);
      expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.shotSize, "Close-up");

      await exportBloc.close();
      await inspector.close();
      await bloc.close();
    },
  );

  test('a cancelled storyboard save dialog leaves no export notice at all', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: FakeExportManager());

    exportBloc.add(
      const OcptShotListStoryboardExportRequestedEvent(
        options: storyboardOptions,
        labels: storyboardLabels,
        floorPlanLabels: testFloorPlanLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(exportBloc.state.ioNotice, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test('a failing storyboard export raises its own transient failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: FakeExportManager(fails: true));

    exportBloc.add(
      const OcptShotListStoryboardExportRequestedEvent(
        options: storyboardOptions,
        labels: storyboardLabels,
        floorPlanLabels: testFloorPlanLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.storyboardExportFailed);
    expect(state.ioNotice!.path, isNull);

    await exportBloc.close();
    await bloc.close();
  });
}
