// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_row_stamp_key.dart';

/// The merge of one role into another, with everything linked to either.
///
/// What `OcptRoleIndexService` forwards to; see `OcptRoleIndexReconcileOps`.
abstract final class OcptRoleIndexMergeOps {
  /// Merges role [sourceRoleId] into role [targetRoleId] (`docs/adr/0030-…`, decision 3): every row
  /// naming *source* is re-pointed onto *target* — deduped where *target* already has the
  /// equivalent — *source*'s casting and notes are carried onto *target* where *target* lacks them,
  /// and *source* is tombstoned last.
  ///
  /// **This method is purely mechanical.** It merges *source* into *target* exactly as given: it
  /// never decides which of the two survives. "The reconciled speaking role wins" (decision 3) is
  /// the **caller's** rule — the caller picks which id is [targetRoleId] before calling this, so
  /// that when one of the two roles is a live, `isFromScreenplay` one, it is passed as
  /// [targetRoleId] and stays owned by `reconcile`. A no-op if [sourceRoleId] equals
  /// [targetRoleId], or if either role is missing or already tombstoned.
  ///
  /// What moves, table by table:
  /// - `shot_characters` (`{shotId, roleId}` primary key): every live row naming *source* is
  ///   tombstoned; the `{shotId, targetRoleId}` row is created, or revived if it exists only as a
  ///   tombstone, keeping the moved row's `position`/`sortKey` — a plain tombstone-and-recreate,
  ///   the only way to re-point a composite primary key. A shot that already has *target* live
  ///   simply drops *source*'s row instead.
  /// - `shooting_slot_cast` (own-id primary key, `roleId` an ordinary column): a live row naming
  ///   *source* has its `roleId` updated to *target* in place, unless that slot already convokes
  ///   *target* live, in which case *source*'s row is tombstoned instead — a convocation must never
  ///   be lost to the merge, which is the one thing that sets this cascade apart from
  ///   `deleteRole`'s (decision 3's own contrast with decision 5).
  /// - `breakdown_tags` (own-id primary key, `roleId` a nullable column): every live tag naming
  ///   *source* has its `roleId` updated to *target*. Tags never dedupe against each other — each
  ///   is its own passage of the screenplay — so every one of them simply moves.
  /// - `role_elements` / `role_candidates` / `role_episodes` (own-id primary keys, `roleId` an
  ///   ordinary column on each): a live link naming *source* is re-pointed to *target* by updating
  ///   its `roleId`, unless *target* already has the equivalent link (same `elementId`, same
  ///   `personId`, same `screenplayId` respectively) live, in which case *source*'s link is
  ///   tombstoned instead.
  /// - `roles`: if *target*'s `personId` is null and *source*'s is not, *target* takes it; if
  ///   *target*'s `castingNotes` is empty and *source*'s is not, *target* takes it too. *Target*'s
  ///   `kind`, `sortKey`, `isFromScreenplay` and `orphanedName` are never touched by a merge.
  ///
  /// No other table of this schema names a role beside these six and `roles` itself.
  ///
  /// One transaction, one [OcptRowStampService] seeded once and flushed once at the end, passed
  /// through every write above — the normal convention, never a nested seed/flush.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> mergeRole({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String sourceRoleId,
    required String targetRoleId,
  }) async {
    if (database.refusesUserWrite("mergeRole")) {
      return;
    }

    if (sourceRoleId == targetRoleId) {
      return;
    }

    await database.transaction(() async {
      final source = await (database.select(
        database.ocptRolesTable,
      )..where((table) => table.id.equals(sourceRoleId) & table.isDeleted.not())).getSingleOrNull();
      final target = await (database.select(
        database.ocptRolesTable,
      )..where((table) => table.id.equals(targetRoleId) & table.isDeleted.not())).getSingleOrNull();
      if (source == null || target == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      // shot_characters: {shotId, roleId} primary key, so a re-point is tombstone-and-recreate —
      // there is no other way to move a composite primary key's row onto a different key.
      final sourceShotCharacters = await (database.select(
        database.ocptShotCharactersTable,
      )..where((table) => table.roleId.equals(sourceRoleId) & table.isDeleted.not())).get();
      for (final row in sourceShotCharacters) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShotCharactersTable,
          rowId: ocptCompositeRowStampKey([row.shotId, sourceRoleId]),
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );

        final existingTarget =
            await (database.select(database.ocptShotCharactersTable)..where(
                  (table) => table.shotId.equals(row.shotId) & table.roleId.equals(targetRoleId),
                ))
                .getSingleOrNull();
        final targetRowId = ocptCompositeRowStampKey([row.shotId, targetRoleId]);

        if (existingTarget == null) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptShotCharactersTable,
            rowId: targetRowId,
            current: null,
            next: OcptShotCharacterRow(
              shotId: row.shotId,
              roleId: targetRoleId,
              position: row.position,
              sortKey: row.sortKey,
              isDeleted: false,
            ),
            stamps: stamps,
          );
        } else if (existingTarget.isDeleted) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptShotCharactersTable,
            rowId: targetRowId,
            current: existingTarget,
            next: existingTarget.copyWith(sortKey: row.sortKey, isDeleted: false),
            stamps: stamps,
          );
        }
        // else target is already live on this shot: dropping source's row (above) is enough.
      }

      // shooting_slot_cast: own-id primary key, so a re-point updates the roleId column in place —
      // unless the slot already convokes target, in which case source's convocation is tombstoned
      // rather than duplicating one, since a role is convoked at most once per slot.
      final sourceSlotCast = await (database.select(
        database.ocptShootingSlotCastTable,
      )..where((table) => table.roleId.equals(sourceRoleId) & table.isDeleted.not())).get();
      for (final row in sourceSlotCast) {
        final targetAlreadyConvoked =
            await (database.select(database.ocptShootingSlotCastTable)..where(
                  (table) =>
                      table.slotId.equals(row.slotId) &
                      table.roleId.equals(targetRoleId) &
                      table.isDeleted.not(),
                ))
                .getSingleOrNull() !=
            null;

        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingSlotCastTable,
          rowId: row.id,
          current: row,
          next: targetAlreadyConvoked
              ? row.copyWith(isDeleted: true)
              : row.copyWith(roleId: targetRoleId),
          stamps: stamps,
        );
      }

      // breakdown_tags: own-id primary key, nullable roleId column, no dedup — each tag is its own
      // passage of the screenplay.
      final sourceTags = await (database.select(
        database.ocptBreakdownTagsTable,
      )..where((table) => table.roleId.equals(sourceRoleId) & table.isDeleted.not())).get();
      for (final row in sourceTags) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptBreakdownTagsTable,
          rowId: row.id,
          current: row,
          next: row.copyWith(roleId: Value(targetRoleId)),
          stamps: stamps,
        );
      }

      // role_elements: own-id primary key, deduped by elementId.
      final sourceElements = await (database.select(
        database.ocptRoleElementsTable,
      )..where((table) => table.roleId.equals(sourceRoleId) & table.isDeleted.not())).get();
      if (sourceElements.isNotEmpty) {
        final targetElementIds =
            (await (database.select(database.ocptRoleElementsTable)
                      ..where((table) => table.roleId.equals(targetRoleId) & table.isDeleted.not()))
                    .get())
                .map((row) => row.elementId)
                .toSet();
        for (final row in sourceElements) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptRoleElementsTable,
            rowId: row.id,
            current: row,
            next: targetElementIds.contains(row.elementId)
                ? row.copyWith(isDeleted: true)
                : row.copyWith(roleId: targetRoleId),
            stamps: stamps,
          );
        }
      }

      // role_candidates: own-id primary key, deduped by personId.
      final sourceCandidates = await (database.select(
        database.ocptRoleCandidatesTable,
      )..where((table) => table.roleId.equals(sourceRoleId) & table.isDeleted.not())).get();
      if (sourceCandidates.isNotEmpty) {
        final targetPersonIds =
            (await (database.select(database.ocptRoleCandidatesTable)
                      ..where((table) => table.roleId.equals(targetRoleId) & table.isDeleted.not()))
                    .get())
                .map((row) => row.personId)
                .toSet();
        for (final row in sourceCandidates) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptRoleCandidatesTable,
            rowId: row.id,
            current: row,
            next: targetPersonIds.contains(row.personId)
                ? row.copyWith(isDeleted: true)
                : row.copyWith(roleId: targetRoleId),
            stamps: stamps,
          );
        }
      }

      // role_episodes: own-id primary key, deduped by screenplayId.
      final sourceEpisodes = await (database.select(
        database.ocptRoleEpisodesTable,
      )..where((table) => table.roleId.equals(sourceRoleId) & table.isDeleted.not())).get();
      if (sourceEpisodes.isNotEmpty) {
        final targetScreenplayIds =
            (await (database.select(database.ocptRoleEpisodesTable)
                      ..where((table) => table.roleId.equals(targetRoleId) & table.isDeleted.not()))
                    .get())
                .map((row) => row.screenplayId)
                .toSet();
        for (final row in sourceEpisodes) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptRoleEpisodesTable,
            rowId: row.id,
            current: row,
            next: targetScreenplayIds.contains(row.screenplayId)
                ? row.copyWith(isDeleted: true)
                : row.copyWith(roleId: targetRoleId),
            stamps: stamps,
          );
        }
      }

      // roles: target carries source's personId/castingNotes where it lacks them of its own; kind,
      // sortKey, isFromScreenplay and orphanedName are never touched by a merge. writeAndStamp is a
      // no-op when nothing actually changes, so this is safe to call unconditionally.
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRolesTable,
        rowId: targetRoleId,
        current: target,
        next: target.copyWith(
          personId: target.personId == null && source.personId != null
              ? Value(source.personId)
              : const Value.absent(),
          castingNotes: target.castingNotes.isEmpty && source.castingNotes.isNotEmpty
              ? source.castingNotes
              : target.castingNotes,
        ),
        stamps: stamps,
      );

      // source is tombstoned last, once everything it carried has moved.
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRolesTable,
        rowId: sourceRoleId,
        current: source,
        next: source.copyWith(isDeleted: true),
        stamps: stamps,
      );

      await stamps.flush(database);
    });
  }
}
