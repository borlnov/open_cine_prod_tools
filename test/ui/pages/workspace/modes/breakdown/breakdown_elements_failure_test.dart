// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_tagging_bloc.dart';
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

  group("the inspector's chain of writes", () {
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

    /// Read straight from the database how many scene breakdowns hold the note "A note".
    Future<int> notedScenes() async {
      final rows = await projectsManager.currentProject!.database
          .customSelect("SELECT id FROM scene_breakdowns WHERE notes = 'A note'")
          .get();

      return rows.length;
    }

    /// Read straight from the database the name of element [id].
    Future<String> nameOf(String id) async {
      final row = await projectsManager.currentProject!.database
          .customSelect("SELECT name AS value FROM elements WHERE id = '$id'")
          .getSingle();

      return row.read<String>("value");
    }

    test("a refused element write stops the edits after it", () async {
      final project = projectsManager.currentProject!;
      final otherId = await projectsManager.elementsService
          .createElement(
            database: project.database,
            name: "Chair",
            category: OcptElementCategory.prop,
            sourceKind: OcptElementSourceKind.owned,
          )
          .valueOrFail;
      inspector.add(
        OcptBreakdownElementFieldChangedEvent(
          elementId: elementId,
          field: OcptElementField.name,
          rawValue: "Renamed lamp",
        ),
      );
      inspector.add(
        OcptBreakdownElementFieldChangedEvent(
          elementId: otherId,
          field: OcptElementField.name,
          rawValue: "Renamed chair",
        ),
      );
      inspector.add(OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "A note"));
      await settle();
      await project.database.customStatement(
        "CREATE TRIGGER refuse_first BEFORE UPDATE ON elements WHEN NEW.id = '$elementId' "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      final status = await inspector.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.ok);
      expect(await nameOf(elementId), "Desk lamp");
      expect(await nameOf(otherId), "Chair", reason: "the element after the refused one");
      expect(await notedScenes(), 0, reason: "the scene note after the refused element");
    });

    test("a refused scene note stops the set names after it", () async {
      final project = projectsManager.currentProject!;
      final locationId = (await projectsManager.locationsService
          .createLocation(database: project.database, name: "House")
          .valueOrFail);
      final setId = (await projectsManager.locationsService
          .createSet(database: project.database, locationId: locationId, name: "Kitchen")
          .valueOrFail);
      inspector.add(OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "A note"));
      inspector.add(OcptBreakdownSetNameChangedEvent(setId: setId, rawValue: "Renamed kitchen"));
      await settle();
      await refuse("INSERT", "scene_breakdowns");

      final status = await inspector.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.ok);
      final names = await project.database
          .customSelect("SELECT name FROM sets WHERE id = '$setId'")
          .get();
      expect(names.single.read<String>("name"), "Kitchen");
    });

    test("a refused element flush without state stops the flush of the scene notes", () async {
      inspector.add(
        OcptBreakdownElementFieldChangedEvent(
          elementId: elementId,
          field: OcptElementField.name,
          rawValue: "Renamed lamp",
        ),
      );
      inspector.add(OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "A note"));
      await settle();
      await refuse("UPDATE", "elements");

      await inspector.flushPendingWritesWithoutState();

      expect(await notedScenes(), 0);

      await lift("UPDATE", "elements");
      await inspector.flushPendingWritesWithoutState();

      expect(await notedScenes(), 1, reason: "the note goes through once the refusal is lifted");
    });
  });

  group("the inspector's tag and scene writes", () {
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

    /// Tag the passage [start]..[end] of the scene with the seeded element, flag it as moved, then
    /// have the mode read the tag, and give its id.
    Future<String> tag(int start, int end) async {
      final tagId = await projectsManager.breakdownService
          .createTag(
            database: projectsManager.currentProject!.database,
            sceneId: sceneId,
            startOffset: start,
            endOffset: end,
            taggedText: "x" * (end - start),
            targetKind: OcptBreakdownTargetKind.element,
            targetId: elementId,
          )
          .valueOrFail;
      await projectsManager.currentProject!.database.customStatement(
        "UPDATE breakdown_tags SET needs_check = 1 WHERE id = '$tagId'",
      );
      await mode.reload({OcptBreakdownReloadScope.snapshot});

      return tagId;
    }

    /// Count the live tags, read straight from the database.
    Future<int> liveTagCount() async {
      final rows = await projectsManager.currentProject!.database
          .customSelect("SELECT id FROM breakdown_tags WHERE is_deleted = 0")
          .get();

      return rows.length;
    }

    /// The handlers, each with the table and the verb that fail it, and the event it dispatches.
    final cases =
        <
          String,
          ({
            String table,
            String verb,
            OcptBreakdownEvent Function(String tagId) event,
            bool selectsTarget,
          })
        >{
          "changing the status of the scene": (
            table: "scene_breakdowns",
            verb: "INSERT",
            event: (tagId) => OcptBreakdownSceneStatusChangedEvent(
              sceneId: sceneId,
              status: OcptBreakdownSceneStatus.done,
            ),
            selectsTarget: false,
          ),
          "confirming the removal of a target's tags": (
            table: "breakdown_tags",
            verb: "UPDATE",
            event: (tagId) => const OcptBreakdownTagRemovalConfirmedEvent(),
            selectsTarget: true,
          ),
          "marking a tag as checked": (
            table: "breakdown_tags",
            verb: "UPDATE",
            event: (tagId) => OcptBreakdownTagNeedsCheckClearedEvent(tagId: tagId),
            selectsTarget: false,
          ),
          "removing a flagged tag": (
            table: "breakdown_tags",
            verb: "UPDATE",
            event: (tagId) => OcptBreakdownFlaggedTagRemovedEvent(tagId: tagId),
            selectsTarget: false,
          ),
        };

    for (final entry in cases.entries) {
      test(
        "${entry.key} stops, reads nothing again, and goes through once the refusal is lifted",
        () async {
          final tagId = await tag(2, 6);
          if (entry.value.selectsTarget) {
            mode.add(
              OcptBreakdownTargetSelectedEvent(
                targetKind: OcptBreakdownTargetKind.element,
                targetId: elementId,
                sceneId: sceneId,
              ),
            );
            await settle();
          }
          final held = mode.state;
          await refuse(entry.value.verb, entry.value.table);

          inspector.add(entry.value.event(tagId));
          await settle();

          expect(mode.state.reloadEpoch, held.reloadEpoch, reason: "the mode read again");
          expect(await liveTagCount(), 1, reason: "a tag was removed");

          await lift(entry.value.verb, entry.value.table);
          inspector.add(entry.value.event(tagId));
          await settle();

          expect(mode.state.reloadEpoch, isNot(held.reloadEpoch));
        },
      );
    }

    test("a refused removal of one tag stops the removal of the ones after it", () async {
      final first = await tag(2, 6);
      await tag(10, 14);
      mode.add(
        OcptBreakdownTargetSelectedEvent(
          targetKind: OcptBreakdownTargetKind.element,
          targetId: elementId,
          sceneId: sceneId,
        ),
      );
      await settle();
      await projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_first BEFORE UPDATE ON breakdown_tags WHEN NEW.id = '$first' "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      inspector.add(const OcptBreakdownTagRemovalConfirmedEvent());
      await settle();

      expect(await liveTagCount(), 2, reason: "the tag after the refused one was removed");
    });
  });

  group("the tagging view", () {
    late OcptBreakdownBloc mode;
    late OcptBreakdownTaggingBloc tagging;

    setUp(() async {
      mode = await buildMode();
      tagging = OcptBreakdownTaggingBloc(modeBloc: mode, projectsManager: projectsManager);
      addTearDown(tagging.close);
    });

    /// Close a range on "lamp sits on the desk" of the scene, to be tagged by the next event.
    Future<void> closeRange() async {
      tagging.add(
        OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24),
      );
      await settle();
      tagging.add(
        OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 37, wordEndOffset: 42),
      );
      await settle();
      expect(tagging.state.pendingTagRange, isNotNull);
    }

    /// Count the live tags, read straight from the database.
    Future<int> liveTagCount() async {
      final rows = await projectsManager.currentProject!.database
          .customSelect("SELECT id FROM breakdown_tags WHERE is_deleted = 0")
          .get();

      return rows.length;
    }

    /// The handlers, each with the event it dispatches once a range is closed.
    final cases = <String, ({bool closesRange, OcptBreakdownTaggingEvent Function() event})>{
      "linking a target": (
        closesRange: true,
        event: () => OcptBreakdownPopoverTargetLinkedEvent(
          targetKind: OcptBreakdownTargetKind.element,
          targetId: elementId,
        ),
      ),
      "creating an element": (
        closesRange: true,
        event: () => const OcptBreakdownPopoverElementCreationRequestedEvent(
          category: OcptElementCategory.prop,
          name: "Lamp",
        ),
      ),
      "creating a set": (
        closesRange: true,
        event: () =>
            const OcptBreakdownPopoverSetCreationRequestedEvent(locationId: null, name: "House"),
      ),
      "accepting a suggestion": (
        closesRange: false,
        event: () => OcptBreakdownSuggestionAcceptedEvent(
          targetKind: OcptBreakdownTargetKind.element,
          targetId: elementId,
          sceneId: sceneId,
          startOffset: 2,
          endOffset: 6,
          taggedText: "lamp",
        ),
      ),
    };

    for (final entry in cases.entries) {
      test("${entry.key} stops without a notice, reads nothing again, and goes through once the "
          "refusal is lifted", () async {
        if (entry.value.closesRange) {
          await closeRange();
        }
        final held = mode.state;
        await refuse("INSERT", "breakdown_tags");

        tagging.add(entry.value.event());
        await settle();

        expect(mode.state.reloadEpoch, held.reloadEpoch, reason: "the mode read again");
        expect(tagging.state.hasTagWriteError, isFalse, reason: "a failure is no refusal");
        expect(tagging.state.pendingTagRange != null, entry.value.closesRange);
        expect(await liveTagCount(), 0);

        await lift("INSERT", "breakdown_tags");
        tagging.add(entry.value.event());
        await settle();

        expect(mode.state.reloadEpoch, isNot(held.reloadEpoch));
        expect(await liveTagCount(), 1);
      });
    }
  });

  group("when the breakdown cannot be read", () {
    // The elements, the scenes' own breakdown rows, the tags, the cast and the locations are
    // separate reads.
    for (final table in ["elements", "scene_breakdowns", "breakdown_tags", "roles", "locations"]) {
      /// Make [table] unreadable.
      Future<void> lose() => projectsManager.currentProject!.database.customStatement(
        "ALTER TABLE $table RENAME TO ${table}_gone",
      );

      test("a mode that cannot read $table stays loading", () async {
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

      test("reading $table again answers false and leaves the state as it was", () async {
        final mode = await buildMode();
        final held = mode.state;
        await lose();

        expect(await mode.reload({OcptBreakdownReloadScope.snapshot}), isFalse);

        expect(mode.state.reloadEpoch, held.reloadEpoch);
        expect(mode.state.snapshot, same(held.snapshot));
      });
    }
  });

  group("a tag and its element are written whole or not at all", () {
    /// Create an element and tag it with "lamp", as the popover's category chips do.
    Future<OcptDatabaseResult<({String elementId, String tagId})>> createElementAndTag() {
      final project = projectsManager.currentProject!;

      return projectsManager.breakdownService.createElementAndTag(
        database: project.database,
        sceneId: sceneId,
        startOffset: 2,
        endOffset: 6,
        taggedText: "lamp",
        name: "Lamp",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      );
    }

    test("an element whose tag is refused is not minted", () async {
      final project = projectsManager.currentProject!;
      await refuse("INSERT", "breakdown_tags");

      final created = await createElementAndTag();

      expect(created.status, OcptDatabaseStatus.databaseError);
      final elements = await projectsManager.elementsService
          .loadElements(database: project.database)
          .valueOrFail;
      expect(elements.map((element) => element.name), ["Desk lamp"]);
    });

    test("a tag whose element is refused leaves nothing behind", () async {
      final project = projectsManager.currentProject!;
      await refuse("INSERT", "elements");

      final created = await createElementAndTag();

      expect(created.status, OcptDatabaseStatus.databaseError);
      expect(await project.database.select(project.database.ocptBreakdownTagsTable).get(), isEmpty);
    });

    test("a tag whose scene link is refused is not written", () async {
      final project = projectsManager.currentProject!;
      await refuse("INSERT", "scene_elements");

      final tagged = await projectsManager.breakdownService.createTag(
        database: project.database,
        sceneId: sceneId,
        startOffset: 2,
        endOffset: 6,
        taggedText: "lamp",
        targetKind: OcptBreakdownTargetKind.element,
        targetId: elementId,
      );

      expect(tagged.status, OcptDatabaseStatus.databaseError);
      expect(await project.database.select(project.database.ocptBreakdownTagsTable).get(), isEmpty);
    });
  });

  group("the inspector's set writes", () {
    late OcptBreakdownBloc mode;
    late OcptBreakdownInspectorBloc inspector;
    late String linkedSetId;
    late String freeSetId;

    setUp(() async {
      final database = projectsManager.currentProject!.database;
      final locationId = await projectsManager.locationsService
          .createLocation(database: database, name: "House")
          .valueOrFail;
      linkedSetId = await projectsManager.locationsService
          .createSet(database: database, locationId: locationId, name: "Kitchen")
          .valueOrFail;
      freeSetId = await projectsManager.locationsService
          .createSet(database: database, locationId: locationId, name: "Hall")
          .valueOrFail;
      await projectsManager.locationsService
          .assignSceneToSet(database: database, sceneId: sceneId, setId: linkedSetId)
          .valueOrFail;
      mode = await buildMode();
      inspector = OcptBreakdownInspectorBloc(
        modeBloc: mode,
        projectsManager: projectsManager,
        fieldEditDebounce: const Duration(days: 1),
      );
      addTearDown(inspector.close);
    });

    /// Read straight from the database every row of the tables the set writes touch, as text.
    Future<String> rows() async {
      final database = projectsManager.currentProject!.database;
      final buffer = StringBuffer();
      for (final table in ["locations", "sets", "scene_sets", "row_field_versions"]) {
        final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2").get();
        buffer.writeln("$table: ${[for (final row in result) row.data]}");
      }

      return buffer.toString();
    }

    /// Read straight from the database the name of every live set, by id.
    Future<Map<String, String>> setNames() async {
      final result = await projectsManager.currentProject!.database
          .customSelect("SELECT id, name FROM sets WHERE is_deleted = 0")
          .get();

      return {for (final row in result) row.read<String>("id"): row.read<String>("name")};
    }

    /// The handlers, each with the table and the verb that fail it, and the event it dispatches.
    final cases =
        <String, ({String table, String verb, OcptBreakdownInspectorEvent Function() event})>{
          "linking a set to the scene": (
            table: "scene_sets",
            verb: "INSERT",
            event: () => OcptBreakdownSceneSetLinkedEvent(sceneId: sceneId, setId: freeSetId),
          ),
          "unlinking a set from the scene": (
            table: "scene_sets",
            verb: "UPDATE",
            event: () => OcptBreakdownSceneSetUnlinkedEvent(sceneId: sceneId, setId: linkedSetId),
          ),
          "creating a set, with its location refused": (
            table: "locations",
            verb: "INSERT",
            event: () => OcptBreakdownSceneSetCreationRequestedEvent(
              sceneId: sceneId,
              locationId: null,
              name: "Garden",
            ),
          ),
          "creating a set, with the set refused": (
            table: "sets",
            verb: "INSERT",
            event: () => OcptBreakdownSceneSetCreationRequestedEvent(
              sceneId: sceneId,
              locationId: null,
              name: "Garden",
            ),
          ),
          "creating a set, with its link refused": (
            table: "scene_sets",
            verb: "INSERT",
            event: () => OcptBreakdownSceneSetCreationRequestedEvent(
              sceneId: sceneId,
              locationId: null,
              name: "Garden",
            ),
          ),
        };

    for (final entry in cases.entries) {
      test("${entry.key} stops, writes nothing, reads nothing again, and goes through once the "
          "refusal is lifted", () async {
        final held = mode.state;
        final untouched = await rows();
        await refuse(entry.value.verb, entry.value.table);

        inspector.add(entry.value.event());
        await settle();

        expect(mode.state.reloadEpoch, held.reloadEpoch, reason: "the mode read again");
        expect(await rows(), untouched, reason: "the failed call rolled back whole");

        await lift(entry.value.verb, entry.value.table);
        inspector.add(entry.value.event());
        await settle();

        expect(mode.state.reloadEpoch, isNot(held.reloadEpoch));
        expect(await rows(), isNot(untouched));
      });
    }

    test("a refused set rename stops the renames after it and forgets the names", () async {
      inspector.add(OcptBreakdownSetNameChangedEvent(setId: linkedSetId, rawValue: "Scullery"));
      inspector.add(OcptBreakdownSetNameChangedEvent(setId: freeSetId, rawValue: "Lobby"));
      await settle();
      await projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_first BEFORE UPDATE ON sets WHEN NEW.id = '$linkedSetId' "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      final status = await inspector.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.ok);
      expect(inspector.state.pendingSetNameEdits, isEmpty);
      final names = await setNames();
      expect(names[linkedSetId], "Kitchen");
      expect(names[freeSetId], "Hall", reason: "the rename after the refused one");
    });

    test("a refused scene note on leaving stops the set renames after it", () async {
      inspector.add(OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "A note"));
      inspector.add(OcptBreakdownSetNameChangedEvent(setId: linkedSetId, rawValue: "Scullery"));
      await settle();
      await refuse("INSERT", "scene_breakdowns");

      await inspector.flushPendingWritesWithoutState();

      expect((await setNames())[linkedSetId], "Kitchen");

      await lift("INSERT", "scene_breakdowns");
      await inspector.flushPendingWritesWithoutState();

      expect((await setNames())[linkedSetId], "Scullery", reason: "the rename goes through later");
    });

    test("a refused set rename on leaving is written again by the next flush", () async {
      inspector.add(OcptBreakdownSetNameChangedEvent(setId: linkedSetId, rawValue: "Scullery"));
      await settle();
      await refuse("UPDATE", "sets");

      await inspector.flushPendingWritesWithoutState();

      expect((await setNames())[linkedSetId], "Kitchen");

      await lift("UPDATE", "sets");
      await inspector.flushPendingWritesWithoutState();

      expect((await setNames())[linkedSetId], "Scullery");
    });
  });
}

/// Build the event a case dispatches for an element and a person.
typedef OcptBreakdownInspectorEventFactory = OcptBreakdownEvent Function(String id, String person);
