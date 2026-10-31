// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:ui';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_inspector_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter for it
/// to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// The options every export test below dispatches, the dialog's own defaults.
const _exportOptions = OcptBreakdownSheetsExportOptions(
  format: OcptPageFormat.a4,
  margins: FountainPageMargins.standard(),
  onlyDoneScenes: false,
  includeNotes: true,
  includeToFindList: true,
);

/// The localized payload every export test below dispatches: what it holds is never read here, only
/// that it reaches the manager unchanged.
const _exportLabels = OcptBreakdownSheetsLabels(
  fileNameSuffix: "breakdown",
  documentTitle: "Breakdown sheets",
  sceneTitles: {},
  statusLabel: "Status",
  lengthLabel: "Length",
  notesLabel: "Breakdown notes",
  targetsSectionTitle: "Tagged elements",
  toFindSectionTitle: "To find",
  nameHeader: "Element",
  statusHeader: "Status",
  ownerHeader: "Owner",
  sceneStatusLabels: {},
  elementStatusLabels: {},
  elementCategoryLabels: {},
  roleGroupLabel: "Characters",
  setGroupLabel: "Set",
  emptySceneNote: "Nothing tagged.",
  emptyDocumentNote: "Nothing to print.",
);

/// The localized payload every workbook export test below dispatches: what it holds is never read
/// here, only that it reaches the manager unchanged.
const _exportXlsxLabels = OcptBreakdownXlsxLabels(
  fileNameSuffix: "breakdown",
  scenesSheetName: "Scenes",
  entriesSheetName: "Breakdown",
  scenesColumnHeaders: {},
  entriesColumnHeaders: {},
  sceneStatusLabels: {},
  elementStatusLabels: {},
  elementCategoryLabels: {},
  roleGroupLabel: "Characters",
  setGroupLabel: "Set",
);

/// An export manager whose [exportBreakdownSheets] and [exportBreakdownXlsx] are stubbed and whose
/// calls are recorded, so the bloc's export paths can be exercised without any real native dialog
/// or file write. Mirrors `resources_bloc_test.dart`'s own `_FakeExportManager`.
class _FakeExportManager extends OcptExportManager {
  /// Class constructor
  _FakeExportManager({this.exportResult, this.fails = false})
    : super(fileSelectorManager: const FileSelectorManager());

  /// The path [exportBreakdownSheets] returns, or null to simulate a cancelled save dialog.
  final String? exportResult;

  /// Whether [exportBreakdownSheets] throws, to exercise the bloc's export failure path.
  final bool fails;

  /// The snapshot of the last [exportBreakdownSheets] call.
  OcptBreakdownSnapshot? lastExportedSnapshot;

  /// The page setup of the last [exportBreakdownSheets] call.
  OcptPageSetup? lastExportedPageSetup;

  /// The labels of the last [exportBreakdownSheets] call.
  OcptBreakdownSheetsLabels? lastExportedLabels;

  /// The project name of the last [exportBreakdownSheets] call.
  String? lastExportedProjectName;

  /// The three content toggles of the last [exportBreakdownSheets] call.
  ({bool onlyDoneScenes, bool includeNotes, bool includeToFindList})? lastExportedToggles;

  /// The file type label of the last [exportBreakdownSheets] call.
  String? lastExportedFileTypeLabel;

  /// The episode tag of the last [exportBreakdownSheets] call.
  String? lastExportedEpisodeTag;

  @override
  Future<OcptExportOutcome?> exportBreakdownSheets({
    required FountainDocument document,
    required OcptBreakdownSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBreakdownSheetsLabels labels,
    required String projectName,
    required bool onlyDoneScenes,
    required bool includeNotes,
    required bool includeToFindList,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    lastExportedSnapshot = snapshot;
    lastExportedPageSetup = pageSetup;
    lastExportedLabels = labels;
    lastExportedProjectName = projectName;
    lastExportedToggles = (
      onlyDoneScenes: onlyDoneScenes,
      includeNotes: includeNotes,
      includeToFindList: includeToFindList,
    );
    lastExportedFileTypeLabel = fileTypeLabel;
    lastExportedEpisodeTag = episodeTag;

    if (fails) {
      throw StateError("breakdown sheets export intentionally failed for the test");
    }

    final result = exportResult;
    return result == null ? null : OcptExportSaved(result);
  }

  /// The snapshot of the last [exportBreakdownXlsx] call.
  OcptBreakdownSnapshot? lastExportedXlsxSnapshot;

  /// The labels of the last [exportBreakdownXlsx] call.
  OcptBreakdownXlsxLabels? lastExportedXlsxLabels;

  /// The project name of the last [exportBreakdownXlsx] call.
  String? lastExportedXlsxProjectName;

  /// The file type label of the last [exportBreakdownXlsx] call.
  String? lastExportedXlsxFileTypeLabel;

  /// The episode tag of the last [exportBreakdownXlsx] call.
  String? lastExportedXlsxEpisodeTag;

  @override
  Future<OcptExportOutcome?> exportBreakdownXlsx({
    required FountainDocument document,
    required OcptBreakdownSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBreakdownXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    lastExportedXlsxSnapshot = snapshot;
    lastExportedXlsxLabels = labels;
    lastExportedXlsxProjectName = projectName;
    lastExportedXlsxFileTypeLabel = fileTypeLabel;
    lastExportedXlsxEpisodeTag = episodeTag;

    if (fails) {
      throw StateError("breakdown workbook export intentionally failed for the test");
    }

    final result = exportResult;
    return result == null ? null : OcptExportSaved(result);
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

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_breakdown_export_bloc_test_");
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
  /// gives the breakdown mode its scenes.
  Future<void> writeScreenplay(String text) async {
    final project = projectsManager.currentProject!;

    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: text,
      snapshotReason: OcptSnapshotReason.manual,
    );
  }

  /// Writes a one-scene screenplay with an element tagged in it.
  Future<void> writeTaggedElement() async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(
      project.database.ocptScenesTable,
    )).get()).single.id;

    final elementId = await projectsManager.elementsService.createElement(
      database: project.database,
      name: "Desk lamp",
      category: OcptElementCategory.prop,
      sourceKind: OcptElementSourceKind.owned,
    );

    await projectsManager.breakdownService.createTag(
      database: project.database,
      sceneId: sceneId,
      startOffset: 2,
      endOffset: 6,
      taggedText: "lamp",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: elementId!,
    );
  }

  /// Builds the mode bloc wired to the test project.
  OcptBreakdownBloc buildBloc() => OcptBreakdownBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the inspector bloc of [modeBloc], which never writes what is typed on its own.
  OcptBreakdownInspectorBloc buildInspector(OcptBreakdownBloc modeBloc) =>
      OcptBreakdownInspectorBloc(
        modeBloc: modeBloc,
        projectsManager: projectsManager,
        fieldEditDebounce: const Duration(days: 1),
      );

  /// Builds the export bloc of [modeBloc], exporting through [exportManager] (a cancelled save
  /// dialog by default, so no test ever reaches a native one).
  OcptBreakdownExportBloc buildExportBloc(
    OcptBreakdownBloc modeBloc, {
    OcptExportManager? exportManager,
  }) => OcptBreakdownExportBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    exportManager: exportManager ?? _FakeExportManager(),
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test(
    "exporting the sheets hands the snapshot, the options and the labels to the manager",
    () async {
      await writeTaggedElement();
      final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - breakdown.pdf");
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc, exportManager: exportManager);
      await waitForState(modeBloc, (state) => state.scenes.isNotEmpty);

      exportBloc.add(
        const OcptBreakdownSheetsExportRequestedEvent(
          options: _exportOptions,
          labels: _exportLabels,
          fileTypeLabel: "PDF document",
          episodeTag: "ep. 2",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(exportManager.lastExportedSnapshot?.targets, hasLength(1));
      expect(exportManager.lastExportedProjectName, "My Movie");
      expect(exportManager.lastExportedLabels, _exportLabels);
      expect(exportManager.lastExportedFileTypeLabel, "PDF document");
      expect(exportManager.lastExportedEpisodeTag, "ep. 2");
      // The dialog's own page format wins over the project's, and its margins travel with it.
      expect(exportManager.lastExportedPageSetup?.format, OcptPageFormat.a4);
      expect(exportManager.lastExportedPageSetup?.margins, const FountainPageMargins.standard());
      expect(exportManager.lastExportedToggles?.onlyDoneScenes, isFalse);
      expect(exportManager.lastExportedToggles?.includeNotes, isTrue);
      expect(exportManager.lastExportedToggles?.includeToFindList, isTrue);
      expect(state.ioNotice?.kind, OcptBreakdownIoNoticeKind.sheetsExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/My Movie - breakdown.pdf");

      await exportBloc.close();
      await modeBloc.close();
    },
  );

  test("a pending scene notes edit is flushed into the snapshot the export is handed", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final exportManager = _FakeExportManager(exportResult: "/tmp/sheets.pdf");
    final modeBloc = buildBloc();
    final inspectorBloc = buildInspector(modeBloc);
    final exportBloc = buildExportBloc(modeBloc, exportManager: exportManager);
    final loaded = await waitForState(modeBloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    inspectorBloc.add(
      OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "handle with care"),
    );
    await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);

    exportBloc.add(
      const OcptBreakdownSheetsExportRequestedEvent(
        options: _exportOptions,
        labels: _exportLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    await waitForState(exportBloc, (state) => state.ioNotice != null);

    expect(exportManager.lastExportedSnapshot?.scenes.single.notes, "handle with care");

    await inspectorBloc.close();
    await exportBloc.close();
    await modeBloc.close();
  });

  test("a cancelled save dialog raises no notice at all", () async {
    await writeTaggedElement();
    final modeBloc = buildBloc();
    final exportBloc = buildExportBloc(modeBloc, exportManager: _FakeExportManager());
    await waitForState(modeBloc, (state) => state.scenes.isNotEmpty);

    exportBloc.add(
      const OcptBreakdownSheetsExportRequestedEvent(
        options: _exportOptions,
        labels: _exportLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    // Nothing to wait for on the state, so the export is let run to completion instead.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(exportBloc.state.ioNotice, isNull);

    await exportBloc.close();
    await modeBloc.close();
  });

  test("a failed export raises the export-failed notice, which dismissing clears", () async {
    await writeTaggedElement();
    final modeBloc = buildBloc();
    final exportBloc = buildExportBloc(modeBloc, exportManager: _FakeExportManager(fails: true));
    await waitForState(modeBloc, (state) => state.scenes.isNotEmpty);

    exportBloc.add(
      const OcptBreakdownSheetsExportRequestedEvent(
        options: _exportOptions,
        labels: _exportLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice?.kind, OcptBreakdownIoNoticeKind.sheetsExportFailed);
    expect(state.ioNotice?.path, isNull);

    exportBloc.add(const OcptBreakdownIoNoticeDismissedEvent());
    await waitForState(exportBloc, (state) => state.ioNotice == null);

    await exportBloc.close();
    await modeBloc.close();
  });

  test(
    "exporting the workbook hands the snapshot and the labels to the manager, with no options",
    () async {
      await writeTaggedElement();
      final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - breakdown.xlsx");
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc, exportManager: exportManager);
      await waitForState(modeBloc, (state) => state.scenes.isNotEmpty);

      exportBloc.add(
        const OcptBreakdownXlsxExportRequestedEvent(
          labels: _exportXlsxLabels,
          fileTypeLabel: "Excel workbook",
          episodeTag: "ep. 2",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(exportManager.lastExportedXlsxSnapshot?.targets, hasLength(1));
      expect(exportManager.lastExportedXlsxProjectName, "My Movie");
      expect(exportManager.lastExportedXlsxLabels, _exportXlsxLabels);
      expect(exportManager.lastExportedXlsxFileTypeLabel, "Excel workbook");
      expect(exportManager.lastExportedXlsxEpisodeTag, "ep. 2");
      expect(state.ioNotice?.kind, OcptBreakdownIoNoticeKind.xlsxExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/My Movie - breakdown.xlsx");

      await exportBloc.close();
      await modeBloc.close();
    },
  );

  test(
    "a pending scene notes edit is flushed into the snapshot the workbook export is handed",
    () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
      final exportManager = _FakeExportManager(exportResult: "/tmp/breakdown.xlsx");
      final modeBloc = buildBloc();
      final inspectorBloc = buildInspector(modeBloc);
      final exportBloc = buildExportBloc(modeBloc, exportManager: exportManager);
      final loaded = await waitForState(modeBloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;

      inspectorBloc.add(
        OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "handle with care"),
      );
      await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);

      exportBloc.add(
        const OcptBreakdownXlsxExportRequestedEvent(
          labels: _exportXlsxLabels,
          fileTypeLabel: "Excel workbook",
        ),
      );
      await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(exportManager.lastExportedXlsxSnapshot?.scenes.single.notes, "handle with care");

      await inspectorBloc.close();
      await exportBloc.close();
      await modeBloc.close();
    },
  );

  test("a cancelled workbook save dialog raises no notice at all", () async {
    await writeTaggedElement();
    final modeBloc = buildBloc();
    final exportBloc = buildExportBloc(modeBloc, exportManager: _FakeExportManager());
    await waitForState(modeBloc, (state) => state.scenes.isNotEmpty);

    exportBloc.add(
      const OcptBreakdownXlsxExportRequestedEvent(
        labels: _exportXlsxLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    // Nothing to wait for on the state, so the export is let run to completion instead.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(exportBloc.state.ioNotice, isNull);

    await exportBloc.close();
    await modeBloc.close();
  });

  test(
    "a failed workbook export raises the export-failed notice, which dismissing clears",
    () async {
      await writeTaggedElement();
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc, exportManager: _FakeExportManager(fails: true));
      await waitForState(modeBloc, (state) => state.scenes.isNotEmpty);

      exportBloc.add(
        const OcptBreakdownXlsxExportRequestedEvent(
          labels: _exportXlsxLabels,
          fileTypeLabel: "Excel workbook",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptBreakdownIoNoticeKind.xlsxExportFailed);
      expect(state.ioNotice?.path, isNull);

      exportBloc.add(const OcptBreakdownIoNoticeDismissedEvent());
      await waitForState(exportBloc, (state) => state.ioNotice == null);

      await exportBloc.close();
      await modeBloc.close();
    },
  );

  group("the events of the export bloc", () {
    /// The name of each event of the export hierarchy: the switch names every one, so an event
    /// added to the hierarchy does not compile until this list, and the test below, know it.
    String nameOf(OcptBreakdownExportEvent event) => switch (event) {
      OcptBreakdownSheetsExportRequestedEvent() => "sheets",
      OcptBreakdownXlsxExportRequestedEvent() => "workbook",
      OcptBreakdownIoNoticeDismissedEvent() => "dismiss",
    };

    test("every event of its hierarchy has a handler", () async {
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(
        modeBloc,
        exportManager: _FakeExportManager(exportResult: "/tmp/export"),
      );
      await waitForState(modeBloc, (state) => !state.isLoading);
      await writeTaggedElement();
      await modeBloc.reload({OcptBreakdownReloadScope.snapshot});

      const events = <OcptBreakdownExportEvent>[
        OcptBreakdownSheetsExportRequestedEvent(
          options: _exportOptions,
          labels: _exportLabels,
          fileTypeLabel: "PDF document",
        ),
        OcptBreakdownXlsxExportRequestedEvent(
          labels: _exportXlsxLabels,
          fileTypeLabel: "Excel workbook",
        ),
        OcptBreakdownIoNoticeDismissedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(3), reason: "one event per name");

      // An event nobody handles is ignored silently, so each is proven by its effect: an export
      // leaves a notice, and the dismissal takes it away again.
      exportBloc.add(events[0]);
      final sheets = await waitForState(exportBloc, (state) => state.ioNotice != null);
      expect(sheets.ioNotice!.kind, OcptBreakdownIoNoticeKind.sheetsExportSucceeded);
      exportBloc.add(events[2]);
      await waitForState(exportBloc, (state) => state.ioNotice == null);

      exportBloc.add(events[1]);
      final workbook = await waitForState(exportBloc, (state) => state.ioNotice != null);
      expect(workbook.ioNotice!.kind, OcptBreakdownIoNoticeKind.xlsxExportSucceeded);

      await exportBloc.close();
      await modeBloc.close();
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc);
      await waitForState(modeBloc, (state) => !state.isLoading);

      expect(modeBloc.pendingWritesFlusherCount, 1);

      await exportBloc.close();
      await modeBloc.close();
    });
  });
}
