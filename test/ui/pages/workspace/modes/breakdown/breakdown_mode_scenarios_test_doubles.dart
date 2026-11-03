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
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// The navigator [BreakdownScenarioHarness.wrap] mounts, so
/// [BreakdownScenarioRouterManager.pop] closes a dialog opened through `showDialog` exactly as the
/// real router would.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] pops [_navigatorKey]'s navigator and whose [push] answers with
/// [pushAnswer] instead of opening a page, so the project settings detour can be driven.
class BreakdownScenarioRouterManager extends OcptRouterManager {
  /// The answer every [push] gives, what the project settings page returns when it closes.
  bool? pushAnswer;

  /// The number of pages pushed since the last reset.
  int pushCount = 0;

  /// Pop the route of the test's own navigator, when it can pop.
  @override
  void pop<Y extends Object?>([Y? result]) {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }

  /// Count the push, and answer with the canned answer when its type fits.
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

/// A save location service whose dialog never opens: it counts how often it was asked and answers
/// as if the user had cancelled.
class BreakdownScenarioSaveLocationService extends OcptSaveLocationService {
  /// The number of times a save dialog was requested since the last reset.
  int askedCount = 0;

  /// Class constructor
  BreakdownScenarioSaveLocationService()
    : super(logger: buildOcptLogsHelper("breakdown_scenarios_save_location"));

  /// Count the question and answer that nothing was picked.
  @override
  Future<String?> pickSaveLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
    String? initialDirectory,
  }) async {
    askedCount++;
    return null;
  }
}

/// One breakdown export a [BreakdownRecordingExportManager] was asked for.
class BreakdownRecordedExport {
  /// The name of the export that ran, `sheets` or `xlsx`.
  final String document;

  /// The breakdown the mode handed over.
  final OcptBreakdownSnapshot snapshot;

  /// The page setup the document is typeset with.
  final OcptPageSetup pageSetup;

  /// The project name the export was handed.
  final String projectName;

  /// The episode tag the export was handed, null on a single-episode project.
  final String? episodeTag;

  /// The sheets option saying only the done scenes are printed, null for the workbook.
  final bool? onlyDoneScenes;

  /// The sheets option saying the notes are printed, null for the workbook.
  final bool? includeNotes;

  /// The sheets option saying the closing to-find list is printed, null for the workbook.
  final bool? includeToFindList;

  /// The number of scenes the parsed screenplay handed over holds.
  final int parsedSceneCount;

  /// Class constructor
  const BreakdownRecordedExport({
    required this.document,
    required this.snapshot,
    required this.pageSetup,
    required this.projectName,
    required this.episodeTag,
    required this.onlyDoneScenes,
    required this.includeNotes,
    required this.includeToFindList,
    required this.parsedSceneCount,
  });
}

/// An export manager answering both breakdown exports with a saved file, and recording what each
/// one was handed so a scenario can tell what the mode had read at the moment of the export.
class BreakdownRecordingExportManager extends OcptExportManager {
  /// Every export run since the last [reset], in order.
  final List<BreakdownRecordedExport> exports = [];

  /// Whether the next exports throw instead of answering.
  bool shouldFail = false;

  /// Whether the next exports answer as if the user had cancelled the dialog.
  bool shouldCancel = false;

  /// Whether the next workbook exports answer with a failure outcome instead of a saved file.
  bool shouldAnswerFailed = false;

  /// The save location service the project package export asks, counting its dialogs.
  BreakdownScenarioSaveLocationService get saveDialog =>
      saveLocationService as BreakdownScenarioSaveLocationService;

  /// Class constructor
  BreakdownRecordingExportManager()
    : super(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: BreakdownScenarioSaveLocationService(),
      );

  /// Forgets everything recorded and answers normally again.
  void reset() {
    exports.clear();
    shouldFail = false;
    shouldCancel = false;
    shouldAnswerFailed = false;
    saveDialog.askedCount = 0;
  }

  /// Record the export as sheets, with its options.
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
  }) async => _record(
    document: "sheets",
    parsed: document,
    snapshot: snapshot,
    pageSetup: pageSetup,
    projectName: projectName,
    episodeTag: episodeTag,
    onlyDoneScenes: onlyDoneScenes,
    includeNotes: includeNotes,
    includeToFindList: includeToFindList,
  );

  /// Record the export as a workbook.
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
  }) async => _record(
    document: "xlsx",
    parsed: document,
    snapshot: snapshot,
    pageSetup: pageSetup,
    projectName: projectName,
    episodeTag: episodeTag,
  );

  /// Records an export of [document], throwing when [shouldFail] says so.
  OcptExportOutcome? _record({
    required String document,
    required FountainDocument parsed,
    required OcptBreakdownSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required String projectName,
    required String? episodeTag,
    bool? onlyDoneScenes,
    bool? includeNotes,
    bool? includeToFindList,
  }) {
    exports.add(
      BreakdownRecordedExport(
        document: document,
        snapshot: snapshot,
        pageSetup: pageSetup,
        projectName: projectName,
        episodeTag: episodeTag,
        onlyDoneScenes: onlyDoneScenes,
        includeNotes: includeNotes,
        includeToFindList: includeToFindList,
        parsedSceneCount: parsed.scenes.length,
      ),
    );
    if (shouldFail) {
      throw StateError("$document export intentionally failed for the scenario");
    }
    if (shouldAnswerFailed) {
      return const OcptExportFailed();
    }

    return shouldCancel ? null : OcptExportSaved("/tmp/$document.out");
  }
}

/// The screenplay most scenarios start from: two scenes, the first one with a speaking role. The
/// words "teapot", "kettle" and "rake" each sit in the scene the scenarios click them in.
const breakdownScenarioScreenplay =
    "INT. KITCHEN - DAY\n\nSAM enters with a teapot on the table.\n\nSAM\nHello.\n\n"
    "EXT. GARDEN - NIGHT\n\nA teapot rests by the old rake.\n";

/// The shared set-up of the breakdown mode scenarios: the global managers, one temporary project
/// per scenario, the way a scenario mounts the mode, drives it and reads the database back.
class BreakdownScenarioHarness {
  /// The preferences manager, backed by an in-memory store.
  late OcptPropertiesManager propertiesManager;

  /// The real projects manager.
  late OcptProjectsManager projectsManager;

  /// What both exports of the mode were handed.
  final exportManager = BreakdownRecordingExportManager();

  /// The router the mode navigates through.
  final routerManager = BreakdownScenarioRouterManager();

  /// The folder holding the current scenario's project file.
  late Directory tempDir;

  /// The database of the open project.
  OcptProjectDatabase get database => projectsManager.currentProject!.database;

  /// The screenplay the project opened with: its first episode.
  String get screenplayId => projectsManager.currentProject!.primaryScreenplayId;

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
  Future<void> setUp({String screenplay = breakdownScenarioScreenplay}) async {
    await propertiesManager.breakdownLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await propertiesManager.breakdownRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );
    await propertiesManager.breakdownLastRightDockTab.store(OcptBreakdownRightDockTab.inspector);

    exportManager.reset();
    routerManager
      ..pushAnswer = null
      ..pushCount = 0;

    tempDir = await Directory.systemTemp.createTemp("ocpt_breakdown_scenarios_");
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

  /// Reads the first episode's scenes, with their tags, back from the database.
  Future<List<OcptBreakdownScene>> readScenes() => projectsManager.breakdownService
      .loadScenes(database: database, screenplayId: screenplayId, episodeNumber: null)
      .valueOrFail;

  /// Reads every live tag of the first episode back from the database, as models.
  Future<List<OcptBreakdownTag>> readTags() async => [
    for (final row
        in await projectsManager.breakdownService
            .loadTags(database: database, screenplayId: screenplayId)
            .valueOrFail)
      OcptBreakdownTag.fromRow(row),
  ];

  /// Reads the elements catalogue back from the database.
  Future<List<OcptElement>> readElements() =>
      projectsManager.elementsService.loadElements(database: database).valueOrFail;

  /// Reads the locations, with their sets, back from the database.
  Future<List<OcptLocation>> readLocations() =>
      projectsManager.locationsService.loadLocations(database: database);

  /// Reads the cast back from the database.
  Future<List<OcptRole>> readRoles() =>
      projectsManager.roleIndexService.loadRoles(database: database);

  /// Reads the breakdown status of the scene at [sceneIndex] back from the database.
  Future<String> readSceneStatus(int sceneIndex) async =>
      (await readScenes())[sceneIndex].status.name;

  /// Reads the breakdown notes of the scene at [sceneIndex] back from the database.
  Future<String> readSceneNotes(int sceneIndex) async => (await readScenes())[sceneIndex].notes;

  /// Creates a prop called [name], returning the id.
  Future<String> seedElement(String name) async {
    final id = await projectsManager.elementsService
        .createElement(
          database: database,
          name: name,
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        )
        .maybeValueOrFail;
    return id!;
  }

  /// Creates a location called [name], returning the id.
  Future<String> seedLocation(String name) async {
    final id = await projectsManager.locationsService.createLocation(
      database: database,
      name: name,
    );
    return id!;
  }

  /// Creates a set called [name] in location [locationId], returning the id.
  Future<String> seedSet(String locationId, String name) async {
    final id = await projectsManager.locationsService.createSet(
      database: database,
      locationId: locationId,
      name: name,
    );
    return id!;
  }

  /// Creates a hand-added silent role called [name], returning the id.
  Future<String> seedRole(String name) async {
    final id = await projectsManager.roleIndexService.addRole(
      database: database,
      screenplayId: screenplayId,
      name: name,
      kind: OcptRoleKind.silent,
    );
    return id!;
  }

  /// Creates a person called [firstName], returning the id.
  Future<String> seedPerson(String firstName) async {
    final id = await projectsManager.peopleService.createPerson(database: database);
    await projectsManager.peopleService.updatePerson(
      database: database,
      personId: id!,
      firstName: Value(firstName),
    );
    return id;
  }

  /// Tags the passage [text] of the scene at [sceneIndex] with target [targetId] of [targetKind],
  /// through the service, returning the tag id.
  ///
  /// The offsets are scene-relative and found in the scene's own text, so a scenario names the
  /// passage rather than counting characters.
  Future<String> seedTag({
    required int sceneIndex,
    required String text,
    required OcptBreakdownTargetKind targetKind,
    required String targetId,
  }) async {
    final scene = (await readScenes())[sceneIndex];
    final fullText = await projectsManager.screenplayService.loadScreenplayText(
      database: database,
      screenplayId: screenplayId,
    );
    final sceneText = fullText.substring(scene.charStart, scene.charEnd);
    final start = sceneText.indexOf(text);
    expect(start, isNonNegative, reason: "$text must be in the scene");
    final tagId = await projectsManager.breakdownService
        .createTag(
          database: database,
          sceneId: scene.id,
          startOffset: start,
          endOffset: start + text.length,
          taggedText: text,
          targetKind: targetKind,
          targetId: targetId,
        )
        .maybeValueOrFail;
    return tagId!;
  }

  /// Wraps [child] with the localization delegates, the theme, the navigator
  /// [BreakdownScenarioRouterManager.pop] closes dialogs on, a scaffold, and the workspace bloc a
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
  /// breakdown mode and settles.
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1800, 1400),
    Widget mode = const OcptBreakdownMode(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(mode));
    await tester.pumpAndSettle();
  }

  /// Takes the mode out of the tree, which is what leaving it for another mode does, and settles.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  /// Reads the localizations of the mounted mode.
  Tr trOf(WidgetTester tester) => Tr.of(tester.element(find.byType(OcptBreakdownMode)));

  /// Reaches the workspace bloc the scenario's scaffold provides to the mode.
  OcptWorkspaceBloc workspaceBlocOf(WidgetTester tester) =>
      tester.element(find.byType(Scaffold)).read<OcptWorkspaceBloc>();

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

  /// Gives a write that real file I/O finishes outside the fake clock a bounded real time to land,
  /// pumping a frame between two checks without letting any fake time pass, so a running field-edit
  /// debounce cannot run out meanwhile; fails when [isWritten] still says no after about two
  /// seconds.
  Future<void> eventually(WidgetTester tester, Future<bool> Function() isWritten) async {
    var written = false;
    for (var attempt = 0; attempt < 100 && !written; attempt++) {
      await tester.pump();
      written = (await tester.runAsync(isWritten))!;
      if (!written) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
    }
    expect(written, isTrue);
  }

  /// Whether [target] is on screen right now.
  bool isShown(Finder target) => target.evaluate().isNotEmpty;

  /// Taps [target] and settles.
  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Scrolls [target] into view, taps it and settles.
  Future<void> tapScrolled(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tap(tester, target);
  }

  /// Scrolls the right dock's sheet until [target], which a lazily built list only creates once it
  /// is near the viewport, is on screen.
  Future<void> scrollRightDockTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find
          .descendant(
            of: find
                .descendant(
                  of: find.byType(OcptBreakdownRightDock),
                  matching: find.byType(ListView),
                )
                .first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  /// Taps [target] and pumps a single frame, so little fake time passes that a running field-edit
  /// debounce cannot run out under the tap.
  Future<void> tapQuickly(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Taps [target], which opens a menu or a dialog, and lets that open without letting a running
  /// field-edit debounce out.
  Future<void> tapOpening(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Types [text] into [field] and pumps one frame, leaving the field-edit debounce running.
  Future<void> type(WidgetTester tester, Finder field, String text) async {
    await tester.enterText(field, text);
    await tester.pump();
  }

  /// Lets the field-edit debounce run out, then settles.
  Future<void> letDebounceRun(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
  }

  /// Finds the text fields whose placeholder reads [hint].
  Finder fieldHinted(String hint) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );

  /// Finds every text field currently on screen that accepts typing.
  Finder editableFields() =>
      find.byWidgetPredicate((widget) => widget is TextField && !widget.readOnly);

  /// Finds every text field currently on screen that refuses typing.
  Finder readOnlyFields() =>
      find.byWidgetPredicate((widget) => widget is TextField && widget.readOnly);

  /// Finds the text field of the sheet field captioned [label], which a sheet draws in capitals
  /// above its input.
  Finder fieldLabelled(String label) => find.descendant(
    of: find.ancestor(of: find.text(label.toUpperCase()), matching: find.byType(Column)).first,
    matching: find.byType(TextField),
  );

  /// Finds a word of the script view, which is drawn with the whitespace that follows it in the
  /// source; [occurrence] picks one when the word appears in several scenes.
  Finder word(String text, {int occurrence = 0}) => find.text(text).at(occurrence);

  /// Confirms the question the mode put in a confirm dialog, tapping [confirmLabel].
  Future<void> confirmDialog(WidgetTester tester, String confirmLabel) async {
    expect(find.byType(OcptConfirmDialog), findsOneWidget);
    await tap(
      tester,
      find.descendant(of: find.byType(OcptConfirmDialog), matching: find.text(confirmLabel)),
    );
  }

  /// Opens the right dock from the toolbar when it is shut.
  Future<void> openRightDock(WidgetTester tester) async {
    final tr = trOf(tester);
    if (!isShown(find.byTooltip(tr.breakdownRightDockCloseTooltip))) {
      await tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    }
  }
}
