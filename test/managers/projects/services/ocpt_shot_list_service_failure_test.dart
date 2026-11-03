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
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import '../../../ocpt_result_expectations.dart';
import 'ocpt_shot_list_service_test_doubles.dart';

/// The rows the calls of this file work on.
typedef _Fixture = ({
  String sceneId,
  String otherSceneId,
  String firstShot,
  String secondShot,
  String thirdShot,
  String roleId,
  String driverId,
});

/// Run the tests of what [OcptShotListService] answers when the database fails or refuses.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const assetsService = OcptAssetsService(logger: SilentLogger(), deviceId: testDeviceId);
  const elementsService = OcptElementsService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );
  const floorPlanService = OcptFloorPlanService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );
  const locationsService = OcptLocationsService(
    logger: SilentLogger(),
    assetsService: assetsService,
    floorPlanService: floorPlanService,
    deviceId: testDeviceId,
  );
  const roleIndexService = OcptRoleIndexService(
    logger: SilentLogger(),
    elementsService: elementsService,
    roleCandidatesService: OcptRoleCandidatesService(
      logger: SilentLogger(),
      deviceId: testDeviceId,
    ),
    deviceId: testDeviceId,
  );
  const storyboardService = OcptStoryboardService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );
  const shotListService = OcptShotListService(
    logger: SilentLogger(),
    roleIndexService: roleIndexService,
    storyboardService: storyboardService,
    floorPlanService: floorPlanService,
    deviceId: testDeviceId,
  );
  const shotCoverageService = OcptShotCoverageService(
    logger: SilentLogger(),
    deviceId: testDeviceId,
  );
  const screenplayService = OcptScreenplayService(
    logger: SilentLogger(),
    sceneIndexService: OcptSceneIndexService(logger: SilentLogger()),
    shotListService: shotListService,
    shotCoverageService: shotCoverageService,
    roleIndexService: roleIndexService,
    breakdownService: OcptBreakdownService(
      logger: SilentLogger(),
      elementsService: elementsService,
      locationsService: locationsService,
      deviceId: testDeviceId,
    ),
    scheduleService: OcptScheduleService(logger: SilentLogger(), deviceId: testDeviceId),
    deviceId: testDeviceId,
  );

  const screenplayId = "screenplay-1";
  const sceneText = "INT. HOUSE - DAY\n\nAction.\n\nINT. GARDEN - DAY\n\nAction two.\n";

  late OcptProjectDatabase database;
  late _Fixture rows;

  /// Every table the shot list writes, directly or through its cascade.
  const tables = [
    "shots",
    "shot_characters",
    "shot_coverages",
    "storyboard_panels",
    "storyboard_annotations",
    "floor_plan_symbols",
    "floor_plan_arrows",
    "roles",
    "role_episodes",
    "assets",
  ];

  /// Two scenes, three shots (the first with a character, a coverage range, a board panel, a
  /// floor plan camera and an arrow), and a role to attach.
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
          fountainText: sceneText,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    final scenes = await database.select(database.ocptScenesTable).get()
      ..sort((a, b) => a.position.compareTo(b.position));
    final sceneId = scenes.first.id;
    final otherSceneId = scenes.last.id;
    Future<String> shot(String scene) => shotListService
        .createShot(database: database, screenplayId: screenplayId, sceneId: scene)
        .valueOrFail;
    final first = await shot(sceneId);
    final second = await shot(sceneId);
    final third = await shot(otherSceneId);
    final driver = await shotListService
        .resolveOrCreateRoleId(database: database, screenplayId: screenplayId, name: "DRIVER")
        .valueOrFail;
    final passerby = await shotListService
        .resolveOrCreateRoleId(database: database, screenplayId: screenplayId, name: "PASSERBY")
        .valueOrFail;
    await shotListService
        .attachCharacter(database: database, shotId: first, roleId: driver)
        .okOrFail;
    await shotCoverageService
        .addRange(
          database: database,
          shotId: first,
          sceneId: sceneId,
          startOffset: 0,
          endOffset: 5,
          sceneText: sceneText,
        )
        .valueOrFail;
    await storyboardService.addPanel(database: database, shotId: first).valueOrFail;
    final setId = await locationsService
        .createSetLinkedToScene(database: database, sceneId: sceneId, name: "Kitchen")
        .valueOrFail;
    Future<String> place(OcptFloorPlanLayer layer, double at) => floorPlanService
        .placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: first,
          layer: layer,
          xM: at,
          yM: at,
        )
        .valueOrFail;
    final camera = await place(OcptFloorPlanLayer.cameras, 1);
    final character = await place(OcptFloorPlanLayer.characters, 2);
    await floorPlanService
        .addArrow(
          database: database,
          setId: setId,
          shotId: first,
          kind: OcptFloorPlanArrowKind.movement,
          fromSymbolId: camera,
          toSymbolId: character,
        )
        .valueOrFail;

    return (
      sceneId: sceneId,
      otherSceneId: otherSceneId,
      firstShot: first,
      secondShot: second,
      thirdShot: third,
      roleId: passerby,
      driverId: driver,
    );
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
    "createShot": (r) async => (await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: r.otherSceneId,
    )).status,
    "updateShot": (r) async => (await shotListService.updateShot(
      database: database,
      shotId: r.secondShot,
      notes: const Value("Wide"),
    )).status,
    "updateTextField": (r) async => (await shotListService.updateTextField(
      database: database,
      shotId: r.secondShot,
      field: OcptShotListEditableField.lens,
      rawValue: "35mm",
    )).status,
    "updateDifficulty": (r) async => (await shotListService.updateDifficulty(
      database: database,
      shotId: r.secondShot,
      axis: OcptShotDifficultyAxis.camera,
      value: 3,
    )).status,
    "deleteShot": (r) async =>
        (await shotListService.deleteShot(database: database, shotId: r.firstShot)).status,
    "reorderShot": (r) async => (await shotListService.reorderShot(
      database: database,
      shotId: r.secondShot,
      newPosition: 0,
    )).status,
    "attachCharacter": (r) async => (await shotListService.attachCharacter(
      database: database,
      shotId: r.secondShot,
      roleId: r.roleId,
    )).status,
    "detachCharacter": (r) async => (await shotListService.detachCharacter(
      database: database,
      shotId: r.firstShot,
      roleId: r.driverId,
    )).status,
    "resolveOrCreateRoleId": (r) async => (await shotListService.resolveOrCreateRoleId(
      database: database,
      screenplayId: screenplayId,
      name: "NEWCOMER",
    )).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadShotList": (r) async => (await shotListService.loadShotList(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: null,
    )).status,
    "loadFieldSuggestions": (r) async => (await shotListService.loadFieldSuggestions(
      database: database,
      screenplayId: screenplayId,
    )).status,
    "distinctShotSizes": (r) async => (await shotListService.distinctShotSizes(
      database: database,
      screenplayId: screenplayId,
    )).status,
    "distinctFramings": (r) async => (await shotListService.distinctFramings(
      database: database,
      screenplayId: screenplayId,
    )).status,
    "distinctCameraMoves": (r) async => (await shotListService.distinctCameraMoves(
      database: database,
      screenplayId: screenplayId,
    )).status,
    "distinctLenses": (r) async => (await shotListService.distinctLenses(
      database: database,
      screenplayId: screenplayId,
    )).status,
    "distinctRecordingFormats": (r) async => (await shotListService.distinctRecordingFormats(
      database: database,
      screenplayId: screenplayId,
    )).status,
    "distinctSounds": (r) async => (await shotListService.distinctSounds(
      database: database,
      screenplayId: screenplayId,
    )).status,
  };

  /// Every row of the tables the service writes, plus the stamps, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in [...tables, "row_field_versions"]) {
      final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2").get();
      buffer.writeln("$table: ${[for (final row in result) row.data]}");
    }

    return buffer.toString();
  }

  /// Refuse the [verbs] on [table], on the rows [when] selects when it is given.
  Future<void> refuse(String table, List<String> verbs, {String? when}) async {
    for (final verb in verbs) {
      await database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "${when == null ? '' : 'WHEN $when '}BEGIN SELECT RAISE(ABORT, 'refused'); END",
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
      final created = <String?>[
        await shotListService
            .createShot(database: preview, screenplayId: screenplayId, sceneId: rows.sceneId)
            .maybeValueOrFail,
        await shotListService
            .resolveOrCreateRoleId(database: preview, screenplayId: screenplayId, name: "ANYONE")
            .maybeValueOrFail,
      ];

      expect(created, everyElement(isNull));
    });

    test("a read is not refused", () async {
      final listed = await shotListService
          .loadShotList(database: preview, screenplayId: screenplayId, episodeNumber: null)
          .valueOrFail;

      expect(listed.sequences, isEmpty);
    });
  });

  group("a write that touches several rows is one transaction", () {
    /// Refuse the [verbs] on [table], then expect the write called [name] to answer a database
    /// error with every table as it was.
    Future<void> expectNothingKept(String name, String table, List<String> verbs) async {
      final untouched = await snapshot();
      await refuse(table, verbs);

      final status = await writes[name]!(rows);

      expect(status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
    }

    for (final (table, verbs) in [
      ("shots", ["UPDATE"]),
      ("shot_characters", ["UPDATE"]),
      ("shot_coverages", ["UPDATE"]),
      ("storyboard_panels", ["UPDATE"]),
      ("floor_plan_symbols", ["UPDATE"]),
      ("floor_plan_arrows", ["UPDATE"]),
    ]) {
      test("a deleted shot keeps everything when $table cannot be written", () async {
        await expectNothingKept("deleteShot", table, verbs);
      });
    }

    test(
      "a role minted for a character is not kept when it cannot be linked to the episode",
      () async {
        await expectNothingKept("resolveOrCreateRoleId", "role_episodes", ["INSERT"]);
      },
    );

    test("a role minted for a character is not kept when its row is refused", () async {
      await expectNothingKept("resolveOrCreateRoleId", "roles", ["INSERT"]);
    });
  });

  test("a typed duration is not a text column and writes nothing", () async {
    final untouched = await snapshot();

    final written = await shotListService.updateTextField(
      database: database,
      shotId: rows.secondShot,
      field: OcptShotListEditableField.estimatedDuration,
      rawValue: "12",
    );

    expect(written.status, OcptDatabaseStatus.ok);
    expect(await snapshot(), untouched);
  });

  test("an existing role is resolved without a write, even when roles cannot be written", () async {
    await refuse("roles", ["INSERT", "UPDATE"]);

    final resolved = await shotListService
        .resolveOrCreateRoleId(database: database, screenplayId: screenplayId, name: "DRIVER")
        .valueOrFail;

    expect(resolved, isNotEmpty);
  });
}
