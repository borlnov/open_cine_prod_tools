// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// The live reads the shot list operations share: a shot fetched by id, the shots of a scene or of
/// the orphan group, the shots of a screenplay, and the characters of a shot.
///
/// Stateless, so a call takes the database it reads from, the same shape every service's own
/// private query helpers have.
abstract final class OcptShotListRows {
  /// Reads back the shot row [shotId], throwing if it doesn't exist or has been tombstoned.
  static Future<OcptShotRow> getShotRow({
    required OcptProjectDatabase database,
    required String shotId,
  }) => (database.select(
    database.ocptShotsTable,
  )..where((table) => table.id.equals(shotId) & table.isDeleted.not())).getSingle();

  /// Reads back the shot row [shotId], or null if it doesn't exist or has been tombstoned: the
  /// non-throwing sibling of [getShotRow], for a write that is a silent no-op on a stale id
  /// rather than a bug.
  static Future<OcptShotRow?> liveShotRowOrNull({
    required OcptProjectDatabase database,
    required String shotId,
  }) => (database.select(
    database.ocptShotsTable,
  )..where((table) => table.id.equals(shotId) & table.isDeleted.not())).getSingleOrNull();

  /// Every live shot row of screenplay [screenplayId] belonging to the group [sceneId] identifies
  /// (a real scene, or the orphan group when [sceneId] is null), ordered by `sortKey`.
  static Future<List<OcptShotRow>> shotRowsOfGroup({
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
  static Future<List<String>> shotIdsOfScreenplay({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final rows = await (database.select(
      database.ocptShotsTable,
    )..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())).get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  /// Every live character row of shot [shotId], ordered by `sortKey`.
  static Future<List<OcptShotCharacterRow>> characterRowsOfShot({
    required OcptProjectDatabase database,
    required String shotId,
  }) =>
      (database.select(database.ocptShotCharactersTable)
            ..where((table) => table.shotId.equals(shotId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// The `{shotId, roleId}` row, **tombstoned or not**, or null if that pair was never attached at
  /// all: the one read that has to see through tombstones, since the primary key it looks up is
  /// what an insertion would collide with.
  static Future<OcptShotCharacterRow?> characterRow({
    required OcptProjectDatabase database,
    required String shotId,
    required String roleId,
  }) => (database.select(
    database.ocptShotCharactersTable,
  )..where((table) => table.shotId.equals(shotId) & table.roleId.equals(roleId))).getSingleOrNull();

  /// Whether role [roleId] names a live row of [database] — the guard `attachCharacter` takes
  /// against being handed a role id that doesn't (or no longer) exist, since a roleId-native caller
  /// is trusted for the id's shape but not for its liveness.
  static Future<bool> liveRoleExists({
    required OcptProjectDatabase database,
    required String roleId,
  }) async {
    final role = await (database.select(
      database.ocptRolesTable,
    )..where((table) => table.id.equals(roleId) & table.isDeleted.not())).getSingleOrNull();
    return role != null;
  }
}
