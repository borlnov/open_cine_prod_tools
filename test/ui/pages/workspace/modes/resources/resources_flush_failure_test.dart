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
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
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
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter for it
/// to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A debounce no test waits out, so every typed edit stays pending until a flush.
const _neverDebounce = Duration(days: 1);

/// Run the tests of the resources flush failure.
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

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's write error path)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_flush_failure_test_");
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

    // One record in each tab, written behind the mode's back, then a typed edit in each sheet.
    final project = projectsManager.currentProject!;
    personId = (await projectsManager.peopleService.createPerson(database: project.database))!;
    roleId = (await projectsManager.roleIndexService
        .addRole(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          name: "",
          kind: OcptRoleKind.silent,
        )
        .valueOrFail);
    locationId = (await projectsManager.locationsService
        .createLocation(database: project.database, name: "")
        .valueOrFail);
    elementId = (await projectsManager.elementsService
        .createElement(
          database: project.database,
          name: "",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        )
        .valueOrFail);

    modeBloc = OcptResourcesBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _RecordingRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    // Built in the order the mode builds them: the flushers are asked in that order.
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

    peopleBloc.add(
      OcptResourcesPersonFieldChangedEvent(
        personId: personId,
        field: OcptPersonField.firstName,
        rawValue: "Alicia",
      ),
    );
    rolesBloc.add(
      OcptResourcesRoleFieldChangedEvent(
        roleId: roleId,
        field: OcptRoleField.castingNotes,
        rawValue: "Zoe",
      ),
    );
    locationsBloc.add(
      OcptResourcesLocationFieldChangedEvent(
        locationId: locationId,
        field: OcptLocationField.city,
        rawValue: "Lyon",
      ),
    );
    elementsBloc.add(
      OcptResourcesElementFieldChangedEvent(
        elementId: elementId,
        field: OcptElementField.notes,
        rawValue: "Fragile",
      ),
    );
    await waitForState(peopleBloc, (state) => state.pendingFieldEdits.isNotEmpty);
    await waitForState(rolesBloc, (state) => state.pendingRoleFieldEdits.isNotEmpty);
    await waitForState(locationsBloc, (state) => state.pendingLocationFieldEdits.isNotEmpty);
    await waitForState(elementsBloc, (state) => state.pendingElementFieldEdits.isNotEmpty);
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

  /// Whether every view bloc has nothing left in its debounce.
  bool isNothingPending() =>
      peopleBloc.state.pendingFieldEdits.isEmpty &&
      rolesBloc.state.pendingRoleFieldEdits.isEmpty &&
      locationsBloc.state.pendingLocationFieldEdits.isEmpty &&
      elementsBloc.state.pendingElementFieldEdits.isEmpty;

  test("a flush with nothing failing writes the four sheets and shows no error", () async {
    final mayProceed = await modeBloc.flushAllPendingWrites();

    expect(mayProceed, isTrue);
    expect(isNothingPending(), isTrue);
    expect(modeBloc.state.hasWriteError, isFalse);
    expect(modeBloc.state.selectedPerson, isNull);
    expect(modeBloc.state.people.single.firstName, "Alicia");
    expect(modeBloc.state.roles.single.castingNotes, "Zoe");
    expect(modeBloc.state.locations.single.city, "Lyon");
    expect(modeBloc.state.elements.single.notes, "Fragile");
  });

  test(
    "a failed write in the first sheet drops every sheet's edit and writes none of the others",
    () async {
      final database = projectsManager.currentProject!.database;
      await database.customStatement("ALTER TABLE people RENAME TO people_gone");
      try {
        final mayProceed = await modeBloc.flushAllPendingWrites();

        // The action the flush was asked for still goes ahead, on the values the database holds.
        expect(mayProceed, isTrue);
        expect(modeBloc.state.hasWriteError, isTrue);
        expect(isNothingPending(), isTrue);
      } finally {
        await database.customStatement("ALTER TABLE people_gone RENAME TO people");
      }

      expect(
        (await projectsManager.peopleService.loadPeople(database: database)).single.firstName,
        isEmpty,
      );
      expect(
        (await projectsManager.roleIndexService.loadRoles(database: database).valueOrFail)
            .single
            .castingNotes,
        isEmpty,
      );
      expect(
        (await projectsManager.locationsService.loadLocations(database: database).valueOrFail)
            .single
            .city,
        isEmpty,
      );
      expect(
        (await projectsManager.elementsService.loadElements(database: database).valueOrFail)
            .single
            .notes,
        isEmpty,
      );
    },
  );

  test(
    "a failed write in a later sheet keeps what the earlier ones wrote and drops the rest",
    () async {
      final database = projectsManager.currentProject!.database;
      // A trigger makes the write fail while every read still works, which renaming the table would
      // not: the earlier sheets read the whole catalogue again after their own write.
      await database.customStatement(
        "CREATE TRIGGER refuse_elements BEFORE UPDATE ON elements "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );
      try {
        await modeBloc.flushAllPendingWrites();

        expect(modeBloc.state.hasWriteError, isTrue);
        expect(isNothingPending(), isTrue);
      } finally {
        await database.customStatement("DROP TRIGGER refuse_elements");
      }

      expect(
        (await projectsManager.peopleService.loadPeople(database: database)).single.firstName,
        "Alicia",
      );
      expect(
        (await projectsManager.locationsService.loadLocations(database: database).valueOrFail)
            .single
            .city,
        "Lyon",
      );
      expect(
        (await projectsManager.elementsService.loadElements(database: database).valueOrFail)
            .single
            .notes,
        isEmpty,
      );
    },
  );

  test(
    "a failed read after a write that landed keeps the other sheets' edits and writes them all",
    () async {
      final database = projectsManager.currentProject!.database;
      // The writes of the four sheets never touch the episodes, whereas every read of the
      // catalogue does: the writes land and the read after each of them fails.
      await database.customStatement("ALTER TABLE screenplays RENAME TO screenplays_gone");
      try {
        final mayProceed = await modeBloc.flushAllPendingWrites();

        expect(mayProceed, isTrue);
        expect(modeBloc.state.hasWriteError, isTrue);
        expect(isNothingPending(), isTrue);
      } finally {
        await database.customStatement("ALTER TABLE screenplays_gone RENAME TO screenplays");
      }

      expect(
        (await projectsManager.peopleService.loadPeople(database: database)).single.firstName,
        "Alicia",
      );
      expect(
        (await projectsManager.roleIndexService.loadRoles(database: database).valueOrFail)
            .single
            .castingNotes,
        "Zoe",
      );
      expect(
        (await projectsManager.locationsService.loadLocations(database: database).valueOrFail)
            .single
            .city,
        "Lyon",
      );
      expect(
        (await projectsManager.elementsService.loadElements(database: database).valueOrFail)
            .single
            .notes,
        "Fragile",
      );
    },
  );

  test("the write error is raised once, however many sheets were holding an edit", () async {
    final database = projectsManager.currentProject!.database;
    final errors = <bool>[];
    final subscription = modeBloc.stream
        .map((state) => state.hasWriteError)
        .distinct()
        .where((hasWriteError) => hasWriteError)
        .listen(errors.add);
    await database.customStatement("ALTER TABLE people RENAME TO people_gone");
    try {
      await modeBloc.flushAllPendingWrites();
    } finally {
      await database.customStatement("ALTER TABLE people_gone RENAME TO people");
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await subscription.cancel();

    expect(errors, hasLength(1));
  });
}
