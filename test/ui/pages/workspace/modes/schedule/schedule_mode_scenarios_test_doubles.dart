// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_result.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_sides_presentation.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_left_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_timetable.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The navigator [ScheduleScenarioHarness.wrap] mounts, so [ScheduleScenarioRouterManager.pop]
/// closes a dialog opened through `showDialog` exactly as the real router would.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] pops [_navigatorKey]'s navigator and whose [push] answers with
/// [pushAnswer] instead of opening a page, so the project settings detour can be driven.
class ScheduleScenarioRouterManager extends OcptRouterManager {
  /// The answer every [push] gives, what the project settings page returns when it closes.
  bool? pushAnswer;

  /// The number of pages pushed since the last reset.
  int pushCount = 0;

  @override
  void pop<Y extends Object?>([Y? result]) {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }

  @override
  Future<Y?> push<Y extends Object?>(
    OcptRoute route, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) async {
    pushCount++;
    final answer = pushAnswer;
    return answer is Y ? answer as Y : null;
  }
}

/// One export a [ScheduleRecordingExportManager] was asked for.
class ScheduleRecordedExport {
  /// The name of the export method that ran.
  final String document;

  /// The plan the mode handed over.
  final OcptSchedulePlanSnapshot plan;

  /// The day ids the export was asked to print.
  final List<String> dayIds;

  /// Class constructor
  const ScheduleRecordedExport({required this.document, required this.plan, required this.dayIds});
}

/// An export manager answering every schedule export with a saved file (or a written folder), and
/// recording what each one was handed so a scenario can tell what the mode had read at the moment
/// of the export.
class ScheduleRecordingExportManager extends OcptExportManager {
  /// Class constructor
  ScheduleRecordingExportManager() : super(fileSelectorManager: const FileSelectorManager());

  /// Every export run since the last [reset], in order.
  final List<ScheduleRecordedExport> exports = [];

  /// Whether the next exports throw instead of answering.
  bool shouldFail = false;

  /// Whether the next exports answer as if the user had cancelled the dialog.
  bool shouldCancel = false;

  /// The failed file names a folder export reports, empty for a complete run.
  List<String> failedFileNames = const [];

  /// Forgets everything recorded and answers normally again.
  void reset() {
    exports.clear();
    shouldFail = false;
    shouldCancel = false;
    failedFileNames = const [];
  }

  /// Records an export of [document], throwing when [shouldFail] says so.
  void _record(String document, OcptSchedulePlanSnapshot plan, List<String> dayIds) {
    exports.add(ScheduleRecordedExport(document: document, plan: plan, dayIds: dayIds));
    if (shouldFail) {
      throw StateError("$document export intentionally failed for the scenario");
    }
  }

  /// The single-file answer of [document].
  OcptExportOutcome? _fileAnswer(String document) =>
      shouldCancel ? null : OcptExportSaved("/tmp/$document.pdf");

  @override
  Future<OcptCallSheetExportResult?> exportGeneralCallSheets({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String confirmButtonText,
    Rect? shareAnchor,
  }) async {
    _record("callSheets", plan, dayIds);
    return _folderAnswer(dayIds);
  }

  @override
  Future<OcptCallSheetExportResult?> exportNamedCallSheets({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    Set<String>? convocationKeys,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String confirmButtonText,
    Rect? shareAnchor,
  }) async {
    _record("namedCallSheets", plan, dayIds);
    return _folderAnswer(dayIds);
  }

  /// The folder answer of a call sheets export of [dayIds].
  OcptCallSheetExportResult? _folderAnswer(List<String> dayIds) => shouldCancel
      ? null
      : OcptCallSheetExportResult(
          folderPath: "/tmp/sheets",
          writtenFileNames: [for (final id in dayIds.skip(failedFileNames.length)) "$id.pdf"],
          failedFileNames: failedFileNames,
        );

  @override
  Future<OcptExportOutcome?> exportShootingPlan({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required bool includeLocationsGrid,
    required bool includeSequencesGrid,
    required bool includePeopleGrid,
    required bool includeTenMinuteGrid,
    required bool includeElementsGrid,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    _record("shootingPlan", plan, dayIds);
    return _fileAnswer("shootingPlan");
  }

  @override
  Future<OcptExportOutcome?> exportShootingPlanXlsx({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptShootingPlanXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    _record("shootingPlanXlsx", plan, dayIds);
    return _fileAnswer("shootingPlanXlsx");
  }

  @override
  Future<OcptExportOutcome?> exportDayOutOfDays({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptDayOutOfDaysLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    _record("dayOutOfDays", plan, dayIds);
    return _fileAnswer("dayOutOfDays");
  }

  @override
  Future<OcptExportOutcome?> exportOneLineSchedule({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptOneLineScheduleLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    _record("oneLineSchedule", plan, dayIds);
    return _fileAnswer("oneLineSchedule");
  }

  @override
  Future<OcptExportOutcome?> exportSides({
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required List<({String screenplayId, FountainDocument document})> documents,
    required OcptPageSetup pageSetup,
    required OcptSidesLabels labels,
    required String projectName,
    required bool includeSceneNumbers,
    required OcptSidesPresentation presentation,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    _record("sides", plan, [dayId]);
    return _fileAnswer("sides");
  }
}

/// The screenplay every scenario starts from: two sequences, the first one with a speaking role.
const scheduleScenarioScreenplay =
    "INT. KITCHEN - DAY\n\nSAM enters.\n\nSAM\nHello.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

/// The shared set-up of the schedule mode scenarios: the global managers, one temporary project
/// per scenario, the way a scenario mounts the mode and the way it reads the database back.
class ScheduleScenarioHarness {
  /// The preferences manager, backed by an in-memory store.
  late OcptPropertiesManager propertiesManager;

  /// The real projects manager.
  late OcptProjectsManager projectsManager;

  /// What every export of the mode was handed.
  final exportManager = ScheduleRecordingExportManager();

  /// The router the mode navigates through.
  final routerManager = ScheduleScenarioRouterManager();

  /// The folder holding the current scenario's project file.
  late Directory tempDir;

  /// Registers the global managers once for the whole file.
  Future<void> setUpAll() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();

    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(routerManager)
      ..registerSingleton<OcptExportManager>(exportManager);
  }

  /// Resets the preferences, then creates a fresh project holding [screenplay].
  ///
  /// The in-memory preference store outlives a single scenario, so every preference the mode
  /// reads on entry is written back to its default here.
  Future<void> setUp({String screenplay = scheduleScenarioScreenplay}) async {
    await propertiesManager.scheduleLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await propertiesManager.scheduleRightDockFraction.store(OcptWorkspaceDock.rightDefaultFraction);
    await propertiesManager.scheduleLastRightDockTab.store(OcptScheduleRightDockTab.inspector);

    exportManager.reset();
    routerManager
      ..pushAnswer = null
      ..pushCount = 0;

    tempDir = await Directory.systemTemp.createTemp("ocpt_schedule_scenarios_");
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

  /// The database of the open project.
  OcptProjectDatabase get database => projectsManager.currentProject!.database;

  /// The screenplay the project opened with: its first episode.
  String get screenplayId => projectsManager.currentProject!.primaryScreenplayId;

  /// Reads the whole schedule back from the database.
  Future<OcptScheduleSnapshot> readSchedule() =>
      projectsManager.scheduleService.loadSchedule(database: database);

  /// Reads the first episode's shot list back from the database.
  Future<OcptShotListSnapshot> readShotList() => projectsManager.shotListService.loadShotList(
    database: database,
    screenplayId: screenplayId,
    episodeNumber: null,
  );

  /// Lists the scene ids of the first episode, in order.
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
      final id = await projectsManager.shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );
      ids.add(id!);
    }
    return ids;
  }

  /// Creates a shooting day on [date], returning its id. The service gives it one default slot.
  Future<String> seedDay(DateTime date) async {
    final id = await projectsManager.scheduleService.createDay(database: database, date: date);
    return id!;
  }

  /// Returns the id of the first slot of day [dayId].
  Future<String> firstSlotOf(String dayId) async =>
      (await readSchedule()).slotsByDayId[dayId]!.first.id;

  /// Creates a person called [firstName] in the address book, returning the id.
  Future<String> seedPerson(String firstName) async {
    final id = await projectsManager.peopleService.createPerson(database: database);
    await projectsManager.peopleService.updatePerson(
      database: database,
      personId: id!,
      firstName: Value(firstName),
    );
    return id;
  }

  /// Creates a silent role called [name] with nobody cast on it, returning the id.
  Future<String> seedUncastRole(String name) async {
    final id = await projectsManager.roleIndexService.addRole(
      database: database,
      screenplayId: screenplayId,
      name: name,
      kind: OcptRoleKind.silent,
    );
    return id!;
  }

  /// Wraps [child] with the localization delegates, the theme, the navigator
  /// [ScheduleScenarioRouterManager.pop] closes dialogs on, a scaffold, and the workspace bloc a
  /// production mode expects its page to provide.
  Widget wrap(Widget child) => MaterialApp(
    navigatorKey: _navigatorKey,
    theme: ocpt_theme.ocptTheme.lightThemeData,
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
  /// schedule mode and settles.
  Future<void> mount(WidgetTester tester, {Size size = const Size(1600, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const OcptScheduleMode()));
    await tester.pumpAndSettle();
  }

  /// Takes the mode out of the tree, which is what leaving it for another mode does, and settles.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  /// Reads the localizations of the mounted mode.
  Tr trOf(WidgetTester tester) => Tr.of(tester.element(find.byType(OcptScheduleMode)));

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

  /// Taps [target] and settles.
  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Opens the right dock from the toolbar when it is shut, leaving it alone otherwise.
  Future<void> openRightDock(WidgetTester tester) async {
    final tr = trOf(tester);
    if (!isShown(find.byTooltip(tr.scheduleRightDockCloseTooltip))) {
      await tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    }
  }

  /// Opens the right dock on the tab labelled [label].
  Future<void> openDockTab(WidgetTester tester, String label) async {
    await openRightDock(tester);
    await tap(tester, find.text(label));
  }

  /// Scopes [matching] to the export panel dialog.
  Finder inDialog(Finder matching) =>
      find.descendant(of: find.byType(AlertDialog), matching: matching);

  /// Taps the centre view segment labelled [label].
  Future<void> switchView(WidgetTester tester, String label) => tap(tester, find.text(label));

  /// Finds the text fields whose placeholder reads [hint].
  Finder fieldHinted(String hint) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );

  /// Finds the text fields of the inspector on the right dock, in the order they are drawn.
  Finder inspectorFields() =>
      find.descendant(of: find.byType(OcptScheduleInspector), matching: find.byType(TextField));

  /// Types [text] into [field] and pumps one frame, leaving the field-edit debounce running.
  Future<void> type(WidgetTester tester, Finder field, String text) async {
    await tester.enterText(field, text);
    await tester.pump();
  }

  /// Finds [text] inside the left dock.
  Finder inLeftDock(String text) =>
      find.descendant(of: find.byType(OcptScheduleLeftDock), matching: find.text(text));

  /// Finds a text containing [text] inside the centre's timetables.
  Finder inTimetable(String text) =>
      find.descendant(of: find.byType(OcptScheduleTimetable), matching: find.textContaining(text));

  /// Finds [text] inside the right dock's inspector.
  Finder inInspector(String text) =>
      find.descendant(of: find.byType(OcptScheduleInspector), matching: find.text(text));

  /// Taps [target] and pumps a single frame, so little fake time passes that a running field-edit
  /// debounce cannot run out under the tap.
  Future<void> tapQuickly(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}
