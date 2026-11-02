// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_find_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_page.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The sample screenplay most scenarios start from: two scenes, one dialogue and some action.
const scenarioSampleText = """
INT. KITCHEN - DAY

SARAH
(to herself)
Smells like Sunday.

EXT. GARDEN - NIGHT

Something moves in the dark.
""";

/// The navigator [EditorScenarioHarness.wrap] mounts, so [EditorScenarioRouterManager.pop] closes a
/// dialog opened through `showDialog` exactly as the real router would.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A route the page pushed, with the extra it handed over.
typedef EditorPushedRoute = ({OcptRoute route, Object? extra});

/// A router manager whose [pop] pops [_navigatorKey]'s navigator and whose [push] records the route
/// and answers with [pushAnswer] instead of opening a page.
class EditorScenarioRouterManager extends OcptRouterManager {
  /// The answer every [push] gives, what the project settings page returns when it closes.
  bool? pushAnswer;

  /// Every route pushed since the last reset, in order.
  final List<EditorPushedRoute> pushed = [];

  /// The number of times the page asked to leave since the last reset.
  int popCount = 0;

  /// Forgets everything recorded.
  void reset() {
    pushAnswer = null;
    pushed.clear();
    popCount = 0;
  }

  /// Count the pop, then pop the route of the test's own navigator, when it can pop.
  @override
  void pop<Y extends Object?>([Y? result]) {
    popCount++;
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }

  /// Record the route and the extra pushed, and answer with the canned answer when its type fits.
  @override
  Future<Y?> push<Y extends Object?>(
    OcptRoute route, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) async {
    pushed.add((route: route, extra: extra));
    final answer = pushAnswer;
    return answer is Y ? answer as Y : null;
  }
}

/// A save location service whose dialog never opens: it counts how often it was asked and answers
/// as if the user had cancelled.
class EditorScenarioSaveLocationService extends OcptSaveLocationService {
  /// The number of times a save dialog was requested since the last reset.
  int askedCount = 0;

  /// Class constructor
  EditorScenarioSaveLocationService()
    : super(logger: buildOcptLogsHelper("editor_scenarios_save_location"));

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

/// One export an [EditorScenarioExportManager] was asked for.
class EditorRecordedExport {
  /// Either `fountain` or `pdf`.
  final String kind;

  /// The Fountain text the export was handed: the text itself for `fountain`, the document's
  /// source text for `pdf`.
  final String text;

  /// The project name the export was handed.
  final String projectName;

  /// The episode tag the export was handed, null for a single-episode project.
  final String? episodeTag;

  /// The page setup the PDF is typeset with, null for the Fountain export.
  final OcptPageSetup? pageSetup;

  /// Whether the PDF prints scene numbers, null for the Fountain export.
  final bool? includeSceneNumbers;

  /// Whether the PDF prints the title page, null for the Fountain export.
  final bool? includeTitlePage;

  /// Class constructor
  const EditorRecordedExport({
    required this.kind,
    required this.text,
    required this.projectName,
    this.episodeTag,
    this.pageSetup,
    this.includeSceneNumbers,
    this.includeTitlePage,
  });
}

/// An export manager answering the screenplay's two exports with a saved file, and the import
/// picker with whatever [importAnswer] says, recording what each one was handed.
class EditorScenarioExportManager extends OcptExportManager {
  /// Every export run since the last [reset], in order.
  final List<EditorRecordedExport> exports = [];

  /// Whether the next exports throw instead of answering.
  bool shouldFail = false;

  /// Whether the next exports answer as if the user had cancelled the dialog.
  bool shouldCancel = false;

  /// The number of times the import file picker opened since the last reset.
  int pickCount = 0;

  /// What the import file picker answers.
  ResultWithStatus<OcptScreenplayImportStatus, OcptImportedFountainModel> importAnswer =
      const ResultWithStatus(status: OcptScreenplayImportStatus.cancelled);

  /// The save location service the project package export asks, counting its dialogs.
  EditorScenarioSaveLocationService get saveDialog =>
      saveLocationService as EditorScenarioSaveLocationService;

  /// Class constructor
  EditorScenarioExportManager()
    : super(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: EditorScenarioSaveLocationService(),
      );

  /// Forgets everything recorded and answers normally again.
  void reset() {
    exports.clear();
    shouldFail = false;
    shouldCancel = false;
    pickCount = 0;
    importAnswer = const ResultWithStatus(status: OcptScreenplayImportStatus.cancelled);
    saveDialog.askedCount = 0;
  }

  /// Makes the import picker answer with the file [fountainText].
  void importing(String fountainText) {
    importAnswer = ResultWithStatus(
      status: OcptScreenplayImportStatus.ok,
      value: OcptImportedFountainModel(fountainText: fountainText, sourceFileName: "script.fdx"),
    );
  }

  /// Makes the import picker answer that the picked file is not a screenplay.
  void importUnreadable() {
    importAnswer = const ResultWithStatus(status: OcptScreenplayImportStatus.unreadableFile);
  }

  /// Record the export as a Fountain one.
  @override
  Future<OcptExportOutcome?> exportFountain({
    required String fountainText,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async => _record(
    EditorRecordedExport(
      kind: "fountain",
      text: fountainText,
      projectName: projectName,
      episodeTag: episodeTag,
    ),
  );

  /// Record the export as a PDF one, with its page setup and options.
  @override
  Future<OcptExportOutcome?> exportPdf({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async => _record(
    EditorRecordedExport(
      kind: "pdf",
      text: document.sourceText,
      projectName: projectName,
      episodeTag: episodeTag,
      pageSetup: pageSetup,
      includeSceneNumbers: includeSceneNumbers,
      includeTitlePage: includeTitlePage,
    ),
  );

  /// Count the pick and answer with the canned import.
  @override
  Future<ResultWithStatus<OcptScreenplayImportStatus, OcptImportedFountainModel>>
  pickAndReadScreenplay({required String fileTypeLabel}) async {
    pickCount++;

    return importAnswer;
  }

  /// Records [export], then answers the way the switches say.
  OcptExportOutcome? _record(EditorRecordedExport export) {
    exports.add(export);
    if (shouldFail) {
      throw StateError("${export.kind} export intentionally failed for the scenario");
    }

    return shouldCancel ? null : OcptExportSaved("/tmp/${export.projectName}.${export.kind}");
  }
}

/// Answers a bundled dictionary asset with a miniature hunspell pair, so the spell-check isolate
/// has real work to do without parsing the two megabytes the app ships.
///
/// The English dictionary knows `hello`, `world` and a handful of function words; the French one
/// knows `bonjour` and `monde` and nothing English.
Future<String> loadScenarioDictionaryAsset(String assetKey) async {
  if (assetKey.endsWith(".aff")) {
    return "SET UTF-8\n";
  }

  return assetKey.contains("/fr/")
      ? "5\nbonjour\nmonde\nle\nchat\nest\n"
      : "13\nhello\nworld\nthe\ncat\nsat\non\nmat\nroom\nis\nhere\nwalks\ninto\nand\n";
}

/// The shared set-up of the screenplay editor scenarios: the global managers, one temporary project
/// per scenario, the way a scenario mounts the page, drives it and reads the database back.
class EditorScenarioHarness {
  /// The preferences manager, backed by an in-memory store.
  late OcptPropertiesManager propertiesManager;

  /// The real projects manager.
  late OcptProjectsManager projectsManager;

  /// What the exports and the import picker were handed.
  final exportManager = EditorScenarioExportManager();

  /// The router the page navigates through.
  final routerManager = EditorScenarioRouterManager();

  /// The real spell-check manager, running its worker isolate over [loadScenarioDictionaryAsset].
  late OcptSpellCheckManager spellCheckManager;

  /// The folder holding the current scenario's project file.
  late Directory tempDir;

  /// The id of the episode the page edits when the workspace has not selected another one.
  String get episodeId => projectsManager.currentProject!.primaryScreenplayId;

  /// Finds the raw source field's text field.
  Finder get rawField =>
      find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField));

  /// Finds the find bar's text fields: the query first, the replacement last.
  Finder get barFields =>
      find.descendant(of: find.byType(OcptEditorFindBar), matching: find.byType(TextField));

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

    spellCheckManager = OcptSpellCheckManager(loadAsset: loadScenarioDictionaryAsset);

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(routerManager)
      ..registerSingleton<OcptExportManager>(exportManager)
      ..registerSingleton<OcptSpellCheckManager>(spellCheckManager);
  }

  /// Stops the spell-check worker the whole file shared.
  Future<void> tearDownAll() => spellCheckManager.disposeLifeCycle();

  /// Resets every preference the page reads on entry, then creates a fresh project holding
  /// [scenarioSampleText].
  ///
  /// The in-memory preference store outlives a single scenario, so every preference is written back
  /// to a known value here: raw mode, no page simulation (so the source field takes the whole
  /// centre) and spell-checking off, which a scenario about it switches on for itself.
  Future<void> setUp() async {
    await propertiesManager.deleteAll();
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    await propertiesManager.isPageSimulationEnabled.store(false);
    await propertiesManager.spellCheckVisible.store(false);

    exportManager.reset();
    routerManager.reset();
    await spellCheckManager.useLanguage(null);
    spellCheckManager
      ..ignoreWords(const {})
      ..setLearnedWords(const {});

    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_scenarios_");
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);

    await seedScreenplay(scenarioSampleText);
  }

  /// Closes the project and removes its folder.
  Future<void> tearDown() async {
    await projectsManager.closeCurrentProject();
    await tempDir.delete(recursive: true);
  }

  /// Writes [text] as the screenplay of the open project, as an earlier session would have left it.
  Future<void> seedScreenplay(String text, {String? screenplayId}) async {
    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: screenplayId ?? project.primaryScreenplayId,
      fountainText: text,
      snapshotReason: OcptSnapshotReason.manual,
    );
  }

  /// Reads the stored text of the episode [screenplayId], by default the first one, from the
  /// working copy file.
  Future<String> storedText({String? screenplayId}) =>
      projectsManager.screenplayService.loadScreenplayText(
        database: projectsManager.currentProject!.fileDatabase,
        screenplayId: screenplayId ?? episodeId,
      );

  /// Opens the scenario's project file again, as the home page would after the page left it.
  Future<void> reopenProject() async {
    final result = await projectsManager.openProject(filePath: p.join(tempDir.path, "movie.ocpt"));
    expect(result.status.isSuccess, isTrue);
  }

  /// Makes every write of the first episode's text fail, or lets them through again: the episode's
  /// row is tombstoned, which the service reads as a screenplay that is no longer there.
  Future<void> setSaveFailing({required bool isFailing}) async {
    final database = projectsManager.currentProject!.fileDatabase;
    await (database.update(database.ocptScreenplaysTable)
          ..where((table) => table.id.equals(episodeId)))
        .write(OcptScreenplaysTableCompanion(isDeleted: Value(isFailing)));
  }

  /// Reads the live snapshots of the first episode back, oldest first, as `(reason, text)`: the
  /// text a snapshot holds is the one the save that took it replaced.
  Future<List<({OcptSnapshotReason reason, String text})>> snapshots() async {
    final database = projectsManager.currentProject!.fileDatabase;
    final rows =
        await (database.select(database.ocptScreenplaySnapshotsTable)
              ..where((table) => table.screenplayId.equals(episodeId) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get();

    return [for (final row in rows) (reason: row.reason, text: row.fountainText)];
  }

  /// Reads the reasons of the live snapshots of the first episode back, oldest first.
  Future<List<OcptSnapshotReason>> snapshotReasons() async => [
    for (final snapshot in await snapshots()) snapshot.reason,
  ];

  /// Holds the project database busy with a transaction of its own, so that every write the page
  /// asks for queues up behind it, and returns the function that lets it go.
  ///
  /// This is how a scenario keeps a save in flight for as long as it needs to.
  Future<void> Function() holdDatabase() {
    final release = Completer<void>();
    final held = projectsManager.currentProject!.fileDatabase.transaction(() => release.future);

    return () async {
      release.complete();
      await held;
    };
  }

  /// Reads the live scenes of the first episode back from the working copy file, in order, as
  /// `(id, heading, number)`.
  Future<List<({String id, String heading, String? number})>> storedScenes() async {
    final database = projectsManager.currentProject!.fileDatabase;
    final rows =
        await (database.select(database.ocptScenesTable)
              ..where((table) => table.screenplayId.equals(episodeId) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.asc(table.charStart)]))
            .get();

    return [for (final row in rows) (id: row.id, heading: row.heading, number: row.sceneNumber)];
  }

  /// Wraps [child] with the localization delegates, the theme, the navigator
  /// [EditorScenarioRouterManager.pop] closes dialogs on, and — unless [child] provides its own —
  /// the workspace bloc a production mode expects its page to find.
  Widget wrap(Widget child, {bool providesWorkspace = false}) => MaterialApp(
    navigatorKey: _navigatorKey,
    theme: ocpt_theme.ocptTheme.lightThemeData,
    localizationsDelegates: const [
      Tr.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: Tr.delegate.supportedLocales,
    home: providesWorkspace
        ? child
        : BlocProvider<OcptWorkspaceBloc>(create: (context) => OcptWorkspaceBloc(), child: child),
  );

  /// Sizes the test surface to [size] (wider than the compact breakpoint by default) and mounts the
  /// screenplay editor page alone, then settles.
  Future<void> mount(WidgetTester tester, {Size size = const Size(1400, 900)}) async {
    _sizeSurface(tester, size);
    await tester.pumpWidget(wrap(const OcptEditorPage()));
    await tester.pumpAndSettle();
  }

  /// Sizes the test surface to [size] and mounts the whole workspace page, the screenplay being
  /// its default mode, then settles. The mode switcher and the episode selector are real.
  Future<void> mountWorkspace(WidgetTester tester, {Size size = const Size(1750, 900)}) async {
    _sizeSurface(tester, size);
    await tester.pumpWidget(wrap(const OcptWorkspacePage(), providesWorkspace: true));
    await tester.pumpAndSettle();
  }

  /// Takes whatever is mounted out of the tree, which is what leaving the page does, and settles.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  /// Reads the localizations of the mounted page.
  Tr trOf(WidgetTester tester) => Tr.of(tester.element(find.byType(Scaffold).first));

  /// Reaches the workspace bloc the mounted page reads its episodes from.
  OcptWorkspaceBloc workspaceBlocOf(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first).read<OcptWorkspaceBloc>();

  /// Reads the text the raw source field holds.
  String rawText(WidgetTester tester) => tester.widget<TextField>(rawField).controller!.text;

  /// Reads the selection the raw source field holds.
  TextSelection rawSelection(WidgetTester tester) =>
      tester.widget<TextField>(rawField).controller!.selection;

  /// Types [text] into [field] and pumps one frame, leaving every debounce running.
  Future<void> type(WidgetTester tester, Finder field, String text) async {
    await tester.enterText(field, text);
    await tester.pump();
  }

  /// Taps [target] and settles.
  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Taps [target] and pumps a single short frame, so little fake time passes that a running
  /// debounce cannot run out under the tap.
  Future<void> tapQuickly(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Taps [target], which opens a menu or a dialog, and lets that open without letting a running
  /// debounce out.
  Future<void> tapOpening(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Presses the Ctrl chord of [key], optionally with Shift.
  Future<void> chord(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false}) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    }
    await tester.sendKeyEvent(key);
    if (shift) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  /// Opens the `⋮` menu and taps its entry labelled [label].
  Future<void> tapOverflowEntry(WidgetTester tester, String label) async {
    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  /// Opens the toolbar's export panel and lets it appear without letting a debounce out.
  Future<void> openExportPanel(WidgetTester tester) =>
      tapOpening(tester, find.byTooltip(trOf(tester).workspaceExportTooltip));

  /// Finds [target] inside the open dialog.
  Finder inDialog(Finder target) => find.descendant(of: find.byType(Dialog), matching: target);

  /// Lets the real event loop run, a few milliseconds at a time, until [isDone] holds, then
  /// settles.
  ///
  /// A version preview or restore, and the spell-check isolate, read and write real files and
  /// ports, which a fake-async pump never waits for: the loop hands the real clock over between two
  /// pumps, and gives up after five seconds so a scenario that never gets there fails on its next
  /// expectation instead of hanging.
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
  /// pumping a frame between two checks without letting any fake time pass; fails when
  /// [isWritten] still says no after about two seconds.
  Future<void> eventually(
    WidgetTester tester,
    Future<bool> Function() isWritten, {
    String? reason,
  }) async {
    var written = false;
    for (var attempt = 0; attempt < 100 && !written; attempt++) {
      await tester.pump();
      written = (await tester.runAsync(isWritten))!;
      if (!written) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
    }
    expect(written, isTrue, reason: reason);
  }

  /// Whether [target] is on screen right now.
  bool isShown(Finder target) => target.evaluate().isNotEmpty;

  /// The words the raw source field currently underlines as misspelled, in order.
  List<String> underlinedWords(WidgetTester tester) {
    final field = tester.widget<TextField>(rawField);
    final span = field.controller!.buildTextSpan(
      context: tester.element(rawField),
      style: const TextStyle(),
      withComposing: false,
    );

    return [
      for (final child in span.children ?? const <InlineSpan>[])
        if (child is TextSpan && child.style?.decoration == TextDecoration.underline) child.text!,
    ];
  }

  /// Sizes the surface of [tester] to [size] for the rest of the test.
  void _sizeSurface(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
}
