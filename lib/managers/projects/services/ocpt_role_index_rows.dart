// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';

/// The live reads the role index operations share: the roles of the project and the episodes each
/// one appears in.
///
/// Stateless, so a call takes the database it reads from, the same shape every service's own
/// private query helpers have.
abstract final class OcptRoleIndexRows {
  /// Every live role row of the project, ordered by `sortKey` — the cast is one list over the
  /// project now, not one per screenplay, so no `screenplayId` filters it.
  static Future<List<OcptRoleRow>> liveRoleRows({required OcptProjectDatabase database}) async {
    final query = database.select(database.ocptRolesTable)
      ..where((table) => table.isDeleted.not())
      ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]);

    return query.get();
  }

  /// Every live `role_episodes` link of the project, joined onto its live `screenplays` row and
  /// grouped by `roleId`, each group in the episodes' own `sortKey` order — the read behind
  /// [OcptRole.episodeIds], which the table itself carries no order for (see
  /// `OcptRoleEpisodesTable`'s doc comment).
  static Future<Map<String, List<String>>> liveEpisodeIdsByRoleId({
    required OcptProjectDatabase database,
  }) async {
    final query =
        database.select(database.ocptRoleEpisodesTable).join([
            innerJoin(
              database.ocptScreenplaysTable,
              database.ocptScreenplaysTable.id.equalsExp(
                database.ocptRoleEpisodesTable.screenplayId,
              ),
            ),
          ])
          ..where(
            database.ocptRoleEpisodesTable.isDeleted.not() &
                database.ocptScreenplaysTable.isDeleted.not(),
          )
          ..orderBy([OrderingTerm.asc(database.ocptScreenplaysTable.sortKey)]);

    final episodeIdsByRoleId = <String, List<String>>{};
    for (final row in await query.get()) {
      final link = row.readTable(database.ocptRoleEpisodesTable);
      episodeIdsByRoleId.putIfAbsent(link.roleId, () => []).add(link.screenplayId);
    }

    return episodeIdsByRoleId;
  }
}
