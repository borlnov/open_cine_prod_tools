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
import '../../../ocpt_result_expectations.dart';

/// Run the tests of what [OcptScreenplayService] answers when the database fails or refuses.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "device-1";

  final assetsService = OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId);
  final elementsService = OcptElementsService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );
  final floorPlanService = OcptFloorPlanService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );
  final roleIndexService = OcptRoleIndexService(
    logger: const SilentLogger(),
    elementsService: elementsService,
    roleCandidatesService: OcptRoleCandidatesService(
      logger: const SilentLogger(),
      deviceId: testDeviceId,
    ),
    deviceId: testDeviceId,
  );
  final service = OcptScreenplayService(
    logger: const SilentLogger(),
    sceneIndexService: const OcptSceneIndexService(logger: SilentLogger()),
    shotListService: OcptShotListService(
      logger: const SilentLogger(),
      roleIndexService: roleIndexService,
      storyboardService: OcptStoryboardService(
        logger: const SilentLogger(),
        assetsService: assetsService,
        deviceId: testDeviceId,
      ),
      floorPlanService: floorPlanService,
      deviceId: testDeviceId,
    ),
    shotCoverageService: OcptShotCoverageService(
      logger: const SilentLogger(),
      deviceId: testDeviceId,
    ),
    roleIndexService: roleIndexService,
    breakdownService: OcptBreakdownService(
      logger: const SilentLogger(),
      elementsService: elementsService,
      locationsService: OcptLocationsService(
        logger: const SilentLogger(),
        assetsService: assetsService,
        floorPlanService: floorPlanService,
        deviceId: testDeviceId,
      ),
      deviceId: testDeviceId,
    ),
    scheduleService: OcptScheduleService(logger: const SilentLogger(), deviceId: testDeviceId),
    deviceId: testDeviceId,
  );

  const firstText = "INT. HOUSE - DAY\n\nCLARA\nHello.\n";
  const secondText = "INT. GARDEN - DAY\n\nPAUL\nHello.\n";

  late OcptProjectDatabase database;
  late String first;
  late String second;
  late String third;

  /// Every table the service writes, directly or through its cascade.
  const tables = [
    "screenplays",
    "screenplay_snapshots",
    "scenes",
    "shots",
    "roles",
    "role_episodes",
    "row_field_versions",
  ];

  /// Open a fresh database holding three episodes, the first two with a text.
  Future<void> seed() async {
    database = OcptProjectDatabase.memory();
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: "screenplay-1",
            title: "Pilot",
            sortKey: const Value("a"),
            updatedAt: DateTime.utc(2026, 1, 5),
          ),
        );
    first = "screenplay-1";
    second = await service.createEpisode(database: database, title: "Two").valueOrFail;
    third = await service.createEpisode(database: database, title: "Three").valueOrFail;
    for (final (id, text) in [(first, firstText), (second, secondText)]) {
      await service
          .saveScreenplayText(
            database: database,
            screenplayId: id,
            fountainText: text,
            snapshotReason: OcptSnapshotReason.manual,
          )
          .okOrFail;
    }
  }

  setUp(seed);

  tearDown(() async {
    await database.close();
  });

  /// Every write of the service, with an input that changes a row.
  final writes = <String, Future<MixinResultStatus> Function()>{
    "saveScreenplayText": () async => (await service.saveScreenplayText(
      database: database,
      screenplayId: first,
      fountainText: "INT. CABIN - DAY\n\nJEAN\nHello.\n",
      snapshotReason: OcptSnapshotReason.manual,
    )).status,
    "snapshotOnProjectOpen": () async =>
        (await service.snapshotOnProjectOpen(database: database, screenplayId: first)).status,
    "createEpisode": () async =>
        (await service.createEpisode(database: database, title: "Four")).status,
    "updateEpisode": () async => (await service.updateEpisode(
      database: database,
      screenplayId: third,
      title: const Value("Three bis"),
    )).status,
    "reorderEpisode": () async => (await service.reorderEpisode(
      database: database,
      screenplayId: third,
      newPosition: 0,
    )).status,
    "deleteEpisode": () async =>
        (await service.deleteEpisode(database: database, screenplayId: second)).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function()>{
    "loadScreenplayText": () async =>
        (await service.loadScreenplayText(database: database, screenplayId: first)).status,
    "loadEpisodes": () async => (await service.loadEpisodes(database: database)).status,
  };

  /// Every row of the tables the service writes, plus the stamps, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in tables) {
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
        expect(await entry.value(), OcptDatabaseStatus.ok);
        expect(await snapshot(), isNot(before), reason: "the input changes no row");
        await database.close();
        await seed();

        final untouched = await snapshot();
        for (final table in tables) {
          await refuse(table, ["INSERT", "UPDATE"]);
        }

        final status = await entry.value();

        expect(status, OcptDatabaseStatus.databaseError);
        expect(await snapshot(), untouched, reason: "the failed call rolled back whole");
      });
    }
  });

  group("every method answers a database error when its tables are gone", () {
    for (final entry in {...writes, ...reads}.entries) {
      test("${entry.key} answers a database error", () async {
        for (final table in ["screenplays", "screenplay_snapshots"]) {
          await database.customStatement("ALTER TABLE $table RENAME TO ${table}_gone");
        }

        expect(await entry.value(), OcptDatabaseStatus.databaseError);
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
        expect(await entry.value(), OcptDatabaseStatus.ok, reason: entry.key);
      }

      expect(await snapshot(), untouched);
      database = previous;
    });

    test("a refused creation answers no id, and a refused deletion answers false", () async {
      final created = await service
          .createEpisode(database: preview, title: "Four")
          .maybeValueOrFail;
      final deleted = await service
          .deleteEpisode(database: preview, screenplayId: "any")
          .valueOrFail;

      expect(created, isNull);
      expect(deleted, isFalse);
    });
  });

  group("a write that touches several rows is one transaction", () {
    /// Refuse the [verbs] on [table], then expect the write called [name] to answer a database
    /// error with every table as it was.
    Future<void> expectNothingKept(
      String name,
      String table,
      List<String> verbs, {
      String? when,
    }) async {
      final untouched = await snapshot();
      await refuse(table, verbs, when: when);

      final status = await writes[name]!();

      expect(status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
    }

    for (final (table, verbs) in [
      ("screenplay_snapshots", ["INSERT"]),
      ("scenes", ["INSERT", "UPDATE"]),
      ("roles", ["INSERT", "UPDATE"]),
      ("row_field_versions", ["INSERT", "UPDATE"]),
    ]) {
      test("a saved text is not kept when $table cannot be written", () async {
        await expectNothingKept("saveScreenplayText", table, verbs);
      });
    }

    test("a saved text keeps the old one when only the screenplay row is refused", () async {
      await expectNothingKept("saveScreenplayText", "screenplays", ["UPDATE"]);
    });

    for (final (table, verbs) in [
      ("scenes", ["UPDATE"]),
      ("screenplay_snapshots", ["UPDATE"]),
      ("role_episodes", ["UPDATE"]),
      ("row_field_versions", ["INSERT"]),
    ]) {
      test("a deleted episode keeps everything when $table cannot be written", () async {
        await expectNothingKept("deleteEpisode", table, verbs);
      });
    }

    test("a deleted episode keeps the row of the episode when only that row is refused", () async {
      await expectNothingKept("deleteEpisode", "screenplays", [
        "UPDATE",
      ], when: "OLD.id = 'screenplay-1' OR OLD.isDeleted = 0");
    });
  });

  test("the last live episode is not deleted, and that is not a failure", () async {
    await service.deleteEpisode(database: database, screenplayId: second).valueOrFail;
    await service.deleteEpisode(database: database, screenplayId: third).valueOrFail;

    final refused = await service.deleteEpisode(database: database, screenplayId: first);

    expect(refused.status, OcptDatabaseStatus.ok);
    expect(refused.value, isFalse);
  });

  test("a text that does not exist is a failure, not an empty text", () async {
    final read = await service.loadScreenplayText(database: database, screenplayId: "no-such");

    expect(read.status, OcptDatabaseStatus.databaseError);
    expect(read.value, isNull);
  });
}
