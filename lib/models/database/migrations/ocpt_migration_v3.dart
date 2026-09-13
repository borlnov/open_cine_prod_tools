// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_roles_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_deterministic_role_id.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_key.dart';

/// The name `shot_characters`'s old, `{shotId, characterName}`-keyed shape is renamed to for the
/// short window between the rename and the drop, below.
const _legacyShotCharactersTableName = 'shot_characters_v2';

/// Schema version 3's own `onUpgrade` step, called from [OcptProjectDatabase.migration] for a file
/// opened below it: reshapes `shot_characters` from its frozen v2 shape — `{shotId, characterName}`,
/// a free normalised name with no foreign key — to `{shotId, roleId}`, referencing [OcptRolesTable]
/// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`).
///
/// SQLite cannot alter a primary key in place, so this recreates the table: [_legacyShotCharactersTableName]
/// is a create-new/copy/drop, not a `Migrator.alterTable`, because copying a row also has to decide
/// *which* role it now points to — a decision `alterTable`'s column-by-column transformer cannot
/// express, since it may have to **mint a role that does not exist yet**.
///
/// For every `shot_characters` row, live or tombstoned alike (sync history is kept), its normalised
/// `characterName` maps to a role:
///
/// - to the **live** `roles` row whose `name` equals it, when one exists — the first in `sortKey`
///   order if, unusually, more than one live role somehow shares the name, the same deterministic
///   tie-break `OcptRoleIndexService.reconcile` uses;
/// - otherwise to a **freshly minted hand-added silent role** (`isFromScreenplay` false, `kind`
///   silent, uncast, `castingNotes` empty), appended after every live role, plus a `role_episodes`
///   link to every episode (`shots.screenplayId`) at least one of that name's old rows belongs to.
///
/// **Every replica migrates its own file independently** (`docs/architecture/sync.md`), so a role
/// minted here with a random id would come back as several rows the moment two replicas met. Both
/// the minted role's own id and its `role_episodes` link's id are therefore **deterministic UUID
/// v5s** of the normalised name (and, for the link, the pair `(roleId, screenplayId)`) —
/// [ocptDeterministicRoleId] / [ocptDeterministicRoleEpisodeId] — so two replicas migrating the same
/// name mint the very same rows. To keep every other part of the outcome just as deterministic: the
/// distinct names needing a fresh role are minted in **sorted** order, so the fractional `sortKey`
/// each one is appended with is a pure function of the (byte-identical, per the argument above)
/// source data rather than of whatever order SQLite happened to return rows in; and a minted role's
/// `role_episodes` links are one per **distinct** screenplay id its rows reference, never one per
/// row. **Neither the minted `roles` row nor its `role_episodes` link is stamped** in
/// `row_field_versions`: their deterministic identity, not a merge stamp, is what makes them
/// converge, and stamping them with this replica's own clock and device id would make two replicas'
/// otherwise-identical rows carry different merge history for no reason. The convergence test
/// (`test/models/database/ocpt_project_database_migration_test.dart`) is the arbiter of this
/// argument, not this comment.
///
/// The **existing** stamps of `shot_characters` rows are a different story: they carry real merge
/// history and must survive the reshape. Every `row_field_versions` row naming `table_name =
/// 'shot_characters'` is rekeyed from `rowId = ocptCompositeRowStampKey([shotId, characterName])` to
/// `rowId = ocptCompositeRowStampKey([shotId, roleId])` — a pure function of the old key and the
/// very same (deterministic where minted) role id every replica computes, so the rekey itself
/// converges — and the one stamp among them whose `columnName` is `characterName` is renamed to
/// `roleId`: the column that carried the row's identity is gone, but the merge history of the
/// identity it carried lives on under its new name.
Future<void> ocptMigrateToSchemaV3({
  required Migrator migrator,
  required OcptProjectDatabase database,
}) async {
  final legacyRows = await database
      .customSelect(
        'SELECT shot_id, character_name, position, sort_key, is_deleted FROM shot_characters',
      )
      .get();

  final screenplayIdByShotId = {
    for (final shot in await database.select(database.ocptShotsTable).get())
      shot.id: shot.screenplayId,
  };

  final distinctNames = <String>{
    for (final row in legacyRows) row.read<String>('character_name'),
  }.toList()..sort();

  final liveRoles =
      await (database.select(database.ocptRolesTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();
  final liveRoleIdByName = <String, String>{};
  for (final role in liveRoles) {
    // The first in `sortKey` order wins when more than one live role shares a name — see the class
    // doc comment.
    liveRoleIdByName.putIfAbsent(role.name, () => role.id);
  }

  final roleIdByName = <String, String>{};
  var previousSortKey = liveRoles.isEmpty ? null : liveRoles.last.sortKey;

  for (final name in distinctNames) {
    final existingRoleId = liveRoleIdByName[name];
    if (existingRoleId != null) {
      roleIdByName[name] = existingRoleId;
      continue;
    }

    final mintedRoleId = ocptDeterministicRoleId(name);
    roleIdByName[name] = mintedRoleId;
    previousSortKey = ocptFractionalKeyBetween(before: previousSortKey);

    await database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(
            id: mintedRoleId,
            name: name,
            sortKey: Value(previousSortKey),
            kind: OcptRoleKind.silent,
          ),
        );

    final screenplayIds = <String>{
      for (final row in legacyRows)
        if (row.read<String>('character_name') == name)
          screenplayIdByShotId[row.read<String>('shot_id')]!,
    }.toList()..sort();

    for (final screenplayId in screenplayIds) {
      await database
          .into(database.ocptRoleEpisodesTable)
          .insert(
            OcptRoleEpisodesTableCompanion.insert(
              id: ocptDeterministicRoleEpisodeId(roleId: mintedRoleId, screenplayId: screenplayId),
              roleId: mintedRoleId,
              screenplayId: screenplayId,
            ),
          );
    }
  }

  await database.customStatement(
    'ALTER TABLE shot_characters RENAME TO $_legacyShotCharactersTableName',
  );
  await migrator.createTable(database.ocptShotCharactersTable);

  for (final row in legacyRows) {
    await database
        .into(database.ocptShotCharactersTable)
        .insert(
          OcptShotCharactersTableCompanion.insert(
            shotId: row.read<String>('shot_id'),
            roleId: roleIdByName[row.read<String>('character_name')]!,
            position: row.read<int>('position'),
            sortKey: Value(row.read<String>('sort_key')),
            isDeleted: Value(row.read<bool>('is_deleted')),
          ),
        );
  }

  await database.customStatement('DROP TABLE $_legacyShotCharactersTableName');

  for (final row in legacyRows) {
    final shotId = row.read<String>('shot_id');
    final roleId = roleIdByName[row.read<String>('character_name')]!;
    final oldRowId = ocptCompositeRowStampKey([shotId, row.read<String>('character_name')]);
    final newRowId = ocptCompositeRowStampKey([shotId, roleId]);

    await (database.update(database.ocptRowFieldVersionsTable)..where(
          (table) =>
              table.targetTableName.equals('shot_characters') &
              table.rowId.equals(oldRowId) &
              table.columnName.equals('characterName'),
        ))
        .write(
          OcptRowFieldVersionsTableCompanion(rowId: Value(newRowId), columnName: const Value('roleId')),
        );

    await (database.update(database.ocptRowFieldVersionsTable)..where(
          (table) =>
              table.targetTableName.equals('shot_characters') &
              table.rowId.equals(oldRowId) &
              table.columnName.equals('characterName').not(),
        ))
        .write(OcptRowFieldVersionsTableCompanion(rowId: Value(newRowId)));
  }
}
