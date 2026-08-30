// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_display_number.dart';
import 'package:uuid/uuid.dart';

/// CRUD over a screenplay's shot list: its shots, their attached characters, and detaching them
/// when the scene they belonged to is deleted from the screenplay.
///
/// A "sequence" is never a stored row: this service builds
/// [OcptShotSequence] objects in memory, by joining the already-ordered `scenes` rows with the
/// shots that reference them. Everything about a coverage range's staleness lives in
/// `OcptShotCoverageService`, this service's sibling; this one only reads coverage rows back
/// unchanged to build [OcptShot.coverageRanges].
///
/// {@template open_cine_prod_tools.tombstones}
/// **Nothing here deletes a row.** Every "delete" sets the row's `isDeleted` flag and every read
/// filters flagged rows back out, so a replica that was offline when a row went away can still
/// learn that it did — see `docs/adr/0010-sync-ready-data-model-prerequisites.md`.
/// {@endtemplate}
///
/// **Order is `sortKey`, never `position`.** A group's rows are ordered by their fractional index,
/// so inserting or moving one writes exactly that one row rather than renumbering the whole group.
/// `position` survives only as the legacy column ADR 0007 forbids dropping in place.
class OcptShotListService {
  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter]. [detachShotsFromDeletedScenes] never calls it: it writes inside a
  /// caller's own transaction, and takes that caller's own [OcptRowStampService] instead.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptShotListService({required this.deviceId});

  /// Loads the whole shot list of [screenplayId] in [database]: every scene, in order, with its
  /// shots, followed by the orphan group if the screenplay has any orphaned shot.
  ///
  /// Runs exactly three queries against `shots`, `shot_characters` and `shot_coverages` (a shot
  /// list is hundreds of rows, not millions, so joining them in memory here is cheap and keeps
  /// each query trivial to read), plus the `scenes` query every sequence is built from. Each of
  /// them filters tombstones out.
  ///
  /// A range's [OcptShotCoverageRange.isStale] here is not recomputed against the current
  /// screenplay text (that would need a further query this method deliberately doesn't run): it
  /// mirrors the owning shot's own `needsCheck`, restricted to a coverage-related
  /// [OcptShotCheckReason] (`coveredTextChanged` or `coverageOutOfBounds`), applied to every range
  /// of that shot alike. `OcptShotCoverageService.refreshStaleness` is the one place that decides
  /// staleness precisely, at save time; nothing here second-guesses it.
  ///
  /// [episodeNumber] is this screenplay's own episode number, or null when the project holds a
  /// single episode — passed in rather than looked up: this service has no reason to depend on
  /// `OcptScreenplayService`, which already depends on this one for the shot list a version restore
  /// needs (dependencies never reference their dependents). It only prefixes
  /// [OcptSceneShotSequence.displaySceneNumber]; the orphaned-shot placeholder is never prefixed,
  /// since an orphan belongs to no scene and so has no number to qualify.
  Future<OcptShotListSnapshot> loadShotList({
    required OcptProjectDatabase database,
    required String screenplayId,
    required int? episodeNumber,
  }) async {
    final sceneRows =
        await (database.select(database.ocptScenesTable)
              ..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();

    final shotRows =
        await (database.select(database.ocptShotsTable)
              ..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
            .get();

    final shotIds = shotRows.map((row) => row.id).toList(growable: false);

    final characterRows = shotIds.isEmpty
        ? const <OcptShotCharacterRow>[]
        : await (database.select(database.ocptShotCharactersTable)
                ..where((table) => table.shotId.isIn(shotIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final coverageRows = shotIds.isEmpty
        ? const <OcptShotCoverageRow>[]
        : await (database.select(database.ocptShotCoveragesTable)..where(
                (table) => table.shotId.isIn(shotIds) & table.isDeleted.not(),
              ))
              .get();

    final charactersByShotId = <String, List<String>>{};
    for (final row in characterRows) {
      charactersByShotId.putIfAbsent(row.shotId, () => []).add(row.characterName);
    }

    final coverageRowsByShotId = <String, List<OcptShotCoverageRow>>{};
    for (final row in coverageRows) {
      coverageRowsByShotId.putIfAbsent(row.shotId, () => []).add(row);
    }

    final shotRowsBySceneId = <String, List<OcptShotRow>>{};
    final orphanedShotRows = <OcptShotRow>[];
    for (final row in shotRows) {
      final sceneId = row.sceneId;
      if (sceneId == null) {
        orphanedShotRows.add(row);
      } else {
        shotRowsBySceneId.putIfAbsent(sceneId, () => []).add(row);
      }
    }

    OcptShot buildShot(OcptShotRow row, String sceneDisplayNumber, int rank) {
      final isCoverageStale =
          row.needsCheck &&
          (row.checkReason == OcptShotCheckReason.coveredTextChanged ||
              row.checkReason == OcptShotCheckReason.coverageOutOfBounds);

      return OcptShot.fromRow(
        row: row,
        position: rank,
        sceneDisplayNumber: sceneDisplayNumber,
        characters: charactersByShotId[row.id] ?? const [],
        coverageRanges: [
          for (final coverageRow in coverageRowsByShotId[row.id] ?? const <OcptShotCoverageRow>[])
            OcptShotCoverageRange.fromRow(row: coverageRow, isStale: isCoverageStale),
        ],
      );
    }

    final sequences = <OcptShotSequence>[
      for (var i = 0; i < sceneRows.length; i++)
        _buildSceneSequence(sceneRows[i], i, episodeNumber, shotRowsBySceneId, buildShot),
    ];

    if (orphanedShotRows.isNotEmpty) {
      sequences.add(
        OcptOrphanShotSequence(
          shots: [
            for (var i = 0; i < orphanedShotRows.length; i++)
              buildShot(orphanedShotRows[i], _orphanSceneDisplayNumber, i),
          ],
        ),
      );
    }

    return OcptShotListSnapshot.build(screenplayId: screenplayId, sequences: sequences);
  }

  /// The placeholder shown in place of a scene number in an orphaned shot's [OcptShot.code]: the
  /// scene the shot originally belonged to no longer exists, and its original number was never
  /// stored (only its heading is, in [OcptShotRow.orphanedHeading]), so there is no real number
  /// left to derive a code from.
  static const _orphanSceneDisplayNumber = "—";

  /// Builds the [OcptSceneShotSequence] for the scene at [sceneRow], whose 0-based index among the
  /// screenplay's scenes is [sceneIndex], prefixed with [episodeNumber] through
  /// `ocptSceneDisplayNumberOf`.
  ///
  /// [shotRowsBySceneId] holds each scene's shots in the order the `sortKey` query returned them,
  /// which is the order they display in and the order their codes are numbered from.
  static OcptSceneShotSequence _buildSceneSequence(
    OcptSceneRow sceneRow,
    int sceneIndex,
    int? episodeNumber,
    Map<String, List<OcptShotRow>> shotRowsBySceneId,
    OcptShot Function(OcptShotRow row, String sceneDisplayNumber, int rank) buildShot,
  ) {
    final displayNumber = ocptSceneDisplayNumberOf(
      sceneNumber: sceneRow.sceneNumber,
      position: sceneIndex,
      episodeNumber: episodeNumber,
    );
    final shotRows = shotRowsBySceneId[sceneRow.id] ?? const <OcptShotRow>[];

    return OcptSceneShotSequence(
      sceneId: sceneRow.id,
      heading: sceneRow.heading,
      sceneNumber: sceneRow.sceneNumber,
      displaySceneNumber: displayNumber,
      charStart: sceneRow.charStart,
      charEnd: sceneRow.charEnd,
      shots: [
        for (var i = 0; i < shotRows.length; i++) buildShot(shotRows[i], displayNumber, i),
      ],
    );
  }

  /// Creates a new shot in scene [sceneId] of screenplay [screenplayId] in [database], appended at
  /// the end of the scene's current shots, and returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  ///
  /// The refusal is what makes the returned id nullable: null means no shot was created, and the
  /// caller has nothing to select.
  Future<String?> createShot({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String sceneId,
  }) async {
    if (database.refusesUserWrite("createShot")) {
      return null;
    }

    final existing = await _shotRowsOfGroup(
      database: database,
      screenplayId: screenplayId,
      sceneId: sceneId,
    );

    final id = const Uuid().v4();
    // Every column [OcptShotsTable] declares a default for is spelled out here to match it exactly:
    // [OcptRowStampService.writeAndStamp] stamps a fresh insert from the full row it is handed,
    // never from what SQLite would fill in on its own.
    final row = OcptShotRow(
      id: id,
      screenplayId: screenplayId,
      sceneId: sceneId,
      position: existing.length,
      sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
      shotSize: "",
      abbreviation: "",
      framing: "",
      cameraMove: "",
      lens: "",
      recordingFormat: "",
      sound: "",
      status: OcptShotStatus.toShoot,
      difficultySet: 1,
      difficultyCamera: 1,
      difficultyActing: 1,
      difficultySound: 1,
      notes: "",
      locationNotes: "",
      needsCheck: false,
      isDeleted: false,
    );

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShotsTable,
        rowId: id,
        current: null,
        next: row,
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates the fields of the shot [shotId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches [shotId]'s `sortKey`, `sceneId` or `orphanedHeading`: those are
  /// only ever changed by [reorderShot] and [detachShotsFromDeletedScenes].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateShot({
    required OcptProjectDatabase database,
    required String shotId,
    Value<String> shotSize = const Value.absent(),
    Value<String> abbreviation = const Value.absent(),
    Value<String> framing = const Value.absent(),
    Value<String> cameraMove = const Value.absent(),
    Value<String> lens = const Value.absent(),
    Value<String> recordingFormat = const Value.absent(),
    Value<int?> estimatedDurationMs = const Value.absent(),
    Value<String?> shootingDay = const Value.absent(),
    Value<int?> plannedTakes = const Value.absent(),
    Value<String> sound = const Value.absent(),
    Value<OcptShotStatus> status = const Value.absent(),
    Value<int> difficultySet = const Value.absent(),
    Value<int> difficultyCamera = const Value.absent(),
    Value<int> difficultyActing = const Value.absent(),
    Value<int> difficultySound = const Value.absent(),
    Value<String> notes = const Value.absent(),
    Value<String> locationNotes = const Value.absent(),
    Value<bool> needsCheck = const Value.absent(),
    Value<OcptShotCheckReason?> checkReason = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateShot")) {
      return;
    }

    final companion = OcptShotsTableCompanion(
      shotSize: shotSize,
      abbreviation: abbreviation,
      framing: framing,
      cameraMove: cameraMove,
      lens: lens,
      recordingFormat: recordingFormat,
      estimatedDurationMs: estimatedDurationMs,
      shootingDay: shootingDay,
      plannedTakes: plannedTakes,
      sound: sound,
      status: status,
      difficultySet: difficultySet,
      difficultyCamera: difficultyCamera,
      difficultyActing: difficultyActing,
      difficultySound: difficultySound,
      notes: notes,
      locationNotes: locationNotes,
      needsCheck: needsCheck,
      checkReason: checkReason,
    );

    await database.transaction(() async {
      final current = await _liveShotRowOrNull(database: database, shotId: shotId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShotsTable,
        rowId: shotId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones the shot [shotId] in [database], its attached characters and coverage ranges along
  /// with it.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// The shots left in the group keep the `sortKey` they had: removing one from an ascending run
  /// leaves the rest ascending, so a deletion writes only what it deletes.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteShot({required OcptProjectDatabase database, required String shotId}) async {
    if (database.refusesUserWrite("deleteShot")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final coverageRows =
          await (database.select(
                database.ocptShotCoveragesTable,
              )..where((table) => table.shotId.equals(shotId) & table.isDeleted.not()))
              .get();
      for (final row in coverageRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShotCoveragesTable,
          rowId: row.id,
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final characterRows = await _characterRowsOfShot(database: database, shotId: shotId);
      for (final row in characterRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShotCharactersTable,
          rowId: ocptCompositeRowStampKey([row.shotId, row.characterName]),
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final shot = await _liveShotRowOrNull(database: database, shotId: shotId);
      if (shot != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShotsTable,
          rowId: shotId,
          current: shot,
          next: shot.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Moves the shot [shotId] to [newPosition] (0-based) within its own group (its scene, or the
  /// orphan group), by giving it a `sortKey` sitting between the two shots it lands between.
  ///
  /// This writes **exactly one row**, whatever the size of the group and however far the shot
  /// moves. [newPosition] is clamped to the group's bounds, so moving a shot "to the end" can be
  /// expressed with any position at or beyond the group's current shot count.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderShot({
    required OcptProjectDatabase database,
    required String shotId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderShot")) {
      return;
    }

    await database.transaction(() async {
      final shot = await _getShotRow(database: database, shotId: shotId);
      final others =
          (await _shotRowsOfGroup(
            database: database,
            screenplayId: shot.screenplayId,
            sceneId: shot.sceneId,
          ))..removeWhere((row) => row.id == shotId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShotsTable,
        rowId: shotId,
        current: shot,
        next: shot.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Attaches [characterName] (normalised through `fountain_kit`'s `normalizeCharacterName`) to
  /// shot [shotId], appended after its current characters. Does nothing if the shot already has it.
  ///
  /// A character detached earlier left a tombstone behind, and the table's primary key is
  /// `{shotId, characterName}`: re-attaching it therefore lifts that tombstone rather than
  /// inserting a second row, which the key would refuse anyway.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> attachCharacter({
    required OcptProjectDatabase database,
    required String shotId,
    required String characterName,
  }) async {
    if (database.refusesUserWrite("attachCharacter")) {
      return;
    }

    final normalized = normalizeCharacterName(characterName);

    await database.transaction(() async {
      final existing = await _characterRowsOfShot(database: database, shotId: shotId);
      if (existing.any((row) => row.characterName == normalized)) {
        return;
      }

      final sortKey = ocptFractionalKeyBetween(
        before: existing.isEmpty ? null : existing.last.sortKey,
      );

      final tombstone = await _characterRow(
        database: database,
        shotId: shotId,
        characterName: normalized,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      final rowId = ocptCompositeRowStampKey([shotId, normalized]);

      if (tombstone != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShotCharactersTable,
          rowId: rowId,
          current: tombstone,
          next: tombstone.copyWith(sortKey: sortKey, isDeleted: false),
          stamps: stamps,
        );
        await stamps.flush(database);
        return;
      }

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShotCharactersTable,
        rowId: rowId,
        current: null,
        next: OcptShotCharacterRow(
          shotId: shotId,
          characterName: normalized,
          position: existing.length,
          sortKey: sortKey,
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Detaches [characterName] (normalised the same way [attachCharacter] does) from shot [shotId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> detachCharacter({
    required OcptProjectDatabase database,
    required String shotId,
    required String characterName,
  }) async {
    if (database.refusesUserWrite("detachCharacter")) {
      return;
    }

    final normalized = normalizeCharacterName(characterName);

    await database.transaction(() async {
      final current = await _characterRow(
        database: database,
        shotId: shotId,
        characterName: normalized,
      );
      if (current == null || current.isDeleted) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShotCharactersTable,
        rowId: ocptCompositeRowStampKey([shotId, normalized]),
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Reorders shot [shotId]'s characters to [orderedCharacterNames] (normalised the same way
  /// [attachCharacter] does), which must be a permutation of its currently attached characters.
  ///
  /// Only the characters that actually have to move are written: `ocptFractionalKeyRekeyPlan`
  /// leaves the longest run already in ascending order alone, so moving a single character writes
  /// a single row.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderCharacters({
    required OcptProjectDatabase database,
    required String shotId,
    required List<String> orderedCharacterNames,
  }) async {
    if (database.refusesUserWrite("reorderCharacters")) {
      return;
    }

    await database.transaction(() async {
      final rows = await _characterRowsOfShot(database: database, shotId: shotId);
      final rowByName = {for (final row in rows) row.characterName: row};

      final names = [
        for (final name in orderedCharacterNames) normalizeCharacterName(name),
      ]..removeWhere((name) => !rowByName.containsKey(name));

      final plan = ocptFractionalKeyRekeyPlan([
        for (final name in names) rowByName[name]!.sortKey,
      ]);

      if (plan.isEmpty) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      for (final entry in plan.entries) {
        final current = rowByName[names[entry.key]]!;
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShotCharactersTable,
          rowId: ocptCompositeRowStampKey([current.shotId, current.characterName]),
          current: current,
          next: current.copyWith(sortKey: entry.value),
          stamps: stamps,
        );
      }
      await stamps.flush(database);
    });
  }

  /// Removes [characterName] (normalised the same way [attachCharacter] does) from every shot of
  /// screenplay [screenplayId] it is attached to: the deleted-character banner's "remove from every
  /// shot" action.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removeCharacterFromEveryShot({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String characterName,
  }) async {
    if (database.refusesUserWrite("removeCharacterFromEveryShot")) {
      return;
    }

    final normalized = normalizeCharacterName(characterName);
    final shotIds = await _shotIdsOfScreenplay(database: database, screenplayId: screenplayId);
    if (shotIds.isEmpty) {
      return;
    }

    await database.transaction(() async {
      final rows =
          await (database.select(database.ocptShotCharactersTable)..where(
                (table) =>
                    table.shotId.isIn(shotIds) &
                    table.characterName.equals(normalized) &
                    table.isDeleted.not(),
              ))
              .get();
      if (rows.isEmpty) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      for (final row in rows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShotCharactersTable,
          rowId: ocptCompositeRowStampKey([row.shotId, row.characterName]),
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }
      await stamps.flush(database);
    });
  }

  /// Replaces [oldCharacterName] with [newCharacterName] (both normalised the same way
  /// [attachCharacter] does) on every shot of screenplay [screenplayId] it is attached to: the
  /// deleted-character banner's replacement chips.
  ///
  /// The new name takes the place the old one held, so a replacement never reshuffles a shot's
  /// characters. A shot that already has [newCharacterName] attached simply drops
  /// [oldCharacterName] instead of attaching a duplicate (the table's primary key is
  /// `{shotId, characterName}`), and one that only has it as a tombstone lifts that tombstone
  /// rather than inserting against the same key.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> replaceCharacterEverywhere({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String oldCharacterName,
    required String newCharacterName,
  }) async {
    if (database.refusesUserWrite("replaceCharacterEverywhere")) {
      return;
    }

    final normalizedOld = normalizeCharacterName(oldCharacterName);
    final normalizedNew = normalizeCharacterName(newCharacterName);
    if (normalizedOld == normalizedNew) {
      return;
    }

    final shotIds = await _shotIdsOfScreenplay(database: database, screenplayId: screenplayId);
    if (shotIds.isEmpty) {
      return;
    }

    await database.transaction(() async {
      final rows =
          await (database.select(database.ocptShotCharactersTable)..where(
                (table) =>
                    table.shotId.isIn(shotIds) &
                    table.characterName.equals(normalizedOld) &
                    table.isDeleted.not(),
              ))
              .get();
      if (rows.isEmpty) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      for (final row in rows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShotCharactersTable,
          rowId: ocptCompositeRowStampKey([row.shotId, normalizedOld]),
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );

        final existingNew = await _characterRow(
          database: database,
          shotId: row.shotId,
          characterName: normalizedNew,
        );
        final newRowId = ocptCompositeRowStampKey([row.shotId, normalizedNew]);

        if (existingNew == null) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptShotCharactersTable,
            rowId: newRowId,
            current: null,
            next: OcptShotCharacterRow(
              shotId: row.shotId,
              characterName: normalizedNew,
              position: row.position,
              sortKey: row.sortKey,
              isDeleted: false,
            ),
            stamps: stamps,
          );
        } else if (existingNew.isDeleted) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptShotCharactersTable,
            rowId: newRowId,
            current: existingNew,
            next: existingNew.copyWith(sortKey: row.sortKey, isDeleted: false),
            stamps: stamps,
          );
        }
      }

      await stamps.flush(database);
    });
  }

  /// The hook `OcptSceneIndexService.reconcile` invokes, through `OcptScreenplayService`,
  /// immediately before tombstoning [scenesAboutToBeDeleted] in the `scenes` table.
  ///
  /// Every shot of every one of [scenesAboutToBeDeleted] is orphaned: its `sceneId` becomes null,
  /// its `orphanedHeading` becomes the scene's heading, `needsCheck` becomes true with
  /// [OcptShotCheckReason.sceneDeleted], and its coverage ranges are tombstoned (a range anchored
  /// to a scene that no longer exists is meaningless). The newly orphaned shots are appended, in
  /// the order [scenesAboutToBeDeleted] lists their scenes and each scene's own shot order, after
  /// whichever shots were already orphaned, each getting a `sortKey` past the orphan group's
  /// current tail so [OcptOrphanShotSequence] reads grouped by [OcptShot.orphanedHeading] without
  /// any extra grouping logic at read time.
  ///
  /// Called inside `reconcile`'s own transaction: this method does not open one of its own, and
  /// stamps through [stamps] — the caller's own instance, seeded and flushed around the whole
  /// save — rather than resolving a device id of its own.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> detachShotsFromDeletedScenes({
    required OcptProjectDatabase database,
    required List<OcptSceneRow> scenesAboutToBeDeleted,
    required OcptRowStampService? stamps,
  }) async {
    if (database.refusesUserWrite("detachShotsFromDeletedScenes")) {
      return;
    }

    if (scenesAboutToBeDeleted.isEmpty) {
      return;
    }

    // Every scene about to be deleted belongs to the same screenplay: `reconcile` only ever
    // reconciles one screenplay's scenes at a time.
    final screenplayId = scenesAboutToBeDeleted.first.screenplayId;

    final existingOrphans = await _shotRowsOfGroup(
      database: database,
      screenplayId: screenplayId,
      sceneId: null,
    );
    var previousSortKey = existingOrphans.isEmpty ? null : existingOrphans.last.sortKey;
    var nextPosition = existingOrphans.length;

    for (final scene in scenesAboutToBeDeleted) {
      final shotsOfScene = await _shotRowsOfGroup(
        database: database,
        screenplayId: screenplayId,
        sceneId: scene.id,
      );

      for (final shot in shotsOfScene) {
        final coverageRows =
            await (database.select(
                  database.ocptShotCoveragesTable,
                )..where((table) => table.shotId.equals(shot.id) & table.isDeleted.not()))
                .get();
        for (final coverageRow in coverageRows) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptShotCoveragesTable,
            rowId: coverageRow.id,
            current: coverageRow,
            next: coverageRow.copyWith(isDeleted: true),
            stamps: stamps,
          );
        }

        previousSortKey = ocptFractionalKeyBetween(before: previousSortKey);
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShotsTable,
          rowId: shot.id,
          current: shot,
          next: shot.copyWith(
            sceneId: const Value(null),
            orphanedHeading: Value(scene.heading),
            position: nextPosition,
            sortKey: previousSortKey,
            needsCheck: true,
            checkReason: const Value(OcptShotCheckReason.sceneDeleted),
          ),
          stamps: stamps,
        );
        nextPosition++;
      }
    }
  }

  /// Tombstones every live shot of [screenplayId] — across every scene and the orphan group alike —
  /// carrying off its `shot_characters` and `shot_coverages` exactly as [deleteShot] does for one
  /// shot, and returns the ids it tombstoned: `OcptScreenplayService.deleteEpisode`'s cascade, which
  /// needs those ids to also tombstone whatever a schedule block placed of one of them.
  ///
  /// **Unguarded**, exactly as `OcptElementsService.tombstoneRoleLinksOfRole` is: its only caller has
  /// already refused the write on a preview connection and is already inside the transaction
  /// removing the episode, so a second guard here would only be able to disagree with the first —
  /// and stamps through [stamps], that caller's own instance, for the same reason
  /// [detachShotsFromDeletedScenes] does.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<List<String>> tombstoneShotsOfScreenplay({
    required OcptProjectDatabase database,
    required String screenplayId,
    required OcptRowStampService? stamps,
  }) async {
    final shotIds = await _shotIdsOfScreenplay(database: database, screenplayId: screenplayId);
    if (shotIds.isEmpty) {
      return const [];
    }

    final coverageRows =
        await (database.select(
              database.ocptShotCoveragesTable,
            )..where((table) => table.shotId.isIn(shotIds) & table.isDeleted.not()))
            .get();
    for (final row in coverageRows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShotCoveragesTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }

    final characterRows =
        await (database.select(
              database.ocptShotCharactersTable,
            )..where((table) => table.shotId.isIn(shotIds) & table.isDeleted.not()))
            .get();
    for (final row in characterRows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShotCharactersTable,
        rowId: ocptCompositeRowStampKey([row.shotId, row.characterName]),
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }

    final shotRows =
        await (database.select(
              database.ocptShotsTable,
            )..where((table) => table.id.isIn(shotIds) & table.isDeleted.not()))
            .get();
    for (final row in shotRows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShotsTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }

    return shotIds;
  }

  /// Every distinct, non-empty value of `shots.shotSize` across screenplay [screenplayId], for the
  /// field's project-wide suggestion list.
  Future<List<String>> distinctShotSizes({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _distinctValuesOf(
    database: database,
    screenplayId: screenplayId,
    column: (table) => table.shotSize,
  );

  /// Every distinct, non-empty value of `shots.framing` across screenplay [screenplayId], for the
  /// field's project-wide suggestion list.
  Future<List<String>> distinctFramings({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _distinctValuesOf(
    database: database,
    screenplayId: screenplayId,
    column: (table) => table.framing,
  );

  /// Every distinct, non-empty value of `shots.cameraMove` across screenplay [screenplayId], for
  /// the field's project-wide suggestion list.
  Future<List<String>> distinctCameraMoves({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _distinctValuesOf(
    database: database,
    screenplayId: screenplayId,
    column: (table) => table.cameraMove,
  );

  /// Every distinct, non-empty value of `shots.lens` across screenplay [screenplayId], for the
  /// field's project-wide suggestion list.
  Future<List<String>> distinctLenses({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _distinctValuesOf(database: database, screenplayId: screenplayId, column: (table) => table.lens);

  /// Every distinct, non-empty value of `shots.recordingFormat` across screenplay [screenplayId],
  /// for the field's project-wide suggestion list.
  Future<List<String>> distinctRecordingFormats({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _distinctValuesOf(
    database: database,
    screenplayId: screenplayId,
    column: (table) => table.recordingFormat,
  );

  /// Every distinct, non-empty value of `shots.sound` across screenplay [screenplayId], for the
  /// field's project-wide suggestion list.
  Future<List<String>> distinctSounds({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) =>
      _distinctValuesOf(database: database, screenplayId: screenplayId, column: (table) => table.sound);

  /// Collects the distinct, non-empty values of a single free-text column of `shots` across
  /// screenplay [screenplayId], sorted alphabetically.
  Future<List<String>> _distinctValuesOf({
    required OcptProjectDatabase database,
    required String screenplayId,
    required TextColumn Function(OcptShotsTable table) column,
  }) async {
    final query = database.selectOnly(database.ocptShotsTable, distinct: true)
      ..addColumns([column(database.ocptShotsTable)])
      ..where(
        database.ocptShotsTable.screenplayId.equals(screenplayId) &
            database.ocptShotsTable.isDeleted.not() &
            column(database.ocptShotsTable).equals("").not(),
      )
      ..orderBy([OrderingTerm.asc(column(database.ocptShotsTable))]);

    final rows = await query.get();
    return [for (final row in rows) row.read(column(database.ocptShotsTable))!];
  }

  /// Reads back the shot row [shotId], throwing if it doesn't exist or has been tombstoned.
  Future<OcptShotRow> _getShotRow({
    required OcptProjectDatabase database,
    required String shotId,
  }) => (database.select(database.ocptShotsTable)
        ..where((table) => table.id.equals(shotId) & table.isDeleted.not()))
      .getSingle();

  /// Reads back the shot row [shotId], or null if it doesn't exist or has been tombstoned: the
  /// non-throwing sibling of [_getShotRow], for a write that is a silent no-op on a stale id
  /// rather than a bug.
  Future<OcptShotRow?> _liveShotRowOrNull({
    required OcptProjectDatabase database,
    required String shotId,
  }) => (database.select(database.ocptShotsTable)
        ..where((table) => table.id.equals(shotId) & table.isDeleted.not()))
      .getSingleOrNull();

  /// Every live shot row of screenplay [screenplayId] belonging to the group [sceneId] identifies
  /// (a real scene, or the orphan group when [sceneId] is null), ordered by `sortKey`.
  Future<List<OcptShotRow>> _shotRowsOfGroup({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String? sceneId,
  }) {
    final sceneCondition = sceneId == null
        ? database.ocptShotsTable.sceneId.isNull()
        : database.ocptShotsTable.sceneId.equals(sceneId);

    return (database.select(database.ocptShotsTable)
          ..where(
            (table) =>
                table.screenplayId.equals(screenplayId) & sceneCondition & table.isDeleted.not(),
          )
          ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
        .get();
  }

  /// Every live shot id of screenplay [screenplayId], across every scene and the orphan group
  /// alike.
  Future<List<String>> _shotIdsOfScreenplay({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final rows =
        await (database.select(database.ocptShotsTable)..where(
              (table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not(),
            ))
            .get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  /// Every live character row of shot [shotId], ordered by `sortKey`.
  Future<List<OcptShotCharacterRow>> _characterRowsOfShot({
    required OcptProjectDatabase database,
    required String shotId,
  }) => (database.select(database.ocptShotCharactersTable)
        ..where((table) => table.shotId.equals(shotId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();

  /// The `{shotId, characterName}` row, **tombstoned or not**, or null if that pair was never
  /// attached at all: the one read that has to see through tombstones, since the primary key it
  /// looks up is what an insertion would collide with.
  Future<OcptShotCharacterRow?> _characterRow({
    required OcptProjectDatabase database,
    required String shotId,
    required String characterName,
  }) => (database.select(database.ocptShotCharactersTable)..where(
        (table) => table.shotId.equals(shotId) & table.characterName.equals(characterName),
      ))
      .getSingleOrNull();
}
