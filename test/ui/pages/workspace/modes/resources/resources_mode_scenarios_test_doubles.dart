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
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_list_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_tab_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_sheet_candidates_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The navigator [ResourcesScenarioHarness.wrap] mounts, so
/// [ResourcesScenarioRouterManager.pop] closes a dialog opened through `showDialog` exactly as the
/// real router would.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] pops [_navigatorKey]'s navigator and whose [push] answers with
/// [pushAnswer] instead of opening a page, so the project settings detour can be driven.
class ResourcesScenarioRouterManager extends OcptRouterManager {
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

/// A save location service whose dialog never opens: it counts how often it was asked and answers
/// as if the user had cancelled.
class ResourcesScenarioSaveLocationService extends OcptSaveLocationService {
  /// Class constructor
  ResourcesScenarioSaveLocationService()
    : super(logger: buildOcptLogsHelper("resources_scenarios_save_location"));

  /// The number of times a save dialog was requested since the last reset.
  int askedCount = 0;

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

/// One catalogue export a [ResourcesRecordingExportManager] was asked for.
class ResourcesRecordedExport {
  /// The name of the export that ran, `xlsx` or `contactList`.
  final String document;

  /// The catalogue the mode handed over.
  final OcptResourcesSnapshot snapshot;

  /// The page setup of a contact list export, null for the workbook.
  final OcptPageSetup? pageSetup;

  /// The project name the export was handed.
  final String projectName;

  /// Class constructor
  const ResourcesRecordedExport({
    required this.document,
    required this.snapshot,
    required this.pageSetup,
    required this.projectName,
  });
}

/// An export manager answering both resources exports with a saved file, and recording what each
/// one was handed so a scenario can tell what the mode had read at the moment of the export.
class ResourcesRecordingExportManager extends OcptExportManager {
  /// Class constructor
  ResourcesRecordingExportManager()
    : super(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: ResourcesScenarioSaveLocationService(),
      );

  /// Every export run since the last [reset], in order.
  final List<ResourcesRecordedExport> exports = [];

  /// Whether the next exports throw instead of answering.
  bool shouldFail = false;

  /// Whether the next exports answer as if the user had cancelled the dialog.
  bool shouldCancel = false;

  /// The save location service the project package export asks, counting its dialogs.
  ResourcesScenarioSaveLocationService get saveDialog =>
      saveLocationService as ResourcesScenarioSaveLocationService;

  /// Forgets everything recorded and answers normally again.
  void reset() {
    exports.clear();
    shouldFail = false;
    shouldCancel = false;
    saveDialog.askedCount = 0;
  }

  /// Records an export of [document], throwing when [shouldFail] says so.
  OcptExportOutcome? _record({
    required String document,
    required OcptResourcesSnapshot snapshot,
    required OcptPageSetup? pageSetup,
    required String projectName,
  }) {
    exports.add(
      ResourcesRecordedExport(
        document: document,
        snapshot: snapshot,
        pageSetup: pageSetup,
        projectName: projectName,
      ),
    );
    if (shouldFail) {
      throw StateError("$document export intentionally failed for the scenario");
    }

    return shouldCancel ? null : OcptExportSaved("/tmp/$document.out");
  }

  @override
  Future<OcptExportOutcome?> exportResourcesXlsx({
    required OcptResourcesSnapshot snapshot,
    required OcptResourcesXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async =>
      _record(document: "xlsx", snapshot: snapshot, pageSetup: null, projectName: projectName);

  @override
  Future<OcptExportOutcome?> exportContactList({
    required OcptResourcesSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptContactListLabels labels,
    required String projectName,
    required String fileTypeLabel,
    DateTime? exportDate,
    Rect? shareAnchor,
  }) async => _record(
    document: "contactList",
    snapshot: snapshot,
    pageSetup: pageSetup,
    projectName: projectName,
  );
}

/// The screenplay most scenarios start from: two scenes, the first one with a speaking role.
const resourcesScenarioScreenplay =
    "INT. KITCHEN - DAY\n\nSAM enters.\n\nSAM\nHello.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

/// The shared set-up of the resources mode scenarios: the global managers, one temporary project
/// per scenario, the way a scenario mounts the mode, drives it and reads the database back.
class ResourcesScenarioHarness {
  /// The preferences manager, backed by an in-memory store.
  late OcptPropertiesManager propertiesManager;

  /// The real projects manager.
  late OcptProjectsManager projectsManager;

  /// What both exports of the mode were handed.
  final exportManager = ResourcesRecordingExportManager();

  /// The router the mode navigates through.
  final routerManager = ResourcesScenarioRouterManager();

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
  Future<void> setUp({String screenplay = resourcesScenarioScreenplay}) async {
    await propertiesManager.resourcesLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await propertiesManager.resourcesRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );

    exportManager.reset();
    routerManager
      ..pushAnswer = null
      ..pushCount = 0;

    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_scenarios_");
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

  /// Reads the address book back from the database.
  Future<List<OcptPerson>> readPeople() =>
      projectsManager.peopleService.loadPeople(database: database);

  /// Reads the cast back from the database.
  Future<List<OcptRole>> readRoles() =>
      projectsManager.roleIndexService.loadRoles(database: database);

  /// Reads the locations, with their sets, back from the database.
  Future<List<OcptLocation>> readLocations() =>
      projectsManager.locationsService.loadLocations(database: database);

  /// Reads the elements catalogue back from the database.
  Future<List<OcptElement>> readElements() =>
      projectsManager.elementsService.loadElements(database: database);

  /// Reads the first episode's scenes back from the database, in screenplay order.
  Future<List<OcptSceneRef>> readScenes() => projectsManager.locationsService.loadScenes(
    database: database,
    screenplayId: screenplayId,
    episodeNumber: null,
  );

  /// Creates a person called [firstName] [lastName] in the address book, returning the id.
  Future<String> seedPerson(String firstName, {String lastName = ""}) async {
    final id = await projectsManager.peopleService.createPerson(database: database);
    await projectsManager.peopleService.updatePerson(
      database: database,
      personId: id!,
      firstName: Value(firstName),
      lastName: Value(lastName),
    );
    return id;
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

  /// Returns the id of the role the screenplay reconciliation named [name].
  Future<String> roleIdNamed(String name) async =>
      (await readRoles()).firstWhere((role) => role.name == name).id;

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

  /// Creates a prop called [name], returning the id.
  Future<String> seedElement(String name) async {
    final id = await projectsManager.elementsService.createElement(
      database: database,
      name: name,
      category: OcptElementCategory.prop,
      sourceKind: OcptElementSourceKind.owned,
    );
    return id!;
  }

  /// Says the scene at [sceneIndex] is shot in set [setId], returning the scene id.
  Future<String> seedSceneInSet(String setId, {int sceneIndex = 0}) async {
    final sceneId = (await readScenes())[sceneIndex].id;
    await projectsManager.locationsService.assignSceneToSet(
      database: database,
      sceneId: sceneId,
      setId: setId,
    );
    return sceneId;
  }

  /// Links element [elementId] to role [roleId], the way the role sheet's `Their things` card does.
  Future<void> seedRoleElement(String roleId, String elementId) async {
    await projectsManager.elementsService.addRoleElement(
      database: database,
      roleId: roleId,
      elementId: elementId,
    );
  }

  /// Links element [elementId] to the scene at [sceneIndex], returning the scene id.
  Future<String> seedSceneElement(String elementId, {int sceneIndex = 0}) async {
    final sceneId = (await readScenes())[sceneIndex].id;
    await projectsManager.elementsService.addSceneElement(
      database: database,
      sceneId: sceneId,
      elementId: elementId,
    );
    return sceneId;
  }

  /// Records person [personId] as a candidate for role [roleId].
  Future<void> seedCandidate(String roleId, String personId) async {
    await projectsManager.roleCandidatesService.addCandidate(
      database: database,
      roleId: roleId,
      personId: personId,
    );
  }

  /// Reads every live candidacy back from the database, grouped by role.
  Future<Map<String, List<OcptRoleCandidate>>> readCandidates() async => projectsManager
      .roleCandidatesService
      .loadCandidatesByRoleId(database: database, people: await readPeople());

  /// Wraps [child] with the localization delegates, the theme, the navigator
  /// [ResourcesScenarioRouterManager.pop] closes dialogs on, a scaffold, and the workspace bloc a
  /// production mode expects its page to provide.
  Widget wrap(Widget child) => MaterialApp(
    navigatorKey: _navigatorKey,
    theme: ocptTheme.lightThemeData,
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
  /// resources mode and settles.
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1600, 1000),
    Widget mode = const OcptResourcesMode(),
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
  Tr trOf(WidgetTester tester) => Tr.of(tester.element(find.byType(OcptResourcesMode)));

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

  /// Finds the text fields whose placeholder reads [hint].
  Finder fieldHinted(String hint) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );

  /// Finds the text field of the sheet field captioned [label], which a sheet draws in capitals
  /// above its input.
  Finder fieldLabelled(String label) => find.descendant(
    of: find.ancestor(of: find.text(label.toUpperCase()), matching: find.byType(Column)).first,
    matching: find.byType(TextField),
  );

  /// Finds the note field of the candidacy on the role sheet, once its row is unfolded.
  Finder candidateNoteField() => find.descendant(
    of: find.byType(OcptRoleSheetCandidatesCard),
    matching: find.byType(TextField),
  );

  /// Unfolds the note of the first candidacy of the role sheet.
  Future<void> openCandidateNote(WidgetTester tester) =>
      tap(tester, find.text(trOf(tester).resourcesRoleCandidateNotesLabel.toUpperCase()).first);

  /// Finds [target] inside the list panel on the left, the only place an unselected record's name
  /// is drawn as plain text.
  Finder inList(Finder target) =>
      find.descendant(of: find.byType(OcptResourcesListPanel), matching: target);

  /// Finds every text field currently on screen that refuses typing.
  Finder readOnlyFields() =>
      find.byWidgetPredicate((widget) => widget is TextField && widget.readOnly);

  /// Finds every text field currently on screen that accepts typing.
  Finder editableFields() =>
      find.byWidgetPredicate((widget) => widget is TextField && !widget.readOnly);

  /// Taps the list panel's tab labelled [label].
  Future<void> openTab(WidgetTester tester, String label) => tap(
    tester,
    find.descendant(of: find.byType(OcptResourcesTabBar), matching: find.text(label)),
  );

  /// Confirms the question the mode put in a confirm dialog, tapping [confirmLabel].
  Future<void> confirmDialog(WidgetTester tester, String confirmLabel) async {
    expect(find.byType(OcptConfirmDialog), findsOneWidget);
    await tap(
      tester,
      find.descendant(of: find.byType(OcptConfirmDialog), matching: find.text(confirmLabel)),
    );
  }

  /// Opens the right dock from the toolbar when it is shut, on its `Versions` tab.
  Future<void> openVersions(WidgetTester tester) async {
    final tr = trOf(tester);
    if (!isShown(find.byTooltip(tr.resourcesRightDockCloseTooltip))) {
      await tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    }
  }
}
