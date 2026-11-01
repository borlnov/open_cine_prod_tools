// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_elements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_locations_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_people_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_roles_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A debounce no test waits out, so every typed edit stays pending until a flush.
const _neverDebounce = Duration(days: 1);

/// What the resources blocs do when a write is refused by the database: each failing handler
/// raises the mode's one write error, and the records stay as they were.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptResourcesBloc modeBloc;
  late OcptResourcesPeopleBloc peopleBloc;
  late OcptResourcesRolesBloc rolesBloc;
  late OcptResourcesLocationsBloc locationsBloc;
  late OcptResourcesElementsBloc elementsBloc;
  late String personId;
  late String roleId;
  late String locationId;
  late String elementId;
  late String candidateId;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_write_failure_test_");
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

    final project = projectsManager.currentProject!;
    personId = (await projectsManager.peopleService.createPerson(database: project.database))!;
    roleId = (await projectsManager.roleIndexService.addRole(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      name: "",
      kind: OcptRoleKind.silent,
    ))!;
    locationId = (await projectsManager.locationsService.createLocation(
      database: project.database,
      name: "",
    ))!;
    elementId = (await projectsManager.elementsService.createElement(
      database: project.database,
      name: "",
      category: OcptElementCategory.prop,
      sourceKind: OcptElementSourceKind.owned,
    ))!;
    candidateId = (await projectsManager.roleCandidatesService.addCandidate(
      database: project.database,
      roleId: roleId,
      personId: personId,
    ))!;

    modeBloc = OcptResourcesBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _RecordingRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    peopleBloc = OcptResourcesPeopleBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      fieldEditDebounce: _neverDebounce,
    );
    rolesBloc = OcptResourcesRolesBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      fieldEditDebounce: _neverDebounce,
    );
    locationsBloc = OcptResourcesLocationsBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      fieldEditDebounce: _neverDebounce,
    );
    elementsBloc = OcptResourcesElementsBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      fieldEditDebounce: _neverDebounce,
    );
    await waitForState(modeBloc, (state) => !state.isLoading);
    await modeBloc.reload({OcptResourcesReloadScope.snapshot});
  });

  tearDown(() async {
    await elementsBloc.close();
    await locationsBloc.close();
    await rolesBloc.close();
    await peopleBloc.close();
    await modeBloc.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Makes every [verb] on [table] fail with a database error until the project is closed.
  Future<void> refuse(String verb, String table) =>
      projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

  test("a refused element creation raises the write error and adds nothing", () async {
    await refuse("INSERT", "elements");

    elementsBloc.add(
      const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop),
    );
    final state = await waitForState(modeBloc, (state) => state.hasWriteError);

    expect(state.elements, hasLength(1));
  });

  test("a refused element deletion raises the write error and keeps the element", () async {
    await refuse("UPDATE", "elements");

    elementsBloc.add(OcptResourcesElementDeletionRequestedEvent(elementId: elementId));
    final state = await waitForState(modeBloc, (state) => state.hasWriteError);

    expect(state.elements.single.id, elementId);
  });

  test("a refused location creation raises the write error and adds nothing", () async {
    await refuse("INSERT", "locations");

    locationsBloc.add(const OcptResourcesLocationCreationRequestedEvent());
    final state = await waitForState(modeBloc, (state) => state.hasWriteError);

    expect(state.locations, hasLength(1));
  });

  test("a refused location deletion raises the write error and keeps the location", () async {
    await refuse("UPDATE", "locations");

    locationsBloc.add(OcptResourcesLocationDeletionRequestedEvent(locationId: locationId));
    final state = await waitForState(modeBloc, (state) => state.hasWriteError);

    expect(state.locations.single.id, locationId);
  });

  test("a refused person erasure raises the write error and keeps the person", () async {
    await refuse("UPDATE", "people");

    peopleBloc.add(OcptResourcesPersonDeletionRequestedEvent(personId: personId));
    final state = await waitForState(modeBloc, (state) => state.hasWriteError);

    expect(state.people.single.id, personId);
  });

  test("a refused role creation raises the write error and adds nothing", () async {
    await refuse("INSERT", "roles");

    rolesBloc.add(const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.silent));
    final state = await waitForState(modeBloc, (state) => state.hasWriteError);

    expect(state.roles, hasLength(1));
  });

  test("a refused role deletion raises the write error and keeps the role", () async {
    await refuse("UPDATE", "roles");

    rolesBloc.add(OcptResourcesRoleDeletionRequestedEvent(roleId: roleId));
    final state = await waitForState(modeBloc, (state) => state.hasWriteError);

    expect(state.roles.single.id, roleId);
  });

  test("a refused candidacy removal raises the write error", () async {
    await refuse("UPDATE", "role_candidates");

    rolesBloc.add(OcptResourcesRoleCandidateRemovedEvent(candidateId: candidateId));
    final state = await waitForState(modeBloc, (state) => state.hasWriteError);

    expect(state.hasWriteError, isTrue);
  });

  test("a refused location field flush raises the write error and drops the edit", () async {
    await refuse("UPDATE", "locations");
    locationsBloc.add(
      OcptResourcesLocationFieldChangedEvent(
        locationId: locationId,
        field: OcptLocationField.city,
        rawValue: "Lyon",
      ),
    );
    await waitForState(locationsBloc, (state) => state.pendingLocationFieldEdits.isNotEmpty);

    final mayProceed = await modeBloc.flushAllPendingWrites();

    expect(mayProceed, isTrue);
    expect(modeBloc.state.hasWriteError, isTrue);
    expect(locationsBloc.state.pendingLocationFieldEdits, isEmpty);
  });

  test("a refused role field flush raises the write error and drops the edit", () async {
    await refuse("UPDATE", "roles");
    rolesBloc.add(
      OcptResourcesRoleFieldChangedEvent(
        roleId: roleId,
        field: OcptRoleField.castingNotes,
        rawValue: "Zoe",
      ),
    );
    await waitForState(rolesBloc, (state) => state.pendingRoleFieldEdits.isNotEmpty);

    final mayProceed = await modeBloc.flushAllPendingWrites();

    expect(mayProceed, isTrue);
    expect(modeBloc.state.hasWriteError, isTrue);
    expect(rolesBloc.state.pendingRoleFieldEdits, isEmpty);
  });

  test("opening a set in the shot list reveals nothing when its link cannot be read", () async {
    await projectsManager.currentProject!.database.customStatement(
      "ALTER TABLE scene_sets RENAME TO scene_sets_gone",
    );

    modeBloc.add(const OcptResourcesOpenSetInShotListRequestedEvent(setId: "some-set"));
    await pumpEventQueue();

    expect(modeBloc.state.pendingShotListReveal, isNull);
    expect(modeBloc.state.hasWriteError, isFalse);

    await projectsManager.currentProject!.database.customStatement(
      "ALTER TABLE scene_sets_gone RENAME TO scene_sets",
    );
  });
}
