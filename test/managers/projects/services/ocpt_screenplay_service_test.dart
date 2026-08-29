// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show BooleanExpressionOperators, OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const screenplayId = "screenplay-1";
  const roleIndexService = OcptRoleIndexService();
  const elementsService = OcptElementsService();
  const locationsService = OcptLocationsService();
  const breakdownService = OcptBreakdownService(
    elementsService: elementsService,
    locationsService: locationsService,
  );
  const scheduleService = OcptScheduleService();
  const sceneIndexService = OcptSceneIndexService();
  Future<String> testDeviceId() async => "test-device";
  final shotListService = OcptShotListService(deviceId: testDeviceId);
  final shotCoverageService = OcptShotCoverageService(deviceId: testDeviceId);
  final service = OcptScreenplayService(
    sceneIndexService: sceneIndexService,
    shotListService: shotListService,
    shotCoverageService: shotCoverageService,
    roleIndexService: roleIndexService,
    breakdownService: breakdownService,
    scheduleService: scheduleService,
    deviceId: testDeviceId,
  );

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

  Future<List<OcptScreenplaySnapshotRow>> readSnapshots() =>
      (database.select(database.ocptScreenplaySnapshotsTable)
            ..where((row) => row.isDeleted.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .get();

  /// Reads back every snapshot row, tombstones included, oldest first.
  Future<List<OcptScreenplaySnapshotRow>> readSnapshotsIncludingTombstones() => (database.select(
    database.ocptScreenplaySnapshotsTable,
  )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).get();

  test('loadScreenplayText returns the empty text of a freshly created screenplay', () async {
    final text = await service.loadScreenplayText(database: database, screenplayId: screenplayId);
    expect(text, "");
  });

  test('saveScreenplayText updates the stored text and reconciles the scene index', () async {
    await service.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: "INT. HOUSE - DAY\n\nAction.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );

    final text = await service.loadScreenplayText(database: database, screenplayId: screenplayId);
    expect(text, "INT. HOUSE - DAY\n\nAction.\n");

    final scenes = await database.select(database.ocptScenesTable).get();
    expect(scenes, hasLength(1));
    expect(scenes.single.heading, "INT. HOUSE - DAY");
  });

  test('saveScreenplayText snapshots the text as it was before the overwrite', () async {
    await service.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: "first version",
      snapshotReason: OcptSnapshotReason.manual,
    );
    await service.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: "second version",
      snapshotReason: OcptSnapshotReason.timer,
    );

    final snapshots = await readSnapshots();

    // The first save snapshots the initial empty text; the second save snapshots "first version".
    expect(snapshots, hasLength(2));
    expect(snapshots[0].fountainText, "");
    expect(snapshots[0].reason, OcptSnapshotReason.manual);
    expect(snapshots[1].fountainText, "first version");
    expect(snapshots[1].reason, OcptSnapshotReason.timer);
  });

  test('snapshotOnProjectOpen takes a snapshot of the current text, tagged "open"', () async {
    await service.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: "current text",
      snapshotReason: OcptSnapshotReason.manual,
    );

    await service.snapshotOnProjectOpen(database: database, screenplayId: screenplayId);

    final snapshots = await readSnapshots();
    expect(snapshots.last.fountainText, "current text");
    expect(snapshots.last.reason, OcptSnapshotReason.open);
  });

  test('snapshots beyond the 30 most recent are pruned after every save', () async {
    for (var i = 0; i < 35; i++) {
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: "version $i",
        snapshotReason: OcptSnapshotReason.timer,
      );
    }

    final snapshots = await readSnapshots();

    expect(snapshots, hasLength(OcptScreenplayService.maxSnapshotsPerScreenplay));
    // The 35 saves snapshot the *previous* text each time: "version 0".."version 33" (34 values,
    // since the very first save snapshots the initial empty text). Only the 30 most recent survive.
    expect(snapshots.first.fountainText, "version 4");
    expect(snapshots.last.fountainText, "version 33");
  });

  test('a pruned snapshot is a tombstone with its text dropped, not a deleted row', () async {
    for (var i = 0; i < 35; i++) {
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: "version $i",
        snapshotReason: OcptSnapshotReason.timer,
      );
    }

    final everyRow = await readSnapshotsIncludingTombstones();
    final pruned = everyRow.where((row) => row.isDeleted).toList(growable: false);

    // 35 saves wrote 35 snapshot rows; the 30 most recent stayed live.
    expect(everyRow, hasLength(35));
    expect(pruned, hasLength(35 - OcptScreenplayService.maxSnapshotsPerScreenplay));
    // Pruning exists to bound the file's size, so a pruned row keeps nothing but its marker.
    expect(pruned.every((row) => row.fountainText.isEmpty), isTrue);
  });

  test('a write handed the read-only database of a previewed version is refused', () async {
    final preview = OcptProjectDatabase.memory(isPreview: true);
    addTearDown(preview.close);

    await preview
        .into(preview.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            fountainText: const Value("INT. HOUSE - DAY"),
            updatedAt: DateTime.now(),
          ),
        );

    await service.saveScreenplayText(
      database: preview,
      screenplayId: screenplayId,
      fountainText: "EXT. STREET - NIGHT",
      snapshotReason: OcptSnapshotReason.manual,
    );
    await service.snapshotOnProjectOpen(database: preview, screenplayId: screenplayId);

    // The user may not edit a version they are only reading, and the UI having hidden the
    // affordance isn't what makes that true: the service refuses the write itself.
    expect(
      await service.loadScreenplayText(database: preview, screenplayId: screenplayId),
      "INT. HOUSE - DAY",
    );
    expect(await preview.select(preview.ocptScreenplaySnapshotsTable).get(), isEmpty);
  });

  test('saveScreenplayText reconciles the cast, inserting a speaking role per character',
      () async {
    await service.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: 'INT. HOUSE - DAY\n\nJOHN\nHello.\n\nMARY\nHi back.\n',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final roles = await (database.select(database.ocptRolesTable)
          ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
        .get();

    expect(roles, hasLength(2));
    expect(roles.map((role) => role.name), ["JOHN", "MARY"]);
    expect(roles.every((role) => role.isFromScreenplay), isTrue);
    expect(roles.every((role) => role.kind == OcptRoleKind.speaking), isTrue);
  });

  test('a save whose screenplay drops a character orphans that role, keeping its casting',
      () async {
    const roleIndexService = OcptRoleIndexService();

    await database
        .into(database.ocptPeopleTable)
        .insert(OcptPeopleTableCompanion.insert(id: "person-1"));

    await service.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: 'INT. HOUSE - DAY\n\nJOHN\nHello.\n\nMARY\nHi back.\n',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final roles = await roleIndexService.loadRoles(database: database);
    final maryRole = roles.firstWhere((role) => role.name == "MARY");

    await roleIndexService.updateRole(
      database: database,
      roleId: maryRole.id,
      personId: const Value("person-1"),
      castingNotes: const Value("Understudy confirmed"),
    );

    // The next save's screenplay no longer names MARY.
    await service.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: 'INT. HOUSE - DAY\n\nJOHN\nHello.\n',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final row = await (database.select(
      database.ocptRolesTable,
    )..where((table) => table.id.equals(maryRole.id))).getSingle();

    expect(row.orphanedName, "MARY");
    expect(row.personId, "person-1");
    expect(row.castingNotes, "Understudy confirmed");
    expect(row.isDeleted, isFalse);
  });

  test('a hand-added role survives a save mentioning none of its character', () async {
    const roleIndexService = OcptRoleIndexService();

    final handAddedId = await roleIndexService.addRole(
      database: database,
      screenplayId: screenplayId,
      name: "Passerby",
      kind: OcptRoleKind.silent,
    );

    await service.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: 'INT. HOUSE - DAY\n\nJOHN\nHello.\n',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final row = await (database.select(
      database.ocptRolesTable,
    )..where((table) => table.id.equals(handAddedId!))).getSingle();

    expect(row.isDeleted, isFalse);
    expect(row.name, "Passerby");
    expect(row.isFromScreenplay, isFalse);
    expect(row.orphanedName, isNull);
  });

  group('saveScreenplayText reconciles the breakdown tags against the newly saved text', () {
    Future<List<OcptSceneRow>> readScenes() =>
        (database.select(database.ocptScenesTable)
              ..where((row) => row.isDeleted.equals(false))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();

    Future<OcptBreakdownTagRow> readTag(String id) => (database.select(
      database.ocptBreakdownTagsTable,
    )..where((row) => row.id.equals(id))).getSingle();

    /// Creates a role of [screenplayId], a stand-in tag target since `OcptRoleIndexService.reconcile`
    /// is out of scope here.
    Future<String> createRole() => roleIndexService
        .addRole(database: database, screenplayId: screenplayId, name: "LÉA", kind: OcptRoleKind.silent)
        .then((id) => id!);

    test(
      'a tag whose passage is unchanged is left untouched, and a stale needsCheck is cleared',
      () async {
        const text = "INT. HOUSE - DAY\n\nAction one two.\n";
        await service.saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: text,
          snapshotReason: OcptSnapshotReason.manual,
        );
        final scene = (await readScenes()).single;
        final sceneText = text.substring(scene.charStart, scene.charEnd);
        final roleId = await createRole();
        final start = sceneText.indexOf("two");
        final tagId = (await breakdownService.createTag(
          database: database,
          sceneId: scene.id,
          startOffset: start,
          endOffset: start + "two".length,
          taggedText: "two",
          targetKind: OcptBreakdownTargetKind.role,
          targetId: roleId,
        ))!;
        // Simulate a tag left needing attention by an earlier, unrelated save, so this save's
        // reconciliation has something to clear.
        await (database.update(
          database.ocptBreakdownTagsTable,
        )..where((table) => table.id.equals(tagId))).write(
          const OcptBreakdownTagsTableCompanion(needsCheck: Value(true)),
        );

        // The same text saved again: nothing about the tagged passage changed.
        await service.saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: text,
          snapshotReason: OcptSnapshotReason.manual,
        );

        final tag = await readTag(tagId);
        expect(tag.startOffset, start);
        expect(tag.endOffset, start + "two".length);
        expect(tag.needsCheck, isFalse);
      },
    );

    test(
      'an edit in a preceding scene shifts the tagged scene but never its own offsets',
      () async {
        const originalText = '''
INT. HOUSE - DAY

Action one.

EXT. STREET - NIGHT

Action two three.
''';
        await service.saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: originalText,
          snapshotReason: OcptSnapshotReason.manual,
        );
        final streetScene = (await readScenes()).firstWhere(
          (row) => row.heading == "EXT. STREET - NIGHT",
        );
        final sceneText = originalText.substring(streetScene.charStart, streetScene.charEnd);
        final roleId = await createRole();
        final start = sceneText.indexOf("two");
        final tagId = (await breakdownService.createTag(
          database: database,
          sceneId: streetScene.id,
          startOffset: start,
          endOffset: start + "two".length,
          taggedText: "two",
          targetKind: OcptBreakdownTargetKind.role,
          targetId: roleId,
        ))!;

        // Only the house scene, above the tagged one, grows.
        const editedText = '''
INT. HOUSE - DAY

Action one, with a lot more happening in this scene now.

EXT. STREET - NIGHT

Action two three.
''';
        await service.saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: editedText,
          snapshotReason: OcptSnapshotReason.manual,
        );

        final newStreetScene = (await readScenes()).firstWhere(
          (row) => row.heading == "EXT. STREET - NIGHT",
        );
        // The scene itself moved further into the document...
        expect(newStreetScene.charStart, isNot(streetScene.charStart));
        // ...but the tag's scene-relative offsets, untouched by an edit outside its own scene,
        // did not move.
        final tag = await readTag(tagId);
        expect(tag.startOffset, start);
        expect(tag.endOffset, start + "two".length);
        expect(tag.needsCheck, isFalse);
      },
    );

    test('an edit earlier inside the tagged scene re-anchors the tag silently', () async {
      const text = "INT. HOUSE - DAY\n\nAction one two.\n";
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: text,
        snapshotReason: OcptSnapshotReason.manual,
      );
      final scene = (await readScenes()).single;
      final sceneText = text.substring(scene.charStart, scene.charEnd);
      final roleId = await createRole();
      final start = sceneText.indexOf("two");
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: start,
        endOffset: start + "two".length,
        taggedText: "two",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;

      const editedText = "INT. HOUSE - DAY\n\nAction one, with a lot more happening, two.\n";
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: editedText,
        snapshotReason: OcptSnapshotReason.manual,
      );

      final newScene = (await readScenes()).single;
      final newSceneText = editedText.substring(newScene.charStart, newScene.charEnd);
      final tag = await readTag(tagId);
      // Re-anchored to the new position of the same words, silently.
      expect(tag.startOffset, isNot(start));
      expect(newSceneText.substring(tag.startOffset, tag.endOffset), "two");
      expect(tag.needsCheck, isFalse);
    });

    test('a passage that no longer occurs at all is flagged, offsets left alone', () async {
      const text = "INT. HOUSE - DAY\n\nAction one two.\n";
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: text,
        snapshotReason: OcptSnapshotReason.manual,
      );
      final scene = (await readScenes()).single;
      final sceneText = text.substring(scene.charStart, scene.charEnd);
      final roleId = await createRole();
      final start = sceneText.indexOf("two");
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: start,
        endOffset: start + "two".length,
        taggedText: "two",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;

      const editedText = "INT. HOUSE - DAY\n\nAction one FOUR.\n";
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: editedText,
        snapshotReason: OcptSnapshotReason.manual,
      );

      final tag = await readTag(tagId);
      expect(tag.needsCheck, isTrue);
      expect(tag.startOffset, start);
      expect(tag.endOffset, start + "two".length);
    });

    test('a passage that now occurs twice is flagged, offsets left alone', () async {
      const text = "INT. HOUSE - DAY\n\nAction alpha beta.\n";
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: text,
        snapshotReason: OcptSnapshotReason.manual,
      );
      final scene = (await readScenes()).single;
      final sceneText = text.substring(scene.charStart, scene.charEnd);
      final roleId = await createRole();
      final start = sceneText.indexOf("beta");
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: start,
        endOffset: start + "beta".length,
        taggedText: "beta",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;

      // Inserting a word before "alpha" shifts the stored offset off "beta", and a second "beta"
      // appears right after the first: now ambiguous.
      const editedText = "INT. HOUSE - DAY\n\nAction extra alpha beta beta.\n";
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: editedText,
        snapshotReason: OcptSnapshotReason.manual,
      );

      final tag = await readTag(tagId);
      expect(tag.needsCheck, isTrue);
      expect(tag.startOffset, start);
      expect(tag.endOffset, start + "beta".length);
    });
  });

  group('episodes', () {
    // The outer setUp inserts `screenplayId` with the `sortKey` column's raw default (the empty
    // string), never having gone through `ocptFractionalKeyBetween` the way a real project's first
    // episode does (schema v18's migration allocates it a real key). An empty string is a valid
    // lower bound but not a valid upper one — nothing sorts below it — so a reorder landing an
    // episode ahead of it would find no key to allocate. Giving it a real key here is what the
    // migration already guarantees in production; it is not this method's concern.
    setUp(() async {
      await (database.update(
        database.ocptScreenplaysTable,
      )..where((table) => table.id.equals(screenplayId))).write(
        OcptScreenplaysTableCompanion(sortKey: Value(ocptFractionalKeyBetween())),
      );
    });

    Future<OcptScreenplayRow> readEpisode(String id) => (database.select(
      database.ocptScreenplaysTable,
    )..where((table) => table.id.equals(id))).getSingle();

    test('loadEpisodes returns live episodes in sortKey order, leaving tombstoned ones out',
        () async {
      final secondId = (await service.createEpisode(database: database, title: "Ep 2"))!;
      final thirdId = (await service.createEpisode(database: database, title: "Ep 3"))!;

      // A middle episode removed some other way is still a tombstone `loadEpisodes` must filter.
      await (database.update(
        database.ocptScreenplaysTable,
      )..where((table) => table.id.equals(secondId))).write(
        const OcptScreenplaysTableCompanion(isDeleted: Value(true)),
      );

      final episodes = await service.loadEpisodes(database: database);

      expect(episodes.map((episode) => episode.id), [screenplayId, thirdId]);
    });

    test(
      'createEpisode appends after the last live episode and numbers it last + 1, and honours '
      'an explicit number',
      () async {
        final secondId = (await service.createEpisode(database: database, title: "Ep 2"))!;

        final afterSecond = await service.loadEpisodes(database: database);
        expect(afterSecond.map((episode) => episode.id), [screenplayId, secondId]);
        final second = afterSecond.firstWhere((episode) => episode.id == secondId);
        expect(second.number, 2);
        expect(second.title, "Ep 2");

        final explicitId = (await service.createEpisode(database: database, number: 99))!;

        final afterExplicit = await service.loadEpisodes(database: database);
        // Appended at the tail, whatever its own printed number turned out to be.
        expect(afterExplicit.last.id, explicitId);
        expect(afterExplicit.firstWhere((episode) => episode.id == explicitId).number, 99);
      },
    );

    test('updateEpisode writes only what it is given, touching neither sortKey, fountainText '
        'nor updatedAt', () async {
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: "INT. HOUSE - DAY\n\nAction.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );
      final before = await readEpisode(screenplayId);

      await service.updateEpisode(
        database: database,
        screenplayId: screenplayId,
        title: const Value("Pilot"),
        number: const Value(7),
      );

      final after = await readEpisode(screenplayId);
      expect(after.title, "Pilot");
      expect(after.number, 7);
      expect(after.sortKey, before.sortKey);
      expect(after.fountainText, before.fountainText);
      expect(after.updatedAt, before.updatedAt);
    });

    test('reorderEpisode moves an episode and writes exactly one row, leaving every number alone',
        () async {
      final secondId = (await service.createEpisode(database: database, title: "Ep 2"))!;
      final thirdId = (await service.createEpisode(database: database, title: "Ep 3"))!;

      final before = {
        for (final row in await database.select(database.ocptScreenplaysTable).get())
          row.id: row,
      };

      // The third episode moves to the front.
      await service.reorderEpisode(database: database, screenplayId: thirdId, newPosition: 0);

      final after = await database.select(database.ocptScreenplaysTable).get();
      final order = (await service.loadEpisodes(database: database))
          .map((episode) => episode.id)
          .toList();
      expect(order, [thirdId, screenplayId, secondId]);

      final rowsWithChangedSortKey = after
          .where((row) => row.sortKey != before[row.id]!.sortKey)
          .toList(growable: false);
      expect(rowsWithChangedSortKey, hasLength(1));
      expect(rowsWithChangedSortKey.single.id, thirdId);

      for (final row in after) {
        expect(row.number, before[row.id]!.number);
      }
    });

    test("deleteEpisode refuses to remove the project's last live episode, writing nothing",
        () async {
      final result = await service.deleteEpisode(database: database, screenplayId: screenplayId);

      expect(result, isFalse);
      final row = await readEpisode(screenplayId);
      expect(row.isDeleted, isFalse);
    });

    test('a deleteEpisode handed the read-only database of a previewed version is refused',
        () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(preview.close);

      await preview
          .into(preview.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(
              id: screenplayId,
              title: "Draft",
              updatedAt: DateTime.now(),
            ),
          );
      await preview
          .into(preview.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(
              id: "screenplay-2",
              title: "Second",
              updatedAt: DateTime.now(),
              sortKey: const Value("A"),
            ),
          );

      final result = await service.deleteEpisode(database: preview, screenplayId: screenplayId);

      expect(result, isFalse);
      final row = await (preview.select(
        preview.ocptScreenplaysTable,
      )..where((table) => table.id.equals(screenplayId))).getSingle();
      expect(row.isDeleted, isFalse);
    });

    test(
      'deleteEpisode tombstones everything the deleted episode owns, and leaves everything else',
      () async {
        final otherScreenplayId = (await service.createEpisode(
          database: database,
          title: "Episode 2",
        ))!;

        // The deleted episode's own text: JOHN speaks only here, MARY speaks here and elsewhere.
        await service.saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: 'INT. HOUSE - DAY\n\nJOHN\nHello.\n\nMARY\nHi back.\n',
          snapshotReason: OcptSnapshotReason.manual,
        );
        // The surviving episode's own text: MARY also speaks here.
        await service.saveScreenplayText(
          database: database,
          screenplayId: otherScreenplayId,
          fountainText: 'INT. GARDEN - DAY\n\nMARY\nStill here.\n',
          snapshotReason: OcptSnapshotReason.manual,
        );

        final scene = await (database.select(
          database.ocptScenesTable,
        )..where((table) => table.screenplayId.equals(screenplayId))).getSingle();
        final otherScene = await (database.select(
          database.ocptScenesTable,
        )..where((table) => table.screenplayId.equals(otherScreenplayId))).getSingle();

        final roles = await roleIndexService.loadRoles(database: database);
        final johnRole = roles.firstWhere((role) => role.name == "JOHN");
        final maryRole = roles.firstWhere((role) => role.name == "MARY");

        // A shot of the deleted episode's scene, carrying a character and a coverage range.
        final shotId = (await shotListService.createShot(
          database: database,
          screenplayId: screenplayId,
          sceneId: scene.id,
        ))!;
        await shotListService.attachCharacter(
          database: database,
          shotId: shotId,
          characterName: "JOHN",
        );
        final screenplayText = await service.loadScreenplayText(
          database: database,
          screenplayId: screenplayId,
        );
        final sceneText = screenplayText.substring(scene.charStart, scene.charEnd);
        final coverageStart = sceneText.indexOf("Hello");
        await shotCoverageService.addRange(
          database: database,
          shotId: shotId,
          sceneId: scene.id,
          startOffset: coverageStart,
          endOffset: coverageStart + "Hello".length,
          sceneText: sceneText,
        );

        // A shot of the surviving episode's own scene, untouched by anything below.
        final otherShotId = (await shotListService.createShot(
          database: database,
          screenplayId: otherScreenplayId,
          sceneId: otherScene.id,
        ))!;

        // A breakdown tag of the deleted episode's scene, pointing at the role speaking only there.
        final tagId = (await breakdownService.createTag(
          database: database,
          sceneId: scene.id,
          startOffset: 0,
          endOffset: 4,
          taggedText: "JOHN",
          targetKind: OcptBreakdownTargetKind.role,
          targetId: johnRole.id,
        ))!;

        // A scene breakdown status on the deleted episode's scene.
        await breakdownService.updateSceneBreakdown(
          database: database,
          sceneId: scene.id,
          status: const Value(OcptBreakdownSceneStatus.done),
        );

        // A scene_elements link and a scene_sets link on the deleted episode's scene, neither one
        // created through a tag — the plain links the resources mode itself writes.
        final elementId = (await elementsService.createElement(
          database: database,
          name: "Lampe",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        ))!;
        final sceneElementId = (await elementsService.addSceneElement(
          database: database,
          sceneId: scene.id,
          elementId: elementId,
        ))!;
        final locationId = (await locationsService.createLocation(
          database: database,
          name: "La maison",
        ))!;
        final setId = (await locationsService.createSet(
          database: database,
          locationId: locationId,
          name: "Salon",
        ))!;
        final sceneSetId = (await locationsService.assignSceneToSet(
          database: database,
          sceneId: scene.id,
          setId: setId,
        ))!;

        // A shooting day whose one slot holds a block placing the deleted episode's shot, plus a
        // milestone block that places nothing.
        final dayId = (await scheduleService.createDay(database: database, date: DateTime(2026)))!;
        final scheduleBefore = await scheduleService.loadSchedule(database: database);
        final slotId = scheduleBefore.slotsByDayId[dayId]!.single.id;
        final shotBlockId = (await scheduleService.placeShot(
          database: database,
          slotId: slotId,
          shotId: shotId,
        ))!;
        final milestoneBlockId = (await scheduleService.createBlock(
          database: database,
          slotId: slotId,
          kind: OcptShootingBlockKind.preparation,
          label: "Prep",
        ))!;

        final deleted = await service.deleteEpisode(database: database, screenplayId: screenplayId);
        expect(deleted, isTrue);

        // The episode itself, and everything keyed to it or its scenes, is gone.
        expect((await readEpisode(screenplayId)).isDeleted, isTrue);
        expect(
          (await (database.select(
            database.ocptScenesTable,
          )..where((table) => table.id.equals(scene.id))).getSingle()).isDeleted,
          isTrue,
        );
        expect(
          (await (database.select(
            database.ocptShotsTable,
          )..where((table) => table.id.equals(shotId))).getSingle()).isDeleted,
          isTrue,
        );
        expect(
          await (database.select(database.ocptShotCharactersTable)..where(
                (table) => table.shotId.equals(shotId) & table.isDeleted.not(),
              ))
              .get(),
          isEmpty,
        );
        expect(
          await (database.select(database.ocptShotCoveragesTable)..where(
                (table) => table.shotId.equals(shotId) & table.isDeleted.not(),
              ))
              .get(),
          isEmpty,
        );
        expect(
          (await (database.select(
            database.ocptBreakdownTagsTable,
          )..where((table) => table.id.equals(tagId))).getSingle()).isDeleted,
          isTrue,
        );
        expect(
          await (database.select(database.ocptSceneBreakdownsTable)..where(
                (table) => table.sceneId.equals(scene.id) & table.isDeleted.not(),
              ))
              .get(),
          isEmpty,
        );
        expect(
          (await (database.select(
            database.ocptSceneElementsTable,
          )..where((table) => table.id.equals(sceneElementId))).getSingle()).isDeleted,
          isTrue,
        );
        expect(
          (await (database.select(
            database.ocptSceneSetsTable,
          )..where((table) => table.id.equals(sceneSetId))).getSingle()).isDeleted,
          isTrue,
        );
        expect(
          await (database.select(database.ocptScreenplaySnapshotsTable)..where(
                (table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not(),
              ))
              .get(),
          isEmpty,
        );
        expect(
          await (database.select(database.ocptRoleEpisodesTable)..where(
                (table) =>
                    table.screenplayId.equals(screenplayId) & table.isDeleted.not(),
              ))
              .get(),
          isEmpty,
        );
        expect(
          (await (database.select(
            database.ocptShootingDayBlocksTable,
          )..where((table) => table.id.equals(shotBlockId))).getSingle()).isDeleted,
          isTrue,
        );

        // Everything the deleted episode never owned is exactly as it was.
        final otherEpisode = await readEpisode(otherScreenplayId);
        expect(otherEpisode.isDeleted, isFalse);
        expect(
          (await (database.select(
            database.ocptScenesTable,
          )..where((table) => table.id.equals(otherScene.id))).getSingle()).isDeleted,
          isFalse,
        );
        expect(
          (await (database.select(
            database.ocptShotsTable,
          )..where((table) => table.id.equals(otherShotId))).getSingle()).isDeleted,
          isFalse,
        );

        final day = await (database.select(
          database.ocptShootingDaysTable,
        )..where((table) => table.id.equals(dayId))).getSingle();
        expect(day.isDeleted, isFalse);
        final slot = await (database.select(
          database.ocptShootingSlotsTable,
        )..where((table) => table.id.equals(slotId))).getSingle();
        expect(slot.isDeleted, isFalse);
        final milestoneBlock = await (database.select(
          database.ocptShootingDayBlocksTable,
        )..where((table) => table.id.equals(milestoneBlockId))).getSingle();
        expect(milestoneBlock.isDeleted, isFalse);

        final element = await (database.select(
          database.ocptElementsTable,
        )..where((table) => table.id.equals(elementId))).getSingle();
        expect(element.isDeleted, isFalse);
        final location = await (database.select(
          database.ocptLocationsTable,
        )..where((table) => table.id.equals(locationId))).getSingle();
        expect(location.isDeleted, isFalse);
        final set = await (database.select(
          database.ocptSetsTable,
        )..where((table) => table.id.equals(setId))).getSingle();
        expect(set.isDeleted, isFalse);

        // JOHN spoke only in the deleted episode: the role itself survives, un-orphaned, simply
        // named in no episode any more.
        final johnRow = await (database.select(
          database.ocptRolesTable,
        )..where((table) => table.id.equals(johnRole.id))).getSingle();
        expect(johnRow.isDeleted, isFalse);
        expect(johnRow.orphanedName, isNull);
        expect(
          await (database.select(database.ocptRoleEpisodesTable)..where(
                (table) => table.roleId.equals(johnRole.id) & table.isDeleted.not(),
              ))
              .get(),
          isEmpty,
        );

        // MARY spoke in both episodes: she keeps her link to the surviving one.
        final maryRow = await (database.select(
          database.ocptRolesTable,
        )..where((table) => table.id.equals(maryRole.id))).getSingle();
        expect(maryRow.isDeleted, isFalse);
        final maryLinks = await (database.select(database.ocptRoleEpisodesTable)..where(
              (table) => table.roleId.equals(maryRole.id) & table.isDeleted.not(),
            ))
            .get();
        expect(maryLinks.map((link) => link.screenplayId), [otherScreenplayId]);
      },
    );
  });
}
