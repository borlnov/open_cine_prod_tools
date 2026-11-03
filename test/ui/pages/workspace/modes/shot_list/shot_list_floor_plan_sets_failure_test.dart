// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'shot_list_floor_plan_sets_bloc_test_doubles.dart';

/// The ids of what the handlers work on.
typedef _Seeded = ({String sceneId, String linkedSetId, String freeSetId, String otherSetId});

/// What the floor plan sets bloc does when the database refuses a write on the sets: the handler
/// raises its write error, writes nothing, reads nothing again, and goes through once the refusal
/// is lifted; a flush stops at the first set name that fails.
void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptShotListBloc mode;
  late OcptShotListFloorPlanSetsBloc sets;
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_sets_failure_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: testAppLanguageCode,
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
      fountainText: twoSceneText,
      snapshotReason: OcptSnapshotReason.manual,
    );
    mode = OcptShotListBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: RecordingRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    sets = OcptShotListFloorPlanSetsBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fileSelectorManager: const StubFileSelectorManager(pickedPath: null),
      fieldEditDebounce: const Duration(days: 1),
    );
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    await settle();

    final sceneId = (mode.state.sequences.first as OcptSceneShotSequence).sceneId;
    final locations = projectsManager.locationsService;
    final locationId = await locations
        .createLocation(database: project.database, name: "House")
        .valueOrFail;
    final linkedSetId = await locations
        .createSet(database: project.database, locationId: locationId, name: "Kitchen")
        .valueOrFail;
    final freeSetId = await locations
        .createSet(database: project.database, locationId: locationId, name: "Hall")
        .valueOrFail;
    final otherSetId = await locations
        .createSet(database: project.database, locationId: locationId, name: "Cellar")
        .valueOrFail;
    await locations
        .assignSceneToSet(database: project.database, sceneId: sceneId, setId: linkedSetId)
        .valueOrFail;
    await projectsManager.floorPlanService
        .placeSymbol(
          database: project.database,
          setId: linkedSetId,
          sceneId: null,
          shotId: null,
          layer: OcptFloorPlanLayer.set,
          xM: 1,
          yM: 2,
        )
        .maybeValueOrFail;
    await mode.reload({
      OcptShotListReloadScope.floorPlans,
      OcptShotListReloadScope.locations,
      OcptShotListReloadScope.setScopeSymbols,
    });
    seeded = (
      sceneId: sceneId,
      linkedSetId: linkedSetId,
      freeSetId: freeSetId,
      otherSetId: otherSetId,
    );
  });

  tearDown(() async {
    await sets.close();
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Make every [verb] on [table] fail with a database error, on the rows [when] selects when it is
  /// given.
  Future<void> refuse(String verb, String table, {String? when}) =>
      projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "${when == null ? '' : 'WHEN $when '}BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

  /// Lift what [refuse] put.
  Future<void> allow(String verb, String table) => projectsManager.currentProject!.database
      .customStatement("DROP TRIGGER refuse_${verb.toLowerCase()}_$table");

  /// Read straight from the database every row of the tables a set creation writes, as text.
  Future<String> rowsOfSets() async {
    final database = projectsManager.currentProject!.database;
    final buffer = StringBuffer();
    for (final table in [
      "locations",
      "sets",
      "scene_sets",
      "floor_plan_symbols",
      "row_field_versions",
    ]) {
      final rows = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2").get();
      buffer.writeln("$table: ${[for (final row in rows) row.data]}");
    }

    return buffer.toString();
  }

  /// Read straight from the database the name of every live set, by id.
  Future<Map<String, String>> setNames() async {
    final rows = await projectsManager.currentProject!.database
        .customSelect("SELECT id, name FROM sets WHERE is_deleted = 0")
        .get();

    return {for (final row in rows) row.read<String>("id"): row.read<String>("name")};
  }

  /// The handlers, each with the tables and the verbs that fail it, and the event it dispatches.
  final cases =
      <
        String,
        ({String table, String verb, OcptShotListFloorPlanSetsEvent Function(_Seeded) event})
      >{
        "creating a set along with a location, with the location refused": (
          table: "locations",
          verb: "INSERT",
          event: (s) => const OcptShotListSetCreationRequestedEvent(),
        ),
        "creating a set, with the set refused": (
          table: "sets",
          verb: "INSERT",
          event: (s) => const OcptShotListSetCreationRequestedEvent(),
        ),
        "creating a set, with its link refused": (
          table: "scene_sets",
          verb: "INSERT",
          event: (s) => const OcptShotListSetCreationRequestedEvent(),
        ),
        "linking a set": (
          table: "scene_sets",
          verb: "INSERT",
          event: (s) => OcptShotListSetLinkRequestedEvent(setId: s.freeSetId),
        ),
        "unlinking a set": (
          table: "scene_sets",
          verb: "UPDATE",
          event: (s) => OcptShotListSetDeletionRequestedEvent(setId: s.linkedSetId),
        ),
        "duplicating a set, with the sibling refused": (
          table: "sets",
          verb: "INSERT",
          event: (s) =>
              OcptShotListSetDuplicationRequestedEvent(setId: s.linkedSetId, newSetName: "Copy"),
        ),
        "duplicating a set, with the plan copy refused": (
          table: "floor_plan_symbols",
          verb: "INSERT",
          event: (s) =>
              OcptShotListSetDuplicationRequestedEvent(setId: s.linkedSetId, newSetName: "Copy"),
        ),
        "duplicating a set, with its link refused": (
          table: "scene_sets",
          verb: "INSERT",
          event: (s) =>
              OcptShotListSetDuplicationRequestedEvent(setId: s.linkedSetId, newSetName: "Copy"),
        ),
      };

  for (final entry in cases.entries) {
    test("${entry.key} raises the write error, writes nothing and reads nothing again, then goes "
        "through once the refusal is lifted", () async {
      final held = mode.state;
      final untouched = await rowsOfSets();
      await refuse(entry.value.verb, entry.value.table);

      sets.add(entry.value.event(seeded));
      await settle();

      expect(sets.state.hasWriteError, isTrue);
      expect(mode.state.reloadEpoch, held.reloadEpoch, reason: "the mode read again");
      expect(await rowsOfSets(), untouched, reason: "the failed call rolled back whole");

      await allow(entry.value.verb, entry.value.table);
      sets.add(const OcptShotListFloorPlanSetsWriteErrorDismissedEvent());
      sets.add(entry.value.event(seeded));
      await settle();

      expect(sets.state.hasWriteError, isFalse);
      expect(mode.state.reloadEpoch, isNot(held.reloadEpoch));
      expect(await rowsOfSets(), isNot(untouched));
    });
  }

  group("flushing the typed set names", () {
    /// Type [name] into the tab of [setId].
    Future<void> type(String setId, String name) async {
      sets.add(OcptShotListSetNameChangedEvent(setId: setId, rawValue: name));
      await settle();
    }

    /// Refuse the rename of the set [setId] alone.
    Future<void> refuseSet(String setId) => refuse("UPDATE", "sets", when: "NEW.id = '$setId'");

    test("a refused rename raises the write error, forgets the names and stops the next", () async {
      await type(seeded.linkedSetId, "Scullery");
      await type(seeded.freeSetId, "Lobby");
      await refuseSet(seeded.linkedSetId);

      final status = await sets.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.ok);
      expect(sets.state.hasWriteError, isTrue);
      expect(sets.state.pendingFieldEdits, isEmpty);
      final names = await setNames();
      expect(names[seeded.linkedSetId], "Kitchen");
      expect(names[seeded.freeSetId], "Hall", reason: "the name after the refused one");
    });

    test("a refused flush on leaving stops the names after it, and keeps them pending", () async {
      await type(seeded.linkedSetId, "Scullery");
      await type(seeded.freeSetId, "Lobby");
      await refuseSet(seeded.linkedSetId);

      await sets.flushPendingWritesWithoutState();

      expect((await setNames())[seeded.freeSetId], "Hall", reason: "the name after the refused");
      expect(sets.state.pendingFieldEdits, isNotEmpty);
      expect(sets.state.hasWriteError, isFalse, reason: "a flush on leaving only logs");
    });

    test("a refused flush on leaving is written again by the next one", () async {
      await type(seeded.linkedSetId, "Scullery");
      await refuse("UPDATE", "sets");
      await sets.flushPendingWritesWithoutState();
      await allow("UPDATE", "sets");

      await sets.flushPendingWritesWithoutState();

      expect((await setNames())[seeded.linkedSetId], "Scullery");
    });
  });
}
