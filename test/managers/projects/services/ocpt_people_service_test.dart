// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_half_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const peopleService = OcptPeopleService();

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
        address: const Value("1 rue de la Paix"),
        city: const Value("Paris"),
        colorIndex: const Value(3),
        birthDate: Value(DateTime(2000)),
        minorNotes: const Value("n/a"),
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
      expect(row.address, "");
      expect(row.city, "");
      expect(row.birthDate, isNull);
      expect(row.minorNotes, "");
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
        date: DateTime(2026, 8, 14),
        halfDay: OcptHalfDay.full,
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
        date: DateTime(2026, 8, 10),
        halfDay: OcptHalfDay.full,
        reason: "Tournage d'un autre film",
      ))!;

      await peopleService.updateUnavailability(
        database: database,
        id: id,
        halfDay: const Value(OcptHalfDay.morning),
      );

      var people = await peopleService.loadPeople(database: database);
      final unavailability = people.single.unavailabilities.single;
      expect(unavailability.halfDay, OcptHalfDay.morning);
      expect(unavailability.reason, "Tournage d'un autre film");

      await peopleService.removeUnavailability(database: database, id: id);
      people = await peopleService.loadPeople(database: database);
      expect(people.single.unavailabilities, isEmpty);
    });
  });
}
