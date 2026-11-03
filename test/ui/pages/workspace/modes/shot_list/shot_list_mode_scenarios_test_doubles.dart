// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_sequence_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_table.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panels_group.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// The navigator [ShotListScenarioHarness.wrap] mounts, so [ScenarioRouterManager.pop] closes a
/// dialog opened through `showDialog` exactly as the real router would.
final _navigatorKey = GlobalKey<NavigatorState>();

/// Answers the device identifier the failing services stamp their rows with.
Future<String> _scenarioDeviceId() async => "scenario-device";

/// A router manager whose [pop] pops [_navigatorKey]'s navigator, so a dialog opened through
/// `showDialog` genuinely closes: the mode resolves its router manager from `globalGetIt()`, with
/// no real router for `pop` to delegate to.
class ScenarioRouterManager extends OcptRouterManager {
  /// Pop the route of the test's own navigator, when it can pop.
  @override
  void pop<Y extends Object?>([Y? result]) {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// An export manager answering every export with a saved file, and recording what each one was
/// handed so a scenario can tell what the mode read from its views at the moment of the export.
class ScenarioRecordingExportManager extends OcptExportManager {
  /// The shot list snapshot of the last export, whichever document it was.
  OcptShotListSnapshot? lastShotListSnapshot;

  /// The storyboard snapshot of the last storyboard export.
  OcptStoryboardSnapshot? lastStoryboardSnapshot;

  /// The floor plan snapshot of the last floor plans export.
  OcptFloorPlanSnapshot? lastFloorPlanSnapshot;

  /// The number of exports run since the last [reset].
  int exportCount = 0;

  /// Class constructor
  ScenarioRecordingExportManager() : super(fileSelectorManager: const FileSelectorManager());

  /// Forgets everything recorded so far.
  void reset() {
    lastShotListSnapshot = null;
    lastStoryboardSnapshot = null;
    lastFloorPlanSnapshot = null;
    exportCount = 0;
  }

  /// Count the export, remember the snapshot and answer that the workbook was saved under the
  /// project name.
  @override
  Future<OcptExportOutcome?> exportShotListXlsx({
    required OcptShotListSnapshot snapshot,
    required OcptShotListXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    exportCount++;
    lastShotListSnapshot = snapshot;
    return OcptExportSaved("/tmp/$projectName.xlsx");
  }

  /// Count the export, remember the snapshots and answer that the PDF was saved under the project
  /// name.
  @override
  Future<OcptExportOutcome?> exportStoryboard({
    required OcptShotListSnapshot snapshot,
    required OcptStoryboardSnapshot storyboardSnapshot,
    required OcptPageSetup pageSetup,
    required OcptStoryboardLabels labels,
    required String projectName,
    required int shotsPerPage,
    required bool includeFloorPlansAfterEachSequence,
    OcptFloorPlanSnapshot? floorPlanSnapshot,
    OcptFloorPlanLabels? floorPlanLabels,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    exportCount++;
    lastShotListSnapshot = snapshot;
    lastStoryboardSnapshot = storyboardSnapshot;
    return OcptExportSaved("/tmp/$projectName.pdf");
  }

  /// Count the export, remember the snapshots and answer that the PDF was saved under the project
  /// name.
  @override
  Future<OcptExportOutcome?> exportFloorPlans({
    required OcptShotListSnapshot snapshot,
    required OcptFloorPlanSnapshot floorPlanSnapshot,
    required OcptPageSetup pageSetup,
    required OcptFloorPlanLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    exportCount++;
    lastShotListSnapshot = snapshot;
    lastFloorPlanSnapshot = floorPlanSnapshot;
    return OcptExportSaved("/tmp/$projectName.pdf");
  }

  /// Count the export, remember the snapshot and answer that the PDF was saved under the project
  /// name.
  @override
  Future<OcptExportOutcome?> exportScenarioCoverage({
    required FountainDocument document,
    required String screenplayText,
    required OcptShotListSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptScenarioCoverageLabels labels,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required bool includeLegendPage,
    required bool includeSummaryPage,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    exportCount++;
    lastShotListSnapshot = snapshot;
    return OcptExportSaved("/tmp/$projectName.pdf");
  }
}

/// A file selector manager answering the picker with a file of its own, so a scenario never opens
/// a native dialog. The file need not exist: the app references a frame by path and treats a
/// missing one as a normal state.
class ScenarioFileSelectorManager extends FileSelectorManager {
  /// The path the next pick answers with.
  String pickedPath = "/frames/a.png";

  /// Class constructor
  ScenarioFileSelectorManager();

  /// Answer with the file at the picked path.
  @override
  Future<ResultWithBoolStatus<XFile>> openSelector({
    required List<String> allowedExtensions,
    required String label,
    bool strictOnExtensions = true,
  }) async => ResultWithBoolStatus(status: BoolResultStatus.success, value: XFile(pickedPath));
}

/// The switches [ScenarioProjectsManager] reads to decide which write fails.
class ScenarioFailures {
  /// Whether creating a shot throws.
  bool failShotCreation = false;

  /// Whether adding a storyboard panel throws.
  bool failPanelCreation = false;

  /// Whether placing a floor plan symbol throws.
  bool failSymbolPlacement = false;

  /// Switches every failure off.
  void reset() {
    failShotCreation = false;
    failPanelCreation = false;
    failSymbolPlacement = false;
  }
}

/// A shot list service whose [createShot] fails while [failures] says so.
class _ScenarioShotListService extends OcptShotListService {
  /// The switches read on every write.
  final ScenarioFailures failures;

  /// Class constructor
  _ScenarioShotListService({required this.failures})
    : super(
        logger: const SilentLogger(),
        roleIndexService: const OcptRoleIndexService(
          logger: SilentLogger(),
          elementsService: OcptElementsService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _scenarioDeviceId),
            deviceId: _scenarioDeviceId,
          ),
          roleCandidatesService: OcptRoleCandidatesService(
            logger: SilentLogger(),
            deviceId: _scenarioDeviceId,
          ),
          deviceId: _scenarioDeviceId,
        ),
        storyboardService: const OcptStoryboardService(
          logger: SilentLogger(),
          assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _scenarioDeviceId),
          deviceId: _scenarioDeviceId,
        ),
        floorPlanService: const OcptFloorPlanService(
          logger: SilentLogger(),
          assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _scenarioDeviceId),
          deviceId: _scenarioDeviceId,
        ),
        deviceId: _scenarioDeviceId,
      );

  /// Fail while the scenario asks for shot creations to fail, otherwise create the shot as the real
  /// service does.
  @override
  Future<OcptDatabaseResult<String>> createShot({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String sceneId,
  }) async {
    if (failures.failShotCreation) {
      return const OcptDatabaseResult(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "shot creation intentionally failed for the scenario",
      );
    }

    return super.createShot(database: database, screenplayId: screenplayId, sceneId: sceneId);
  }
}

/// A storyboard service whose [addPanel] fails while [failures] says so.
class _ScenarioStoryboardService extends OcptStoryboardService {
  /// The switches read on every write.
  final ScenarioFailures failures;

  /// Class constructor
  const _ScenarioStoryboardService({required this.failures})
    : super(
        logger: const SilentLogger(),
        assetsService: const OcptAssetsService(logger: SilentLogger(), deviceId: _scenarioDeviceId),
        deviceId: _scenarioDeviceId,
      );

  /// Fail while the scenario asks for panel creations to fail, otherwise add the panel as the real
  /// service does.
  @override
  Future<OcptDatabaseResult<String>> addPanel({
    required OcptProjectDatabase database,
    required String shotId,
  }) async {
    if (failures.failPanelCreation) {
      return const OcptDatabaseResult(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "panel creation intentionally failed for the scenario",
      );
    }

    return super.addPanel(database: database, shotId: shotId);
  }
}

/// A floor plan service whose [placeSymbol] fails while [failures] says so.
class _ScenarioFloorPlanService extends OcptFloorPlanService {
  /// The switches read on every write.
  final ScenarioFailures failures;

  /// Class constructor
  const _ScenarioFloorPlanService({required this.failures})
    : super(
        logger: const SilentLogger(),
        assetsService: const OcptAssetsService(logger: SilentLogger(), deviceId: _scenarioDeviceId),
        deviceId: _scenarioDeviceId,
      );

  /// Fail while the scenario asks for symbol placements to fail, otherwise place the symbol as the
  /// real service does.
  @override
  Future<OcptDatabaseResult<String>> placeSymbol({
    required OcptProjectDatabase database,
    required String setId,
    required String? sceneId,
    required String? shotId,
    required OcptFloorPlanLayer layer,
    required double xM,
    required double yM,
    double rotationDeg = 0,
    double? widthM,
    double? heightM,
    double? fovDeg,
    double? fovReachM,
    String label = '',
    OcptFloorPlanSetElementShape? setElementShape,
    String? overridesSymbolId,
    bool isHidden = false,
  }) async {
    if (failures.failSymbolPlacement) {
      return const OcptDatabaseResult(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "symbol placement intentionally failed for the scenario",
      );
    }

    return super.placeSymbol(
      database: database,
      setId: setId,
      sceneId: sceneId,
      shotId: shotId,
      layer: layer,
      xM: xM,
      yM: yM,
      rotationDeg: rotationDeg,
      widthM: widthM,
      heightM: heightM,
      fovDeg: fovDeg,
      fovReachM: fovReachM,
      label: label,
      setElementShape: setElementShape,
      overridesSymbolId: overridesSymbolId,
      isHidden: isHidden,
    );
  }
}

/// A projects manager handing the shot list mode services that fail on demand, everything else
/// being the real manager.
class ScenarioProjectsManager extends OcptProjectsManager {
  /// The switches deciding which write fails.
  final ScenarioFailures failures = ScenarioFailures();

  /// The shot list service, failing on demand.
  late final _shotListService = _ScenarioShotListService(failures: failures);

  /// The storyboard service, failing on demand.
  late final _storyboardService = _ScenarioStoryboardService(failures: failures);

  /// The floor plan service, failing on demand.
  late final _floorPlanService = _ScenarioFloorPlanService(failures: failures);

  /// Get the shot list service the scenario holds.
  @override
  OcptShotListService get shotListService => _shotListService;

  /// Get the storyboard service the scenario holds.
  @override
  OcptStoryboardService get storyboardService => _storyboardService;

  /// Get the floor plan service the scenario holds.
  @override
  OcptFloorPlanService get floorPlanService => _floorPlanService;

  /// Class constructor
  ScenarioProjectsManager({super.propertiesManager, super.appLanguageCode});
}

/// The screenplay every scenario starts from: two sequences, the first one with a speaking role.
const scenarioScreenplay =
    "INT. KITCHEN - DAY\n\nSAM enters.\n\nSAM\nHello.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

/// The shared set-up of the shot list mode scenarios: the global managers, one temporary project
/// per scenario, the way a scenario mounts the mode and the way it reads the database back.
class ShotListScenarioHarness {
  /// The preferences manager, backed by an in-memory store.
  late OcptPropertiesManager propertiesManager;

  /// The real projects manager, whose failing services are switched on through
  /// [ScenarioProjectsManager.failures].
  late ScenarioProjectsManager projectsManager;

  /// What every export of the mode was handed.
  final exportManager = ScenarioRecordingExportManager();

  /// Answers the board's and the floor plans' file pickers.
  final fileSelectorManager = ScenarioFileSelectorManager();

  /// The folder holding the current scenario's project file.
  late Directory tempDir;

  /// The database of the open project.
  OcptProjectDatabase get database => projectsManager.currentProject!.database;

  /// The screenplay the mode reads: the project's only episode.
  String get screenplayId => projectsManager.currentProject!.primaryScreenplayId;

  /// Registers the global managers once for the whole file.
  Future<void> setUpAll() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();

    projectsManager = ScenarioProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(ScenarioRouterManager())
      ..registerSingleton<OcptExportManager>(exportManager)
      ..registerSingleton<FileSelectorManager>(fileSelectorManager);
  }

  /// Resets the preferences, then creates a fresh project holding [screenplay].
  ///
  /// The in-memory preference store outlives a single scenario, so every preference the mode
  /// reads on entry is written back to its default here.
  Future<void> setUp({String screenplay = scenarioScreenplay}) async {
    await propertiesManager.shotListVisibleColumns.store(OcptShotListColumn.defaultVisibleColumns);
    await propertiesManager.shotListLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await propertiesManager.shotListRightDockFraction.store(OcptWorkspaceDock.rightDefaultFraction);
    await propertiesManager.shotListLastRightDockTab.store(OcptShotListRightDockTab.inspector);
    await propertiesManager.shotListLastCentreView.store(OcptShotListCentreView.table);

    projectsManager.failures.reset();
    exportManager.reset();
    fileSelectorManager.pickedPath = "/frames/a.png";

    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_scenarios_");
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);

    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: screenplay,
      snapshotReason: OcptSnapshotReason.manual,
    );
  }

  /// Closes the project and removes its folder.
  Future<void> tearDown() async {
    await projectsManager.closeCurrentProject();
    await tempDir.delete(recursive: true);
  }

  /// Reads the whole shot list back from the database.
  Future<OcptShotListSnapshot> readShotList() => projectsManager.shotListService
      .loadShotList(database: database, screenplayId: screenplayId, episodeNumber: null)
      .valueOrFail;

  /// Reads the whole storyboard back from the database.
  Future<OcptStoryboardSnapshot> readStoryboard() => projectsManager.storyboardService
      .loadStoryboard(database: database, screenplayId: screenplayId)
      .valueOrFail;

  /// Reads the floor plans back from the database.
  Future<OcptFloorPlanSnapshot> readFloorPlans() => projectsManager.floorPlanService
      .loadFloorPlans(database: database, screenplayId: screenplayId)
      .valueOrFail;

  /// Lists the scene ids of the screenplay, in order.
  Future<List<String>> sceneIds() async => [
    for (final sequence in (await readShotList()).sequences.whereType<OcptSceneShotSequence>())
      sequence.sceneId,
  ];

  /// Creates [count] shots on the scene at [sceneIndex] straight in the database, returning their
  /// ids in creation order.
  Future<List<String>> seedShots(int count, {int sceneIndex = 0}) async {
    final sceneId = (await sceneIds())[sceneIndex];
    final ids = <String>[];
    for (var index = 0; index < count; index++) {
      final id = await projectsManager.shotListService
          .createShot(database: database, screenplayId: screenplayId, sceneId: sceneId)
          .maybeValueOrFail;
      ids.add(id!);
    }
    return ids;
  }

  /// Creates a location with a set named [name], linked to the scene at [sceneIndex], and returns
  /// the set id.
  Future<String> seedLinkedSet(String name, {int sceneIndex = 0}) async {
    final sceneId = (await sceneIds())[sceneIndex];
    final setId = await projectsManager.locationsService
        .createSetLinkedToScene(database: database, sceneId: sceneId, name: name)
        .maybeValueOrFail;
    return setId!;
  }

  /// Wraps [child] with the localization delegates, the navigator [ScenarioRouterManager.pop]
  /// closes dialogs on, a scaffold, and the workspace bloc a production mode expects its page to
  /// provide.
  Widget wrap(Widget child) => MaterialApp(
    navigatorKey: _navigatorKey,
    localizationsDelegates: const [
      Tr.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: Tr.delegate.supportedLocales,
    home: BlocProvider<OcptWorkspaceBloc>(
      create: (context) => OcptWorkspaceBloc(),
      child: Scaffold(body: child),
    ),
  );

  /// Sizes the test surface to [size] (wider than the compact breakpoint by default), mounts the
  /// shot list mode and settles.
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
    OcptShotListRevealRequest? revealRequest,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(OcptShotListMode(revealRequest: revealRequest)));
    await tester.pumpAndSettle();
  }

  /// Takes the mode out of the tree, which is what leaving it for another mode does, and settles.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  /// Reads the localizations of the mounted mode.
  Tr trOf(WidgetTester tester) => Tr.of(tester.element(find.byType(OcptShotListMode)));

  /// Finds the text field of the inspector input labelled [label].
  Finder inspectorField(String label) => find.descendant(
    of: find.ancestor(
      of: find.text(label.toUpperCase()),
      matching: find.byType(OcptShotInspectorField),
    ),
    matching: find.byType(TextField),
  );

  /// Finds the first comment field of the inspector's Panels group.
  Finder panelCommentField() => find
      .descendant(of: find.byType(OcptStoryboardPanelsGroup), matching: find.byType(TextField))
      .first;

  /// Finds a shot [code] as the table's rows show it.
  Finder tableRow(String code) =>
      find.descendant(of: find.byType(OcptShotListRow), matching: find.text(code));

  /// Finds the left dock's entry for the sequence headed [heading].
  Finder sequenceEntry(String heading) =>
      find.descendant(of: find.byType(OcptShotListSequencePanel), matching: find.text(heading));

  /// Taps the table's row at [index] on its left edge, which the right dock never covers.
  Future<void> tapRow(WidgetTester tester, int index) async {
    final row = find.byType(OcptShotListRow).at(index);
    await tester.tapAt(tester.getTopLeft(row) + const Offset(60, 10));
    await tester.pumpAndSettle();
  }

  /// Finds the inspector's header for the shot [code].
  Finder inspectorHeader(Tr tr, String code) => find.text(tr.shotListInspectorHeaderTitle(code));

  /// Scrolls the inspector, up or down, until [target] is built and on screen.
  Future<void> scrollInspectorTo(WidgetTester tester, Finder target) async {
    final scrollable = find
        .descendant(of: find.byType(OcptShotInspectorPanel), matching: find.byType(Scrollable))
        .first;
    final isAbove =
        target.evaluate().isEmpty && tester.state<ScrollableState>(scrollable).position.pixels > 0;
    await tester.scrollUntilVisible(target, isAbove ? -200 : 200, scrollable: scrollable);
  }

  /// Scopes [matching] to the dialog on screen, the export panel's own.
  Finder inPanel(Finder matching) =>
      find.descendant(of: find.byType(AlertDialog), matching: matching);

  /// Taps the segment switching the centre view to [label].
  Future<void> switchView(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// Types [text] into the inspector input labelled [label].
  Future<void> typeIntoInspector(WidgetTester tester, String label, String text) async {
    await tester.enterText(inspectorField(label), text);
    await tester.pump();
  }

  /// Lets the real event loop run, a few milliseconds at a time, until [isDone] holds, then
  /// settles.
  ///
  /// A version preview or restore reads and writes real files, which a fake-async pump never waits
  /// for: the loop hands the real clock over between two pumps, and gives up after five seconds so
  /// a scenario that never gets there fails on its next expectation instead of hanging.
  Future<void> pumpUntil(WidgetTester tester, bool Function() isDone) async {
    for (var attempt = 0; attempt < 500; attempt++) {
      await tester.pump();
      if (isDone()) {
        break;
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    await tester.pumpAndSettle();
  }

  /// Whether [target] is on screen right now.
  bool isShown(Finder target) => target.evaluate().isNotEmpty;
}
