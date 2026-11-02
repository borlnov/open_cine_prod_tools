// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

/// Run the tests of `restoreVersion`.
void main() {
  // Reading a version's stored summary logs through appLogger(), which requires a global manager
  // instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const codec = OcptProjectVersionCodec(logger: SilentLogger());

  const deviceId = "device-1";

  Future<String> testDeviceId() async => deviceId;

  final assetsService = OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId);

  final roleCandidatesService = OcptRoleCandidatesService(
    logger: const SilentLogger(),
    deviceId: testDeviceId,
  );

  final scheduleService = OcptScheduleService(logger: const SilentLogger(), deviceId: testDeviceId);

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

  final locationsService = OcptLocationsService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    floorPlanService: floorPlanService,
    deviceId: testDeviceId,
  );

  final roleIndexService = OcptRoleIndexService(
    logger: const SilentLogger(),
    elementsService: elementsService,
    roleCandidatesService: roleCandidatesService,
    deviceId: testDeviceId,
  );

  final breakdownService = OcptBreakdownService(
    logger: const SilentLogger(),
    elementsService: elementsService,
    locationsService: locationsService,
    deviceId: testDeviceId,
  );

  // Used directly by the breakdown restore tests below, to seed a real scene index and a real
  // reconciled role — separate from the one `service` builds for its own screenplay-snapshotting
  // needs, but a stateless collaborator over the same database, so the two never disagree.
  final screenplayService = OcptScreenplayService(
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
      floorPlanService: OcptFloorPlanService(
        logger: const SilentLogger(),
        assetsService: assetsService,
        deviceId: testDeviceId,
      ),
      deviceId: testDeviceId,
    ),
    shotCoverageService: OcptShotCoverageService(
      logger: const SilentLogger(),
      deviceId: testDeviceId,
    ),
    roleIndexService: roleIndexService,
    breakdownService: breakdownService,
    scheduleService: scheduleService,
    deviceId: testDeviceId,
  );

  final service = OcptProjectVersionsService(
    logger: const SilentLogger(),
    codec: codec,
    screenplayService: screenplayService,
  );

  const screenplayId = "screenplay-1";

  const appVersion = "0.1.0";

  const margins = FountainPageMargins(
    leftInches: 1.5,
    rightInches: 1,
    topInches: 0.75,
    bottomInches: 1.25,
  );

  late OcptProjectDatabase database;

  setUp(() async {
    database = OcptProjectDatabase.memory();

    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: "My Movie",
            createdAt: DateTime.utc(2026, 1, 4),
            appVersionAtCreation: appVersion,
            pageFormat: OcptPageFormat.a4,
            settingsJson: const Value('{"someSetting":true}'),
          ),
        );

    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            fountainText: const Value("INT. HOUSE - DAY\n\nCLARA enters."),
            updatedAt: DateTime.utc(2026, 1, 5),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  /// Inserts the scene [id] of the project's screenplay, tombstoned when [isDeleted].
  Future<void> insertScene({required String id, bool isDeleted = false}) => database
      .into(database.ocptScenesTable)
      .insert(
        OcptScenesTableCompanion.insert(
          id: id,
          screenplayId: screenplayId,
          position: 0,
          heading: "INT. HOUSE - DAY",
          charStart: 0,
          charEnd: 18,
          isDeleted: Value(isDeleted),
        ),
      );

  /// Inserts the shot [id] of scene [sceneId], tombstoned when [isDeleted].
  Future<void> insertShot({required String id, required String sceneId, bool isDeleted = false}) =>
      database
          .into(database.ocptShotsTable)
          .insert(
            OcptShotsTableCompanion.insert(
              id: id,
              screenplayId: screenplayId,
              sceneId: Value(sceneId),
              position: 0,
              sortKey: const Value("V"),
              framing: const Value("Low angle"),
              status: const Value(OcptShotStatus.shot),
              isDeleted: Value(isDeleted),
            ),
          );

  /// Creates a version named [name], with the fixed provenance every test here uses.
  Future<OcptProjectVersion> createVersion({String name = "v1 — First read", String note = ""}) =>
      service.createVersion(
        database: database,
        name: name,
        note: note,
        appVersion: appVersion,
        deviceId: deviceId,
        pageMargins: margins,
      );

  /// The payload stored with the version [id], decoded.
  Future<OcptProjectVersionPayload> readPayload(String id) async {
    final row = await (database.select(
      database.ocptProjectVersionsTable,
    )..where((table) => table.id.equals(id))).getSingle();

    final result = codec.decode(row.payload);
    expect(result.status, OcptProjectVersionPayloadStatus.ok);

    return result.value!;
  }

  /// The project header's pointer at the version the working copy descends from.
  Future<String?> readCurrentVersionId() async =>
      (await database.select(database.ocptProjectInfoTable).getSingle()).currentVersionId;

  group("restoreVersion", () {
    const rewrittenText = "EXT. STREET - NIGHT\n\nThe rewrite.";

    /// The screenplay's text as the project currently holds it.
    Future<String> readScreenplayText() async =>
        (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText;

    /// The shot [id] as the project currently holds it, tombstone included.
    Future<OcptShotRow?> readShot(String id) => (database.select(
      database.ocptShotsTable,
    )..where((table) => table.id.equals(id))).getSingleOrNull();

    /// Every version stamp the project currently holds, keyed by `<table>/<row>/<column>`.
    Future<Map<String, OcptRowFieldVersionRow>> readStamps() async => {
      for (final stamp in await database.select(database.ocptRowFieldVersionsTable).get())
        "${stamp.targetTableName}/${stamp.rowId}/${stamp.columnName}": stamp,
    };

    /// Restores the version [id], with the fixed provenance every test here uses.
    Future<ResultWithStatus<OcptProjectRestoreStatus, OcptPageSetup>> restore(String id) =>
        service.restoreVersion(
          database: database,
          id: id,
          safetyVersionName: "Before restoring",
          appVersion: appVersion,
          deviceId: deviceId,
          pageMargins: margins,
        );

    /// Captures the project as a version, then makes the working copy diverge from it: the
    /// screenplay is rewritten, one shot is edited, and another is added.
    Future<OcptProjectVersion> createDivergedProject() async {
      await insertScene(id: "scene-1");
      await insertShot(id: "shot-1", sceneId: "scene-1");

      final version = await createVersion();

      await database
          .update(database.ocptScreenplaysTable)
          .write(const OcptScreenplaysTableCompanion(fountainText: Value(rewrittenText)));
      await (database.update(database.ocptShotsTable)..where((table) => table.id.equals("shot-1")))
          .write(const OcptShotsTableCompanion(framing: Value("High angle")));
      await insertShot(id: "shot-2", sceneId: "scene-1");

      return version;
    }

    test(
      "stamps every column it changed with one version, above what any of them already held",
      () async {
        final version = await createDivergedProject();

        // As if the edit that rewrote the framing had been stamped by the changeset engine.
        await database
            .into(database.ocptRowFieldVersionsTable)
            .insert(
              OcptRowFieldVersionsTableCompanion.insert(
                targetTableName: "shots",
                rowId: "shot-1",
                columnName: "framing",
                version: 7,
                deviceId: "device-0",
              ),
            );

        await restore(version.id);

        final stamps = await readStamps();

        // A column the restore rewrote reads, to every other replica, as the most recent edit there
        // is — which is exactly what it is.
        expect(stamps["shots/shot-1/framing"]?.version, 8);
        expect(stamps["shots/shot-1/framing"]?.deviceId, deviceId);

        // A row the version didn't hold is tombstoned, and the tombstone is stamped like any other
        // write — sharing the very same version, since the whole restore is one transaction and
        // this device's clock hands out exactly one tick for it.
        expect(stamps["shots/shot-2/isDeleted"]?.version, 8);
        expect(stamps["shots/shot-2/isDeleted"]?.deviceId, deviceId);

        // A column whose value already matched the version is left alone: a restore must not stomp
        // an unrelated concurrent edit that happened to agree with it.
        expect(stamps.containsKey("shots/shot-1/lens"), isFalse);
        expect(stamps.containsKey("shots/shot-1/sortKey"), isFalse);
      },
    );

    test("snapshots the screenplay before writing the version's text over it", () async {
      final version = await createDivergedProject();

      await restore(version.id);

      final snapshots = await (database.select(
        database.ocptScreenplaySnapshotsTable,
      )..where((table) => table.reason.equalsValue(OcptSnapshotReason.restore))).get();

      // The three-way merge a screenplay is reconciled with looks for a common snapshot, and a
      // restore replaces the whole text in one write: without this row, the merge base would skip
      // the discontinuity entirely.
      expect(snapshots.single.fountainText, rewrittenText);
    });

    test(
      "brings the scenes back with their own ids, leaving no shot pointing at nothing",
      () async {
        final version = await createDivergedProject();

        // A scene the version never held, with a shot of its own hanging off it.
        await insertScene(id: "scene-later");
        await insertShot(id: "shot-later", sceneId: "scene-later");

        await restore(version.id);

        final scenes = await database.select(database.ocptScenesTable).get();
        expect(scenes.map((scene) => scene.id), containsAll(["scene-1", "scene-later"]));
        expect(scenes.firstWhere((scene) => scene.id == "scene-1").isDeleted, isFalse);
        expect(scenes.firstWhere((scene) => scene.id == "scene-later").isDeleted, isTrue);

        // Every shot the user is left with points at a scene the version carried: the ids are the
        // payload's own, never re-derived, which is what keeps the references it holds valid.
        final liveSceneIds = {
          for (final scene in scenes.where((scene) => !scene.isDeleted)) scene.id,
        };
        final liveShots = await (database.select(
          database.ocptShotsTable,
        )..where((table) => table.isDeleted.equals(false))).get();

        expect(liveShots, isNotEmpty);
        for (final shot in liveShots) {
          expect(liveSceneIds, contains(shot.sceneId));
        }
      },
    );

    test("keeps the state it replaces as a version, restorable in its turn", () async {
      final version = await createDivergedProject();

      await restore(version.id);

      final versions = await service.listVersions(database: database);
      final safety = versions.firstWhere((entry) => entry.name == "Before restoring");

      // The project descends from the version it was put back on, not from the safety copy taken
      // on the way there.
      expect(versions.singleWhere((entry) => entry.id == version.id).isBase, isTrue);
      expect(safety.isBase, isFalse);

      // Undoing the restore is restoring the safety version, and it brings the whole diverged
      // state back.
      expect((await restore(safety.id)).status, OcptProjectRestoreStatus.ok);
      expect(await readScreenplayText(), rewrittenText);
      expect((await readShot("shot-1"))?.framing, "High angle");
      expect((await readShot("shot-2"))?.isDeleted, isFalse);
      expect(await readCurrentVersionId(), safety.id);
    });

    test("a restore from a dirty working copy adds exactly one safety version", () async {
      final version = await createDivergedProject();

      await restore(version.id);

      final versions = await service.listVersions(database: database);
      expect(versions.map((entry) => entry.name), ["Before restoring", "v1 — First read"]);
    });

    test("a restore from a clean working copy adds no version", () async {
      await insertScene(id: "scene-1");
      final first = await createVersion(name: "v1");
      // Nothing changed since v1, so a second capture right after it is content-identical: this is
      // what lets the working copy stay "clean" against a base other than the one being restored.
      final second = await createVersion(name: "v2");

      final result = await restore(first.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      // The list is exactly what it was — no safety version — apart from the pointer, which now
      // names the version just restored instead of the one the working copy stood on beforehand.
      final versions = await service.listVersions(database: database);
      expect(versions.map((entry) => entry.id), unorderedEquals([first.id, second.id]));
      expect(await readCurrentVersionId(), first.id);
    });

    test("a restore whose base version has no stored digest adds one anyway", () async {
      await insertScene(id: "scene-1");
      final version = await createVersion();

      // A version written before schema v5 carries no digest: unknown reads as "modified" so a
      // restore doesn't wrongly assume it matches the untouched working copy.
      await (database.update(database.ocptProjectVersionsTable)
            ..where((table) => table.id.equals(version.id)))
          .write(const OcptProjectVersionsTableCompanion(contentDigest: Value(null)));

      await restore(version.id);

      final versions = await service.listVersions(database: database);
      expect(
        versions.map((entry) => entry.name),
        containsAll(["v1 — First read", "Before restoring"]),
      );
    });

    test("a restore that fails leaves the project exactly as it was", () async {
      await createDivergedProject();

      // A payload no project could ever hold: its shot belongs to a screenplay that doesn't exist,
      // so the transaction can only fail — at the commit, since the foreign keys are deferred.
      final payload = await readPayload((await createVersion(name: "v2 — Sound")).id);
      await database
          .into(database.ocptProjectVersionsTable)
          .insert(
            OcptProjectVersionsTableCompanion.insert(
              id: "version-inconsistent",
              name: "v3 — Broken",
              createdAt: DateTime.utc(2026, 6, 2),
              appVersion: appVersion,
              payloadFormat: OcptProjectVersionCodec.currentPayloadFormat,
              payload: codec.encode(
                OcptProjectVersionPayload(
                  screenplays: payload.screenplays,
                  scenes: payload.scenes,
                  shots: [payload.shots.first.copyWith(screenplayId: "no-such-screenplay")],
                  shotCharacters: payload.shotCharacters,
                  shotCoverages: payload.shotCoverages,
                  people: payload.people,
                  personPositions: payload.personPositions,
                  personSkills: payload.personSkills,
                  personUnavailabilities: payload.personUnavailabilities,
                  roles: payload.roles,
                  roleEpisodes: payload.roleEpisodes,
                  locations: payload.locations,
                  locationAvailabilities: payload.locationAvailabilities,
                  sets: payload.sets,
                  sceneSets: payload.sceneSets,
                  elements: payload.elements,
                  sceneElements: payload.sceneElements,
                  roleElements: payload.roleElements,
                  roleCandidates: payload.roleCandidates,
                  assets: payload.assets,
                  breakdownTags: payload.breakdownTags,
                  sceneBreakdowns: payload.sceneBreakdowns,
                  shootingDays: payload.shootingDays,
                  shootingSlots: payload.shootingSlots,
                  shootingSlotCrew: payload.shootingSlotCrew,
                  shootingSlotCast: payload.shootingSlotCast,
                  shootingDayBlocks: payload.shootingDayBlocks,
                  shootingSlotGuests: payload.shootingSlotGuests,
                  shootingDayEvents: payload.shootingDayEvents,
                  projectDictionaryWords: payload.projectDictionaryWords,
                  budgetAccounts: payload.budgetAccounts,
                  budgetLines: payload.budgetLines,
                  budgetEntries: payload.budgetEntries,
                  budgetCommitments: payload.budgetCommitments,
                  budgetResources: payload.budgetResources,
                  budgetMileageRates: payload.budgetMileageRates,
                  budgetRevenues: payload.budgetRevenues,
                  budgetShares: payload.budgetShares,
                  budgetAllowances: payload.budgetAllowances,
                  storyboardPanels: payload.storyboardPanels,
                  storyboardAnnotations: payload.storyboardAnnotations,
                  floorPlanSets: payload.floorPlanSets,
                  floorPlanSymbols: payload.floorPlanSymbols,
                  floorPlanArrows: payload.floorPlanArrows,
                  rowFieldVersions: payload.rowFieldVersions,
                  pageSetup: payload.pageSetup,
                  settingsJson: payload.settingsJson,
                  currencyCode: payload.currencyCode,
                  minimumRestMinutes: payload.minimumRestMinutes,
                  screenplayLanguage: payload.screenplayLanguage,
                  shootingBlockCandidates: const [],
                  defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
                  mealPriceCents: payload.mealPriceCents,
                  snackPriceCents: payload.snackPriceCents,
                  isBudgetSimplified: payload.isBudgetSimplified,
                ),
              ),
              summaryJson: "{}",
              createdByDeviceId: deviceId,
            ),
          );

      final versionsBefore = await service.listVersions(database: database);

      final result = await restore("version-inconsistent");

      expect(result.status, OcptProjectRestoreStatus.writeFailed);
      expect(result.value, isNull);
      expect(await readScreenplayText(), rewrittenText);
      expect((await readShot("shot-1"))?.framing, "High angle");

      // The safety version is part of the same transaction, so a failed restore doesn't even leave
      // that behind.
      expect(
        (await service.listVersions(database: database)).map((entry) => entry.id),
        versionsBefore.map((entry) => entry.id),
      );
    });

    test("refuses a version the project doesn't have, and one from a later build", () async {
      await createDivergedProject();

      expect((await restore("no-such-version")).status, OcptProjectRestoreStatus.versionNotFound);

      await database
          .into(database.ocptProjectVersionsTable)
          .insert(
            OcptProjectVersionsTableCompanion.insert(
              id: "version-from-the-future",
              name: "v9 — Written by a later build",
              createdAt: DateTime.utc(2026, 6, 2),
              appVersion: "99.0.0",
              payloadFormat: OcptProjectVersionCodec.currentPayloadFormat + 1,
              payload: '{"payloadFormat":${OcptProjectVersionCodec.currentPayloadFormat + 1}}',
              summaryJson: "{}",
              createdByDeviceId: deviceId,
            ),
          );

      expect(
        (await restore("version-from-the-future")).status,
        OcptProjectRestoreStatus.unsupportedFutureFormat,
      );
      expect(await readScreenplayText(), rewrittenText);
    });

    test("inserts, updates and tombstones resources rows, like any other table", () async {
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: "person-1", firstName: const Value("Clara")));

      final version = await createVersion();

      // Diverge: the captured person is edited, and a second one is added since.
      await (database.update(database.ocptPeopleTable)
            ..where((table) => table.id.equals("person-1")))
          .write(const OcptPeopleTableCompanion(firstName: Value("Edited")));
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: "person-2", firstName: const Value("Later")));

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      final restoredPerson1 = await (database.select(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals("person-1"))).getSingle();
      expect(restoredPerson1.firstName, "Clara");

      // The person the version never held is tombstoned, not deleted, exactly like a shot.
      final restoredPerson2 = await (database.select(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals("person-2"))).getSingle();
      expect(restoredPerson2.isDeleted, isTrue);
    });

    test("the cash journal comes back, and a movement recorded since is tombstoned", () async {
      await database
          .into(database.ocptBudgetAccountsTable)
          .insert(OcptBudgetAccountsTableCompanion.insert(id: "poste-1", label: "Personnel"));
      await database
          .into(database.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(
              id: "entry-1",
              date: DateTime.utc(2026, 3, 12),
              label: "Gaffer tape",
              accountId: const Value("poste-1"),
              debitCents: const Value(1250),
              voucherNumber: const Value("J-001"),
            ),
          );
      await database
          .into(database.ocptBudgetCommitmentsTable)
          .insert(
            OcptBudgetCommitmentsTableCompanion.insert(
              id: "commitment-1",
              accountId: "poste-1",
              label: "Camera deposit",
              amountCents: const Value(45000),
            ),
          );

      final version = await createVersion();

      // Diverge: the captured entry is edited, and a second one is recorded since.
      await (database.update(database.ocptBudgetEntriesTable)
            ..where((table) => table.id.equals("entry-1")))
          .write(const OcptBudgetEntriesTableCompanion(debitCents: Value(9999)));
      await database
          .into(database.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(
              id: "entry-2",
              date: DateTime.utc(2026, 4),
              label: "Recorded later",
              voucherNumber: const Value("J-002"),
            ),
          );
      await (database.update(database.ocptBudgetCommitmentsTable)
            ..where((table) => table.id.equals("commitment-1")))
          .write(const OcptBudgetCommitmentsTableCompanion(amountCents: Value(1)));

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      // The amount comes back exactly as it was typed, to the cent.
      final restoredEntry = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals("entry-1"))).getSingle();
      expect(restoredEntry.debitCents, 1250);
      expect(restoredEntry.voucherNumber, "J-001");

      final restoredCommitment = await (database.select(
        database.ocptBudgetCommitmentsTable,
      )..where((table) => table.id.equals("commitment-1"))).getSingle();
      expect(restoredCommitment.amountCents, 45000);

      // The movement the version never held is tombstoned, not deleted.
      final laterEntry = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals("entry-2"))).getSingle();
      expect(laterEntry.isDeleted, isTrue);
    });

    test("a financing resource, a mileage rate and a person's commute come back too", () async {
      await database
          .into(database.ocptBudgetMileageRatesTable)
          .insert(
            OcptBudgetMileageRatesTableCompanion.insert(
              id: "rate-1",
              label: "Voiture personnelle",
              ratePerKmMilliCents: const Value(52900),
            ),
          );
      await database
          .into(database.ocptBudgetResourcesTable)
          .insert(
            OcptBudgetResourcesTableCompanion.insert(
              id: "resource-1",
              label: "Région Île-de-France",
              amountCents: const Value(500000),
            ),
          );
      await database
          .into(database.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(
              id: "entry-3",
              date: DateTime.utc(2026, 5, 4),
              label: "Acompte région",
              creditCents: const Value(200000),
              voucherNumber: const Value("J-003"),
              resourceId: const Value("resource-1"),
            ),
          );
      await database
          .into(database.ocptPeopleTable)
          .insert(
            OcptPeopleTableCompanion.insert(
              id: "person-3",
              firstName: const Value("Théo"),
              commuteKmMilli: const Value(1484000),
              mileageRateId: const Value("rate-1"),
            ),
          );

      final version = await createVersion();

      // Diverge: everything just captured is edited, and a fresh resource is recorded since.
      await (database.update(database.ocptBudgetMileageRatesTable)
            ..where((table) => table.id.equals("rate-1")))
          .write(const OcptBudgetMileageRatesTableCompanion(ratePerKmMilliCents: Value(1)));
      await (database.update(database.ocptBudgetResourcesTable)
            ..where((table) => table.id.equals("resource-1")))
          .write(const OcptBudgetResourcesTableCompanion(amountCents: Value(1)));
      await (database.update(database.ocptBudgetEntriesTable)
            ..where((table) => table.id.equals("entry-3")))
          .write(const OcptBudgetEntriesTableCompanion(resourceId: Value(null)));
      await (database.update(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals("person-3"))).write(
        const OcptPeopleTableCompanion(commuteKmMilli: Value(1), mileageRateId: Value(null)),
      );
      await database
          .into(database.ocptBudgetResourcesTable)
          .insert(
            OcptBudgetResourcesTableCompanion.insert(id: "resource-2", label: "Recorded later"),
          );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      final restoredRate = await database.select(database.ocptBudgetMileageRatesTable).getSingle();
      expect(restoredRate.ratePerKmMilliCents, 52900);

      final restoredResource = await (database.select(
        database.ocptBudgetResourcesTable,
      )..where((table) => table.id.equals("resource-1"))).getSingle();
      expect(restoredResource.amountCents, 500000);

      final restoredEntry = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals("entry-3"))).getSingle();
      expect(restoredEntry.resourceId, "resource-1");

      final restoredPerson = await (database.select(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals("person-3"))).getSingle();
      expect(restoredPerson.commuteKmMilli, 1484000);
      expect(restoredPerson.mileageRateId, "rate-1");

      // The resource the version never held is tombstoned, not deleted.
      final laterResource = await (database.select(
        database.ocptBudgetResourcesTable,
      )..where((table) => table.id.equals("resource-2"))).getSingle();
      expect(laterResource.isDeleted, isTrue);
    });

    test("the sharing comes back, and a taking recorded since is tombstoned", () async {
      await database
          .into(database.ocptBudgetRevenuesTable)
          .insert(
            OcptBudgetRevenuesTableCompanion.insert(
              id: "revenue-1",
              date: DateTime.utc(2026, 2, 2),
              label: "Clermont-Ferrand — audience award",
              amountCents: const Value(300000),
            ),
          );
      await database
          .into(database.ocptBudgetSharesTable)
          .insert(
            OcptBudgetSharesTableCompanion.insert(
              id: "share-1",
              label: "Director",
              sharePermille: const Value(400),
              reinvestPermille: const Value(1000),
            ),
          );
      await database
          .into(database.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(
              id: "entry-1",
              date: DateTime.utc(2026, 2, 20),
              label: "Award paid in",
              creditCents: const Value(300000),
              voucherNumber: const Value("J-001"),
              revenueId: const Value("revenue-1"),
            ),
          );

      final version = await createVersion();

      // Diverge: the captured taking is edited, its share is renamed, and a second taking is
      // recorded since.
      await (database.update(database.ocptBudgetRevenuesTable)
            ..where((table) => table.id.equals("revenue-1")))
          .write(const OcptBudgetRevenuesTableCompanion(amountCents: Value(1)));
      await (database.update(database.ocptBudgetSharesTable)
            ..where((table) => table.id.equals("share-1")))
          .write(const OcptBudgetSharesTableCompanion(sharePermille: Value(999)));
      await database
          .into(database.ocptBudgetRevenuesTable)
          .insert(
            OcptBudgetRevenuesTableCompanion.insert(
              id: "revenue-2",
              date: DateTime.utc(2026, 5, 30),
              label: "Recorded later",
            ),
          );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      // The amount comes back exactly as it was typed, to the cent.
      final restoredRevenue = await (database.select(
        database.ocptBudgetRevenuesTable,
      )..where((table) => table.id.equals("revenue-1"))).getSingle();
      expect(restoredRevenue.amountCents, 300000);

      final restoredShare = await (database.select(
        database.ocptBudgetSharesTable,
      )..where((table) => table.id.equals("share-1"))).getSingle();
      expect(restoredShare.sharePermille, 400);
      expect(restoredShare.reinvestPermille, 1000);

      // The link an entry carries onto a taking survives the round trip: without it the sharing
      // would read the takings as never having brought anything in.
      final restoredEntry = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals("entry-1"))).getSingle();
      expect(restoredEntry.revenueId, "revenue-1");

      // The taking the version never held is tombstoned, not deleted.
      final laterRevenue = await (database.select(
        database.ocptBudgetRevenuesTable,
      )..where((table) => table.id.equals("revenue-2"))).getSingle();
      expect(laterRevenue.isDeleted, isTrue);
    });

    test("a role's things come back, and a link made since is tombstoned", () async {
      await database
          .into(database.ocptRolesTable)
          .insert(
            OcptRolesTableCompanion.insert(
              id: "role-1",
              name: "CLARA",
              kind: OcptRoleKind.speaking,
            ),
          );
      await database
          .into(database.ocptElementsTable)
          .insert(
            OcptElementsTableCompanion.insert(
              id: "element-1",
              name: "Manteau rouge",
              category: OcptElementCategory.costume,
              sourceKind: OcptElementSourceKind.owned,
            ),
          );
      await database
          .into(database.ocptRoleElementsTable)
          .insert(
            OcptRoleElementsTableCompanion.insert(
              id: "link-1",
              roleId: "role-1",
              elementId: "element-1",
              notes: const Value("Taché"),
            ),
          );

      final version = await createVersion();

      // Diverge: the captured link's note is edited, and a second link is made since.
      await (database.update(database.ocptRoleElementsTable)
            ..where((table) => table.id.equals("link-1")))
          .write(const OcptRoleElementsTableCompanion(notes: Value("Edited")));
      await database
          .into(database.ocptRoleElementsTable)
          .insert(
            OcptRoleElementsTableCompanion.insert(
              id: "link-2",
              roleId: "role-1",
              elementId: "element-1",
            ),
          );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      final restored = await (database.select(
        database.ocptRoleElementsTable,
      )..where((table) => table.id.equals("link-1"))).getSingle();
      expect(restored.notes, "Taché");
      expect(restored.isDeleted, isFalse);

      // The link the version never held is tombstoned, not deleted, like every other row.
      final later = await (database.select(
        database.ocptRoleElementsTable,
      )..where((table) => table.id.equals("link-2"))).getSingle();
      expect(later.isDeleted, isTrue);
    });
  });
}
