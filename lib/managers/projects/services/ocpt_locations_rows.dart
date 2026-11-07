// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// The live reads the locations operations share: the locations of the project, the sets of one
/// location, the codes sets already carry and the scenes each set is shot in.
///
/// Stateless, so a call takes the database it reads from, the same shape every service's own
/// private query helpers have.
abstract final class OcptLocationsRows {
  /// Get the ids of the live scenes linked to each of [setIds], keyed by set id and ordered by the
  /// screenplay's own scene order. See `loadLocations` for why a link onto a tombstoned scene is
  /// left out rather than reported.
  static Future<Map<String, List<String>>> liveSceneIdsBySetId({
    required OcptProjectDatabase database,
    required List<String> setIds,
  }) async {
    if (setIds.isEmpty) {
      return const {};
    }

    final linkRows = await (database.select(
      database.ocptSceneSetsTable,
    )..where((table) => table.setId.isIn(setIds) & table.isDeleted.not())).get();
    if (linkRows.isEmpty) {
      return const {};
    }

    final sceneRows =
        await (database.select(database.ocptScenesTable)..where(
              (table) =>
                  table.id.isIn(linkRows.map((row) => row.sceneId).toList(growable: false)) &
                  table.isDeleted.not(),
            ))
            .get();

    final positionBySceneId = {for (final row in sceneRows) row.id: row.position};

    final sceneIdsBySetId = <String, List<String>>{};
    for (final link in linkRows) {
      if (positionBySceneId.containsKey(link.sceneId)) {
        sceneIdsBySetId.putIfAbsent(link.setId, () => []).add(link.sceneId);
      }
    }

    for (final sceneIds in sceneIdsBySetId.values) {
      sceneIds.sort((a, b) => positionBySceneId[a]!.compareTo(positionBySceneId[b]!));
    }

    return sceneIdsBySetId;
  }

  /// Get every live location row of [database], ordered by `sortKey`.
  static Future<List<OcptLocationRow>> liveLocationRows(OcptProjectDatabase database) =>
      (database.select(database.ocptLocationsTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get the code of every live set of [database], whichever location it belongs to — what
  /// `createSet` numbers a new code from, a set's code being unique across the whole project rather
  /// than within its location (`ocptSetCodeOf`).
  static Future<List<String>> liveSetCodes(OcptProjectDatabase database) async {
    final query = database.selectOnly(database.ocptSetsTable)
      ..addColumns([database.ocptSetsTable.code])
      ..where(database.ocptSetsTable.isDeleted.not());

    final rows = await query.get();

    return [for (final row in rows) row.read(database.ocptSetsTable.code) ?? ""];
  }

  /// Get every live set row of location [locationId], ordered by `sortKey`.
  static Future<List<OcptSetRow>> liveSetRowsOfLocation({
    required OcptProjectDatabase database,
    required String locationId,
  }) =>
      (database.select(database.ocptSetsTable)
            ..where((table) => table.locationId.equals(locationId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();
}
