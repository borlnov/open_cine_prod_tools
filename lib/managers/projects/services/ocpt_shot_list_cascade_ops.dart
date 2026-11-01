// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_rows.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';

/// What the deletion of scenes or of a whole screenplay owes the shots hanging off them, written
/// inside the caller's own transaction.
///
/// What `OcptShotListService` forwards to; see `OcptShotListCharacterOps`.
abstract final class OcptShotListCascadeOps {
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
  static Future<void> detachShotsFromDeletedScenes({
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

    final existingOrphans = await OcptShotListRows.shotRowsOfGroup(
      database: database,
      screenplayId: screenplayId,
      sceneId: null,
    );
    var previousSortKey = existingOrphans.isEmpty ? null : existingOrphans.last.sortKey;
    var nextPosition = existingOrphans.length;

    for (final scene in scenesAboutToBeDeleted) {
      final shotsOfScene = await OcptShotListRows.shotRowsOfGroup(
        database: database,
        screenplayId: screenplayId,
        sceneId: scene.id,
      );

      for (final shot in shotsOfScene) {
        final coverageRows = await (database.select(
          database.ocptShotCoveragesTable,
        )..where((table) => table.shotId.equals(shot.id) & table.isDeleted.not())).get();
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
  /// carrying off its `shot_characters`, `shot_coverages`, storyboard panels and floor plan
  /// shot-layer placements exactly as `deleteShot` does for one shot, and returns the ids it
  /// tombstoned: `OcptScreenplayService.deleteEpisode`'s cascade, which needs those ids to also
  /// tombstone whatever a schedule block placed of one of them.
  ///
  /// **Unguarded**, exactly as `OcptElementsService.tombstoneRoleLinksOfRole` is: its only caller
  /// has already refused the write on a preview connection and is already inside the transaction
  /// removing the episode, so a second guard here would only be able to disagree with the first —
  /// and stamps through [stamps], that caller's own instance, for the same reason
  /// [detachShotsFromDeletedScenes] does.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  static Future<List<String>> tombstoneShotsOfScreenplay({
    required OcptStoryboardService storyboardService,
    required OcptFloorPlanService floorPlanService,
    required OcptProjectDatabase database,
    required String screenplayId,
    required OcptRowStampService? stamps,
  }) async {
    final shotIds = await OcptShotListRows.shotIdsOfScreenplay(
      database: database,
      screenplayId: screenplayId,
    );
    if (shotIds.isEmpty) {
      return const [];
    }

    final coverageRows = await (database.select(
      database.ocptShotCoveragesTable,
    )..where((table) => table.shotId.isIn(shotIds) & table.isDeleted.not())).get();
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

    final characterRows = await (database.select(
      database.ocptShotCharactersTable,
    )..where((table) => table.shotId.isIn(shotIds) & table.isDeleted.not())).get();
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

    for (final shotId in shotIds) {
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
    }

    final shotRows = await (database.select(
      database.ocptShotsTable,
    )..where((table) => table.id.isIn(shotIds) & table.isDeleted.not())).get();
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
}
