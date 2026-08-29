// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final assetsService = OcptAssetsService(deviceId: testDeviceId);
  final peopleService = OcptPeopleService(
    deviceId: testDeviceId,
    assetsService: assetsService,
    roleCandidatesService: OcptRoleCandidatesService(deviceId: testDeviceId),
  );

  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every live person row, in `sortKey` order.
  Future<List<OcptPersonRow>> readPeople() =>
      (database.select(database.ocptPeopleTable)
            ..where((row) => row.isDeleted.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// The person row [id], tombstoned or not.
  Future<OcptPersonRow> readPerson(String id) =>
      (database.select(database.ocptPeopleTable)..where((row) => row.id.equals(id))).getSingle();

  /// The asset row [id], tombstoned or not.
  Future<OcptAssetRow> readAsset(String id) =>
      (database.select(database.ocptAssetsTable)..where((row) => row.id.equals(id))).getSingle();

  /// Whether the asset row [id] has been tombstoned.
  Future<bool> readAssetIsDeleted(String id) async => (await readAsset(id)).isDeleted;

  /// Every version stamp the project currently holds, keyed by `<table>/<row>/<column>` — the same
  /// shape `OcptShotListService`'s own stamping tests read `row_field_versions` back through.
  Future<Map<String, OcptRowFieldVersionRow>> readStamps() async => {
    for (final stamp in await database.select(database.ocptRowFieldVersionsTable).get())
      "${stamp.targetTableName}/${stamp.rowId}/${stamp.columnName}": stamp,
  };

  group("people CRUD and ordering", () {
    test("createPerson appends at the end and loadPeople reads it back", () async {
      final firstId = (await peopleService.createPerson(database: database))!;
      final secondId = (await peopleService.createPerson(database: database))!;

      final people = await peopleService.loadPeople(database: database);
      expect(people.map((person) => person.id), [firstId, secondId]);
    });

    test("createPerson in the middle keeps sortKey ordering", () async {
      final firstId = (await peopleService.createPerson(database: database))!;
      final secondId = (await peopleService.createPerson(database: database))!;

      await peopleService.reorderPerson(database: database, personId: secondId, newPosition: 0);
      final thirdId = (await peopleService.createPerson(database: database))!;
      await peopleService.reorderPerson(database: database, personId: thirdId, newPosition: 1);

      final rows = await readPeople();
      expect(rows.map((row) => row.id), [secondId, thirdId, firstId]);
    });

    test("updatePerson only touches the fields it's given a Value for", () async {
      final id = (await peopleService.createPerson(database: database))!;

      await peopleService.updatePerson(
        database: database,
        personId: id,
        firstName: const Value("Clara"),
        lastName: const Value("Martin"),
        email: const Value("clara@example.com"),
      );

      final row = await readPerson(id);
      expect(row.firstName, "Clara");
      expect(row.lastName, "Martin");
      expect(row.email, "clara@example.com");
      expect(row.phone, ""); // untouched, still its column default
    });

    test("reorderPerson moves a person by writing exactly one row", () async {
      final firstId = (await peopleService.createPerson(database: database))!;
      final secondId = (await peopleService.createPerson(database: database))!;
      final thirdId = (await peopleService.createPerson(database: database))!;

      final keysBefore = {for (final row in await readPeople()) row.id: row.sortKey};
      await peopleService.reorderPerson(database: database, personId: firstId, newPosition: 2);
      final keysAfter = {for (final row in await readPeople()) row.id: row.sortKey};

      expect((await readPeople()).map((row) => row.id), [secondId, thirdId, firstId]);
      expect(keysAfter.keys.where((id) => keysAfter[id] != keysBefore[id]), [firstId]);
    });

    test("a delete writes a tombstone and the row disappears from every read", () async {
      final firstId = (await peopleService.createPerson(database: database))!;
      final secondId = (await peopleService.createPerson(database: database))!;

      await peopleService.deletePerson(database: database, personId: firstId);

      final people = await peopleService.loadPeople(database: database);
      expect(people.map((person) => person.id), [secondId]);

      final tombstoned = await readPerson(firstId);
      expect(tombstoned.isDeleted, isTrue);
    });
  });

  group("erasure", () {
    test("deletePerson blanks every personal column and keeps id/sortKey/colorIndex", () async {
      final id = (await peopleService.createPerson(database: database))!;
      await peopleService.updatePerson(
        database: database,
        personId: id,
        firstName: const Value("Clara"),
        lastName: const Value("Martin"),
        email: const Value("clara@example.com"),
        phone: const Value("0600000000"),
        addressLine1: const Value("1 rue de la Paix"),
        addressLine2: const Value("3e étage"),
        postalCode: const Value("75002"),
        city: const Value("Paris"),
        region: const Value("Île-de-France"),
        country: const Value("France"),
        colorIndex: const Value(3),
        birthDate: Value(DateTime(2000)),
        minorNotes: const Value("n/a"),
        maxDailyPresenceMinutes: const Value(480),
        isTransportAutonomous: const Value(true),
        accommodationNotes: const Value("Chez Camille"),
        travelNotes: const Value("Carte de fidélité 1234"),
        dietaryNotes: const Value("Végétarienne"),
        allergies: const Value("Arachides"),
        sizeTop: const Value("38"),
        sizeBottom: const Value("38"),
        sizeShoes: const Value("39"),
        hmcNotes: const Value("Cicatrice au menton"),
        imageRightsStatus: const Value(OcptImageRightsStatus.signed),
        imageRightsDate: Value(DateTime(2026)),
        notes: const Value("Ponctuelle"),
      );

      final sortKeyBefore = (await readPerson(id)).sortKey;

      await peopleService.deletePerson(database: database, personId: id);

      final row = await readPerson(id);
      expect(row.isDeleted, isTrue);
      // Kept, since they aren't personal data.
      expect(row.id, id);
      expect(row.sortKey, sortKeyBefore);
      expect(row.colorIndex, 3);
      // Blanked, since they are personal data.
      expect(row.firstName, "");
      expect(row.lastName, "");
      expect(row.email, "");
      expect(row.phone, "");
      expect(row.addressLine1, "");
      expect(row.addressLine2, "");
      expect(row.postalCode, "");
      expect(row.city, "");
      expect(row.region, "");
      expect(row.country, "");
      expect(row.birthDate, isNull);
      expect(row.minorNotes, "");
      expect(row.maxDailyPresenceMinutes, isNull);
      expect(row.isTransportAutonomous, isNull);
      expect(row.accommodationNotes, "");
      expect(row.travelNotes, "");
      expect(row.dietaryNotes, "");
      expect(row.allergies, "");
      expect(row.sizeTop, "");
      expect(row.sizeBottom, "");
      expect(row.sizeShoes, "");
      expect(row.hmcNotes, "");
      expect(row.imageRightsStatus, OcptImageRightsStatus.notApplicable);
      expect(row.imageRightsDate, isNull);
      expect(row.imageRightsAssetId, isNull);
      expect(row.photoAssetId, isNull);
      expect(row.notes, "");
    });

    test("deletePerson erases the free text of the rows hanging off the person", () async {
      final id = (await peopleService.createPerson(database: database))!;
      await peopleService.addPosition(
        database: database,
        personId: id,
        positionId: "soundEngineer",
        customLabel: "",
      );
      await peopleService.addSkill(database: database, personId: id, label: "Permis B, allemand");
      await peopleService.addUnavailability(
        database: database,
        personId: id,
        startDate: DateTime(2026, 8, 14),
        endDate: DateTime(2026, 8, 14),
        slot: OcptDayPartSlot.fullDay,
        reason: "Mariage de sa sœur",
      );

      await peopleService.deletePerson(database: database, personId: id);

      // Tombstoned along with the person they hang off: they describe somebody who is gone.
      final positions = await (database.select(
        database.ocptPersonPositionsTable,
      )..where((row) => row.personId.equals(id))).get();
      final skills = await (database.select(
        database.ocptPersonSkillsTable,
      )..where((row) => row.personId.equals(id))).get();
      final unavailabilities = await (database.select(
        database.ocptPersonUnavailabilitiesTable,
      )..where((row) => row.personId.equals(id))).get();

      expect(positions.single.isDeleted, isTrue);
      expect(skills.single.isDeleted, isTrue);
      expect(unavailabilities.single.isDeleted, isTrue);

      // And the free text about the person is gone from the file, not merely unreachable: an
      // erasure is about what the `.ocpt` stops holding, whatever screen still reads it.
      expect(skills.single.label, "");
      expect(unavailabilities.single.reason, "");

      // A crew position describes the production rather than the person, and identifies nobody once
      // the row it hangs off holds no name, so it survives as it stood.
      expect(positions.single.positionId, "soundEngineer");
    });

    test("deletePerson records the erasure in local_erasures", () async {
      final id = (await peopleService.createPerson(database: database))!;

      await peopleService.deletePerson(database: database, personId: id);

      final erasure = await (database.select(
        database.ocptLocalErasuresTable,
      )..where((row) => row.personId.equals(id))).getSingle();
      expect(erasure.personId, id);
    });

    test("deletePerson twice is idempotent: one erasure row, no error", () async {
      final id = (await peopleService.createPerson(database: database))!;

      await peopleService.deletePerson(database: database, personId: id);
      await peopleService.deletePerson(database: database, personId: id);

      final erasures = await (database.select(
        database.ocptLocalErasuresTable,
      )..where((row) => row.personId.equals(id))).get();
      expect(erasures, hasLength(1));
    });
  });


  group("referenced files", () {
    test("setPersonPhoto references the file and points the person at it", () async {
      final id = (await peopleService.createPerson(database: database))!;

      final assetId = (await peopleService.setPersonPhoto(
        database: database,
        personId: id,
        path: "/photos/clara.jpg",
      ))!;

      expect((await readPerson(id)).photoAssetId, assetId);

      final people = await peopleService.loadPeople(database: database);
      expect(people.single.photo?.path, "/photos/clara.jpg");
      expect(people.single.photo?.kind, OcptAssetKind.personPhoto);
    });

    test("referencing a second photo tombstones the first, an orphan being no history", () async {
      final id = (await peopleService.createPerson(database: database))!;

      final firstId = (await peopleService.setPersonPhoto(
        database: database,
        personId: id,
        path: "/photos/first.jpg",
      ))!;
      final secondId = (await peopleService.setPersonPhoto(
        database: database,
        personId: id,
        path: "/photos/second.jpg",
      ))!;

      expect(await readAssetIsDeleted(firstId), isTrue);
      expect(await readAssetIsDeleted(secondId), isFalse);

      final people = await peopleService.loadPeople(database: database);
      expect(people.single.photo?.path, "/photos/second.jpg");
    });

    test("clearPersonPhoto tombstones the row and nulls the column", () async {
      final id = (await peopleService.createPerson(database: database))!;
      final assetId = (await peopleService.setPersonPhoto(
        database: database,
        personId: id,
        path: "/photos/clara.jpg",
      ))!;

      await peopleService.clearPersonPhoto(database: database, personId: id);

      expect(await readAssetIsDeleted(assetId), isTrue);
      expect((await readPerson(id)).photoAssetId, isNull);
      expect((await peopleService.loadPeople(database: database)).single.photo, isNull);
    });

    test("setImageRightsDocument never touches the status a release stands at", () async {
      final id = (await peopleService.createPerson(database: database))!;
      await peopleService.updatePerson(
        database: database,
        personId: id,
        imageRightsStatus: const Value(OcptImageRightsStatus.toGenerate),
      );

      await peopleService.setImageRightsDocument(
        database: database,
        personId: id,
        path: "/documents/cession.pdf",
      );

      // Filing a draft is not the same claim as filing a signature: the badge stays the only thing
      // that says where the release stands.
      final row = await readPerson(id);
      expect(row.imageRightsStatus, OcptImageRightsStatus.toGenerate);
      expect(row.imageRightsAssetId, isNotNull);

      final people = await peopleService.loadPeople(database: database);
      expect(people.single.imageRightsDocument?.path, "/documents/cession.pdf");
    });

    test("a person's photo and release are two references, not one", () async {
      final id = (await peopleService.createPerson(database: database))!;

      await peopleService.setPersonPhoto(
        database: database,
        personId: id,
        path: "/photos/clara.jpg",
      );
      await peopleService.setImageRightsDocument(
        database: database,
        personId: id,
        path: "/documents/cession.pdf",
      );

      // Referencing one must not tombstone the other: they are different columns of one row, and
      // the replacement rule is per column.
      final person = (await peopleService.loadPeople(database: database)).single;
      expect(person.photo?.path, "/photos/clara.jpg");
      expect(person.imageRightsDocument?.path, "/documents/cession.pdf");
    });

    test("a photo whose row was tombstoned behind its column resolves to null", () async {
      final id = (await peopleService.createPerson(database: database))!;
      final assetId = (await peopleService.setPersonPhoto(
        database: database,
        personId: id,
        path: "/photos/clara.jpg",
      ))!;

      await assetsService.removeAsset(database: database, assetId: assetId);

      // The column still names the row; the row is gone, and "no photo" is what that means.
      expect((await readPerson(id)).photoAssetId, assetId);
      expect((await peopleService.loadPeople(database: database)).single.photo, isNull);
    });

    test("deletePerson blanks the path of every file the person referenced", () async {
      final id = (await peopleService.createPerson(database: database))!;
      final photoId = (await peopleService.setPersonPhoto(
        database: database,
        personId: id,
        path: "/photos/clara-martin.jpg",
      ))!;
      final documentId = (await peopleService.setImageRightsDocument(
        database: database,
        personId: id,
        path: "/documents/cession-clara-martin.pdf",
      ))!;

      await peopleService.deletePerson(database: database, personId: id);

      // A tombstone alone would leave the person's name, and where their photograph sits, written
      // in the file — an erasure is about what the `.ocpt` stops holding.
      for (final assetId in [photoId, documentId]) {
        final row = await readAsset(assetId);
        expect(row.isDeleted, isTrue);
        expect(row.path, isEmpty);
        expect(row.label, isEmpty);
      }
    });
  });

  group("positions, skills and unavailabilities", () {
    test("addPosition appends and loadPeople reads it back in order", () async {
      final personId = (await peopleService.createPerson(database: database))!;

      await peopleService.addPosition(
        database: database,
        personId: personId,
        positionId: "director",
        customLabel: "",
      );
      await peopleService.addPosition(
        database: database,
        personId: personId,
        positionId: "",
        customLabel: "Régie",
      );

      final people = await peopleService.loadPeople(database: database);
      final positions = people.single.positions;
      expect(positions.map((position) => position.positionId), ["director", ""]);
      expect(positions.map((position) => position.customLabel), ["", "Régie"]);
    });

    test("removePosition tombstones it and it disappears from loadPeople", () async {
      final personId = (await peopleService.createPerson(database: database))!;
      final positionId = (await peopleService.addPosition(
        database: database,
        personId: personId,
        positionId: "director",
        customLabel: "",
      ))!;

      await peopleService.removePosition(database: database, id: positionId);

      final people = await peopleService.loadPeople(database: database);
      expect(people.single.positions, isEmpty);
    });

    test("reorderPositions moves one by writing exactly one row", () async {
      final personId = (await peopleService.createPerson(database: database))!;
      final ids = [
        for (var i = 0; i < 3; i++)
          (await peopleService.addPosition(
            database: database,
            personId: personId,
            positionId: "position$i",
            customLabel: "",
              ))!,
      ];

      await peopleService.reorderPositions(
        database: database,
        personId: personId,
        orderedIds: [ids[1], ids[2], ids[0]],
      );

      final people = await peopleService.loadPeople(database: database);
      expect(people.single.positions.map((position) => position.id), [ids[1], ids[2], ids[0]]);
    });

    test("skills round trip: add, update, reorder, remove", () async {
      final personId = (await peopleService.createPerson(database: database))!;
      final firstId = (await peopleService.addSkill(
        database: database,
        personId: personId,
        label: "Permis B",
      ))!;
      final secondId = (await peopleService.addSkill(
        database: database,
        personId: personId,
        label: "Anglais",
      ))!;

      await peopleService.updateSkill(database: database, id: firstId, label: "Permis B et C1");
      await peopleService.reorderSkills(
        database: database,
        personId: personId,
        orderedIds: [secondId, firstId],
      );

      var people = await peopleService.loadPeople(database: database);
      expect(people.single.skills.map((skill) => skill.id), [secondId, firstId]);
      expect(
        people.single.skills.singleWhere((skill) => skill.id == firstId).label,
        "Permis B et C1",
      );

      await peopleService.removeSkill(database: database, id: secondId);
      people = await peopleService.loadPeople(database: database);
      expect(people.single.skills.map((skill) => skill.id), [firstId]);
    });

    test("unavailabilities round trip: add, update, remove", () async {
      final personId = (await peopleService.createPerson(database: database))!;
      final id = (await peopleService.addUnavailability(
        database: database,
        personId: personId,
        startDate: DateTime(2026, 8, 10),
        endDate: DateTime(2026, 8, 12),
        slot: OcptDayPartSlot.fullDay,
        reason: "Tournage d'un autre film",
      ))!;

      await peopleService.updateUnavailability(
        database: database,
        id: id,
        slot: const Value(OcptDayPartSlot.custom),
        startMinute: const Value(14 * 60),
        endMinute: const Value(17 * 60 + 30),
      );

      var people = await peopleService.loadPeople(database: database);
      final unavailability = people.single.unavailabilities.single;
      expect(unavailability.startDate, DateTime(2026, 8, 10));
      expect(unavailability.endDate, DateTime(2026, 8, 12));
      expect(unavailability.slot, OcptDayPartSlot.custom);
      expect(unavailability.startMinute, 14 * 60);
      expect(unavailability.endMinute, 17 * 60 + 30);
      expect(unavailability.reason, "Tournage d'un autre film");

      await peopleService.removeUnavailability(database: database, id: id);
      people = await peopleService.loadPeople(database: database);
      expect(people.single.unavailabilities, isEmpty);
    });
  });

  group("row-field-version stamps", () {
    test("createPerson stamps every column of the new row", () async {
      final personId = (await peopleService.createPerson(database: database))!;

      final stamps = await readStamps();
      final person = await readPerson(personId);
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("people/$personId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(person.toJson().length));
      for (final column in person.toJson().keys) {
        final stamp = ownStamps["people/$personId/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        expect(stamp!.version, 1);
      }
    });

    test("updatePerson stamps only the columns that actually changed", () async {
      final personId = (await peopleService.createPerson(database: database))!;
      // Clears what `createPerson` itself stamped, so only `updatePerson`'s own stamps remain.
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await peopleService.updatePerson(
        database: database,
        personId: personId,
        firstName: const Value("Camille"),
        lastName: const Value("Ferrand"),
      );

      final stamps = await readStamps();
      final ownKeys = stamps.keys.where((key) => key.startsWith("people/$personId/")).toSet();
      expect(ownKeys, {"people/$personId/firstName", "people/$personId/lastName"});
      expect(stamps["people/$personId/firstName"]!.version, 1);
      expect(stamps["people/$personId/lastName"]!.version, 1);

      // Writing the same values again touches nothing: there is nothing left to stamp.
      await peopleService.updatePerson(
        database: database,
        personId: personId,
        firstName: const Value("Camille"),
      );
      expect(await readStamps(), stamps);
    });

    test("deletePerson stamps isDeleted along with every blanked column", () async {
      final personId = (await peopleService.createPerson(database: database))!;
      await peopleService.updatePerson(
        database: database,
        personId: personId,
        firstName: const Value("Camille"),
        email: const Value("camille@example.com"),
      );
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await peopleService.deletePerson(database: database, personId: personId);

      final stamps = await readStamps();
      final ownKeys = stamps.keys.where((key) => key.startsWith("people/$personId/")).toSet();
      expect(ownKeys, containsAll(["people/$personId/isDeleted", "people/$personId/firstName"]));
      expect(stamps["people/$personId/isDeleted"]!.version, 1);
      // A column already blank (never set) is left unchanged, and is therefore not restamped.
      expect(ownKeys.contains("people/$personId/city"), isFalse);
    });

    test("addPosition stamps every column of the new row", () async {
      final personId = (await peopleService.createPerson(database: database))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final positionId = (await peopleService.addPosition(
        database: database,
        personId: personId,
        positionId: "director",
        customLabel: "",
      ))!;

      final stamps = await readStamps();
      final row = await (database.select(
        database.ocptPersonPositionsTable,
      )..where((table) => table.id.equals(positionId))).getSingle();
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("person_positions/$positionId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(row.toJson().length));
      for (final column in row.toJson().keys) {
        expect(ownStamps["person_positions/$positionId/$column"], isNotNull);
      }
    });
  });
}
