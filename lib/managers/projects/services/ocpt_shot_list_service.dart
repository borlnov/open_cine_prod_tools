// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_cascade_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_character_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_rows.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_suggestion_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_display_number.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
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
class OcptShotListService extends AbsOcptService {
  /// The placeholder shown in place of a scene number in an orphaned shot's [OcptShot.code]: the
  /// scene the shot originally belonged to no longer exists, and its original number was never
  /// stored (only its heading is, in [OcptShotRow.orphanedHeading]), so there is no real number
  /// left to derive a code from.
  static const _orphanSceneDisplayNumber = "—";

  /// The service a character resolved to no live role is created through
  /// (`OcptRoleIndexService.addRole`), by [resolveOrCreateRoleId]: a shot's characters are the
  /// production's `roles` (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`), so a
  /// hand-added role minted here reuses the very same creation path the resources mode's "add a
  /// role" affordance calls, hand-added and silent, so a character invented in the shot list shows
  /// up in Ressources at once, castable and dressable.
  final OcptRoleIndexService roleIndexService;

  /// The service owning a shot's storyboard panels, held so [deleteShot] and
  /// [tombstoneShotsOfScreenplay] can carry them off with the shot.
  final OcptStoryboardService storyboardService;

  /// The service owning a shot's floor plan symbols and arrows, held for the same cascade
  /// [storyboardService] is.
  final OcptFloorPlanService floorPlanService;

  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter]. [detachShotsFromDeletedScenes] never calls it: it writes inside a
  /// caller's own transaction, and takes that caller's own [OcptRowStampService] instead.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptShotListService({
    required super.logger,
    required this.roleIndexService,
    required this.storyboardService,
    required this.floorPlanService,
    required this.deviceId,
  });

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  ///
  /// Initialises the services this one owns, in the order they are listed in its constructor.
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();
    await roleIndexService.initLifeCycle();
    await storyboardService.initLifeCycle();
    await floorPlanService.initLifeCycle();
  }

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
        : await (database.select(
            database.ocptShotCoveragesTable,
          )..where((table) => table.shotId.isIn(shotIds) & table.isDeleted.not())).get();

    final roleIds = {for (final row in characterRows) row.roleId};
    // A tombstoned role's rows don't surface here at all (ADR 0030, decision 6): the query is
    // scoped to live roles, so `nameByRoleId` simply has no entry for one, and the loop below skips
    // it — the same way every other read in this app lets a tombstone filter drop it.
    final liveRoleRows = roleIds.isEmpty
        ? const <OcptRoleRow>[]
        : await (database.select(
            database.ocptRolesTable,
          )..where((table) => table.id.isIn(roleIds.toList()) & table.isDeleted.not())).get();
    final nameByRoleId = {for (final row in liveRoleRows) row.id: row.name};

    final charactersByShotId = <String, List<String>>{};
    final characterRoleIdsByShotId = <String, List<String>>{};
    for (final row in characterRows) {
      final name = nameByRoleId[row.roleId];
      if (name == null) {
        continue;
      }
      charactersByShotId.putIfAbsent(row.shotId, () => []).add(name);
      characterRoleIdsByShotId.putIfAbsent(row.shotId, () => []).add(row.roleId);
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
        characterRoleIds: characterRoleIdsByShotId[row.id] ?? const [],
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

    final existing = await OcptShotListRows.shotRowsOfGroup(
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
      final current = await OcptShotListRows.liveShotRowOrNull(database: database, shotId: shotId);
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

  /// Writes [rawValue] onto the free-text column of shot [shotId] that [field] names, through
  /// [updateShot]. [OcptShotListEditableField.estimatedDuration] is not a text column: its typed
  /// text has to be parsed first, so the caller writes it through [updateShot] itself and this
  /// writes nothing for it.
  Future<void> updateTextField({
    required OcptProjectDatabase database,
    required String shotId,
    required OcptShotListEditableField field,
    required String rawValue,
  }) async {
    final value = Value(rawValue);
    switch (field) {
      case OcptShotListEditableField.shotSize:
        await updateShot(database: database, shotId: shotId, shotSize: value);
      case OcptShotListEditableField.abbreviation:
        await updateShot(database: database, shotId: shotId, abbreviation: value);
      case OcptShotListEditableField.framing:
        await updateShot(database: database, shotId: shotId, framing: value);
      case OcptShotListEditableField.cameraMove:
        await updateShot(database: database, shotId: shotId, cameraMove: value);
      case OcptShotListEditableField.lens:
        await updateShot(database: database, shotId: shotId, lens: value);
      case OcptShotListEditableField.recordingFormat:
        await updateShot(database: database, shotId: shotId, recordingFormat: value);
      case OcptShotListEditableField.sound:
        await updateShot(database: database, shotId: shotId, sound: value);
      case OcptShotListEditableField.notes:
        await updateShot(database: database, shotId: shotId, notes: value);
      case OcptShotListEditableField.locationNotes:
        await updateShot(database: database, shotId: shotId, locationNotes: value);
      case OcptShotListEditableField.estimatedDuration:
        return;
    }
  }

  /// Sets difficulty [axis] of shot [shotId] to [value], through [updateShot].
  Future<void> updateDifficulty({
    required OcptProjectDatabase database,
    required String shotId,
    required OcptShotDifficultyAxis axis,
    required int value,
  }) async {
    switch (axis) {
      case OcptShotDifficultyAxis.set:
        await updateShot(database: database, shotId: shotId, difficultySet: Value(value));
      case OcptShotDifficultyAxis.camera:
        await updateShot(database: database, shotId: shotId, difficultyCamera: Value(value));
      case OcptShotDifficultyAxis.acting:
        await updateShot(database: database, shotId: shotId, difficultyActing: Value(value));
      case OcptShotDifficultyAxis.sound:
        await updateShot(database: database, shotId: shotId, difficultySound: Value(value));
    }
  }

  /// Tombstones the shot [shotId] in [database], its attached characters and coverage ranges along
  /// with it, and its storyboard panels (and their
  /// annotations and image `assets` rows, through [storyboardService]) and its floor plan
  /// shot-layer symbols and arrows (through [floorPlanService]) — a deleted shot drops its
  /// placements wherever it made any.
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

      final coverageRows = await (database.select(
        database.ocptShotCoveragesTable,
      )..where((table) => table.shotId.equals(shotId) & table.isDeleted.not())).get();
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

      final characterRows = await OcptShotListRows.characterRowsOfShot(
        database: database,
        shotId: shotId,
      );
      for (final row in characterRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShotCharactersTable,
          rowId: ocptCompositeRowStampKey([row.shotId, row.roleId]),
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await storyboardService.tombstonePanelsOfShot(
        database: database,
        shotId: shotId,
        stamps: stamps,
      );
      await floorPlanService.tombstoneFloorPlanRowsOfShot(
        database: database,
        shotId: shotId,
        stamps: stamps,
      );

      final shot = await OcptShotListRows.liveShotRowOrNull(database: database, shotId: shotId);
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
      final shot = await OcptShotListRows.getShotRow(database: database, shotId: shotId);
      final others = (await OcptShotListRows.shotRowsOfGroup(
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

  /// Forwards to [OcptShotListCharacterOps.attachCharacter].
  Future<void> attachCharacter({
    required OcptProjectDatabase database,
    required String shotId,
    required String roleId,
  }) => OcptShotListCharacterOps.attachCharacter(
    database: database,
    shotId: shotId,
    roleId: roleId,
    deviceId: deviceId,
  );

  /// Forwards to [OcptShotListCharacterOps.detachCharacter].
  Future<void> detachCharacter({
    required OcptProjectDatabase database,
    required String shotId,
    required String roleId,
  }) => OcptShotListCharacterOps.detachCharacter(
    database: database,
    shotId: shotId,
    roleId: roleId,
    deviceId: deviceId,
  );

  /// Forwards to [OcptShotListCascadeOps.detachShotsFromDeletedScenes].
  Future<void> detachShotsFromDeletedScenes({
    required OcptProjectDatabase database,
    required List<OcptSceneRow> scenesAboutToBeDeleted,
    required OcptRowStampService? stamps,
  }) => OcptShotListCascadeOps.detachShotsFromDeletedScenes(
    database: database,
    scenesAboutToBeDeleted: scenesAboutToBeDeleted,
    stamps: stamps,
  );

  /// Forwards to [OcptShotListCascadeOps.tombstoneShotsOfScreenplay].
  Future<List<String>> tombstoneShotsOfScreenplay({
    required OcptProjectDatabase database,
    required String screenplayId,
    required OcptRowStampService? stamps,
  }) => OcptShotListCascadeOps.tombstoneShotsOfScreenplay(
    database: database,
    screenplayId: screenplayId,
    stamps: stamps,
    storyboardService: storyboardService,
    floorPlanService: floorPlanService,
  );

  /// Forwards to [OcptShotListSuggestionOps.distinctShotSizes].
  Future<List<String>> distinctShotSizes({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => OcptShotListSuggestionOps.distinctShotSizes(database: database, screenplayId: screenplayId);

  /// Forwards to [OcptShotListSuggestionOps.distinctFramings].
  Future<List<String>> distinctFramings({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => OcptShotListSuggestionOps.distinctFramings(database: database, screenplayId: screenplayId);

  /// Forwards to [OcptShotListSuggestionOps.distinctCameraMoves].
  Future<List<String>> distinctCameraMoves({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) =>
      OcptShotListSuggestionOps.distinctCameraMoves(database: database, screenplayId: screenplayId);

  /// Forwards to [OcptShotListSuggestionOps.distinctLenses].
  Future<List<String>> distinctLenses({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => OcptShotListSuggestionOps.distinctLenses(database: database, screenplayId: screenplayId);

  /// Forwards to [OcptShotListSuggestionOps.distinctRecordingFormats].
  Future<List<String>> distinctRecordingFormats({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => OcptShotListSuggestionOps.distinctRecordingFormats(
    database: database,
    screenplayId: screenplayId,
  );

  /// Forwards to [OcptShotListSuggestionOps.distinctSounds].
  Future<List<String>> distinctSounds({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => OcptShotListSuggestionOps.distinctSounds(database: database, screenplayId: screenplayId);

  /// Forwards to [OcptShotListSuggestionOps.loadFieldSuggestions].
  Future<OcptShotFieldSuggestions> loadFieldSuggestions({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => OcptShotListSuggestionOps.loadFieldSuggestions(
    database: database,
    screenplayId: screenplayId,
  );

  /// Forwards to [OcptShotListCharacterOps.resolveOrCreateRoleId].
  Future<String?> resolveOrCreateRoleId({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String name,
  }) => OcptShotListCharacterOps.resolveOrCreateRoleId(
    database: database,
    screenplayId: screenplayId,
    name: name,
    roleIndexService: roleIndexService,
  );

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
      shots: [for (var i = 0; i < shotRows.length; i++) buildShot(shotRows[i], displayNumber, i)],
    );
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// Disposes the services this one owns, in the reverse order they were initialised.
  @override
  Future<void> disposeLifeCycle() async {
    await floorPlanService.disposeLifeCycle();
    await storyboardService.disposeLifeCycle();
    await roleIndexService.disposeLifeCycle();

    return super.disposeLifeCycle();
  }
}
