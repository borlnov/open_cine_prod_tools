// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
  /// [overrideProjectsManager] lets a test swap in a manager of its own (already holding an open
  /// project) when it needs to.
  OcptResourcesBloc buildBloc({
    OcptRouterManager? routerManager,
    OcptProjectsManager? overrideProjectsManager,
    FileSelectorManager? fileSelectorManager,
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
  }) => OcptResourcesBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
    fileSelectorManager: fileSelectorManager,
    fieldEditDebounce: fieldEditDebounce,
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
      OcptResourcesSetFieldChangedEvent(setId: setId, field: OcptSetField.code, rawValue: "A"),
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
}
