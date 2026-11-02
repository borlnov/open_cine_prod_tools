// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
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
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import '../../../ocpt_result_expectations.dart';

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

  final peopleService = OcptPeopleService(
    logger: const SilentLogger(),
    deviceId: testDeviceId,
    assetsService: assetsService,
    roleCandidatesService: roleCandidatesService,
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

  /// Inserts the shooting day [id], belonging to no episode, tombstoned when [isDeleted].
  Future<void> insertShootingDay({
    required String id,
    DateTime? date,
    String sortKey = "V",
    bool isDeleted = false,
  }) => database
      .into(database.ocptShootingDaysTable)
      .insert(
        OcptShootingDaysTableCompanion.insert(
          id: id,
          date: date ?? DateTime.utc(2026, 3, 10),
          sortKey: Value(sortKey),
          isDeleted: Value(isDeleted),
        ),
      );

  /// Inserts the shooting slot [id] of shooting day [shootingDayId], tombstoned when [isDeleted].
  Future<void> insertShootingSlot({
    required String id,
    required String shootingDayId,
    String sortKey = "V",
    int anchorMinute = 420,
    bool isDeleted = false,
  }) => database
      .into(database.ocptShootingSlotsTable)
      .insert(
        OcptShootingSlotsTableCompanion.insert(
          id: id,
          shootingDayId: shootingDayId,
          sortKey: Value(sortKey),
          anchorMinute: Value(anchorMinute),
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

  group("restoreVersion", () {
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

    test("a role's candidates come back, and one seen since is tombstoned", () async {
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
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: "person-1", firstName: const Value("Clara")));
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: "person-2", firstName: const Value("Sam")));
      await database
          .into(database.ocptRoleCandidatesTable)
          .insert(
            OcptRoleCandidatesTableCompanion.insert(
              id: "candidate-1",
              roleId: "role-1",
              personId: "person-1",
              notes: const Value("Very sure of the last scene"),
            ),
          );

      final version = await createVersion();

      // Diverge: the captured candidacy's note is edited, and somebody else is seen since.
      await (database.update(database.ocptRoleCandidatesTable)
            ..where((table) => table.id.equals("candidate-1")))
          .write(const OcptRoleCandidatesTableCompanion(notes: Value("Edited")));
      await database
          .into(database.ocptRoleCandidatesTable)
          .insert(
            OcptRoleCandidatesTableCompanion.insert(
              id: "candidate-2",
              roleId: "role-1",
              personId: "person-2",
            ),
          );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      final restored = await (database.select(
        database.ocptRoleCandidatesTable,
      )..where((table) => table.id.equals("candidate-1"))).getSingle();
      expect(restored.notes, "Very sure of the last scene");
      expect(restored.isDeleted, isFalse);

      // The candidate the version never held is tombstoned, not deleted, like every other row —
      // and the `people` row they are is untouched: a person outlives a candidacy.
      final later = await (database.select(
        database.ocptRoleCandidatesTable,
      )..where((table) => table.id.equals("candidate-2"))).getSingle();
      expect(later.isDeleted, isTrue);
      final person2 = await (database.select(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals("person-2"))).getSingle();
      expect(person2.isDeleted, isFalse);
    });

    test(
      "a role's episode links come back, and one made since is tombstoned like any other row",
      () async {
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
            .into(database.ocptRoleEpisodesTable)
            .insert(
              OcptRoleEpisodesTableCompanion.insert(
                id: "link-1",
                roleId: "role-1",
                screenplayId: screenplayId,
              ),
            );

        final version = await createVersion();

        // Diverge: a second episode link is made since — as if the character had started
        // speaking in a second episode of the same production.
        await database
            .into(database.ocptScreenplaysTable)
            .insert(
              OcptScreenplaysTableCompanion.insert(
                id: "screenplay-2",
                title: "Episode 2",
                fountainText: const Value(""),
                updatedAt: DateTime.utc(2026, 1, 6),
              ),
            );
        await database
            .into(database.ocptRoleEpisodesTable)
            .insert(
              OcptRoleEpisodesTableCompanion.insert(
                id: "link-2",
                roleId: "role-1",
                screenplayId: "screenplay-2",
              ),
            );

        final result = await restore(version.id);

        expect(result.status, OcptProjectRestoreStatus.ok);

        final restored = await (database.select(
          database.ocptRoleEpisodesTable,
        )..where((table) => table.id.equals("link-1"))).getSingle();
        expect(restored.roleId, "role-1");
        expect(restored.screenplayId, screenplayId);
        expect(restored.isDeleted, isFalse);

        // The link the version never held is tombstoned, not deleted, exactly like every other
        // row a payload doesn't carry.
        final later = await (database.select(
          database.ocptRoleEpisodesTable,
        )..where((table) => table.id.equals("link-2"))).getSingle();
        expect(later.isDeleted, isTrue);
      },
    );

    test("tombstones a word learned since the capture, and revives one removed since", () async {
      await database
          .into(database.ocptProjectDictionaryWordsTable)
          .insert(OcptProjectDictionaryWordsTableCompanion.insert(id: "word-1", word: "Clara"));

      final version = await createVersion();

      // Diverge: the word is un-learned since — as if the writer had removed it after the
      // capture — and a fresh one is learned.
      await (database.update(database.ocptProjectDictionaryWordsTable)
            ..where((table) => table.id.equals("word-1")))
          .write(const OcptProjectDictionaryWordsTableCompanion(isDeleted: Value(true)));
      await database
          .into(database.ocptProjectDictionaryWordsTable)
          .insert(OcptProjectDictionaryWordsTableCompanion.insert(id: "word-2", word: "Julien"));

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      // "word-1" was live in the captured version: restoring revives it.
      final revived = await (database.select(
        database.ocptProjectDictionaryWordsTable,
      )..where((table) => table.id.equals("word-1"))).getSingle();
      expect(revived.word, "Clara");
      expect(revived.isDeleted, isFalse);

      // "word-2" was learned after the capture: the version never held it, so it is
      // tombstoned, not deleted, exactly like every other row a payload doesn't carry.
      final tombstoned = await (database.select(
        database.ocptProjectDictionaryWordsTable,
      )..where((table) => table.id.equals("word-2"))).getSingle();
      expect(tombstoned.isDeleted, isTrue);
    });

    test("stamps a resources column it changed, above what it already held", () async {
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: "person-1", firstName: const Value("Clara")));
      final version = await createVersion();

      await (database.update(database.ocptPeopleTable)
            ..where((table) => table.id.equals("person-1")))
          .write(const OcptPeopleTableCompanion(firstName: Value("Edited")));

      // As if the edit had already been stamped by the changeset engine.
      await database
          .into(database.ocptRowFieldVersionsTable)
          .insert(
            OcptRowFieldVersionsTableCompanion.insert(
              targetTableName: "people",
              rowId: "person-1",
              columnName: "firstName",
              version: 4,
              deviceId: "device-0",
            ),
          );

      await restore(version.id);

      final stamps = await readStamps();
      expect(stamps["people/person-1/firstName"]?.version, 5);
      expect(stamps["people/person-1/firstName"]?.deviceId, deviceId);
    });

    test("restores a captured schedule exactly, tombstones and sort keys included", () async {
      await insertShootingDay(id: "day-1", date: DateTime.utc(2026, 3, 10));
      await insertShootingSlot(id: "slot-1", shootingDayId: "day-1");
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: "person-1", firstName: const Value("Clara")));
      await database
          .into(database.ocptShootingSlotCrewTable)
          .insert(
            OcptShootingSlotCrewTableCompanion.insert(
              id: "crew-1",
              slotId: "slot-1",
              personId: "person-1",
            ),
          );

      final version = await createVersion(name: "v1 — Day planned");

      // Diverge: the slot's anchored hour is edited, its position renamed by the shooting day it
      // belongs to, a second day is added, and the crew row is tombstoned.
      await (database.update(database.ocptShootingSlotsTable)
            ..where((table) => table.id.equals("slot-1")))
          .write(const OcptShootingSlotsTableCompanion(anchorMinute: Value(360)));
      await insertShootingDay(id: "day-2", date: DateTime.utc(2026, 3, 11), sortKey: "k");
      await scheduleService
          .removeSlotCrewMember(database: database, crewMemberId: "crew-1")
          .okOrFail;

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      final restoredSlot = await (database.select(
        database.ocptShootingSlotsTable,
      )..where((table) => table.id.equals("slot-1"))).getSingle();
      expect(restoredSlot.anchorMinute, 420);
      expect(restoredSlot.sortKey, "V");

      final restoredDay = await (database.select(
        database.ocptShootingDaysTable,
      )..where((table) => table.id.equals("day-1"))).getSingle();
      expect(restoredDay.isDeleted, isFalse);
      expect(restoredDay.sortKey, "V");

      // The day the version never held is tombstoned, not deleted, exactly like a shot.
      final droppedDay = await (database.select(
        database.ocptShootingDaysTable,
      )..where((table) => table.id.equals("day-2"))).getSingle();
      expect(droppedDay.isDeleted, isTrue);

      // The crew row is restored live again.
      final restoredCrew = await (database.select(
        database.ocptShootingSlotCrewTable,
      )..where((table) => table.id.equals("crew-1"))).getSingle();
      expect(restoredCrew.isDeleted, isFalse);
      expect(restoredCrew.personId, "person-1");
    });

    test("a guest and an event survive a capture and a restore, tombstones included", () async {
      await insertShootingDay(id: "day-1", date: DateTime.utc(2026, 3, 10));
      await insertShootingSlot(id: "slot-1", shootingDayId: "day-1");
      final guestId = await scheduleService
          .addSlotGuest(
            database: database,
            slotId: "slot-1",
            freeName: "Le maire",
            reason: "Prête la place",
          )
          .maybeValueOrFail;
      final eventId = await scheduleService
          .createDayEvent(
            database: database,
            dayId: "day-1",
            minute: 1020,
            label: "Feu d'artifice du village",
          )
          .maybeValueOrFail;

      final version = await createVersion(name: "v1 — Guest and event planned");

      // Diverge: the guest and the event are both removed in the working copy, and a second
      // guest is added on a new slot.
      await scheduleService.deleteSlotGuest(database: database, guestId: guestId!).okOrFail;
      await scheduleService.deleteDayEvent(database: database, eventId: eventId!).okOrFail;
      final secondSlotId = await scheduleService
          .createSlot(database: database, shootingDayId: "day-1", anchorMinute: 600)
          .maybeValueOrFail;
      await scheduleService
          .addSlotGuest(database: database, slotId: secondSlotId!, freeName: "Une journaliste")
          .maybeValueOrFail;

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      // The guest and the event the version held are revived — live again.
      final restoredGuest = await (database.select(
        database.ocptShootingSlotGuestsTable,
      )..where((table) => table.id.equals(guestId))).getSingle();
      expect(restoredGuest.isDeleted, isFalse);
      expect(restoredGuest.freeName, "Le maire");
      expect(restoredGuest.reason, "Prête la place");

      final restoredEvent = await (database.select(
        database.ocptShootingDayEventsTable,
      )..where((table) => table.id.equals(eventId))).getSingle();
      expect(restoredEvent.isDeleted, isFalse);
      expect(restoredEvent.minute, 1020);
      expect(restoredEvent.label, "Feu d'artifice du village");

      // The guest the version never held is tombstoned, not deleted, exactly like a shot.
      final droppedGuests = await database.select(database.ocptShootingSlotGuestsTable).get();
      expect(
        droppedGuests.where((row) => row.freeName == "Une journaliste").single.isDeleted,
        isTrue,
      );

      // And the schedule mode reads the guest and the event back exactly the way they were
      // written.
      final restoredSnapshot = await scheduleService.loadSchedule(database: database).valueOrFail;
      expect(restoredSnapshot.slotsByDayId["day-1"]!.first.guests.single.freeName, "Le maire");
      expect(restoredSnapshot.eventsByDayId["day-1"]!.single.label, "Feu d'artifice du village");
    });

    test("stamps a schedule column it changed, above what it already held", () async {
      await insertShootingDay(id: "day-1");
      await insertShootingSlot(id: "slot-1", shootingDayId: "day-1");
      final version = await createVersion();

      await (database.update(database.ocptShootingSlotsTable)
            ..where((table) => table.id.equals("slot-1")))
          .write(const OcptShootingSlotsTableCompanion(anchorMinute: Value(360)));

      // As if the edit had already been stamped by the changeset engine.
      await database
          .into(database.ocptRowFieldVersionsTable)
          .insert(
            OcptRowFieldVersionsTableCompanion.insert(
              targetTableName: "shooting_slots",
              rowId: "slot-1",
              columnName: "anchorMinute",
              version: 4,
              deviceId: "device-0",
            ),
          );

      await restore(version.id);

      final stamps = await readStamps();
      expect(stamps["shooting_slots/slot-1/anchorMinute"]?.version, 5);
      expect(stamps["shooting_slots/slot-1/anchorMinute"]?.deviceId, deviceId);
    });

    test("restores the currency the version was captured with", () async {
      final version = await createVersion();

      await database
          .update(database.ocptProjectInfoTable)
          .write(const OcptProjectInfoTableCompanion(currencyCode: Value("USD")));

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);
      final info = await database.select(database.ocptProjectInfoTable).getSingle();
      expect(info.currencyCode, "EUR");
    });

    test(
      "restoring a payload with no currency leaves the project's own currency untouched",
      () async {
        // A live capture always states a real `currencyCode` ("restores the currency the version
        // was captured with" above): a null one is reachable only by hand-editing the stored
        // payload, which is exactly what this does — everything else about the capture stays
        // genuine.
        final version = await createVersion();
        final storedRow = await (database.select(
          database.ocptProjectVersionsTable,
        )..where((table) => table.id.equals(version.id))).getSingle();
        final withNoCurrency = jsonDecode(storedRow.payload) as Map<String, dynamic>;
        (withNoCurrency["projectSettings"] as Map<String, dynamic>)["currencyCode"] = null;
        await (database.update(database.ocptProjectVersionsTable)
              ..where((table) => table.id.equals(version.id)))
            .write(OcptProjectVersionsTableCompanion(payload: Value(jsonEncode(withNoCurrency))));

        await database
            .update(database.ocptProjectInfoTable)
            .write(const OcptProjectInfoTableCompanion(currencyCode: Value("GBP")));

        final result = await restore(version.id);

        expect(result.status, OcptProjectRestoreStatus.ok);
        final info = await database.select(database.ocptProjectInfoTable).getSingle();
        expect(info.currencyCode, "GBP");
      },
    );

    test("restores the minimum rest the version was captured with", () async {
      await database
          .update(database.ocptProjectInfoTable)
          .write(const OcptProjectInfoTableCompanion(minimumRestMinutes: Value(660)));
      final version = await createVersion();

      await database
          .update(database.ocptProjectInfoTable)
          .write(const OcptProjectInfoTableCompanion(minimumRestMinutes: Value(720)));

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);
      final info = await database.select(database.ocptProjectInfoTable).getSingle();
      expect(info.minimumRestMinutes, 660);
    });

    test(
      "restoring a payload with no minimum rest clears one recorded since — unlike the currency",
      () async {
        // Unlike currencyCode, which is never null on a live capture, minimumRestMinutes is null
        // right here because nobody has recorded one yet — a truthful value of its own, not a
        // format predating the column.
        final version = await createVersion();

        await database
            .update(database.ocptProjectInfoTable)
            .write(const OcptProjectInfoTableCompanion(minimumRestMinutes: Value(600)));

        final result = await restore(version.id);

        expect(result.status, OcptProjectRestoreStatus.ok);
        final info = await database.select(database.ocptProjectInfoTable).getSingle();
        expect(info.minimumRestMinutes, isNull);
      },
    );

    test("restores the screenplay language the version was captured with", () async {
      await database
          .update(database.ocptProjectInfoTable)
          .write(
            const OcptProjectInfoTableCompanion(
              screenplayLanguage: Value(OcptScreenplayLanguage.fr),
            ),
          );
      final version = await createVersion();

      await database
          .update(database.ocptProjectInfoTable)
          .write(
            const OcptProjectInfoTableCompanion(
              screenplayLanguage: Value(OcptScreenplayLanguage.enGb),
            ),
          );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);
      final info = await database.select(database.ocptProjectInfoTable).getSingle();
      expect(info.screenplayLanguage, OcptScreenplayLanguage.fr);
    });

    test("restoring a payload with no screenplay language clears one recorded since — unlike the "
        "currency", () async {
      // Unlike currencyCode, which is never null on a live capture, screenplayLanguage is null
      // right here because nobody has recorded one yet — a truthful value of its own, exactly
      // the reading minimumRestMinutes' own null carries.
      final version = await createVersion();

      await database
          .update(database.ocptProjectInfoTable)
          .write(
            const OcptProjectInfoTableCompanion(
              screenplayLanguage: Value(OcptScreenplayLanguage.enGb),
            ),
          );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);
      final info = await database.select(database.ocptProjectInfoTable).getSingle();
      expect(info.screenplayLanguage, isNull);
    });

    test(
      "restoring a version captured before an erasure does not resurrect the erased person",
      () async {
        await database
            .into(database.ocptPeopleTable)
            .insert(
              OcptPeopleTableCompanion.insert(
                id: "person-1",
                firstName: const Value("Clara"),
                lastName: const Value("Martin"),
                email: const Value("clara@example.com"),
                phone: const Value("0102030405"),
                maxDailyPresenceMinutes: const Value(480),
              ),
            );
        await database
            .into(database.ocptPersonSkillsTable)
            .insert(
              OcptPersonSkillsTableCompanion.insert(
                id: "skill-1",
                personId: "person-1",
                label: const Value("Permis B"),
              ),
            );
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
            .into(database.ocptRoleCandidatesTable)
            .insert(
              OcptRoleCandidatesTableCompanion.insert(
                id: "candidate-1",
                roleId: "role-1",
                personId: "person-1",
                notes: const Value("Fragile, exactly right for the part"),
              ),
            );

        final version = await createVersion();

        // The erasure itself is other work (OcptPeopleService.deletePerson); this only checks that
        // a restore of a version captured before it can't undo it.
        await peopleService.deletePerson(database: database, personId: "person-1");

        final result = await restore(version.id);

        expect(result.status, OcptProjectRestoreStatus.ok);

        final person = await (database.select(
          database.ocptPeopleTable,
        )..where((table) => table.id.equals("person-1"))).getSingle();
        expect(person.isDeleted, isTrue);
        expect(person.firstName, isEmpty);
        expect(person.lastName, isEmpty);
        expect(person.email, isEmpty);
        expect(person.phone, isEmpty);
        expect(person.maxDailyPresenceMinutes, isNull);

        final skill = await (database.select(
          database.ocptPersonSkillsTable,
        )..where((table) => table.id.equals("skill-1"))).getSingle();
        expect(skill.isDeleted, isTrue);
        expect(skill.label, isEmpty);

        // A candidacy is the one link table holding something about a person: what was written
        // about them at an audition is scrubbed out of the payload on its way back too.
        final candidate = await (database.select(
          database.ocptRoleCandidatesTable,
        )..where((table) => table.id.equals("candidate-1"))).getSingle();
        expect(candidate.isDeleted, isTrue);
        expect(candidate.notes, isEmpty);

        // The erasure itself is never rewound: it is recorded outside any payload, on purpose.
        final erasures = await database.select(database.ocptLocalErasuresTable).get();
        expect(erasures.map((row) => row.personId), contains("person-1"));
      },
    );

    test("restoring a version does not put back an erased person's referenced files", () async {
      await database
          .into(database.ocptPeopleTable)
          .insert(
            OcptPeopleTableCompanion.insert(
              id: "person-1",
              firstName: const Value("Clara"),
              lastName: const Value("Martin"),
            ),
          );
      final photoId = (await peopleService.setPersonPhoto(
        database: database,
        personId: "person-1",
        path: "/photos/clara-martin.jpg",
      ))!;

      final version = await createVersion();

      await peopleService.deletePerson(database: database, personId: "person-1");

      final result = await restore(version.id);
      expect(result.status, OcptProjectRestoreStatus.ok);

      // An asset's path is personal data in its own right — it names the person and says where a
      // photograph of them sits — so the payload's copy is scrubbed exactly as the person's own
      // row is, or a restore would write the leak straight back.
      final asset = await (database.select(
        database.ocptAssetsTable,
      )..where((table) => table.id.equals(photoId))).getSingle();
      expect(asset.isDeleted, isTrue);
      expect(asset.path, isEmpty);
    });

    test("restoring keeps a location's own referenced files, which are nobody's data", () async {
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: "person-1"));
      await database
          .into(database.ocptLocationsTable)
          .insert(OcptLocationsTableCompanion.insert(id: "location-1", name: "Le hangar"));
      final photoId = (await locationsService.addLocationPhoto(
        database: database,
        locationId: "location-1",
        path: "/photos/repérage.jpg",
      ))!;

      final version = await createVersion();
      await peopleService.deletePerson(database: database, personId: "person-1");

      final result = await restore(version.id);
      expect(result.status, OcptProjectRestoreStatus.ok);

      final asset = await (database.select(
        database.ocptAssetsTable,
      )..where((table) => table.id.equals(photoId))).getSingle();
      expect(asset.isDeleted, isFalse);
      expect(asset.path, "/photos/repérage.jpg");
    });

    test("previewing a version captured before an erasure shows nothing of the person", () async {
      await database
          .into(database.ocptPeopleTable)
          .insert(
            OcptPeopleTableCompanion.insert(
              id: "person-1",
              firstName: const Value("Clara"),
              lastName: const Value("Martin"),
              email: const Value("clara@example.com"),
              phone: const Value("0102030405"),
              allergies: const Value("Arachides"),
            ),
          );
      await database
          .into(database.ocptPersonSkillsTable)
          .insert(
            OcptPersonSkillsTableCompanion.insert(
              id: "skill-1",
              personId: "person-1",
              label: const Value("Permis B"),
            ),
          );

      final version = await createVersion();
      await peopleService.deletePerson(database: database, personId: "person-1");

      // A preview reads the very same payload a restore does, and hydrates it into the database
      // every mode draws its sheets from: scrubbing only the restore would put an erased person's
      // contact details and allergies back on screen, one click away, for as long as the version
      // lives.
      final payload = (await service.loadPayload(database: database, id: version.id)).value!;

      final previewDatabase = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(previewDatabase.close);
      await service.hydratePreview(
        database: previewDatabase,
        projectInfo: await database.select(database.ocptProjectInfoTable).getSingle(),
        payload: payload,
      );

      final person = await (previewDatabase.select(
        previewDatabase.ocptPeopleTable,
      )..where((table) => table.id.equals("person-1"))).getSingle();
      expect(person.isDeleted, isTrue);
      expect(person.firstName, isEmpty);
      expect(person.lastName, isEmpty);
      expect(person.email, isEmpty);
      expect(person.phone, isEmpty);
      expect(person.allergies, isEmpty);

      final skill = await (previewDatabase.select(
        previewDatabase.ocptPersonSkillsTable,
      )..where((table) => table.id.equals("skill-1"))).getSingle();
      expect(skill.isDeleted, isTrue);
      expect(skill.label, isEmpty);
    });
  });
}
