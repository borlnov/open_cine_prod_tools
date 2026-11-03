// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_inspector_bloc.dart';
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

/// What the breakdown mode does when the database refuses a write of an element, or cannot read
/// the catalogue, with a real SQLite failure: the handler stops where the exception stopped it,
/// reads nothing again, and the same event goes through once the refusal is lifted; a tag and its
/// element are written whole or not at all.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late String sceneId;
  late String elementId;
  late String personId;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Give the blocs time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_breakdown_elements_failure_test_");
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
      fountainText: "INT. HOUSE - DAY\n\nA lamp sits on the desk.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );
    sceneId = (await project.database.select(project.database.ocptScenesTable).get()).single.id;
    elementId = await projectsManager.elementsService
        .createElement(
          database: project.database,
          name: "Desk lamp",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        )
        .valueOrFail;
    personId = (await projectsManager.peopleService.createPerson(database: project.database))!;
  });

  tearDown(() async {
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

  /// Build the mode bloc on the test project and wait for it to load.
  Future<OcptBreakdownBloc> buildMode() async {
    final mode = OcptBreakdownBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    addTearDown(mode.close);
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));

    return mode;
  }

  group("the inspector", () {
    late OcptBreakdownBloc mode;
    late OcptBreakdownInspectorBloc inspector;

    setUp(() async {
      mode = await buildMode();
      inspector = OcptBreakdownInspectorBloc(
        modeBloc: mode,
        projectsManager: projectsManager,
        fieldEditDebounce: const Duration(days: 1),
      );
      addTearDown(inspector.close);
    });

    final cases = <String, ({String verb, OcptBreakdownInspectorEventFactory event})>{
      "changing the status": (
        verb: "UPDATE",
        event: (id, person) => OcptBreakdownElementStatusChangedEvent(
          elementId: id,
          status: OcptElementStatus.confirmed,
        ),
      ),
      "changing the category": (
        verb: "UPDATE",
        event: (id, person) => OcptBreakdownElementCategoryChangedEvent(
          elementId: id,
          category: OcptElementCategory.vehicle,
        ),
      ),
      "changing the owner": (
        verb: "UPDATE",
        event: (id, person) =>
            OcptBreakdownElementOwnerChangedEvent(elementId: id, personId: person),
      ),
      "changing who brings it": (
        verb: "UPDATE",
        event: (id, person) =>
            OcptBreakdownElementBringerChangedEvent(elementId: id, personId: person),
      ),
    };

    for (final entry in cases.entries) {
      test(
        "${entry.key} stops, reads nothing again, and goes through once the refusal is lifted",
        () async {
          final held = mode.state;
          await refuse(entry.value.verb, "elements");

          inspector.add(entry.value.event(elementId, personId));
          await settle();

          expect(mode.state.reloadEpoch, held.reloadEpoch, reason: "the mode read again");

          await lift(entry.value.verb, "elements");
          inspector.add(entry.value.event(elementId, personId));
          await settle();

          expect(mode.state.reloadEpoch, isNot(held.reloadEpoch));
        },
      );
    }

    for (final field in [
      OcptElementField.name,
      OcptElementField.subCategory,
      OcptElementField.quantity,
      OcptElementField.notes,
    ]) {
      test("a refused flush of $field forgets the edit, reads nothing and goes on", () async {
        final held = mode.state;
        inspector.add(
          OcptBreakdownElementFieldChangedEvent(
            elementId: elementId,
            field: field,
            rawValue: "Renamed",
          ),
        );
        await settle();
        await refuse("UPDATE", "elements");

        final status = await inspector.flushPendingWrites();

        expect(status, OcptPendingWritesStatus.ok);
        expect(inspector.state.pendingElementFieldEdits, isEmpty);
        expect(mode.state.reloadEpoch, held.reloadEpoch);
      });
    }

    test("a refused field flush without state leaves the edit to the next one", () async {
      final held = mode.state;
      inspector.add(
        OcptBreakdownElementFieldChangedEvent(
          elementId: elementId,
          field: OcptElementField.name,
          rawValue: "Renamed",
        ),
      );
      await settle();
      await refuse("UPDATE", "elements");

      await inspector.flushPendingWritesWithoutState();

      expect(mode.state.reloadEpoch, held.reloadEpoch);

      await lift("UPDATE", "elements");
      await inspector.flushPendingWritesWithoutState();
      await mode.reload({OcptBreakdownReloadScope.snapshot});

      expect(
        mode.state.snapshot!.elements.firstWhere((element) => element.id == elementId).name,
        "Renamed",
      );
    });
  });

  group("when the catalogue cannot be read", () {
    /// Make the elements unreadable.
    Future<void> lose() => projectsManager.currentProject!.database.customStatement(
      "ALTER TABLE elements RENAME TO elements_gone",
    );

    test("a mode that cannot read the elements stays loading", () async {
      await lose();

      final mode = OcptBreakdownBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _SilentRouterManager(),
        exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      );
      addTearDown(mode.close);
      await settle();

      expect(mode.state.isLoading, isTrue);
    });

    test("reading the snapshot again answers false and leaves the state as it was", () async {
      final mode = await buildMode();
      final held = mode.state;
      await lose();

      expect(await mode.reload({OcptBreakdownReloadScope.snapshot}), isFalse);

      expect(mode.state.reloadEpoch, held.reloadEpoch);
      expect(mode.state.snapshot, same(held.snapshot));
    });
  });

  group("a tag and its element are written whole or not at all", () {
    test("an element whose tag is refused is not minted", () async {
      final project = projectsManager.currentProject!;
      await refuse("INSERT", "breakdown_tags");

      await expectLater(
        projectsManager.breakdownService.createElementAndTag(
          database: project.database,
          sceneId: sceneId,
          startOffset: 2,
          endOffset: 6,
          taggedText: "lamp",
          name: "Lamp",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        ),
        throwsA(anything),
      );

      final elements = await projectsManager.elementsService
          .loadElements(database: project.database)
          .valueOrFail;
      expect(elements.map((element) => element.name), ["Desk lamp"]);
    });

    test("a tag whose element is refused leaves nothing behind", () async {
      final project = projectsManager.currentProject!;
      await refuse("INSERT", "elements");

      await expectLater(
        projectsManager.breakdownService.createElementAndTag(
          database: project.database,
          sceneId: sceneId,
          startOffset: 2,
          endOffset: 6,
          taggedText: "lamp",
          name: "Lamp",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        ),
        throwsA(isA<OcptDatabaseAbort>()),
      );

      expect(await project.database.select(project.database.ocptBreakdownTagsTable).get(), isEmpty);
    });

    test("a tag whose scene link is refused is not written", () async {
      final project = projectsManager.currentProject!;
      await refuse("INSERT", "scene_elements");

      await expectLater(
        projectsManager.breakdownService.createTag(
          database: project.database,
          sceneId: sceneId,
          startOffset: 2,
          endOffset: 6,
          taggedText: "lamp",
          targetKind: OcptBreakdownTargetKind.element,
          targetId: elementId,
        ),
        throwsA(isA<OcptDatabaseAbort>()),
      );

      expect(await project.database.select(project.database.ocptBreakdownTagsTable).get(), isEmpty);
    });
  });
}

/// Build the event a case dispatches for an element and a person.
typedef OcptBreakdownInspectorEventFactory = OcptBreakdownEvent Function(String id, String person);
