// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import '../../../ocpt_result_expectations.dart';

/// The fixed device id every stamp this file's writes carry.
const _deviceId = "device-1";

/// The rows the calls of this file work on.
typedef _Fixture = ({String shot, String firstPanel, String secondPanel, String mark});

/// Answer with the fixed device id.
Future<String> _testDeviceId() async => _deviceId;

/// Run the tests of what [OcptStoryboardService] answers when the database fails or refuses.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const assetsService = OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId);
  const storyboardService = OcptStoryboardService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: _testDeviceId,
  );
  const elementsService = OcptElementsService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: _testDeviceId,
  );
  const locationsService = OcptLocationsService(
    logger: SilentLogger(),
    assetsService: assetsService,
    floorPlanService: OcptFloorPlanService(
      logger: SilentLogger(),
      assetsService: assetsService,
      deviceId: _testDeviceId,
    ),
    deviceId: _testDeviceId,
  );
  const roleIndexService = OcptRoleIndexService(
    logger: SilentLogger(),
    elementsService: elementsService,
    roleCandidatesService: OcptRoleCandidatesService(
      logger: SilentLogger(),
      deviceId: _testDeviceId,
    ),
    deviceId: _testDeviceId,
  );
  const shotListService = OcptShotListService(
    logger: SilentLogger(),
    roleIndexService: roleIndexService,
    storyboardService: storyboardService,
    floorPlanService: OcptFloorPlanService(
      logger: SilentLogger(),
      assetsService: assetsService,
      deviceId: _testDeviceId,
    ),
    deviceId: _testDeviceId,
  );
  const screenplayService = OcptScreenplayService(
    logger: SilentLogger(),
    sceneIndexService: OcptSceneIndexService(logger: SilentLogger()),
    shotListService: shotListService,
    shotCoverageService: OcptShotCoverageService(logger: SilentLogger(), deviceId: _testDeviceId),
    roleIndexService: roleIndexService,
    breakdownService: OcptBreakdownService(
      logger: SilentLogger(),
      elementsService: elementsService,
      locationsService: locationsService,
      deviceId: _testDeviceId,
    ),
    scheduleService: OcptScheduleService(logger: SilentLogger(), deviceId: _testDeviceId),
    deviceId: _testDeviceId,
  );
  const screenplayId = "screenplay-1";

  late OcptProjectDatabase database;
  late _Fixture rows;

  const tables = ["storyboard_panels", "storyboard_annotations", "assets"];

  /// Save a one-scene screenplay and give back the id of a fresh shot, then attach two panels to
  /// it, the first with an image and a mark.
  Future<_Fixture> seed() async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );
    await screenplayService
        .saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: "INT. HOUSE - DAY\n\nAction.\n",
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    final scene = await (database.select(
      database.ocptScenesTable,
    )..where((row) => row.isDeleted.equals(false))).getSingle();
    final shot = (await shotListService
        .createShot(database: database, screenplayId: screenplayId, sceneId: scene.id)
        .valueOrFail);
    final first = await storyboardService.addPanel(database: database, shotId: shot).valueOrFail;
    final second = await storyboardService.addPanel(database: database, shotId: shot).valueOrFail;
    await storyboardService
        .replacePanelImage(database: database, panelId: first, path: "/frames/one.png")
        .okOrFail;
    final mark = await storyboardService
        .addAnnotation(
          database: database,
          panelId: first,
          kind: OcptStoryboardAnnotationKind.label,
          x1: 0.5,
          y1: 0.5,
        )
        .valueOrFail;

    return (shot: shot, firstPanel: first, secondPanel: second, mark: mark);
  }

  setUp(() async {
    database = OcptProjectDatabase.memory();
    rows = await seed();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every write of the service, with an input that changes a row.
  final writes = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "addPanel": (r) async =>
        (await storyboardService.addPanel(database: database, shotId: r.shot)).status,
    "replacePanelImage": (r) async => (await storyboardService.replacePanelImage(
      database: database,
      panelId: r.firstPanel,
      path: "/frames/two.png",
    )).status,
    "reorderPanel": (r) async => (await storyboardService.reorderPanel(
      database: database,
      panelId: r.secondPanel,
      newPosition: 0,
    )).status,
    "updatePanelComment": (r) async => (await storyboardService.updatePanelComment(
      database: database,
      panelId: r.firstPanel,
      comment: "Wide",
    )).status,
    "deletePanel": (r) async =>
        (await storyboardService.deletePanel(database: database, panelId: r.firstPanel)).status,
    "addAnnotation": (r) async => (await storyboardService.addAnnotation(
      database: database,
      panelId: r.firstPanel,
      kind: OcptStoryboardAnnotationKind.movementArrow,
      x1: 0.1,
      y1: 0.1,
      x2: 0.9,
      y2: 0.9,
    )).status,
    "updateAnnotation": (r) async => (await storyboardService.updateAnnotation(
      database: database,
      annotationId: r.mark,
      text: const Value("Pan"),
    )).status,
    "deleteAnnotation": (r) async =>
        (await storyboardService.deleteAnnotation(database: database, annotationId: r.mark)).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadStoryboard": (r) async => (await storyboardService.loadStoryboard(
      database: database,
      screenplayId: screenplayId,
    )).status,
  };

  /// Every row of the tables the service writes, plus the stamps, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in [...tables, "row_field_versions"]) {
      final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2, 3").get();
      buffer.writeln("$table: ${[for (final row in result) row.data]}");
    }

    return buffer.toString();
  }

  /// Refuse the [verbs] on [table].
  Future<void> refuse(String table, List<String> verbs) async {
    for (final verb in verbs) {
      await database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );
    }
  }

  group("every write answers a database error when the database refuses it", () {
    for (final entry in writes.entries) {
      test("${entry.key} writes nothing", () async {
        // The call must change something when nothing is wrong, or the refusal proves nothing.
        final before = await snapshot();
        expect(await entry.value(rows), OcptDatabaseStatus.ok);
        expect(await snapshot(), isNot(before), reason: "the input changes no row");
        await database.close();
        database = OcptProjectDatabase.memory();
        rows = await seed();

        final untouched = await snapshot();
        for (final table in tables) {
          await refuse(table, ["INSERT", "UPDATE"]);
        }

        final status = await entry.value(rows);

        expect(status, OcptDatabaseStatus.databaseError);
        expect(await snapshot(), untouched, reason: "the failed call rolled back whole");
      });
    }
  });

  group("every method answers a database error when its tables are gone", () {
    for (final entry in {...writes, ...reads}.entries) {
      test("${entry.key} answers a database error", () async {
        for (final table in tables) {
          await database.customStatement("ALTER TABLE $table RENAME TO ${table}_gone");
        }

        expect(await entry.value(rows), OcptDatabaseStatus.databaseError);
      });
    }
  });

  group("on the database of a version being previewed", () {
    late OcptProjectDatabase preview;

    setUp(() => preview = OcptProjectDatabase.memory(isPreview: true));

    tearDown(() => preview.close());

    test("every write is refused as a call that went well, and writes nothing", () async {
      final previous = database;
      database = preview;
      final untouched = await snapshot();

      for (final entry in writes.entries) {
        expect(await entry.value(rows), OcptDatabaseStatus.ok, reason: entry.key);
      }

      expect(await snapshot(), untouched);
      database = previous;
    });

    test("a write that answers an id answers none", () async {
      final panel = await storyboardService
          .addPanel(database: preview, shotId: rows.shot)
          .maybeValueOrFail;
      final mark = await storyboardService
          .addAnnotation(
            database: preview,
            panelId: rows.firstPanel,
            kind: OcptStoryboardAnnotationKind.label,
            x1: 0.5,
            y1: 0.5,
          )
          .maybeValueOrFail;

      expect(panel, isNull);
      expect(mark, isNull);
    });

    test("a read is not refused", () async {
      final read = await storyboardService
          .loadStoryboard(database: preview, screenplayId: screenplayId)
          .valueOrFail;

      expect(read.panelsByShotId, isEmpty);
    });
  });

  group("a write that touches two tables is one transaction", () {
    test("a panel whose marks cannot be tombstoned stays live", () async {
      final untouched = await snapshot();
      await refuse("storyboard_annotations", ["UPDATE"]);

      final deleted = await storyboardService.deletePanel(
        database: database,
        panelId: rows.firstPanel,
      );

      expect(deleted.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
    });

    test("a panel keeps its former image when the new one cannot be minted", () async {
      final untouched = await snapshot();
      await refuse("assets", ["INSERT"]);

      final replaced = await storyboardService.replacePanelImage(
        database: database,
        panelId: rows.firstPanel,
        path: "/frames/two.png",
      );

      expect(replaced.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "the former image stayed tombstoned");
    });
  });
}
