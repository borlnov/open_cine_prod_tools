// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const candidatesService = OcptRoleCandidatesService();
  const roleIndexService = OcptRoleIndexService();
  const peopleService = OcptPeopleService();

  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  /// Inserts the role [id] named [name] and returns its id.
  Future<String> createRole(String id, {String name = "CLARA"}) async {
    await database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(
            id: id,
            name: name,
            kind: OcptRoleKind.speaking,
            sortKey: Value(id),
          ),
        );

    return id;
  }

  /// Inserts the person [id] called [firstName] and returns their id.
  Future<String> createPerson(String id, {String firstName = "Camille"}) async {
    await database
        .into(database.ocptPeopleTable)
        .insert(OcptPeopleTableCompanion.insert(id: id, firstName: Value(firstName)));

    return id;
  }

  /// The candidacy row [id], tombstoned or not.
  Future<OcptRoleCandidateRow> readCandidate(String id) => (database.select(
    database.ocptRoleCandidatesTable,
  )..where((row) => row.id.equals(id))).getSingle();

  /// Every live candidacy row of the project, in `sortKey` order.
  Future<List<OcptRoleCandidateRow>> readCandidates() =>
      (database.select(database.ocptRoleCandidatesTable)
            ..where((row) => row.isDeleted.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// The person role [roleId] is cast with, or null while it is uncast.
  Future<String?> readCasting(String roleId) async =>
      (await (database.select(
        database.ocptRolesTable,
      )..where((row) => row.id.equals(roleId))).getSingle()).personId;

  group("candidates CRUD and ordering", () {
    test("addCandidate appends after the role's other candidates", () async {
      await createRole("role-1");
      await createPerson("person-1");
      await createPerson("person-2");

      final firstId = await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      );
      final secondId = await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-2",
      );

      expect((await readCandidates()).map((row) => row.id), [firstId, secondId]);
      expect((await readCandidate(firstId!)).status, OcptRoleCandidateStatus.seen);
      expect((await readCandidate(firstId)).auditionedOn, isNull);
    });

    test("addCandidate on a pair the role already carries is a no-op", () async {
      await createRole("role-1");
      await createPerson("person-1");

      final firstId = await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      );
      final againId = await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      );

      expect(againId, firstId);
      expect(await readCandidates(), hasLength(1));
    });

    test("addCandidate revives a removed candidacy, notes and status included", () async {
      await createRole("role-1");
      await createPerson("person-1");

      final id = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      ))!;
      await candidatesService.updateCandidate(
        database: database,
        candidateId: id,
        notes: const Value("Très juste"),
      );
      await candidatesService.setStatus(
        database: database,
        candidateId: id,
        status: OcptRoleCandidateStatus.shortlisted,
      );
      await candidatesService.removeCandidate(database: database, candidateId: id);

      final revivedId = await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      );

      expect(revivedId, id);
      final revived = await readCandidate(id);
      expect(revived.isDeleted, isFalse);
      expect(revived.notes, "Très juste");
      expect(revived.status, OcptRoleCandidateStatus.shortlisted);
    });

    test("the same person seen for two parts is two candidacies", () async {
      await createRole("role-1");
      await createRole("role-2", name: "MARC");
      await createPerson("person-1");

      final firstId = await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      );
      final secondId = await candidatesService.addCandidate(
        database: database,
        roleId: "role-2",
        personId: "person-1",
      );

      expect(secondId, isNot(firstId));
      expect(await readCandidates(), hasLength(2));
    });

    test("updateCandidate writes the date and the notes, and nothing else", () async {
      await createRole("role-1");
      await createPerson("person-1");
      final id = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      ))!;

      await candidatesService.updateCandidate(
        database: database,
        candidateId: id,
        auditionedOn: Value(DateTime.utc(2026, 2, 12)),
        notes: const Value("Fragile, exactly right"),
      );

      final candidate = await readCandidate(id);
      expect(candidate.auditionedOn, DateTime.utc(2026, 2, 12));
      expect(candidate.notes, "Fragile, exactly right");
      expect(candidate.status, OcptRoleCandidateStatus.seen);
    });

    test("reorderCandidate writes exactly one row", () async {
      await createRole("role-1");
      await createPerson("person-1");
      await createPerson("person-2");
      await createPerson("person-3");

      final firstId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      ))!;
      final secondId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-2",
      ))!;
      final thirdId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-3",
      ))!;

      final untouchedSortKey = (await readCandidate(secondId)).sortKey;

      await candidatesService.reorderCandidate(
        database: database,
        roleId: "role-1",
        candidateId: thirdId,
        newPosition: 0,
      );

      expect((await readCandidates()).map((row) => row.id), [thirdId, firstId, secondId]);
      expect((await readCandidate(secondId)).sortKey, untouchedSortKey);
    });

    test("removeCandidate tombstones the candidacy and leaves the person alone", () async {
      await createRole("role-1");
      await createPerson("person-1");
      final id = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      ))!;

      await candidatesService.removeCandidate(database: database, candidateId: id);

      expect((await readCandidate(id)).isDeleted, isTrue);
      final person = await (database.select(
        database.ocptPeopleTable,
      )..where((row) => row.id.equals("person-1"))).getSingle();
      expect(person.isDeleted, isFalse);
    });
  });

  group("the retained rule", () {
    late String firstCandidateId;
    late String secondCandidateId;

    setUp(() async {
      await createRole("role-1");
      await createPerson("person-1");
      await createPerson("person-2", firstName: "Sam");

      firstCandidateId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      ))!;
      secondCandidateId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-2",
      ))!;
    });

    test("retaining a candidate casts the part with them", () async {
      await candidatesService.retainCandidate(database: database, candidateId: firstCandidateId);

      expect((await readCandidate(firstCandidateId)).status, OcptRoleCandidateStatus.retained);
      expect(await readCasting("role-1"), "person-1");
    });

    test("retaining a second candidate demotes the first and recasts the part", () async {
      await candidatesService.retainCandidate(database: database, candidateId: firstCandidateId);
      await candidatesService.retainCandidate(database: database, candidateId: secondCandidateId);

      expect((await readCandidate(firstCandidateId)).status, OcptRoleCandidateStatus.seen);
      expect((await readCandidate(secondCandidateId)).status, OcptRoleCandidateStatus.retained);
      expect(await readCasting("role-1"), "person-2");
    });

    test("dropping the retained candidate leaves the part uncast", () async {
      await candidatesService.retainCandidate(database: database, candidateId: firstCandidateId);

      await candidatesService.unretainCandidate(database: database, candidateId: firstCandidateId);

      expect((await readCandidate(firstCandidateId)).status, OcptRoleCandidateStatus.seen);
      expect(await readCasting("role-1"), isNull);
    });

    test("any status taken away from the retained one clears the casting too", () async {
      // Every one of them, not a listed few: the cast column was written by exactly the status
      // being taken away, so leaving it for any reason at all has to give the column back.
      for (final status in OcptRoleCandidateStatus.values.where(
        (status) => status != OcptRoleCandidateStatus.retained,
      )) {
        await candidatesService.retainCandidate(database: database, candidateId: firstCandidateId);
        expect(await readCasting("role-1"), isNotNull, reason: "before moving to $status");

        await candidatesService.setStatus(
          database: database,
          candidateId: firstCandidateId,
          status: status,
        );

        expect((await readCandidate(firstCandidateId)).status, status);
        expect(await readCasting("role-1"), isNull, reason: "after moving to $status");
      }
    });

    test("turning the retained candidate down uncasts the part, as any other move away does",
        () async {
      // `notRetained` is the mirror of `retained` and the likeliest way a production changes its
      // mind, so it gets its own case beside the walk above rather than only being one of its
      // iterations.
      await candidatesService.retainCandidate(database: database, candidateId: firstCandidateId);

      await candidatesService.setStatus(
        database: database,
        candidateId: firstCandidateId,
        status: OcptRoleCandidateStatus.notRetained,
      );

      expect((await readCandidate(firstCandidateId)).status, OcptRoleCandidateStatus.notRetained);
      expect(await readCasting("role-1"), isNull);
    });

    test("removing the retained candidate leaves the part uncast", () async {
      await candidatesService.retainCandidate(database: database, candidateId: firstCandidateId);

      await candidatesService.removeCandidate(database: database, candidateId: firstCandidateId);

      expect((await readCandidate(firstCandidateId)).isDeleted, isTrue);
      expect(await readCasting("role-1"), isNull);
    });

    test("removing a candidate nobody retained leaves the casting alone", () async {
      await candidatesService.retainCandidate(database: database, candidateId: firstCandidateId);

      await candidatesService.removeCandidate(database: database, candidateId: secondCandidateId);

      expect(await readCasting("role-1"), "person-1");
    });

    test("a part cast by hand keeps its candidates, and they keep their hands off it", () async {
      // The role sheet's own picker, which writes `roles.personId` alone and touches no candidacy.
      await roleIndexService.updateRole(
        database: database,
        roleId: "role-1",
        personId: const Value("person-1"),
      );

      await candidatesService.setStatus(
        database: database,
        candidateId: secondCandidateId,
        status: OcptRoleCandidateStatus.declined,
      );

      expect(await readCasting("role-1"), "person-1");
      expect((await readCandidate(firstCandidateId)).status, OcptRoleCandidateStatus.seen);
    });

    test("retaining a candidate of one part leaves another part's casting alone", () async {
      await createRole("role-2", name: "MARC");
      final otherCandidateId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-2",
        personId: "person-1",
      ))!;
      await candidatesService.retainCandidate(database: database, candidateId: otherCandidateId);

      await candidatesService.retainCandidate(database: database, candidateId: firstCandidateId);

      expect((await readCandidate(otherCandidateId)).status, OcptRoleCandidateStatus.retained);
      expect(await readCasting("role-2"), "person-1");
      expect(await readCasting("role-1"), "person-1");
    });

    test("setStatus on a candidacy that isn't there writes nothing", () async {
      await candidatesService.retainCandidate(database: database, candidateId: firstCandidateId);

      await candidatesService.setStatus(
        database: database,
        candidateId: "nobody",
        status: OcptRoleCandidateStatus.retained,
      );

      expect((await readCandidate(firstCandidateId)).status, OcptRoleCandidateStatus.retained);
      expect(await readCasting("role-1"), "person-1");
    });
  });

  group("the cascades", () {
    test("deleting a role carries its candidates off, and leaves the people", () async {
      await createRole("role-1");
      await createPerson("person-1");
      final candidateId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      ))!;

      await roleIndexService.deleteRole(database: database, roleId: "role-1");

      expect((await readCandidate(candidateId)).isDeleted, isTrue);
      final person = await (database.select(
        database.ocptPeopleTable,
      )..where((row) => row.id.equals("person-1"))).getSingle();
      expect(person.isDeleted, isFalse);
    });

    test("erasing a person tombstones their candidacies and blanks the notes", () async {
      await createRole("role-1");
      await createRole("role-2", name: "MARC");
      await createPerson("person-1");
      await createPerson("person-2", firstName: "Sam");

      final erasedCandidateId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      ))!;
      await candidatesService.updateCandidate(
        database: database,
        candidateId: erasedCandidateId,
        auditionedOn: Value(DateTime.utc(2026, 2, 12)),
        notes: const Value("Fragile, exactly right for the part"),
      );
      final otherCandidateId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-2",
      ))!;
      // A second part the same erased person was seen for: every candidacy of theirs goes, not
      // only the first one found.
      final secondPartCandidateId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-2",
        personId: "person-1",
      ))!;

      await peopleService.deletePerson(database: database, personId: "person-1");

      final erased = await readCandidate(erasedCandidateId);
      expect(erased.isDeleted, isTrue);
      expect(erased.notes, isEmpty);
      // The status and the date say nothing about somebody the row no longer names, and nothing in
      // this schema is ever hard-deleted.
      expect(erased.auditionedOn, DateTime.utc(2026, 2, 12));
      expect((await readCandidate(secondPartCandidateId)).isDeleted, isTrue);

      // Somebody else's candidacy for the same part is untouched.
      final other = await readCandidate(otherCandidateId);
      expect(other.isDeleted, isFalse);
    });

    test("erasing the person a part is cast with leaves the part cast", () async {
      await createRole("role-1");
      await createPerson("person-1");
      final candidateId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      ))!;
      await candidatesService.retainCandidate(database: database, candidateId: candidateId);

      await peopleService.deletePerson(database: database, personId: "person-1");

      // `roles.personId` still points at the blanked `people` row, exactly as every other
      // reference to an erased person does: the row is never dropped, so the reference resolves.
      expect(await readCasting("role-1"), "person-1");
    });
  });

  group("loading", () {
    test("joins each candidacy with the person it names, in sortKey order", () async {
      await createRole("role-1");
      await createPerson("person-1");
      await createPerson("person-2", firstName: "Sam");
      final firstId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      ))!;
      final secondId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-2",
      ))!;

      final people = await peopleService.loadPeople(database: database);
      final candidatesByRoleId = await candidatesService.loadCandidatesByRoleId(
        database: database,
        people: people,
      );

      final candidates = candidatesByRoleId["role-1"]!;
      expect(candidates.map((candidate) => candidate.id), [firstId, secondId]);
      expect(candidates.first.person.firstName, "Camille");
      expect(candidates.last.person.firstName, "Sam");
      expect(candidates.first.isRetained, isFalse);
    });

    test("leaves out a candidacy whose person is gone, and every tombstoned one", () async {
      await createRole("role-1");
      await createPerson("person-1");
      await createPerson("person-2", firstName: "Sam");
      await createPerson("person-3", firstName: "Alex");
      final keptId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-1",
      ))!;
      final erasedPersonCandidateId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-2",
      ))!;
      final removedId = (await candidatesService.addCandidate(
        database: database,
        roleId: "role-1",
        personId: "person-3",
      ))!;

      await candidatesService.removeCandidate(database: database, candidateId: removedId);
      await peopleService.deletePerson(database: database, personId: "person-2");

      final candidatesByRoleId = await candidatesService.loadCandidatesByRoleId(
        database: database,
        people: await peopleService.loadPeople(database: database),
      );

      expect(candidatesByRoleId["role-1"]!.map((candidate) => candidate.id), [keptId]);
      expect(erasedPersonCandidateId, isNot(keptId));
    });
  });

  group("a previewed version", () {
    test("refuses every write, and writes nothing at all", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      await preview
          .into(preview.ocptRolesTable)
          .insert(
            OcptRolesTableCompanion.insert(
              id: "role-1",
              name: "CLARA",
              kind: OcptRoleKind.speaking,
            ),
          );
      await preview
          .into(preview.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: "person-1"));

      final candidateId = await candidatesService.addCandidate(
        database: preview,
        roleId: "role-1",
        personId: "person-1",
      );

      expect(candidateId, isNull);
      expect(await preview.select(preview.ocptRoleCandidatesTable).get(), isEmpty);

      await preview.close();
    });

    test("refuses to retain, so the previewed casting can't move", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      await preview
          .into(preview.ocptRolesTable)
          .insert(
            OcptRolesTableCompanion.insert(
              id: "role-1",
              name: "CLARA",
              kind: OcptRoleKind.speaking,
            ),
          );
      await preview
          .into(preview.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: "person-1"));
      await preview
          .into(preview.ocptRoleCandidatesTable)
          .insert(
            OcptRoleCandidatesTableCompanion.insert(
              id: "candidate-1",
              roleId: "role-1",
              personId: "person-1",
            ),
          );

      await candidatesService.retainCandidate(database: preview, candidateId: "candidate-1");

      final candidate = await preview.select(preview.ocptRoleCandidatesTable).getSingle();
      expect(candidate.status, OcptRoleCandidateStatus.seen);
      final role = await preview.select(preview.ocptRolesTable).getSingle();
      expect(role.personId, isNull);

      await preview.close();
    });
  });
}
