// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_tracking_flag.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The seven weekday names an availability window's summary cell is built from, keyed by their
/// `DateTime.monday`…`DateTime.sunday` numbers — the locale's own names in the app, plain English
/// ones here.
const Map<int, String> _weekdayLabels = {
  DateTime.monday: "Mon",
  DateTime.tuesday: "Tue",
  DateTime.wednesday: "Wed",
  DateTime.thursday: "Thu",
  DateTime.friday: "Fri",
  DateTime.saturday: "Sat",
  DateTime.sunday: "Sun",
};

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  final _popCompleter = Completer<void>();

  /// Completes the moment [pop] is called.
  Future<void> get onPop => _popCompleter.future;

  /// Records the call instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {
    if (!_popCompleter.isCompleted) {
      _popCompleter.complete();
    }
  }
}

/// A file selector manager answering the picker with a file of its own, so a test never opens a
/// native dialog: [pickedPath] is what the user is pretending to pick, and null is a cancellation.
class _StubFileSelectorManager extends FileSelectorManager {
  /// The path the next pick answers with, or null to answer as a cancelled dialog does.
  final String? pickedPath;

  /// Class constructor
  const _StubFileSelectorManager({required this.pickedPath});

  /// Answers with [pickedPath] instead of opening the platform's own dialog.
  @override
  Future<ResultWithBoolStatus<XFile>> openSelector({
    required List<String> allowedExtensions,
    required String label,
    bool strictOnExtensions = true,
  }) async {
    final pickedPath = this.pickedPath;
    if (pickedPath == null) {
      return const ResultWithBoolStatus(status: BoolResultStatus.error);
    }

    return ResultWithBoolStatus(status: BoolResultStatus.success, value: XFile(pickedPath));
  }
}

/// An export manager whose [exportResourcesXlsx] is stubbed and whose calls are recorded, so the
/// bloc's export path can be exercised without any real native dialog or workbook write. Mirrors
/// `shot_list_bloc_test.dart`'s own `_FakeExportManager`.
class _FakeExportManager extends OcptExportManager {
  /// Class constructor
  _FakeExportManager({this.exportResult, this.fails = false})
    : super(fileSelectorManager: const FileSelectorManager());

  /// The path [exportResourcesXlsx] returns, or null to simulate a cancelled save dialog.
  final String? exportResult;

  /// Whether [exportResourcesXlsx] throws, to exercise the bloc's export failure path.
  final bool fails;

  /// The snapshot of the last [exportResourcesXlsx] call.
  OcptResourcesSnapshot? lastExportedSnapshot;

  /// The labels of the last [exportResourcesXlsx] call.
  OcptResourcesXlsxLabels? lastExportedLabels;

  /// The project name of the last [exportResourcesXlsx] call.
  String? lastExportedProjectName;

  /// The file type label of the last [exportResourcesXlsx] call.
  String? lastExportedFileTypeLabel;

  @override
  Future<String?> exportResourcesXlsx({
    required OcptResourcesSnapshot snapshot,
    required OcptResourcesXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
  }) async {
    lastExportedSnapshot = snapshot;
    lastExportedLabels = labels;
    lastExportedProjectName = projectName;
    lastExportedFileTypeLabel = fileTypeLabel;

    if (fails) {
      throw StateError("resources export intentionally failed for the test");
    }

    return exportResult;
  }

  /// The snapshot of the last [exportContactList] call.
  OcptResourcesSnapshot? lastExportedContactListSnapshot;

  /// The page setup of the last [exportContactList] call.
  OcptPageSetup? lastExportedContactListPageSetup;

  /// The labels of the last [exportContactList] call.
  OcptContactListLabels? lastExportedContactListLabels;

  /// The project name of the last [exportContactList] call.
  String? lastExportedContactListProjectName;

  /// The file type label of the last [exportContactList] call.
  String? lastExportedContactListFileTypeLabel;

  @override
  Future<String?> exportContactList({
    required OcptResourcesSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptContactListLabels labels,
    required String projectName,
    required String fileTypeLabel,
    DateTime? exportDate,
  }) async {
    lastExportedContactListSnapshot = snapshot;
    lastExportedContactListPageSetup = pageSetup;
    lastExportedContactListLabels = labels;
    lastExportedContactListProjectName = projectName;
    lastExportedContactListFileTypeLabel = fileTypeLabel;

    if (fails) {
      throw StateError("contact list export intentionally failed for the test");
    }

    return exportResult;
  }
}

/// The labels the export tests dispatch, standing in for what `ocptResourcesXlsxLabelsOf` builds
/// from a real `Tr`: the bloc only carries them through to the manager.
const _exportLabels = OcptResourcesXlsxLabels(
  fileNameSuffix: "resources",
  peopleSheetName: "People",
  rolesSheetName: "Roles",
  locationsSheetName: "Locations",
  elementsSheetName: "Elements",
  peopleColumnHeaders: {},
  rolesColumnHeaders: {},
  locationsColumnHeaders: {},
  elementsColumnHeaders: {},
  crewPositionLabels: {},
  roleKindLabels: {},
  imageRightsStatusLabels: {},
  permitStatusLabels: {},
  elementCategoryLabels: {},
  elementSourceKindLabels: {},
  dayPartSlotLabels: {},
  availabilityKindLabels: {},
  elementTrackingToSecureLabel: "To secure",
  elementTrackingSecuredLabel: "Secured",
  elementTrackingReadyLabel: "Ready",
  elementTrackingReturnedLabel: "Returned",
  everyDayLabel: "Every day",
  weekdayLabels: _weekdayLabels,
  sceneLabels: {},
);

/// The labels the contact list export tests dispatch, standing in for what
/// `ocptContactListLabelsOf` builds from a real `Tr`: the bloc only carries them through to the
/// manager.
const _contactListLabels = OcptContactListLabels(
  fileNameSuffix: "contacts",
  documentTitle: "Contact list",
  versionLabel: "Version",
  crewSectionTitle: "Crew",
  castSectionTitle: "Cast",
  nameHeader: "Name",
  positionHeader: "Position",
  phoneHeader: "Phone",
  emailHeader: "Email",
  crewDepartmentLabels: {},
  crewPositionLabels: {},
  unassignedDepartmentLabel: "Unassigned",
  emptyDocumentNote: "Nothing to print.",
);

/// The options the contact list export tests dispatch, standing in for what
/// `OcptContactListExportDialog` returns.
const _contactListOptions = OcptContactListExportOptions(
  format: OcptPageFormat.usLetter,
  margins: FountainPageMargins.standard(),
);

void main() {
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_bloc_test_");
    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager);
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

  /// Builds a bloc wired to the test project. [fieldEditDebounce] defaults to a short duration so
  /// tests exercising the field-edit debounce don't have to wait out the real 2 s one,
  /// [exportManager] to a [_FakeExportManager] whose export cancels, so no test ever reaches a
  /// native save dialog, and [overrideProjectsManager] lets a test swap in a manager of its own
  /// (already holding an open project) when it needs to.
  OcptResourcesBloc buildBloc({
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
    OcptProjectsManager? overrideProjectsManager,
    FileSelectorManager? fileSelectorManager,
    OcptResourcesRevealRequest? revealRequest,
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
    String? selectedEpisodeId,
  }) => OcptResourcesBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
    exportManager: exportManager ?? _FakeExportManager(),
    fileSelectorManager: fileSelectorManager,
    revealRequest: revealRequest,
    fieldEditDebounce: fieldEditDebounce,
    selectedEpisodeId: selectedEpisodeId,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptResourcesState> waitForState(
    OcptResourcesBloc bloc,
    bool Function(OcptResourcesState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test("loads an empty catalogue with every count at zero", () async {
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.title, "My Movie");
    expect(state.peopleCount, 0);
    expect(state.roleCount, 0);
    expect(state.positionCount, 0);
    expect(state.locationCount, 0);
    expect(state.elementCount, 0);
    expect(state.selectedPersonId, isNull);

    await bloc.close();
  });

  test("the project settings changed event reloads the snapshot from the database", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    // Written directly against the database, bypassing the bloc entirely: the resources catalogue
    // isn't something the project settings page writes, so this is what a change this bloc
    // doesn't otherwise know about has to look like from its point of view.
    final project = projectsManager.currentProject!;
    await project.database
        .into(project.database.ocptPeopleTable)
        .insert(OcptPeopleTableCompanion.insert(id: "person-1"));

    bloc.add(const OcptResourcesProjectSettingsChangedEvent());
    final state = await waitForState(bloc, (state) => state.peopleCount == 1);

    expect(state.peopleCount, 1);

    await bloc.close();
  });

  test("the project settings changed event re-reads the currency", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final initialCode = bloc.state.currencyCode;
    final otherCode = initialCode == "USD" ? "GBP" : "USD";

    await projectsManager.saveCurrentProjectCurrencyCode(otherCode);

    bloc.add(const OcptResourcesProjectSettingsChangedEvent());
    final state = await waitForState(bloc, (state) => state.currencyCode == otherCode);

    expect(state.currencyCode, otherCode);

    await bloc.close();
  });

  test("the initial load reads the project's currency", () async {
    await projectsManager.saveCurrentProjectCurrencyCode("GBP");

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.currencyCode, "GBP");

    await bloc.close();
  });

  test("creating a person appends it to the address book and selects it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    final state = await waitForState(bloc, (state) => state.peopleCount == 1);

    expect(state.selectedPersonId, isNotNull);
    expect(state.selectedPerson, isNotNull);
    expect(state.people.single.id, state.selectedPersonId);

    await bloc.close();
  });

  test("a typed field edit is visible as a pending value and writes once after the debounce",
      () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.peopleCount == 1);
    final personId = created.selectedPersonId!;

    bloc.add(
      OcptResourcesPersonFieldChangedEvent(
        personId: personId,
        field: OcptPersonField.firstName,
        rawValue: "L",
      ),
    );
    var state = await waitForState(
      bloc,
      (state) => state.pendingFieldEdits[(personId, OcptPersonField.firstName)] == "L",
    );
    // Not written yet: still the field's default empty value.
    expect(state.selectedPerson!.firstName, isEmpty);

    // A second keystroke before the debounce elapses restarts it rather than firing twice: only
    // the last value typed is ever written.
    bloc.add(
      OcptResourcesPersonFieldChangedEvent(
        personId: personId,
        field: OcptPersonField.firstName,
        rawValue: "Léa",
      ),
    );
    state = await waitForState(
      bloc,
      (state) => state.pendingFieldEdits[(personId, OcptPersonField.firstName)] == "Léa",
    );
    expect(state.selectedPerson!.firstName, isEmpty);

    state = await waitForState(bloc, (state) => state.selectedPerson!.firstName == "Léa");
    expect(state.pendingFieldEdits, isEmpty);

    await bloc.close();
  });

  test("deleting the selected person erases it and clears the selection", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.peopleCount == 1);
    final personId = state.selectedPersonId!;

    bloc.add(OcptResourcesPersonDeletionRequestedEvent(personId: personId));
    state = await waitForState(bloc, (state) => state.peopleCount == 0);

    expect(state.selectedPersonId, isNull);
    expect(state.people, isEmpty);

    await bloc.close();
  });

  test("deleting a person that isn't selected leaves the selection alone", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.peopleCount == 1);
    final firstPersonId = state.selectedPersonId!;

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.peopleCount == 2);
    final secondPersonId = state.selectedPersonId!;
    expect(secondPersonId, isNot(firstPersonId));

    bloc.add(OcptResourcesPersonDeletionRequestedEvent(personId: firstPersonId));
    state = await waitForState(bloc, (state) => state.peopleCount == 1);

    expect(state.selectedPersonId, secondPersonId);

    await bloc.close();
  });

  test("each created person gets a colour index derived from their rank", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    final first = await waitForState(bloc, (state) => state.peopleCount == 1);
    expect(first.selectedPerson!.colorIndex, 0);

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    final second = await waitForState(bloc, (state) => state.peopleCount == 2);
    expect(second.selectedPerson!.colorIndex, 1);

    await bloc.close();
  });

  test("selecting a tab other than people clears the selected person", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    await waitForState(bloc, (state) => state.selectedPersonId != null);

    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.roles));
    final state = await waitForState(bloc, (state) => state.selectedPersonId == null);

    expect(state.activeTab, OcptResourcesTab.roles);

    await bloc.close();
  });

  test("opening search opens the left dock when it was closed", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesLeftPanelToggledEvent());
    await waitForState(bloc, (state) => !state.isListPanelVisible);

    bloc.add(const OcptResourcesSearchToggledEvent());
    final state = await waitForState(bloc, (state) => state.isSearchVisible);

    expect(state.isListPanelVisible, isTrue);

    await bloc.close();
  });

  test("opening search leaves an already-open left dock open", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesSearchToggledEvent());
    final state = await waitForState(bloc, (state) => state.isSearchVisible);

    expect(state.isListPanelVisible, isTrue);

    await bloc.close();
  });

  test("a typed query is applied to the state immediately, with no debounce", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesSearchToggledEvent());
    await waitForState(bloc, (state) => state.isSearchVisible);

    bloc.add(const OcptResourcesSearchQueryChangedEvent(query: "léa"));
    final state = await waitForState(bloc, (state) => state.searchQuery == "léa");

    expect(state.searchQuery, "léa");

    await bloc.close();
  });

  test("closing search clears whatever query was typed", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesSearchToggledEvent());
    await waitForState(bloc, (state) => state.isSearchVisible);
    bloc.add(const OcptResourcesSearchQueryChangedEvent(query: "léa"));
    await waitForState(bloc, (state) => state.searchQuery == "léa");

    bloc.add(const OcptResourcesSearchToggledEvent());
    final state = await waitForState(bloc, (state) => !state.isSearchVisible);

    expect(state.searchQuery, isEmpty);

    await bloc.close();
  });

  test("changing tab clears the query but leaves the search field open", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesSearchToggledEvent());
    await waitForState(bloc, (state) => state.isSearchVisible);
    bloc.add(const OcptResourcesSearchQueryChangedEvent(query: "léa"));
    await waitForState(bloc, (state) => state.searchQuery == "léa");

    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.roles));
    final state = await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.roles);

    expect(state.searchQuery, isEmpty);
    expect(state.isSearchVisible, isTrue);

    await bloc.close();
  });

  test("re-selecting the already-active tab leaves the query untouched", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesSearchToggledEvent());
    await waitForState(bloc, (state) => state.isSearchVisible);
    bloc.add(const OcptResourcesSearchQueryChangedEvent(query: "léa"));
    await waitForState(bloc, (state) => state.searchQuery == "léa");

    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.people));
    // Reselecting the tab already active is not a tab change, so it may emit no new state at all:
    // the assertion is that the bloc settles back with the query untouched.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.searchQuery, "léa");

    await bloc.close();
  });

  test("going back closes the current project and pops", () async {
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(routerManager: routerManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesBackRequestedEvent());
    await routerManager.onPop.timeout(const Duration(seconds: 5));

    expect(projectsManager.currentProject, isNull);

    await bloc.close();
  });

  test("previewing a version emits its own catalogue together with its id", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    // A person created before the version is captured, so it belongs to it.
    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    await waitForState(bloc, (state) => state.peopleCount == 1);

    bloc.add(
      const OcptProjectVersionCreationRequestedEvent(name: "Cast locked", note: ""),
    );
    final withVersion = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = withVersion.projectVersions.single.id;

    // A second person, created after the version, must not be part of what it holds.
    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    await waitForState(bloc, (state) => state.peopleCount == 2);

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    final previewing = await waitForState(bloc, (state) => state.previewedVersionId != null);

    // The version's own id and the catalogue it was captured with land in the very same state.
    expect(previewing.previewedVersionId, versionId);
    expect(previewing.peopleCount, 1);
    expect(previewing.isPreviewingVersion, isTrue);

    await bloc.close();
  });

  test("creating a silent role appends it to the cast and selects it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.silent));
    final state = await waitForState(bloc, (state) => state.roleCount == 1);

    expect(state.selectedRoleId, isNotNull);
    expect(state.selectedRole, isNotNull);
    expect(state.roles.single.id, state.selectedRoleId);
    expect(state.roles.single.kind, OcptRoleKind.silent);
    expect(state.roles.single.isFromScreenplay, isFalse);

    await bloc.close();
  });

  test(
    "constructed with a second episode selected, reads and writes that episode rather than the "
    "primary screenplay",
    () async {
      final project = projectsManager.currentProject!;
      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: "INT. PRIMARY - DAY\n\nAction one.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );
      final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
        database: project.database,
      );
      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: secondEpisodeId!,
        fountainText: "INT. SECOND EPISODE - NIGHT\n\nAction two.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );

      final bloc = buildBloc(selectedEpisodeId: secondEpisodeId);
      final state = await waitForState(bloc, (state) => !state.isLoading);

      // The scenes offered to a set or an element are the selected episode's own, not the
      // primary screenplay's.
      expect(state.scenes, hasLength(1));
      expect(state.scenes.single.heading, "INT. SECOND EPISODE - NIGHT");

      // A hand-added role is linked to the selected episode (ADR 0019's "created on the
      // selected episode"), not to the primary screenplay.
      bloc.add(const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.silent));
      final withRole = await waitForState(bloc, (state) => state.roleCount == 1);
      expect(withRole.roles.single.episodeIds, [secondEpisodeId]);

      await bloc.close();
    },
  );

  test("casting a person to a role and changing its kind both land in the database", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    final withPerson = await waitForState(bloc, (state) => state.peopleCount == 1);
    final personId = withPerson.selectedPersonId!;

    bloc.add(const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.extra));
    final withRole = await waitForState(bloc, (state) => state.roleCount == 1);
    final roleId = withRole.selectedRoleId!;

    bloc.add(OcptResourcesRoleCastChangedEvent(roleId: roleId, personId: personId));
    var state = await waitForState(
      bloc,
      (state) => state.roles.single.personId == personId,
    );
    expect(state.roles.single.kind, OcptRoleKind.extra);

    bloc.add(OcptResourcesRoleKindChangedEvent(roleId: roleId, kind: OcptRoleKind.silent));
    state = await waitForState(bloc, (state) => state.roles.single.kind == OcptRoleKind.silent);
    expect(state.roles.single.personId, personId);

    await bloc.close();
  });

  test(
    "changing a role's episodes writes through setRoleEpisodes and the reload shows it",
    () async {
      final project = projectsManager.currentProject!;
      final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
        database: project.database,
      );

      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      // Created on the primary episode, ADR 0019's "created on the selected episode".
      bloc.add(const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.extra));
      final withRole = await waitForState(bloc, (state) => state.roleCount == 1);
      final roleId = withRole.selectedRoleId!;
      expect(withRole.roles.single.episodeIds, [project.primaryScreenplayId]);

      bloc.add(
        OcptResourcesRoleEpisodesChangedEvent(
          roleId: roleId,
          episodeIds: {project.primaryScreenplayId, secondEpisodeId!},
        ),
      );
      final state = await waitForState(bloc, (state) => state.roles.single.episodeIds.length == 2);
      expect(state.roles.single.episodeIds.toSet(), {project.primaryScreenplayId, secondEpisodeId});

      await bloc.close();
    },
  );

  test("a role's episodes cannot be changed while a version is being previewed", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.extra));
    final withRole = await waitForState(bloc, (state) => state.roleCount == 1);
    final roleId = withRole.selectedRoleId!;
    final originalEpisodeIds = withRole.roles.single.episodeIds;

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "Cast locked", note: ""));
    final withVersion = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = withVersion.projectVersions.single.id;

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await waitForState(bloc, (state) => state.previewedVersionId != null);

    bloc.add(OcptResourcesRoleEpisodesChangedEvent(roleId: roleId, episodeIds: const {}));
    // The write is refused by the database's own preview guard; wait long enough that a bug
    // silently applying it anyway would have shown up.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(bloc.state.roles.single.episodeIds, originalEpisodeIds);
    expect(bloc.state.hasWriteError, isFalse);

    await bloc.close();
  });

  test("a debounced role name edit is written and flushed by a selection change", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.silent));
    final created = await waitForState(bloc, (state) => state.roleCount == 1);
    final roleId = created.selectedRoleId!;

    bloc.add(
      OcptResourcesRoleFieldChangedEvent(
        roleId: roleId,
        field: OcptRoleField.name,
        rawValue: "Passerby",
      ),
    );
    var state = await waitForState(
      bloc,
      (state) => state.pendingRoleFieldEdits[(roleId, OcptRoleField.name)] == "Passerby",
    );
    // Not written yet: still the field's default empty value.
    expect(state.selectedRole!.name, isEmpty);

    // Selecting another role flushes the pending edit rather than losing it.
    bloc.add(const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.silent));
    state = await waitForState(bloc, (state) => state.selectedRoleId != roleId);
    expect(state.pendingRoleFieldEdits, isEmpty);

    final roles = await waitForState(
      bloc,
      (state) => state.roles.any((role) => role.name == "Passerby"),
    );
    expect(roles.roles.firstWhere((role) => role.id == roleId).name, "Passerby");

    await bloc.close();
  });

  test("deleting the selected role clears the selection", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.extra));
    var state = await waitForState(bloc, (state) => state.roleCount == 1);
    final roleId = state.selectedRoleId!;

    bloc.add(OcptResourcesRoleDeletionRequestedEvent(roleId: roleId));
    state = await waitForState(bloc, (state) => state.roleCount == 0);

    expect(state.selectedRoleId, isNull);
    expect(state.roles, isEmpty);

    await bloc.close();
  });

  test("opening a person's sheet from the roles tab selects them on the people tab at once",
      () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    final withPerson = await waitForState(bloc, (state) => state.peopleCount == 1);
    final personId = withPerson.selectedPersonId!;

    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.roles));
    await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.roles);

    bloc.add(OcptResourcesPersonSheetOpenRequestedEvent(personId: personId));
    final state = await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.people);

    expect(state.selectedPersonId, personId);

    await bloc.close();
  });

  test("creating a location appends it to the list, selects it and colours it by rank", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesLocationCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.locationCount == 1);
    expect(state.selectedLocationId, state.locations.single.id);
    expect(state.locations.single.colorIndex, 0);

    bloc.add(const OcptResourcesLocationCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.locationCount == 2);
    expect(state.locations.last.colorIndex, 1);
    expect(state.selectedLocationId, state.locations.last.id);

    await bloc.close();
  });

  test("a typed location field edit is pending until the debounce writes it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesLocationCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.locationCount == 1);
    final locationId = created.selectedLocationId!;

    bloc.add(
      OcptResourcesLocationFieldChangedEvent(
        locationId: locationId,
        field: OcptLocationField.city,
        rawValue: "Lyon",
      ),
    );
    var state = await waitForState(
      bloc,
      (state) => state.pendingLocationFieldEdits[(locationId, OcptLocationField.city)] == "Lyon",
    );
    expect(state.selectedLocation!.city, isEmpty);

    state = await waitForState(bloc, (state) => state.selectedLocation!.city == "Lyon");
    expect(state.pendingLocationFieldEdits, isEmpty);

    await bloc.close();
  });

  // "45,76" is the ordinary French way of typing it, and the one a decimal-point parser refuses.
  test("a coordinate that isn't a number is stored as no coordinate at all", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesLocationCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.locationCount == 1);
    final locationId = created.selectedLocationId!;

    bloc.add(
      OcptResourcesLocationFieldChangedEvent(
        locationId: locationId,
        field: OcptLocationField.latitude,
        rawValue: "45.76",
      ),
    );
    var state = await waitForState(bloc, (state) => state.selectedLocation!.latitude == 45.76);

    bloc.add(
      OcptResourcesLocationFieldChangedEvent(
        locationId: locationId,
        field: OcptLocationField.latitude,
        rawValue: "45,76",
      ),
    );
    state = await waitForState(bloc, (state) => state.selectedLocation!.latitude == null);
    expect(state.pendingLocationFieldEdits, isEmpty);

    await bloc.close();
  });

  test("the permit status and its date land in the database at once", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesLocationCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.locationCount == 1);
    final locationId = created.selectedLocationId!;

    bloc.add(
      OcptResourcesLocationPermitStatusChangedEvent(
        locationId: locationId,
        status: OcptPermitStatus.granted,
      ),
    );
    await waitForState(
      bloc,
      (state) => state.selectedLocation!.permitStatus == OcptPermitStatus.granted,
    );

    bloc.add(
      OcptResourcesLocationPermitDateChangedEvent(
        locationId: locationId,
        date: DateTime(2026, 8, 13),
      ),
    );
    final state = await waitForState(bloc, (state) => state.selectedLocation!.permitDate != null);
    expect(state.selectedLocation!.permitDate, DateTime(2026, 8, 13));

    await bloc.close();
  });

  test("a set is added, typed into, and removed with its pending edit", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesLocationCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.locationCount == 1);
    final locationId = created.selectedLocationId!;

    bloc.add(OcptResourcesSetAddedEvent(locationId: locationId));
    var state = await waitForState(bloc, (state) => state.selectedLocation!.sets.length == 1);
    final setId = state.selectedLocation!.sets.single.id;

    bloc.add(
      OcptResourcesSetFieldChangedEvent(
        setId: setId,
        field: OcptSetField.name,
        rawValue: "Cuisine",
      ),
    );
    state = await waitForState(bloc, (state) => state.selectedLocation!.sets.single.name == "Cuisine");
    expect(state.pendingSetFieldEdits, isEmpty);

    bloc.add(
      OcptResourcesSetFieldChangedEvent(setId: setId, field: OcptSetField.notes, rawValue: "Nord"),
    );
    await waitForState(bloc, (state) => state.pendingSetFieldEdits.isNotEmpty);

    bloc.add(OcptResourcesSetRemovedEvent(setId: setId));
    state = await waitForState(bloc, (state) => state.selectedLocation!.sets.isEmpty);
    expect(state.pendingSetFieldEdits, isEmpty);

    await bloc.close();
  });

  test("deleting the selected location clears the selection", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesLocationCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.locationCount == 1);
    final locationId = state.selectedLocationId!;

    bloc.add(OcptResourcesLocationDeletionRequestedEvent(locationId: locationId));
    state = await waitForState(bloc, (state) => state.locationCount == 0);

    expect(state.selectedLocationId, isNull);

    await bloc.close();
  });

  test("picking a scouting photo stores the path the picker answered with", () async {
    final bloc = buildBloc(
      fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/photos/hangar.jpg"),
    );
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesLocationCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.locationCount == 1);
    final locationId = created.selectedLocationId!;

    bloc.add(
      OcptResourcesLocationPhotoAddRequestedEvent(
        locationId: locationId,
        fileTypeLabel: "Images",
      ),
    );
    var state = await waitForState(bloc, (state) => state.selectedLocation!.photos.isNotEmpty);
    expect(state.selectedLocation!.photos.single.path, "/photos/hangar.jpg");

    bloc.add(OcptResourcesAssetRemovedEvent(assetId: state.selectedLocation!.photos.single.id));
    state = await waitForState(bloc, (state) => state.selectedLocation!.photos.isEmpty);

    await bloc.close();
  });

  test("the permit document's validity dates land in the database", () async {
    final bloc = buildBloc(
      fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/permits/autorisation.pdf"),
    );
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesLocationCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.locationCount == 1);
    final locationId = created.selectedLocationId!;

    bloc.add(
      OcptResourcesPermitDocumentPickRequestedEvent(
        locationId: locationId,
        fileTypeLabel: "Documents",
      ),
    );
    var state = await waitForState(bloc, (state) => state.selectedLocation!.permitDocument != null);
    final assetId = state.selectedLocation!.permitDocument!.id;

    bloc.add(
      OcptResourcesAssetValidFromChangedEvent(assetId: assetId, date: DateTime(2026, 3, 5)),
    );
    state = await waitForState(
      bloc,
      (state) => state.selectedLocation!.permitDocument!.validFrom != null,
    );
    expect(state.selectedLocation!.permitDocument!.validFrom, DateTime(2026, 3, 5));

    bloc.add(
      OcptResourcesAssetValidUntilChangedEvent(assetId: assetId, date: DateTime(2026, 9, 30)),
    );
    state = await waitForState(
      bloc,
      (state) => state.selectedLocation!.permitDocument!.validUntil != null,
    );
    expect(state.selectedLocation!.permitDocument!.validUntil, DateTime(2026, 9, 30));

    // Clearing is as real a gesture as setting: the date goes back to null.
    bloc.add(OcptResourcesAssetValidFromChangedEvent(assetId: assetId, date: null));
    state = await waitForState(
      bloc,
      (state) => state.selectedLocation!.permitDocument!.validFrom == null,
    );

    await bloc.close();
  });

  test("a cancelled picker references nothing at all", () async {
    final bloc = buildBloc(
      fileSelectorManager: const _StubFileSelectorManager(pickedPath: null),
    );
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesLocationCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.locationCount == 1);
    final locationId = created.selectedLocationId!;

    bloc.add(
      OcptResourcesPermitDocumentPickRequestedEvent(
        locationId: locationId,
        fileTypeLabel: "Documents",
      ),
    );
    // Nothing to wait for: the cancellation emits no state at all, so the assertion is that the
    // location still has no document once the event has certainly been handled.
    bloc.add(
      OcptResourcesLocationFieldChangedEvent(
        locationId: locationId,
        field: OcptLocationField.name,
        rawValue: "Le hangar",
      ),
    );
    final state = await waitForState(bloc, (state) => state.selectedLocation!.name == "Le hangar");
    expect(state.selectedLocation!.permitDocument, isNull);

    await bloc.close();
  });

  test("selecting another tab clears the selected location", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.locations));
    await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.locations);
    bloc.add(const OcptResourcesLocationCreationRequestedEvent());
    await waitForState(bloc, (state) => state.selectedLocationId != null);

    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.people));
    final state = await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.people);

    expect(state.selectedLocationId, isNull);

    await bloc.close();
  });
  test("creating an element appends it in its own category and selects it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.vehicle),
    );
    final state = await waitForState(bloc, (state) => state.elementCount == 1);

    expect(state.selectedElementId, state.elements.single.id);
    expect(state.elements.single.category, OcptElementCategory.vehicle);
    expect(state.elements.single.sceneLinks, isEmpty);

    await bloc.close();
  });

  // Nobody can type a code, so one that no longer says which department the item comes from could
  // never be repaired: it follows every category change.
  test("changing an element's category renumbers its code", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;
    expect(created.selectedElement!.code, "PRP-1");

    bloc.add(
      OcptResourcesElementCategoryChangedEvent(
        elementId: elementId,
        category: OcptElementCategory.vehicle,
      ),
    );
    await waitForState(bloc, (state) => state.selectedElement!.code == "VEH-1");

    bloc.add(
      OcptResourcesElementCategoryChangedEvent(
        elementId: elementId,
        category: OcptElementCategory.costume,
      ),
    );
    final state = await waitForState(
      bloc,
      (state) => state.selectedElement!.category == OcptElementCategory.costume,
    );
    expect(state.selectedElement!.code, "COS-1");

    await bloc.close();
  });

  test("a typed element field edit is pending until the debounce writes it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;

    bloc.add(
      OcptResourcesElementFieldChangedEvent(
        elementId: elementId,
        field: OcptElementField.name,
        rawValue: "Vélo de Léa",
      ),
    );
    var state = await waitForState(
      bloc,
      (state) => state.pendingElementFieldEdits[(elementId, OcptElementField.name)] == "Vélo de Léa",
    );
    expect(state.selectedElement!.name, isEmpty);

    state = await waitForState(bloc, (state) => state.selectedElement!.name == "Vélo de Léa");
    expect(state.pendingElementFieldEdits, isEmpty);

    await bloc.close();
  });

  // The cost is typed as money and stored as cents, and what cannot be read as an amount is stored
  // as no amount at all rather than as zero — a prop whose price is unknown is not a free one.
  test("a typed cost is stored in cents, and what isn't an amount as no cost at all", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;

    bloc.add(
      OcptResourcesElementFieldChangedEvent(
        elementId: elementId,
        field: OcptElementField.cost,
        rawValue: "12,50",
      ),
    );
    await waitForState(bloc, (state) => state.selectedElement!.cost == 1250);

    bloc.add(
      OcptResourcesElementFieldChangedEvent(
        elementId: elementId,
        field: OcptElementField.cost,
        rawValue: "gratuit",
      ),
    );
    final state = await waitForState(bloc, (state) => state.selectedElement!.cost == null);
    expect(state.pendingElementFieldEdits, isEmpty);

    await bloc.close();
  });

  test("the provenance, the owner, the bringer and the flags all land in the database", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    final withPerson = await waitForState(bloc, (state) => state.peopleCount == 1);
    final personId = withPerson.people.single.id;

    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;

    bloc.add(
      OcptResourcesElementSourceKindChangedEvent(
        elementId: elementId,
        sourceKind: OcptElementSourceKind.borrowed,
      ),
    );
    await waitForState(
      bloc,
      (state) => state.elements.single.sourceKind == OcptElementSourceKind.borrowed,
    );

    bloc.add(OcptResourcesElementOwnerChangedEvent(elementId: elementId, personId: personId));
    await waitForState(bloc, (state) => state.elements.single.ownerPersonId == personId);

    bloc.add(OcptResourcesElementBringerChangedEvent(elementId: elementId, personId: personId));
    await waitForState(bloc, (state) => state.elements.single.broughtByPersonId == personId);

    bloc.add(
      OcptResourcesElementTrackingFlagChangedEvent(
        elementId: elementId,
        flag: OcptElementTrackingFlag.secured,
        value: true,
      ),
    );
    final state = await waitForState(bloc, (state) => state.elements.single.isSecured);
    expect(state.elements.single.isReadyForShoot, isFalse);
    expect(state.elements.single.isReturned, isFalse);

    await bloc.close();
  });

  test("a scene is linked to an element, given its own quantity, then unlinked", () async {
    final project = projectsManager.currentProject!;
    await project.database
        .into(project.database.ocptScenesTable)
        .insert(
          OcptScenesTableCompanion.insert(
            id: "scene-1",
            screenplayId: project.primaryScreenplayId,
            position: 0,
            heading: "INT. CUISINE - NUIT",
            charStart: 0,
            charEnd: 10,
          ),
        );

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;

    bloc.add(
      OcptResourcesSceneAssignedToElementEvent(sceneId: "scene-1", elementId: elementId),
    );
    var state = await waitForState(bloc, (state) => state.elements.single.sceneLinks.isNotEmpty);
    final linkId = state.elements.single.sceneLinks.single.id;
    expect(state.elements.single.sceneLinks.single.sceneId, "scene-1");

    bloc.add(
      OcptResourcesSceneElementUpdatedEvent(id: linkId, quantity: "2", notes: "Dont un cassé"),
    );
    state = await waitForState(
      bloc,
      (state) => state.elements.single.sceneLinks.single.quantity == "2",
    );
    expect(state.elements.single.sceneLinks.single.notes, "Dont un cassé");

    bloc.add(OcptResourcesSceneElementRemovedEvent(id: linkId));
    state = await waitForState(bloc, (state) => state.elements.single.sceneLinks.isEmpty);

    await bloc.close();
  });

  test("linking an element to a role, noting it, then unlinking it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.silent));
    final withRole = await waitForState(bloc, (state) => state.roles.length == 1);
    final roleId = withRole.selectedRoleId!;

    bloc.add(
      const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.costume),
    );
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;

    bloc.add(OcptResourcesElementLinkedToRoleEvent(roleId: roleId, elementId: elementId));
    var state = await waitForState(bloc, (state) => state.elements.single.roleLinks.isNotEmpty);
    final linkId = state.elements.single.roleLinks.single.id;
    expect(state.elements.single.roleLinks.single.roleId, roleId);

    bloc.add(OcptResourcesRoleElementUpdatedEvent(id: linkId, notes: "Taché"));
    state = await waitForState(
      bloc,
      (state) => state.elements.single.roleLinks.single.notes == "Taché",
    );

    bloc.add(OcptResourcesRoleElementRemovedEvent(id: linkId));
    state = await waitForState(bloc, (state) => state.elements.single.roleLinks.isEmpty);

    // The element itself is untouched: only the link went.
    expect(state.elementCount, 1);

    await bloc.close();
  });

  test("opening a role's sheet from the elements tab selects it on the roles tab at once", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.silent));
    final withRole = await waitForState(bloc, (state) => state.roles.length == 1);
    final roleId = withRole.selectedRoleId!;

    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.elements));
    await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.elements);

    bloc.add(OcptResourcesRoleSheetOpenRequestedEvent(roleId: roleId));
    final state = await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.roles);

    expect(state.selectedRoleId, roleId);
    expect(state.selectedElementId, isNull);

    await bloc.close();
  });

  test("deleting the selected element clears the selection and drops its pending edit", () async {
    final bloc = buildBloc(fieldEditDebounce: const Duration(seconds: 30));
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;

    bloc.add(
      OcptResourcesElementFieldChangedEvent(
        elementId: elementId,
        field: OcptElementField.name,
        rawValue: "Valise",
      ),
    );
    await waitForState(bloc, (state) => state.pendingElementFieldEdits.isNotEmpty);

    bloc.add(OcptResourcesElementDeletionRequestedEvent(elementId: elementId));
    final state = await waitForState(bloc, (state) => state.elementCount == 0);
    expect(state.selectedElementId, isNull);
    expect(state.pendingElementFieldEdits, isEmpty);

    await bloc.close();
  });

  test("selecting another tab clears the selected element", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.elements));
    await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.elements);
    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    await waitForState(bloc, (state) => state.selectedElementId != null);

    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.people));
    final state = await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.people);
    expect(state.selectedElementId, isNull);

    await bloc.close();
  });

  test('exporting the resources catalogue hands its snapshot to the export manager', () async {
    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - resources.xlsx");
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    await waitForState(bloc, (state) => state.peopleCount == 1);

    bloc.add(
      const OcptResourcesXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    final state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptResourcesIoNoticeKind.xlsxExportSucceeded);
    expect(state.ioNotice!.path, "/tmp/My Movie - resources.xlsx");
    expect(exportManager.lastExportedProjectName, "My Movie");
    expect(exportManager.lastExportedFileTypeLabel, "Excel workbook");
    expect(exportManager.lastExportedLabels, _exportLabels);
    expect(exportManager.lastExportedSnapshot!.peopleCount, 1);

    bloc.add(const OcptResourcesIoNoticeDismissedEvent());
    final dismissedState = await waitForState(bloc, (state) => state.ioNotice == null);
    expect(dismissedState.hasWriteError, isFalse);

    await bloc.close();
  });

  test('exporting flushes a pending field edit first, so the workbook holds it', () async {
    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - resources.xlsx");
    final bloc = buildBloc(
      exportManager: exportManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.peopleCount == 1);
    final personId = state.selectedPersonId!;

    bloc.add(
      OcptResourcesPersonFieldChangedEvent(
        personId: personId,
        field: OcptPersonField.firstName,
        rawValue: "Léa",
      ),
    );
    await waitForState(bloc, (state) => state.pendingFieldEdits.isNotEmpty);

    bloc.add(
      const OcptResourcesXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.pendingFieldEdits, isEmpty);
    final exportedPerson = exportManager.lastExportedSnapshot!.people.firstWhere(
      (person) => person.id == personId,
    );
    expect(exportedPerson.firstName, "Léa");

    await bloc.close();
  });

  test('a cancelled save dialog leaves no export notice at all', () async {
    final bloc = buildBloc(exportManager: _FakeExportManager());
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptResourcesXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    // Nothing to wait for: a cancellation emits no state of its own, so the assertion is that the
    // bloc settles back with no notice once the export has had time to resolve.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.ioNotice, isNull);

    await bloc.close();
  });

  test('a failing export raises the transient export failure notice', () async {
    final bloc = buildBloc(exportManager: _FakeExportManager(fails: true));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptResourcesXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    final state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptResourcesIoNoticeKind.xlsxExportFailed);
    expect(state.ioNotice!.path, isNull);

    await bloc.close();
  });

  test('the page setup used to prefill the contact list dialog is loaded on entry', () async {
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.pageSetup.format, OcptPageFormat.usLetter);

    await bloc.close();
  });

  test('exporting the contact list hands its snapshot and its options to the export manager',
      () async {
    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - contacts.pdf");
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.peopleCount == 1);
    final personId = state.selectedPersonId!;

    bloc.add(
      OcptResourcesPositionAddedEvent(personId: personId, positionId: "director", customLabel: ""),
    );
    await waitForState(bloc, (state) => state.positionCount == 1);

    bloc.add(
      const OcptResourcesContactListExportRequestedEvent(
        options: _contactListOptions,
        labels: _contactListLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptResourcesIoNoticeKind.contactListExportSucceeded);
    expect(state.ioNotice!.path, "/tmp/My Movie - contacts.pdf");
    expect(exportManager.lastExportedContactListProjectName, "My Movie");
    expect(exportManager.lastExportedContactListFileTypeLabel, "PDF document");
    expect(exportManager.lastExportedContactListLabels, _contactListLabels);
    expect(
      exportManager.lastExportedContactListPageSetup,
      const OcptPageSetup(format: OcptPageFormat.usLetter, margins: FountainPageMargins.standard()),
    );
    expect(exportManager.lastExportedContactListSnapshot!.positionCount, 1);

    bloc.add(const OcptResourcesIoNoticeDismissedEvent());
    final dismissedState = await waitForState(bloc, (state) => state.ioNotice == null);
    expect(dismissedState.hasWriteError, isFalse);

    await bloc.close();
  });

  test('exporting the contact list flushes a pending field edit first, so it holds it', () async {
    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - contacts.pdf");
    final bloc = buildBloc(
      exportManager: exportManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesPersonCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.peopleCount == 1);
    final personId = state.selectedPersonId!;

    bloc.add(
      OcptResourcesPersonFieldChangedEvent(
        personId: personId,
        field: OcptPersonField.firstName,
        rawValue: "Léa",
      ),
    );
    await waitForState(bloc, (state) => state.pendingFieldEdits.isNotEmpty);

    bloc.add(
      const OcptResourcesContactListExportRequestedEvent(
        options: _contactListOptions,
        labels: _contactListLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.pendingFieldEdits, isEmpty);
    final exportedPerson = exportManager.lastExportedContactListSnapshot!.people.firstWhere(
      (person) => person.id == personId,
    );
    expect(exportedPerson.firstName, "Léa");

    await bloc.close();
  });

  test('a cancelled contact list save dialog leaves no export notice at all', () async {
    final bloc = buildBloc(exportManager: _FakeExportManager());
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptResourcesContactListExportRequestedEvent(
        options: _contactListOptions,
        labels: _contactListLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.ioNotice, isNull);

    await bloc.close();
  });

  test('a failing contact list export raises the transient export failure notice', () async {
    final bloc = buildBloc(exportManager: _FakeExportManager(fails: true));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptResourcesContactListExportRequestedEvent(
        options: _contactListOptions,
        labels: _contactListLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    final state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptResourcesIoNoticeKind.contactListExportFailed);
    expect(state.ioNotice!.path, isNull);

    await bloc.close();
  });

  test("a reveal request opens its own tab with its record already selected", () async {
    final seed = buildBloc();
    await waitForState(seed, (state) => !state.isLoading);
    seed.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final seeded = await waitForState(seed, (state) => state.elementCount == 1);
    final elementId = seeded.selectedElementId!;
    await seed.close();

    final bloc = buildBloc(
      revealRequest: OcptResourcesRevealRequest(
        tab: OcptResourcesTab.elements,
        recordId: elementId,
      ),
    );
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.activeTab, OcptResourcesTab.elements);
    expect(state.selectedElementId, elementId);
    expect(state.selectedElement, isNotNull);

    await bloc.close();
  });

  // The load clears every selection, so a reveal re-applied on each one would yank the user back to
  // the revealed record every time a version preview is entered or left.
  test("a reveal request is applied to the first load only", () async {
    final seed = buildBloc();
    await waitForState(seed, (state) => !state.isLoading);
    seed.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final seeded = await waitForState(seed, (state) => state.elementCount == 1);
    final elementId = seeded.selectedElementId!;
    await seed.close();

    final bloc = buildBloc(
      revealRequest: OcptResourcesRevealRequest(
        tab: OcptResourcesTab.elements,
        recordId: elementId,
      ),
    );
    await waitForState(bloc, (state) => state.selectedElementId == elementId);

    bloc.add(const OcptResourcesLoadRequestedEvent());
    final reloaded = await waitForState(bloc, (state) => state.selectedElementId == null);

    expect(reloaded.selectedElementId, isNull);

    await bloc.close();
  });

  test("a reveal request naming an unknown record only opens its tab", () async {
    final bloc = buildBloc(
      revealRequest: const OcptResourcesRevealRequest(
        tab: OcptResourcesTab.locations,
        recordId: "no-such-location",
      ),
    );

    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.activeTab, OcptResourcesTab.locations);
    expect(state.selectedLocationId, isNull);

    await bloc.close();
  });
}
