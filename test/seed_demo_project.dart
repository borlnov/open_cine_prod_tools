// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

// Seeds the demonstration project the README screenshots are taken against.
//
// This is not a test: it is a script that happens to run through `flutter test`, which is the only
// runner in this repository that gives a plain Dart VM the app's package resolution and the system
// `libsqlite3` drift needs. Its name deliberately lacks the `_test` suffix, so `flutter test` never
// picks it up on its own.
//
//   flutter test test/seed_demo_project.dart
//
// It writes `$OCPT_DEMO_PROJECT` (default: `/tmp/ocpt-screenshot/home/The Last Ferry.ocpt`),
// replacing whatever is there, and drives the app's own services rather than raw inserts, so the
// file it leaves behind is one the application could have written itself.

import 'dart:io';

import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:uuid/uuid.dart';

import 'ocpt_result_expectations.dart';
import 'seed_demo_project_budget.dart';
import 'seed_demo_project_catalogue.dart';
import 'seed_demo_project_data.dart';
import 'seed_demo_project_schedule.dart';
import 'seed_demo_project_shots.dart';

/// Run the tests of the seed demo project.
void main() {
  // Every service logs through appLogger(), which needs a global manager instance to exist;
  // merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> deviceId() async => "seed-device";
  final assetsService = OcptAssetsService(logger: const SilentLogger(), deviceId: deviceId);
  final roleCandidatesService = OcptRoleCandidatesService(
    logger: const SilentLogger(),
    deviceId: deviceId,
  );
  final elementsService = OcptElementsService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    deviceId: deviceId,
  );
  final floorPlanService = OcptFloorPlanService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    deviceId: deviceId,
  );
  final locationsService = OcptLocationsService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    floorPlanService: floorPlanService,
    deviceId: deviceId,
  );
  final roleIndexService = OcptRoleIndexService(
    logger: const SilentLogger(),
    elementsService: elementsService,
    roleCandidatesService: roleCandidatesService,
    deviceId: deviceId,
  );
  final breakdownService = OcptBreakdownService(
    logger: const SilentLogger(),
    elementsService: elementsService,
    locationsService: locationsService,
    deviceId: deviceId,
  );
  final storyboardService = OcptStoryboardService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    deviceId: deviceId,
  );
  final shotListService = OcptShotListService(
    logger: const SilentLogger(),
    roleIndexService: roleIndexService,
    storyboardService: storyboardService,
    floorPlanService: floorPlanService,
    deviceId: deviceId,
  );
  final peopleService = OcptPeopleService(
    logger: const SilentLogger(),
    deviceId: deviceId,
    assetsService: assetsService,
    roleCandidatesService: roleCandidatesService,
  );
  final scheduleService = OcptScheduleService(logger: const SilentLogger(), deviceId: deviceId);
  final budgetQuoteService = OcptBudgetQuoteService(
    logger: const SilentLogger(),
    deviceId: deviceId,
  );
  final budgetJournalService = OcptBudgetJournalService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    deviceId: deviceId,
  );
  final budgetFinancingService = OcptBudgetFinancingService(
    logger: const SilentLogger(),
    deviceId: deviceId,
  );
  final budgetSharingService = OcptBudgetSharingService(
    logger: const SilentLogger(),
    deviceId: deviceId,
  );
  final screenplayService = OcptScreenplayService(
    logger: const SilentLogger(),
    sceneIndexService: const OcptSceneIndexService(logger: SilentLogger()),
    shotListService: shotListService,
    shotCoverageService: OcptShotCoverageService(logger: const SilentLogger(), deviceId: deviceId),
    roleIndexService: roleIndexService,
    breakdownService: breakdownService,
    scheduleService: scheduleService,
    deviceId: deviceId,
  );

  test("seed the demonstration project", () async {
    final path =
        Platform.environment["OCPT_DEMO_PROJECT"] ??
        "/tmp/ocpt-screenshot/home/The Last Ferry.ocpt";
    final file = File(path);
    await file.parent.create(recursive: true);
    if (file.existsSync()) {
      await file.delete();
    }

    final database = OcptProjectDatabase(file);
    addTearDown(database.close);

    final now = DateTime.now();
    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: "The Last Ferry",
            createdAt: now,
            appVersionAtCreation: "0.1.0",
            pageFormat: OcptPageFormat.a4,
            currencyCode: const Value("EUR"),
          ),
        );

    final screenplayId = const Uuid().v4();
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "The Last Ferry",
            updatedAt: now,
            number: const Value(1),
            sortKey: Value(ocptFractionalKeyBetween()),
          ),
        );

    await screenplayService
        .saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: demoFountainText,
          snapshotReason: OcptSnapshotReason.import,
        )
        .okOrFail;

    // ---------------------------------------------------------------- the scene index just built

    final sceneRows =
        (await (database.select(database.ocptScenesTable)
                  ..where((row) => row.screenplayId.equals(screenplayId))
                  ..orderBy([(row) => OrderingTerm.asc(row.position)]))
                .get())
            .where((row) => !row.isDeleted)
            .toList();
    expect(sceneRows, hasLength(4), reason: "the demonstration screenplay holds four scenes");
    final sceneIds = [for (final row in sceneRows) row.id];

    final (:actorIds, :crewIds) = await seedAddressBook(
      database: database,
      peopleService: peopleService,
    );
    final roleIdByName = await seedCast(
      actorIds: actorIds,
      database: database,
      roleIndexService: roleIndexService,
    );
    final (:boatSetId, :cafeSetId, :harbourId, :pierSetId, :seaId) = await seedLocations(
      database: database,
      locationsService: locationsService,
      sceneIds: sceneIds,
    );
    final (
      :banknoteId,
      :boatId,
      :chartId,
      :compassId,
      :oilskinId,
      :rainTowerId,
      :satchelId,
      :wetCoatId,
    ) = await seedElements(
      database: database,
      elementsService: elementsService,
    );
    await seedBreakdown(
      banknoteId: banknoteId,
      boatId: boatId,
      boatSetId: boatSetId,
      breakdownService: breakdownService,
      cafeSetId: cafeSetId,
      chartId: chartId,
      compassId: compassId,
      database: database,
      oilskinId: oilskinId,
      pierSetId: pierSetId,
      rainTowerId: rainTowerId,
      roleIdByName: roleIdByName,
      satchelId: satchelId,
      sceneIds: sceneIds,
      sceneRows: sceneRows,
      wetCoatId: wetCoatId,
    );
    final shotsByScene = await seedShotList(
      database: database,
      sceneIds: sceneIds,
      screenplayId: screenplayId,
      shotListService: shotListService,
    );
    await seedFloorPlans(
      boatSetId: boatSetId,
      cafeSetId: cafeSetId,
      database: database,
      floorPlanService: floorPlanService,
      pierSetId: pierSetId,
      sceneIds: sceneIds,
      shotsByScene: shotsByScene,
    );
    await seedStoryboard(
      database: database,
      file: file,
      path: path,
      shotsByScene: shotsByScene,
      storyboardService: storyboardService,
    );
    await seedSchedule(
      boatSetId: boatSetId,
      cafeSetId: cafeSetId,
      crewIds: crewIds,
      database: database,
      harbourId: harbourId,
      pierSetId: pierSetId,
      roleIdByName: roleIdByName,
      sceneIds: sceneIds,
      scheduleService: scheduleService,
      seaId: seaId,
      shotsByScene: shotsByScene,
    );
    final (:costumesLineId, :accountIdOf) = await seedQuote(
      budgetQuoteService: budgetQuoteService,
      database: database,
    );
    await seedFinancing(
      budgetFinancingService: budgetFinancingService,
      budgetJournalService: budgetJournalService,
      budgetSharingService: budgetSharingService,
      costumesLineId: costumesLineId,
      database: database,
      accountIdOf: accountIdOf,
    );
    await seedSharing(
      budgetJournalService: budgetJournalService,
      budgetSharingService: budgetSharingService,
      database: database,
    );

    // ignore: avoid_print, this script reports where it wrote to the terminal that ran it
    print("Seeded $path");
  });
}
