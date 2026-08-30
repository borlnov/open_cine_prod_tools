// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_screenplay_merge_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_screenplay_merge_conflict.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:uuid/uuid.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton —
  // this class's own `_nearestCommonBaseText` "no snapshot found" path logs the same way.
  setUpAll(() => OcptGlobalManager.instance);

  const screenplayId = 'screenplay-1';
  const deviceId = 'test-device';
  Future<String> testDeviceId() async => deviceId;

  final assetsService = OcptAssetsService(deviceId: testDeviceId);
  final roleCandidatesService = OcptRoleCandidatesService(deviceId: testDeviceId);
  final elementsService = OcptElementsService(assetsService: assetsService, deviceId: testDeviceId);
  final locationsService = OcptLocationsService(assetsService: assetsService, deviceId: testDeviceId);
  final roleIndexService = OcptRoleIndexService(
    elementsService: elementsService,
    roleCandidatesService: roleCandidatesService,
    deviceId: testDeviceId,
  );
  final breakdownService = OcptBreakdownService(
    elementsService: elementsService,
    locationsService: locationsService,
    deviceId: testDeviceId,
  );
  final scheduleService = OcptScheduleService(deviceId: testDeviceId);
  const sceneIndexService = OcptSceneIndexService();
  final shotListService = OcptShotListService(deviceId: testDeviceId);
  final shotCoverageService = OcptShotCoverageService(deviceId: testDeviceId);
  final screenplayService = OcptScreenplayService(
    sceneIndexService: sceneIndexService,
    shotListService: shotListService,
    shotCoverageService: shotCoverageService,
    roleIndexService: roleIndexService,
    breakdownService: breakdownService,
    scheduleService: scheduleService,
    deviceId: testDeviceId,
  );
  final mergeService = OcptScreenplayMergeService(screenplayService: screenplayService, deviceId: testDeviceId);

  late OcptProjectDatabase database;

  setUp(() async {
    database = OcptProjectDatabase.memory();
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: screenplayId, title: 'Title', updatedAt: DateTime.utc(2026)),
        );
  });

  tearDown(() async {
    await database.close();
  });

  /// Sets the screenplay's stored text directly, bypassing `saveScreenplayText` entirely — used to
  /// put the row in a known state without generating a snapshot or a stamp of its own, exactly as
  /// `ocpt_merge_service_test.dart`'s own fixtures bypass `OcptRowStampService` for a baseline.
  Future<void> setStoredTextDirectly(String text) async {
    final current = await (database.select(
      database.ocptScreenplaysTable,
    )..where((table) => table.id.equals(screenplayId))).getSingle();
    await database
        .into(database.ocptScreenplaysTable)
        .insertOnConflictUpdate(current.copyWith(fountainText: text).toCompanion(false));
  }

  /// Inserts a live snapshot row for the screenplay directly, with a caller-chosen `createdAt` —
  /// used to control which of several snapshots the "nearest common base" heuristic should pick.
  Future<void> insertSnapshotDirectly({required String fountainText, required DateTime createdAt}) =>
      database
          .into(database.ocptScreenplaySnapshotsTable)
          .insert(
            OcptScreenplaySnapshotsTableCompanion.insert(
              id: const Uuid().v4(),
              screenplayId: screenplayId,
              createdAt: createdAt,
              reason: OcptSnapshotReason.manual,
              fountainText: fountainText,
            ),
          );

  Future<String> storedText() =>
      screenplayService.loadScreenplayText(database: database, screenplayId: screenplayId);

  test('an incoming text identical to the local one needs no merge at all', () async {
    await setStoredTextDirectly('INT. HOUSE - DAY\n\nAction.');

    final conflict = await mergeService.mergeIncomingFountainText(
      fileDatabase: database,
      screenplayId: screenplayId,
      incomingText: 'INT. HOUSE - DAY\n\nAction.',
    );

    expect(conflict, isNull);
    expect(await storedText(), 'INT. HOUSE - DAY\n\nAction.');
  });

  test('no common snapshot at all is surfaced as a full-text conflict, not a crash', () async {
    await setStoredTextDirectly('local text');

    final conflict = await mergeService.mergeIncomingFountainText(
      fileDatabase: database,
      screenplayId: screenplayId,
      incomingText: 'incoming text',
    );

    expect(
      conflict,
      const OcptScreenplayMergeConflict(
        screenplayId: screenplayId,
        baseText: '',
        localText: 'local text',
        incomingText: 'incoming text',
      ),
    );
    // Nothing was overwritten.
    expect(await storedText(), 'local text');
  });

  test('a clean merge writes the merged text back and recomputes scenes', () async {
    // The snapshot is what saveScreenplayText itself takes, right before the overwrite: it
    // captures the original text as the merge base, exactly like a real edit would.
    await setStoredTextDirectly('INT. HOUSE - DAY\n\nAction one.\n\nEXT. STREET - NIGHT\n\nAction two.');
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: 'INT. HOUSE - DAY\n\nAction one, local.\n\nEXT. STREET - NIGHT\n\nAction two.',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final conflict = await mergeService.mergeIncomingFountainText(
      fileDatabase: database,
      screenplayId: screenplayId,
      incomingText: 'INT. HOUSE - DAY\n\nAction one.\n\nEXT. STREET - NIGHT\n\nAction two, incoming.',
    );

    expect(conflict, isNull);
    expect(
      await storedText(),
      'INT. HOUSE - DAY\n\nAction one, local.\n\nEXT. STREET - NIGHT\n\nAction two, incoming.',
    );

    final scenes = await (database.select(
      database.ocptScenesTable,
    )..orderBy([(table) => OrderingTerm.asc(table.position)])).get();
    expect(scenes.map((scene) => scene.heading), ['INT. HOUSE - DAY', 'EXT. STREET - NIGHT']);
  });

  test('a clean merge snapshots the pre-merge text, tagged merge', () async {
    // "c" sits between the two edits, unchanged on both sides: the anchor line3 alignment needs
    // between two independent edits to be treated as non-overlapping, exactly as
    // `ocpt_three_way_merge_test.dart`'s own "non-overlapping changes" case does.
    await setStoredTextDirectly('a\nb\nc\nd\ne');
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: 'a\nb-local\nc\nd\ne',
      snapshotReason: OcptSnapshotReason.manual,
    );

    await mergeService.mergeIncomingFountainText(
      fileDatabase: database,
      screenplayId: screenplayId,
      incomingText: 'a\nb\nc\nd-incoming\ne',
    );

    final mergeSnapshots =
        await (database.select(database.ocptScreenplaySnapshotsTable)
              ..where((table) => table.reason.equalsValue(OcptSnapshotReason.merge)))
            .get();

    expect(mergeSnapshots, hasLength(1));
    expect(mergeSnapshots.single.fountainText, 'a\nb-local\nc\nd\ne');
  });

  test('overlapping edits are a conflict, and the local text is left untouched', () async {
    await setStoredTextDirectly('a\nb\nc');
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: 'a\nb-local\nc',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final conflict = await mergeService.mergeIncomingFountainText(
      fileDatabase: database,
      screenplayId: screenplayId,
      incomingText: 'a\nb-incoming\nc',
    );

    expect(
      conflict,
      const OcptScreenplayMergeConflict(
        screenplayId: screenplayId,
        baseText: 'a\nb\nc',
        localText: 'a\nb-local\nc',
        incomingText: 'a\nb-incoming\nc',
      ),
    );

    // Nothing was lost or overwritten: the local text is exactly as it stood.
    expect(await storedText(), 'a\nb-local\nc');
    final scenes = await database.select(database.ocptScenesTable).get();
    expect(scenes, isEmpty);
  });

  test('the nearest common base is the most recent live snapshot, not just any snapshot', () async {
    // An older snapshot holding content unrelated to what local/incoming actually derive from: if
    // this were picked as the base by mistake, neither side's text would share a single line with
    // it, and the merge would see a whole-document rewrite on both sides — a conflict, not the
    // clean merge this test expects.
    await insertSnapshotDirectly(fountainText: 'AAAA\nBBBB\nCCCC', createdAt: DateTime.utc(2026));
    // The true, more recent common ancestor both local and incoming actually edited from.
    await insertSnapshotDirectly(fountainText: 'line1\nline2\nline3', createdAt: DateTime.utc(2026, 6));

    await setStoredTextDirectly('line1-edited\nline2\nline3');

    final conflict = await mergeService.mergeIncomingFountainText(
      fileDatabase: database,
      screenplayId: screenplayId,
      incomingText: 'line1\nline2\nline3-edited',
    );

    expect(conflict, isNull);
    expect(await storedText(), 'line1-edited\nline2\nline3-edited');
  });
}
