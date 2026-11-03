// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_tracking_flag.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_elements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A file selector manager answering the picker with a file of its own.
class _StubFileSelectorManager extends FileSelectorManager {
  /// Class constructor
  const _StubFileSelectorManager();

  /// Answer with a file instead of opening the platform's own dialog.
  @override
  Future<ResultWithBoolStatus<XFile>> openSelector({
    required List<String> allowedExtensions,
    required String label,
    bool strictOnExtensions = true,
  }) async => ResultWithBoolStatus(status: BoolResultStatus.success, value: XFile("/photos/a.jpg"));
}

/// The ids of what the handlers work on.
typedef _Seeded = ({
  String elementId,
  String freeElementId,
  String personId,
  String sceneId,
  String roleId,
  String sceneLinkId,
  String roleLinkId,
});

/// What the elements tab does when the database refuses a write, with a real SQLite failure: the
/// handler stops where the exception stopped it, raises the mode's write error, reads nothing
/// again, and the same event goes through once the refusal is lifted.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptResourcesBloc mode;
  late OcptResourcesElementsBloc view;
  late _Seeded seeded;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Give the blocs time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_elements_failure_test_");
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
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: "INT. HOUSE - DAY\n\nAction one.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );
    final scene = await (project.database.select(project.database.ocptScenesTable)).getSingle();
    final elements = projectsManager.elementsService;
    final elementId = await elements
        .createElement(
          database: project.database,
          name: "Lamp",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        )
        .valueOrFail;
    final freeElementId = await elements
        .createElement(
          database: project.database,
          name: "Chair",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        )
        .valueOrFail;
    final personId = (await projectsManager.peopleService.createPerson(
      database: project.database,
    ))!;
    final roleId = (await projectsManager.roleIndexService.addRole(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      name: "CLARA",
      kind: OcptRoleKind.silent,
    ))!;
    final sceneLinkId = await elements
        .addSceneElement(database: project.database, sceneId: scene.id, elementId: elementId)
        .valueOrFail;
    final roleLinkId = await elements
        .addRoleElement(database: project.database, roleId: roleId, elementId: elementId)
        .valueOrFail;
    await elements
        .setElementPhoto(database: project.database, elementId: elementId, path: "/photos/old.jpg")
        .valueOrFail;

    mode = OcptResourcesBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    view = OcptResourcesElementsBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fileSelectorManager: const _StubFileSelectorManager(),
      fieldEditDebounce: const Duration(days: 1),
    );
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    seeded = (
      elementId: elementId,
      freeElementId: freeElementId,
      personId: personId,
      sceneId: scene.id,
      roleId: roleId,
      sceneLinkId: sceneLinkId,
      roleLinkId: roleLinkId,
    );
  });

  tearDown(() async {
    await view.close();
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Make the database refuse the [verb] of [table].
  Future<void> refuse(String verb, String table) =>
      projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

  /// Lift the refusal [refuse] put on the [verb] of [table].
  Future<void> lift(String verb, String table) => projectsManager.currentProject!.database
      .customStatement("DROP TRIGGER refuse_${verb.toLowerCase()}_$table");

  /// The handlers, each with the table and the verb that fail it, and the event it dispatches.
  final cases = <String, ({String table, String verb, OcptResourcesEvent Function(_Seeded) event})>{
    "creating an element": (
      table: "elements",
      verb: "INSERT",
      event: (s) =>
          const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop),
    ),
    "deleting an element": (
      table: "elements",
      verb: "UPDATE",
      event: (s) => OcptResourcesElementDeletionRequestedEvent(elementId: s.freeElementId),
    ),
    "changing the category": (
      table: "elements",
      verb: "UPDATE",
      event: (s) => OcptResourcesElementCategoryChangedEvent(
        elementId: s.elementId,
        category: OcptElementCategory.vehicle,
      ),
    ),
    "changing the provenance": (
      table: "elements",
      verb: "UPDATE",
      event: (s) => OcptResourcesElementSourceKindChangedEvent(
        elementId: s.elementId,
        sourceKind: OcptElementSourceKind.borrowed,
      ),
    ),
    "changing the owner": (
      table: "elements",
      verb: "UPDATE",
      event: (s) =>
          OcptResourcesElementOwnerChangedEvent(elementId: s.elementId, personId: s.personId),
    ),
    "changing who brings it": (
      table: "elements",
      verb: "UPDATE",
      event: (s) =>
          OcptResourcesElementBringerChangedEvent(elementId: s.elementId, personId: s.personId),
    ),
    "ticking a tracking flag": (
      table: "elements",
      verb: "UPDATE",
      event: (s) => OcptResourcesElementTrackingFlagChangedEvent(
        elementId: s.elementId,
        flag: OcptElementTrackingFlag.secured,
        value: true,
      ),
    ),
    "assigning a scene": (
      table: "scene_elements",
      verb: "INSERT",
      event: (s) =>
          OcptResourcesSceneAssignedToElementEvent(sceneId: s.sceneId, elementId: s.freeElementId),
    ),
    "updating a scene link": (
      table: "scene_elements",
      verb: "UPDATE",
      event: (s) =>
          OcptResourcesSceneElementUpdatedEvent(id: s.sceneLinkId, quantity: "2", notes: "Blue"),
    ),
    "removing a scene link": (
      table: "scene_elements",
      verb: "UPDATE",
      event: (s) => OcptResourcesSceneElementRemovedEvent(id: s.sceneLinkId),
    ),
    "linking a role": (
      table: "role_elements",
      verb: "INSERT",
      event: (s) =>
          OcptResourcesElementLinkedToRoleEvent(roleId: s.roleId, elementId: s.freeElementId),
    ),
    "updating a role link": (
      table: "role_elements",
      verb: "UPDATE",
      event: (s) => OcptResourcesRoleElementUpdatedEvent(id: s.roleLinkId, notes: "Worn"),
    ),
    "removing a role link": (
      table: "role_elements",
      verb: "UPDATE",
      event: (s) => OcptResourcesRoleElementRemovedEvent(id: s.roleLinkId),
    ),
    "referencing a photo": (
      table: "assets",
      verb: "INSERT",
      event: (s) => OcptResourcesElementPhotoPickRequestedEvent(
        elementId: s.elementId,
        fileTypeLabel: "Image",
      ),
    ),
    "dropping the photo": (
      table: "assets",
      verb: "UPDATE",
      event: (s) => OcptResourcesElementPhotoClearedEvent(elementId: s.elementId),
    ),
  };

  for (final entry in cases.entries) {
    final case_ = entry.value;
    test(
      "${entry.key} raises the write error, reads nothing again, and goes through once lifted",
      () async {
        final held = mode.state;
        await refuse(case_.verb, case_.table);

        view.add(case_.event(seeded));
        await settle();

        expect(mode.state.hasWriteError, isTrue);
        expect(mode.state.reloadEpoch, held.reloadEpoch, reason: "the mode read again");

        await lift(case_.verb, case_.table);
        mode.add(const OcptResourcesWriteErrorDismissedEvent());
        view.add(case_.event(seeded));
        await settle();

        expect(mode.state.hasWriteError, isFalse);
        expect(mode.state.reloadEpoch, isNot(held.reloadEpoch));
      },
    );
  }

  group("flushing the typed edits", () {
    /// Type a name into the element.
    Future<void> type() async {
      view.add(
        OcptResourcesElementFieldChangedEvent(
          elementId: seeded.elementId,
          field: OcptElementField.name,
          rawValue: "Renamed",
        ),
      );
      await settle();
    }

    test("a refused write loses the edit, raises the write error and reads nothing", () async {
      await type();
      final held = mode.state;
      await refuse("UPDATE", "elements");

      final status = await view.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.ok);
      expect(mode.state.hasWriteError, isTrue);
      expect(view.state.pendingElementFieldEdits, isEmpty);
      expect(mode.state.snapshot, same(held.snapshot), reason: "the mode read again");

      await lift("UPDATE", "elements");
      mode.add(const OcptResourcesWriteErrorDismissedEvent());
      await type();

      expect(await view.flushPendingWrites(), OcptPendingWritesStatus.ok);
      expect(mode.state.snapshot, isNot(same(held.snapshot)));
    });

    test("a refused write leaves the edit to the next flush that has no state", () async {
      await type();
      final held = mode.state;
      await refuse("UPDATE", "elements");

      await view.flushPendingWritesWithoutState();

      expect(mode.state.reloadEpoch, held.reloadEpoch);
      expect(view.state.pendingElementFieldEdits, isNotEmpty);

      await lift("UPDATE", "elements");
      await view.flushPendingWritesWithoutState();
      await mode.reload({OcptResourcesReloadScope.snapshot});

      expect(
        mode.state.snapshot!.elements.firstWhere((element) => element.id == seeded.elementId).name,
        "Renamed",
      );
    });
  });
}
