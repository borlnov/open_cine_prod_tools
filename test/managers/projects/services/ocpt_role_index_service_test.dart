// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// Parses [source] with the real Fountain parser, so reconciliation is exercised against a
/// realistic document rather than a hand-built one.
FountainDocument _parse(String source) => const FountainParser().parse(source);

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const roleIndexService = OcptRoleIndexService();
  const screenplayId = "screenplay-1";

  late OcptProjectDatabase database;

  setUp(() async {
    database = OcptProjectDatabase.memory();
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> reconcile(String source) => roleIndexService.reconcile(
    database: database,
    screenplayId: screenplayId,
    document: _parse(source),
  );

  group("reconciliation", () {
    test("a new speaking character creates an uncast, speaking role", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');

      final roles = await roleIndexService.loadRoles(database: database, screenplayId: screenplayId);
      expect(roles, hasLength(1));
      expect(roles.single.name, "CLARA");
      expect(roles.single.kind, OcptRoleKind.speaking);
      expect(roles.single.isFromScreenplay, isTrue);
      expect(roles.single.personId, isNull);
      expect(roles.single.orphanedName, isNull);
      expect(roles.single.number, 1);
    });

    test("several speaking characters get roles in first-appearance order", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.

MARC
Hi.
''');

      final roles = await roleIndexService.loadRoles(database: database, screenplayId: screenplayId);
      expect(roles.map((role) => role.name), ["CLARA", "MARC"]);
      expect(roles.map((role) => role.number), [1, 2]);
    });

    test("a vanished character gets orphanedName while keeping its casting", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');
      final roleId = (await roleIndexService.loadRoles(
        database: database,
        screenplayId: screenplayId,
      )).single.id;
      const personId = "person-1";
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: personId));
      await roleIndexService.updateRole(
        database: database,
        roleId: roleId,
        personId: const Value(personId),
        castingNotes: const Value("Great fit"),
      );

      await reconcile('''
INT. HOUSE - DAY

Action, no dialogue anymore.
''');

      final roles = await roleIndexService.loadRoles(database: database, screenplayId: screenplayId);
      expect(roles, hasLength(1));
      expect(roles.single.id, roleId);
      expect(roles.single.orphanedName, "CLARA");
      expect(roles.single.personId, personId);
      expect(roles.single.castingNotes, "Great fit");

      final alerts = OcptRemovedRoleAlert.buildAll(roles);
      expect(alerts, hasLength(1));
      expect(alerts.single.characterName, "CLARA");
    });

    test("the character reappearing clears orphanedName again", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');
      await reconcile('''
INT. HOUSE - DAY

Action, no dialogue anymore.
''');
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello again.
''');

      final roles = await roleIndexService.loadRoles(database: database, screenplayId: screenplayId);
      expect(roles, hasLength(1));
      expect(roles.single.orphanedName, isNull);
    });

    test("a hand-added role survives reconcile untouched", () async {
      final handAddedId = (await roleIndexService.addRole(
        database: database,
        screenplayId: screenplayId,
        name: "Extra crowd",
        kind: OcptRoleKind.extra,
      ))!;

      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');

      final roles = await roleIndexService.loadRoles(database: database, screenplayId: screenplayId);
      expect(roles.map((role) => role.name), ["Extra crowd", "CLARA"]);
      final handAdded = roles.singleWhere((role) => role.id == handAddedId);
      expect(handAdded.isFromScreenplay, isFalse);
      expect(handAdded.orphanedName, isNull);
    });

    test("re-running reconcile with the same document is idempotent", () async {
      const source = '''
INT. HOUSE - DAY

CLARA
Hello.

MARC
Hi.
''';
      await reconcile(source);
      final rolesAfterFirst = await roleIndexService.loadRoles(
        database: database,
        screenplayId: screenplayId,
      );

      await reconcile(source);
      final rolesAfterSecond = await roleIndexService.loadRoles(
        database: database,
        screenplayId: screenplayId,
      );

      expect(rolesAfterSecond, rolesAfterFirst);
    });
  });

  group("hand CRUD", () {
    test("addRole appends and updateRole only touches the fields it's given a Value for", () async {
      final id = (await roleIndexService.addRole(
        database: database,
        screenplayId: screenplayId,
        name: "Silent neighbour",
        kind: OcptRoleKind.silent,
      ))!;

      await roleIndexService.updateRole(
        database: database,
        roleId: id,
        castingNotes: const Value("Cast locally"),
      );

      final role = (await roleIndexService.loadRoles(
        database: database,
        screenplayId: screenplayId,
      )).single;
      expect(role.name, "Silent neighbour");
      expect(role.castingNotes, "Cast locally");
      expect(role.personId, isNull);
    });

    test("deleteRole tombstones it and it disappears from loadRoles", () async {
      final firstId = (await roleIndexService.addRole(
        database: database,
        screenplayId: screenplayId,
        name: "First",
        kind: OcptRoleKind.extra,
      ))!;
      final secondId = (await roleIndexService.addRole(
        database: database,
        screenplayId: screenplayId,
        name: "Second",
        kind: OcptRoleKind.extra,
      ))!;

      await roleIndexService.deleteRole(database: database, roleId: firstId);

      final roles = await roleIndexService.loadRoles(database: database, screenplayId: screenplayId);
      expect(roles.map((role) => role.id), [secondId]);
    });

    test("reorderRole moves a role by writing exactly one row", () async {
      final ids = [
        for (var i = 0; i < 3; i++)
          (await roleIndexService.addRole(
            database: database,
            screenplayId: screenplayId,
            name: "Role $i",
            kind: OcptRoleKind.extra,
          ))!,
      ];

      await roleIndexService.reorderRole(
        database: database,
        screenplayId: screenplayId,
        roleId: ids[0],
        newPosition: 2,
      );

      final roles = await roleIndexService.loadRoles(database: database, screenplayId: screenplayId);
      expect(roles.map((role) => role.id), [ids[1], ids[2], ids[0]]);
    });

    test("keepOrphanedRoleAsSilent detaches it from reconciliation", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');
      final roleId = (await roleIndexService.loadRoles(
        database: database,
        screenplayId: screenplayId,
      )).single.id;

      await reconcile('''
INT. HOUSE - DAY

Action, no dialogue anymore.
''');
      await roleIndexService.keepOrphanedRoleAsSilent(database: database, roleId: roleId);

      final role = (await roleIndexService.loadRoles(
        database: database,
        screenplayId: screenplayId,
      )).single;
      expect(role.kind, OcptRoleKind.silent);
      expect(role.isFromScreenplay, isFalse);
      expect(role.orphanedName, isNull);
      expect(role.name, "CLARA");

      // Reconciling again must not touch this role: it is no longer owned by the screenplay.
      await reconcile('''
INT. HOUSE - DAY

CLARA
Back again.
''');
      final rolesAfter = await roleIndexService.loadRoles(
        database: database,
        screenplayId: screenplayId,
      );
      expect(rolesAfter, hasLength(2));
      expect(
        rolesAfter.singleWhere((role) => role.id == roleId).isFromScreenplay,
        isFalse,
      );
    });
  });
}
