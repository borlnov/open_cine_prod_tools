// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// Parses [source] with the real Fountain parser, so reconciliation is exercised against a
/// realistic document rather than a hand-built one.
FountainDocument _parse(String source) => const FountainParser().parse(source);

/// An [OcptProjectDatabase] that counts how many transactions it opens, so a test can assert
/// [OcptRoleIndexService.reconcile] never opens one when its plan is empty — the [transaction]
/// override is the only way to observe "wrote nothing" from outside the service.
class _TransactionCountingDatabase extends OcptProjectDatabase {
  /// Opens a fresh in-memory database, exactly as [OcptProjectDatabase.memory] does.
  _TransactionCountingDatabase() : super.memory();

  /// How many transactions have been opened on this database so far.
  int transactionCount = 0;

  /// {@macro drift.DatabaseConnectionUser.transaction}
  @override
  Future<T> transaction<T>(Future<T> Function() action, {bool requireNew = false}) {
    transactionCount++;
    return super.transaction(action, requireNew: requireNew);
  }
}

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final assetsService = OcptAssetsService(deviceId: testDeviceId);
  final elementsService = OcptElementsService(assetsService: assetsService, deviceId: testDeviceId);
  final roleIndexService = OcptRoleIndexService(
    elementsService: elementsService,
    roleCandidatesService: OcptRoleCandidatesService(deviceId: testDeviceId),
    deviceId: testDeviceId,
  );
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
  stamps: null,
  );

  group("reconciliation", () {
    test("a new speaking character creates an uncast, speaking role", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles, hasLength(1));
      expect(roles.single.name, "CLARA");
      expect(roles.single.kind, OcptRoleKind.speaking);
      expect(roles.single.isFromScreenplay, isTrue);
      expect(roles.single.personId, isNull);
      expect(roles.single.orphanedName, isNull);
      expect(roles.single.number, 1);
      expect(roles.single.episodeIds, [screenplayId]);
    });

    test("several speaking characters get roles in first-appearance order", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.

MARC
Hi.
''');

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles.map((role) => role.name), ["CLARA", "MARC"]);
      expect(roles.map((role) => role.number), [1, 2]);
    });

    test("a vanished character gets orphanedName while keeping its casting", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');
      final roleId = (await roleIndexService.loadRoles(database: database)).single.id;
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

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles, hasLength(1));
      expect(roles.single.id, roleId);
      expect(roles.single.orphanedName, "CLARA");
      expect(roles.single.personId, personId);
      expect(roles.single.castingNotes, "Great fit");
      expect(roles.single.episodeIds, isEmpty);

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

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles, hasLength(1));
      expect(roles.single.orphanedName, isNull);
      expect(roles.single.episodeIds, [screenplayId]);
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

      final roles = await roleIndexService.loadRoles(database: database);
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
      final rolesAfterFirst = await roleIndexService.loadRoles(database: database);

      await reconcile(source);
      final rolesAfterSecond = await roleIndexService.loadRoles(database: database);

      expect(rolesAfterSecond, rolesAfterFirst);
    });

    test("reconcile opens no transaction at all when nothing changed", () async {
      final countingDatabase = _TransactionCountingDatabase();
      await countingDatabase
          .into(countingDatabase.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(
              id: screenplayId,
              title: "Draft",
              updatedAt: DateTime.now(),
            ),
          );

      const source = '''
INT. HOUSE - DAY

CLARA
Hello.
''';
      await roleIndexService.reconcile(
        database: countingDatabase,
        screenplayId: screenplayId,
        document: _parse(source),
      stamps: null,
      );
      expect(countingDatabase.transactionCount, 1);

      await roleIndexService.reconcile(
        database: countingDatabase,
        screenplayId: screenplayId,
        document: _parse(source),
      stamps: null,
      );
      expect(
        countingDatabase.transactionCount,
        1,
        reason: "nothing changed the second time, so no transaction should have opened",
      );

      await countingDatabase.close();
    });
  });

  group("action-detected characters", () {
    test("a name only found in the action creates an uncast, silent, from-screenplay role", () async {
      await reconcile('''
INT. HOUSE - DAY

MARC enters, followed by CLARA. Nobody speaks.
''');

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles.map((role) => role.name), ["MARC", "CLARA"]);
      for (final role in roles) {
        expect(role.kind, OcptRoleKind.silent);
        expect(role.isFromScreenplay, isTrue);
        expect(role.personId, isNull);
        expect(role.episodeIds, [screenplayId]);
      }
    });

    test("a first cue promotes an action-detected role without splitting it in two", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA enters, silent.
''');
      final roleId = (await roleIndexService.loadRoles(database: database)).single.id;
      const personId = "person-1";
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: personId));
      await roleIndexService.updateRole(
        database: database,
        roleId: roleId,
        personId: const Value(personId),
        castingNotes: const Value("Cast already"),
      );

      await reconcile('''
INT. HOUSE - DAY

CLARA
Finally, a line.
''');

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles, hasLength(1));
      expect(roles.single.id, roleId);
      expect(roles.single.kind, OcptRoleKind.speaking);
      expect(roles.single.personId, personId);
      expect(roles.single.castingNotes, "Cast already");
    });

    test("cutting the line afterwards does not demote a promoted role", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA enters, silent.
''');
      final roleId = (await roleIndexService.loadRoles(database: database)).single.id;

      await reconcile('''
INT. HOUSE - DAY

CLARA
Finally, a line.
''');
      expect(
        (await roleIndexService.loadRoles(database: database)).single.kind,
        OcptRoleKind.speaking,
      );

      // The line is cut, but the character still stands in the action.
      await reconcile('''
INT. HOUSE - DAY

CLARA enters, silent again.
''');

      final role = (await roleIndexService.loadRoles(
        database: database,
      )).singleWhere((role) => role.id == roleId);
      expect(role.kind, OcptRoleKind.speaking);
    });

    test("deleting an action-detected role rejects it on the next reconcile of the same source", () async {
      await reconcile('''
INT. HOUSE - DAY

OK enters, silent.
''');
      final roleId = (await roleIndexService.loadRoles(database: database)).single.id;
      expect((await roleIndexService.loadRoles(database: database)).single.name, "OK");

      await roleIndexService.deleteRole(database: database, roleId: roleId);
      expect(await roleIndexService.loadRoles(database: database), isEmpty);

      // Re-running reconcile against the very same source must not bring "OK" back.
      await reconcile('''
INT. HOUSE - DAY

OK enters, silent.
''');
      expect(await roleIndexService.loadRoles(database: database), isEmpty);
    });

    test("a deleted speaking role still comes back: rejection is scoped to action-detected roles", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');
      final roleId = (await roleIndexService.loadRoles(database: database)).single.id;
      await roleIndexService.deleteRole(database: database, roleId: roleId);
      expect(await roleIndexService.loadRoles(database: database), isEmpty);

      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello again.
''');

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles, hasLength(1));
      expect(roles.single.name, "CLARA");
      expect(roles.single.kind, OcptRoleKind.speaking);
      // A fresh row, not the tombstoned one: deleting a speaking role does not stop it coming back.
      expect(roles.single.id, isNot(roleId));
    });

    test("a name cued this episode is never rejected, whatever tombstone bears it", () async {
      // CLARA first stands mute in the action and is rejected as an action-detected role…
      await reconcile('''
INT. HOUSE - DAY

CLARA enters, silent.
''');
      final roleId = (await roleIndexService.loadRoles(database: database)).single.id;
      await roleIndexService.deleteRole(database: database, roleId: roleId);
      expect(await roleIndexService.loadRoles(database: database), isEmpty);

      // …but this time the same document also cues her: the cue must win over the tombstone.
      await reconcile('''
INT. HOUSE - DAY

CLARA enters, silent no more.

CLARA
Hello.
''');

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles, hasLength(1));
      expect(roles.single.name, "CLARA");
      expect(roles.single.kind, OcptRoleKind.speaking);
    });

    test("a name in both an action line and a cue counts once, as speaking", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA enters the room.

CLARA
Hello.
''');

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles, hasLength(1));
      expect(roles.single.name, "CLARA");
      expect(roles.single.kind, OcptRoleKind.speaking);
      expect(roles.single.isFromScreenplay, isTrue);
    });

    test("an action-detected role this episode no longer names loses its link and is orphaned", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA enters, silent.
''');
      final roleId = (await roleIndexService.loadRoles(database: database)).single.id;
      const personId = "person-1";
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: personId));
      await roleIndexService.updateRole(
        database: database,
        roleId: roleId,
        personId: const Value(personId),
      );

      await reconcile('''
INT. HOUSE - DAY

Nobody is there anymore.
''');

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles, hasLength(1));
      expect(roles.single.id, roleId);
      expect(roles.single.orphanedName, "CLARA");
      expect(roles.single.personId, personId);
      expect(roles.single.episodeIds, isEmpty);

      final alerts = OcptRemovedRoleAlert.buildAll(roles);
      expect(alerts, hasLength(1));
      expect(alerts.single.characterName, "CLARA");
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

      final role = (await roleIndexService.loadRoles(database: database)).single;
      expect(role.name, "Silent neighbour");
      expect(role.castingNotes, "Cast locally");
      expect(role.personId, isNull);
      expect(role.episodeIds, [screenplayId]);
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

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles.map((role) => role.id), [secondId]);
    });

    test("deleteRole carries the role's things off with it, the elements untouched", () async {
      final roleId = (await roleIndexService.addRole(
        database: database,
        screenplayId: screenplayId,
        name: "CLARA",
        kind: OcptRoleKind.extra,
      ))!;
      final elementId = (await elementsService.createElement(
        database: database,
        name: "Manteau rouge",
        category: OcptElementCategory.costume,
        sourceKind: OcptElementSourceKind.owned,
      ))!;
      await elementsService.addRoleElement(
        database: database,
        roleId: roleId,
        elementId: elementId,
      );

      await roleIndexService.deleteRole(database: database, roleId: roleId);

      // The link is gone…
      final links = await database.select(database.ocptRoleElementsTable).get();
      expect(links.single.isDeleted, isTrue);

      // …and the coat is still in the catalogue, which is the whole point: it outlives the
      // character who wore it.
      final element = (await elementsService.loadElements(database: database)).single;
      expect(element.name, "Manteau rouge");
      expect(element.roleLinks, isEmpty);
    });

    test("deleteRole tombstones its role_episodes links too", () async {
      final roleId = (await roleIndexService.addRole(
        database: database,
        screenplayId: screenplayId,
        name: "CLARA",
        kind: OcptRoleKind.extra,
      ))!;

      await roleIndexService.deleteRole(database: database, roleId: roleId);

      final links = await database.select(database.ocptRoleEpisodesTable).get();
      expect(links.single.isDeleted, isTrue);
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

      await roleIndexService.reorderRole(database: database, roleId: ids[0], newPosition: 2);

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles.map((role) => role.id), [ids[1], ids[2], ids[0]]);
    });

    test("keepOrphanedRoleAsSilent detaches it from reconciliation", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');
      final roleId = (await roleIndexService.loadRoles(database: database)).single.id;

      await reconcile('''
INT. HOUSE - DAY

Action, no dialogue anymore.
''');
      await roleIndexService.keepOrphanedRoleAsSilent(database: database, roleId: roleId);

      final role = (await roleIndexService.loadRoles(database: database)).single;
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
      final rolesAfter = await roleIndexService.loadRoles(database: database);
      expect(rolesAfter, hasLength(2));
      expect(
        rolesAfter.singleWhere((role) => role.id == roleId).isFromScreenplay,
        isFalse,
      );
    });
  });

  group("multiple episodes", () {
    const otherScreenplayId = "screenplay-2";

    setUp(() async {
      // Explicit sortKeys so the episodes' order is deterministic and independent from insertion
      // order, exactly as a project's episodes are ordered in the app.
      await (database.update(
        database.ocptScreenplaysTable,
      )..where((table) => table.id.equals(screenplayId))).write(
        const OcptScreenplaysTableCompanion(sortKey: Value("A")),
      );
      await database
          .into(database.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(
              id: otherScreenplayId,
              title: "Episode 2",
              updatedAt: DateTime.now(),
              number: const Value(2),
              sortKey: const Value("B"),
            ),
          );
    });

    Future<void> reconcileOther(String source) => roleIndexService.reconcile(
      database: database,
      screenplayId: otherScreenplayId,
      document: _parse(source),
    stamps: null,
    );

    test("a character speaking in two episodes stays one row, one casting, one number", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');
      await reconcileOther('''
INT. STREET - NIGHT

CLARA
Hi again.
''');

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles, hasLength(1));
      expect(roles.single.name, "CLARA");
      expect(roles.single.number, 1);
      expect(roles.single.episodeIds, [screenplayId, otherScreenplayId]);

      const personId = "person-1";
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: personId));
      await roleIndexService.updateRole(
        database: database,
        roleId: roles.single.id,
        personId: const Value(personId),
      );

      final rolesAfterCasting = await roleIndexService.loadRoles(database: database);
      expect(rolesAfterCasting, hasLength(1));
      expect(rolesAfterCasting.single.personId, personId);
    });

    test("a character cut from one of two episodes keeps its casting and is not orphaned", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');
      await reconcileOther('''
INT. STREET - NIGHT

CLARA
Hi again.
''');
      final roleId = (await roleIndexService.loadRoles(database: database)).single.id;
      const personId = "person-1";
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: personId));
      await roleIndexService.updateRole(
        database: database,
        roleId: roleId,
        personId: const Value(personId),
      );

      // CLARA is cut from the first episode, but keeps speaking in the second.
      await reconcile('''
INT. HOUSE - DAY

Action, no dialogue anymore.
''');

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles, hasLength(1));
      expect(roles.single.id, roleId);
      expect(roles.single.orphanedName, isNull);
      expect(roles.single.personId, personId);
      expect(roles.single.episodeIds, [otherScreenplayId]);
      expect(OcptRemovedRoleAlert.buildAll(roles), isEmpty);
    });

    test("a character cut from every episode is orphaned exactly once, casting surviving", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');
      await reconcileOther('''
INT. STREET - NIGHT

CLARA
Hi again.
''');
      final roleId = (await roleIndexService.loadRoles(database: database)).single.id;
      const personId = "person-1";
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: personId));
      await roleIndexService.updateRole(
        database: database,
        roleId: roleId,
        personId: const Value(personId),
      );

      await reconcile('''
INT. HOUSE - DAY

Action, no dialogue anymore.
''');
      await reconcileOther('''
INT. STREET - NIGHT

Action, no dialogue anymore.
''');

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles, hasLength(1));
      expect(roles.single.id, roleId);
      expect(roles.single.orphanedName, "CLARA");
      expect(roles.single.personId, personId);
      expect(roles.single.episodeIds, isEmpty);

      final alerts = OcptRemovedRoleAlert.buildAll(roles);
      expect(alerts, hasLength(1));
    });

    test("loadRoles numbers roles across the whole project", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');
      await reconcileOther('''
INT. STREET - NIGHT

MARC
Hi.
''');

      final roles = await roleIndexService.loadRoles(database: database);
      expect(roles.map((role) => role.name), ["CLARA", "MARC"]);
      expect(roles.map((role) => role.number), [1, 2]);
    });

    test("episodeIds reads back in the episodes' own sortKey order", () async {
      await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');
      // Linked to the second episode (higher sortKey) first, so only sortKey order — not
      // link-creation order — can explain the read-back order.
      await reconcileOther('''
INT. STREET - NIGHT

CLARA
Hi again.
''');

      final role = (await roleIndexService.loadRoles(database: database)).single;
      expect(role.episodeIds, [screenplayId, otherScreenplayId]);
    });

    test("setRoleEpisodes adds, removes and re-adds a link without duplicating it", () async {
      final roleId = (await roleIndexService.addRole(
        database: database,
        screenplayId: screenplayId,
        name: "Silent neighbour",
        kind: OcptRoleKind.silent,
      ))!;

      Future<List<OcptRoleEpisodeRow>> rawLinks() => (database.select(
        database.ocptRoleEpisodesTable,
      )..where((table) => table.roleId.equals(roleId))).get();

      await roleIndexService.setRoleEpisodes(
        database: database,
        roleId: roleId,
        screenplayIds: {screenplayId, otherScreenplayId},
      );
      var links = await rawLinks();
      expect(links, hasLength(2)); // the link addRole made, plus the new one.
      expect(
        links.where((link) => !link.isDeleted).map((link) => link.screenplayId).toSet(),
        {screenplayId, otherScreenplayId},
      );

      await roleIndexService.setRoleEpisodes(
        database: database,
        roleId: roleId,
        screenplayIds: {otherScreenplayId},
      );
      links = await rawLinks();
      expect(links, hasLength(2)); // dropping the first episode tombstones its row, no deletion.
      expect(
        links.where((link) => !link.isDeleted).map((link) => link.screenplayId).toList(),
        [otherScreenplayId],
      );

      await roleIndexService.setRoleEpisodes(
        database: database,
        roleId: roleId,
        screenplayIds: {screenplayId, otherScreenplayId},
      );
      links = await rawLinks();
      // The tombstoned link is revived rather than a second live row being inserted: still two
      // rows in total, both live again.
      expect(links, hasLength(2));
      expect(
        links.where((link) => !link.isDeleted).map((link) => link.screenplayId).toSet(),
        {screenplayId, otherScreenplayId},
      );
    });

    test("setRoleEpisodes with an empty set leaves the role named in no episode", () async {
      final roleId = (await roleIndexService.addRole(
        database: database,
        screenplayId: screenplayId,
        name: "Silent neighbour",
        kind: OcptRoleKind.silent,
      ))!;

      await roleIndexService.setRoleEpisodes(database: database, roleId: roleId, screenplayIds: {});

      final role = (await roleIndexService.loadRoles(
        database: database,
      )).singleWhere((role) => role.id == roleId);
      expect(role.episodeIds, isEmpty);
    });

    test(
      "a hand-added role linked to an episode survives a reconcile naming none of its characters",
      () async {
        final roleId = (await roleIndexService.addRole(
          database: database,
          screenplayId: otherScreenplayId,
          name: "Crowd",
          kind: OcptRoleKind.extra,
        ))!;

        await reconcileOther('''
INT. STREET - NIGHT

CLARA
Hi.
''');

        final links = await (database.select(
          database.ocptRoleEpisodesTable,
        )..where((table) => table.roleId.equals(roleId))).get();
        expect(links.single.isDeleted, isFalse);
        expect(links.single.screenplayId, otherScreenplayId);

        final role = (await roleIndexService.loadRoles(
          database: database,
        )).singleWhere((role) => role.id == roleId);
        expect(role.isFromScreenplay, isFalse);
        expect(role.orphanedName, isNull);
        expect(role.episodeIds, [otherScreenplayId]);
      },
    );
  });
}
