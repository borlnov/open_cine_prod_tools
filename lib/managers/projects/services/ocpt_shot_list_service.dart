// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:uuid/uuid.dart';

/// CRUD over a screenplay's shot list: its shots, their attached characters, and detaching them
/// when the scene they belonged to is deleted from the screenplay.
///
/// A "sequence" is never a stored row: this service builds
/// [OcptShotSequence] objects in memory, by joining the already-ordered `scenes` rows with the
/// shots that reference them. Everything about a coverage range's staleness lives in
/// `OcptShotCoverageService`, this service's sibling; this one only reads coverage rows back
/// unchanged to build [OcptShot.coverageRanges].
class OcptShotListService {
  /// Class constructor
  const OcptShotListService();

  /// Loads the whole shot list of [screenplayId] in [database]: every scene, in order, with its
  /// shots, followed by the orphan group if the screenplay has any orphaned shot.
  ///
  /// Runs exactly three queries against `shots`, `shot_characters` and `shot_coverages` (a shot
  /// list is hundreds of rows, not millions, so joining them in memory here is cheap and keeps
  /// each query trivial to read), plus the `scenes` query every sequence is built from.
  ///
  /// A range's [OcptShotCoverageRange.isStale] here is not recomputed against the current
  /// screenplay text (that would need a further query this method deliberately doesn't run): it
  /// mirrors the owning shot's own `needsCheck`, restricted to a coverage-related
  /// [OcptShotCheckReason] (`coveredTextChanged` or `coverageOutOfBounds`), applied to every range
  /// of that shot alike. `OcptShotCoverageService.refreshStaleness` is the one place that decides
  /// staleness precisely, at save time; nothing here second-guesses it.
  Future<OcptShotListSnapshot> loadShotList({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final sceneRows =
        await (database.select(database.ocptScenesTable)
              ..where((table) => table.screenplayId.equals(screenplayId))
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();

    final shotRows =
        await (database.select(database.ocptShotsTable)
              ..where((table) => table.screenplayId.equals(screenplayId))
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();

    final shotIds = shotRows.map((row) => row.id).toList(growable: false);

    final characterRows = shotIds.isEmpty
        ? const <OcptShotCharacterRow>[]
        : await (database.select(database.ocptShotCharactersTable)
                ..where((table) => table.shotId.isIn(shotIds))
                ..orderBy([(table) => OrderingTerm.asc(table.position)]))
              .get();

    final coverageRows = shotIds.isEmpty
        ? const <OcptShotCoverageRow>[]
        : await (database.select(
            database.ocptShotCoveragesTable,
          )..where((table) => table.shotId.isIn(shotIds))).get();

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

    OcptShot buildShot(OcptShotRow row, String sceneDisplayNumber) {
      final isCoverageStale =
          row.needsCheck &&
          (row.checkReason == OcptShotCheckReason.coveredTextChanged ||
              row.checkReason == OcptShotCheckReason.coverageOutOfBounds);

      return OcptShot.fromRow(
        row: row,
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
        _buildSceneSequence(sceneRows[i], i, shotRowsBySceneId, buildShot),
    ];

    if (orphanedShotRows.isNotEmpty) {
      final orderedOrphans = List<OcptShotRow>.of(orphanedShotRows)
        ..sort((a, b) => a.position.compareTo(b.position));
      sequences.add(
        OcptOrphanShotSequence(
          shots: [
            for (final row in orderedOrphans) buildShot(row, _orphanSceneDisplayNumber),
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
  /// screenplay's scenes is [sceneIndex].
  static OcptSceneShotSequence _buildSceneSequence(
    OcptSceneRow sceneRow,
    int sceneIndex,
    Map<String, List<OcptShotRow>> shotRowsBySceneId,
    OcptShot Function(OcptShotRow row, String sceneDisplayNumber) buildShot,
  ) {
    final displayNumber = sceneRow.sceneNumber ?? "${sceneIndex + 1}";
    final shotRows = List<OcptShotRow>.of(shotRowsBySceneId[sceneRow.id] ?? const [])
      ..sort((a, b) => a.position.compareTo(b.position));

    return OcptSceneShotSequence(
      sceneId: sceneRow.id,
      heading: sceneRow.heading,
      sceneNumber: sceneRow.sceneNumber,
      displaySceneNumber: displayNumber,
      shots: [for (final row in shotRows) buildShot(row, displayNumber)],
    );
  }

  /// Creates a new shot in scene [sceneId] of screenplay [screenplayId] in [database], appended at
  /// the end of the scene's current shots, and returns its freshly generated id.
  Future<String> createShot({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String sceneId,
  }) async {
    final existing = await _shotRowsOfGroup(
      database: database,
      screenplayId: screenplayId,
      sceneId: sceneId,
    );

    final id = const Uuid().v4();
    await database
        .into(database.ocptShotsTable)
        .insert(
          OcptShotsTableCompanion.insert(
            id: id,
            screenplayId: screenplayId,
            sceneId: Value(sceneId),
            position: existing.length,
          ),
        );

    return id;
  }

  /// Updates the fields of the shot [shotId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches [shotId]'s `position`, `sceneId` or `orphanedHeading`: those are
  /// only ever changed by [reorderShot], [deleteShot] and [detachShotsFromDeletedScenes].
  Future<void> updateShot({
    required OcptProjectDatabase database,
    required String shotId,
    Value<String> shotSize = const Value.absent(),
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
    await (database.update(
      database.ocptShotsTable,
    )..where((table) => table.id.equals(shotId))).write(
      OcptShotsTableCompanion(
        shotSize: shotSize,
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
      ),
    );
  }

  /// Deletes the shot [shotId] from [database], its attached characters and coverage ranges along
  /// with it, then renumbers the `position` of every remaining shot of its group (its scene, or the
  /// orphan group) contiguously from 0.
  Future<void> deleteShot({required OcptProjectDatabase database, required String shotId}) async {
    await database.transaction(() async {
      final shot = await _getShotRow(database: database, shotId: shotId);

      await (database.delete(
        database.ocptShotCoveragesTable,
      )..where((table) => table.shotId.equals(shotId))).go();
      await (database.delete(
        database.ocptShotCharactersTable,
      )..where((table) => table.shotId.equals(shotId))).go();
      await (database.delete(
        database.ocptShotsTable,
      )..where((table) => table.id.equals(shotId))).go();

      final remaining = await _shotRowsOfGroup(
        database: database,
        screenplayId: shot.screenplayId,
        sceneId: shot.sceneId,
      );
      await _renumberGroup(database: database, orderedRows: remaining);
    });
  }

  /// Moves the shot [shotId] to [newPosition] (0-based) within its own group (its scene, or the
  /// orphan group), renumbering every shot of that group contiguously from 0 afterwards.
  ///
  /// [newPosition] is clamped to the group's bounds, so moving a shot "to the end" can be expressed
  /// with any position at or beyond the group's current shot count.
  Future<void> reorderShot({
    required OcptProjectDatabase database,
    required String shotId,
    required int newPosition,
  }) async {
    await database.transaction(() async {
      final shot = await _getShotRow(database: database, shotId: shotId);
      final group = await _shotRowsOfGroup(
        database: database,
        screenplayId: shot.screenplayId,
        sceneId: shot.sceneId,
      );

      group.removeWhere((row) => row.id == shotId);
      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > group.length ? group.length : newPosition);
      group.insert(clampedPosition, shot);

      await _renumberGroup(database: database, orderedRows: group);
    });
  }

  /// Attaches [characterName] (normalised through `fountain_kit`'s `normalizeCharacterName`) to
  /// shot [shotId], appended after its current characters. Does nothing if the shot already has it.
  Future<void> attachCharacter({
    required OcptProjectDatabase database,
    required String shotId,
    required String characterName,
  }) async {
    final normalized = normalizeCharacterName(characterName);
    final existing =
        await (database.select(
          database.ocptShotCharactersTable,
        )..where((table) => table.shotId.equals(shotId))).get();

    if (existing.any((row) => row.characterName == normalized)) {
      return;
    }

    await database
        .into(database.ocptShotCharactersTable)
        .insert(
          OcptShotCharactersTableCompanion.insert(
            shotId: shotId,
            characterName: normalized,
            position: existing.length,
          ),
        );
  }

  /// Detaches [characterName] (normalised the same way [attachCharacter] does) from shot [shotId],
  /// renumbering the shot's remaining characters contiguously from 0.
  Future<void> detachCharacter({
    required OcptProjectDatabase database,
    required String shotId,
    required String characterName,
  }) async {
    final normalized = normalizeCharacterName(characterName);

    await database.transaction(() async {
      await (database.delete(database.ocptShotCharactersTable)..where(
            (table) => table.shotId.equals(shotId) & table.characterName.equals(normalized),
          ))
          .go();

      final remaining =
          await (database.select(database.ocptShotCharactersTable)
                ..where((table) => table.shotId.equals(shotId))
                ..orderBy([(table) => OrderingTerm.asc(table.position)]))
              .get();

      for (var i = 0; i < remaining.length; i++) {
        if (remaining[i].position == i) {
          continue;
        }
        await (database.update(database.ocptShotCharactersTable)..where(
              (table) =>
                  table.shotId.equals(shotId) & table.characterName.equals(remaining[i].characterName),
            ))
            .write(OcptShotCharactersTableCompanion(position: Value(i)));
      }
    });
  }

  /// Reorders shot [shotId]'s characters to [orderedCharacterNames] (normalised the same way
  /// [attachCharacter] does), which must be a permutation of its currently attached characters.
  Future<void> reorderCharacters({
    required OcptProjectDatabase database,
    required String shotId,
    required List<String> orderedCharacterNames,
  }) async {
    await database.transaction(() async {
      for (var i = 0; i < orderedCharacterNames.length; i++) {
        final normalized = normalizeCharacterName(orderedCharacterNames[i]);
        await (database.update(database.ocptShotCharactersTable)..where(
              (table) => table.shotId.equals(shotId) & table.characterName.equals(normalized),
            ))
            .write(OcptShotCharactersTableCompanion(position: Value(i)));
      }
    });
  }

  /// Removes [characterName] (normalised the same way [attachCharacter] does) from every shot of
  /// screenplay [screenplayId] it is attached to: the deleted-character banner's "remove from every
  /// shot" action.
  Future<void> removeCharacterFromEveryShot({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String characterName,
  }) async {
    final normalized = normalizeCharacterName(characterName);
    final shotIds = await _shotIdsOfScreenplay(database: database, screenplayId: screenplayId);
    if (shotIds.isEmpty) {
      return;
    }

    await (database.delete(database.ocptShotCharactersTable)..where(
          (table) => table.shotId.isIn(shotIds) & table.characterName.equals(normalized),
        ))
        .go();
  }

  /// Replaces [oldCharacterName] with [newCharacterName] (both normalised the same way
  /// [attachCharacter] does) on every shot of screenplay [screenplayId] it is attached to: the
  /// deleted-character banner's replacement chips.
  ///
  /// A shot that already has [newCharacterName] attached simply drops [oldCharacterName] instead of
  /// attaching a duplicate (the table's primary key is `{shotId, characterName}`).
  Future<void> replaceCharacterEverywhere({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String oldCharacterName,
    required String newCharacterName,
  }) async {
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
                (table) => table.shotId.isIn(shotIds) & table.characterName.equals(normalizedOld),
              ))
              .get();

      for (final row in rows) {
        final alreadyHasNewName =
            await (database.select(database.ocptShotCharactersTable)..where(
                  (table) => table.shotId.equals(row.shotId) & table.characterName.equals(normalizedNew),
                ))
                .getSingleOrNull() !=
            null;

        await (database.delete(database.ocptShotCharactersTable)..where(
              (table) => table.shotId.equals(row.shotId) & table.characterName.equals(normalizedOld),
            ))
            .go();

        if (!alreadyHasNewName) {
          await database
              .into(database.ocptShotCharactersTable)
              .insert(
                OcptShotCharactersTableCompanion.insert(
                  shotId: row.shotId,
                  characterName: normalizedNew,
                  position: row.position,
                ),
              );
        }
      }
    });
  }

  /// The hook `OcptSceneIndexService.reconcile` invokes, through `OcptScreenplayService`,
  /// immediately before deleting [scenesAboutToBeDeleted] from the `scenes` table.
  ///
  /// Every shot of every one of [scenesAboutToBeDeleted] is orphaned: its `sceneId` becomes null,
  /// its `orphanedHeading` becomes the scene's heading, `needsCheck` becomes true with
  /// [OcptShotCheckReason.sceneDeleted], and its coverage ranges are deleted (a range anchored to a
  /// scene that no longer exists is meaningless). The newly orphaned shots are appended, in the
  /// order [scenesAboutToBeDeleted] lists their scenes and each scene's own shot order, after
  /// whichever shots were already orphaned, renumbering the whole orphan group's `position`
  /// contiguously from 0 so [OcptOrphanShotSequence] reads grouped by [OcptShot.orphanedHeading]
  /// without any extra grouping logic at read time.
  ///
  /// Called inside `reconcile`'s own transaction: this method does not open one of its own.
  Future<void> detachShotsFromDeletedScenes({
    required OcptProjectDatabase database,
    required List<OcptSceneRow> scenesAboutToBeDeleted,
  }) async {
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
    var nextPosition = existingOrphans.length;

    for (final scene in scenesAboutToBeDeleted) {
      final shotsOfScene = await _shotRowsOfGroup(
        database: database,
        screenplayId: screenplayId,
        sceneId: scene.id,
      );

      for (final shot in shotsOfScene) {
        await (database.delete(
          database.ocptShotCoveragesTable,
        )..where((table) => table.shotId.equals(shot.id))).go();

        await (database.update(database.ocptShotsTable)..where((table) => table.id.equals(shot.id)))
            .write(
              OcptShotsTableCompanion(
                sceneId: const Value(null),
                orphanedHeading: Value(scene.heading),
                position: Value(nextPosition),
                needsCheck: const Value(true),
                checkReason: const Value(OcptShotCheckReason.sceneDeleted),
              ),
            );
        nextPosition++;
      }
    }
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
            column(database.ocptShotsTable).equals("").not(),
      )
      ..orderBy([OrderingTerm.asc(column(database.ocptShotsTable))]);

    final rows = await query.get();
    return [for (final row in rows) row.read(column(database.ocptShotsTable))!];
  }

  /// Reads back the shot row [shotId], throwing if it doesn't exist.
  Future<OcptShotRow> _getShotRow({
    required OcptProjectDatabase database,
    required String shotId,
  }) => (database.select(database.ocptShotsTable)..where((table) => table.id.equals(shotId))).getSingle();

  /// Every shot row of screenplay [screenplayId] belonging to the group [sceneId] identifies (a
  /// real scene, or the orphan group when [sceneId] is null), ordered by `position`.
  Future<List<OcptShotRow>> _shotRowsOfGroup({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String? sceneId,
  }) {
    final sceneCondition = sceneId == null
        ? database.ocptShotsTable.sceneId.isNull()
        : database.ocptShotsTable.sceneId.equals(sceneId);

    return (database.select(database.ocptShotsTable)
          ..where((table) => table.screenplayId.equals(screenplayId) & sceneCondition)
          ..orderBy([(table) => OrderingTerm.asc(table.position)]))
        .get();
  }

  /// Every shot id of screenplay [screenplayId], across every scene and the orphan group alike.
  Future<List<String>> _shotIdsOfScreenplay({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final rows = await (database.select(
      database.ocptShotsTable,
    )..where((table) => table.screenplayId.equals(screenplayId))).get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  /// Writes `position` `0, 1, 2, …` onto [orderedRows], in the order given, skipping a row whose
  /// `position` is already correct.
  Future<void> _renumberGroup({
    required OcptProjectDatabase database,
    required List<OcptShotRow> orderedRows,
  }) async {
    for (var i = 0; i < orderedRows.length; i++) {
      if (orderedRows[i].position == i) {
        continue;
      }
      await (database.update(
        database.ocptShotsTable,
      )..where((table) => table.id.equals(orderedRows[i].id))).write(
        OcptShotsTableCompanion(position: Value(i)),
      );
    }
  }
}
