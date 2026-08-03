// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
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
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
  }) => OcptResourcesBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
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

    // Selecting the role away (collapsing it) flushes the pending edit rather than losing it.
    bloc.add(OcptResourcesRoleSelectedEvent(roleId: roleId));
    state = await waitForState(bloc, (state) => state.selectedRoleId == null);
    expect(state.pendingRoleFieldEdits, isEmpty);

    final roles = await waitForState(bloc, (state) => state.roles.single.name == "Passerby");
    expect(roles.roles.single.name, "Passerby");

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
}
