// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_rows.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// A shot's characters: attaching a role to a shot, detaching it, and resolving a typed name to a
/// live role (creating a silent one when none exists).
///
/// What `OcptShotListService` forwards to; that service documents the shot list whole.
abstract final class OcptShotListCharacterOps {
  /// Attaches role [roleId] to shot [shotId], appended after its current characters. Does nothing
  /// if the shot already has it, if [shotId] doesn't name a live shot, or if [roleId] doesn't name
  /// a live role.
  ///
  /// A shot's characters are the production's `roles`
  /// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`), and `shot_characters` is
  /// keyed by `{shotId, roleId}`: this method is purely mechanical, taking [roleId] as given rather
  /// than resolving one out of a typed name — that resolution (or creation, decision 1) is the
  /// caller's, through [resolveOrCreateRoleId]. A character detached earlier left a tombstone
  /// behind: re-attaching it therefore lifts that tombstone rather than inserting a second row,
  /// which the key would refuse anyway.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> attachCharacter({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String shotId,
    required String roleId,
  }) async {
    if (database.refusesUserWrite("attachCharacter")) {
      return;
    }

    await database.transaction(() async {
      final shot = await OcptShotListRows.liveShotRowOrNull(database: database, shotId: shotId);
      if (shot == null ||
          !await OcptShotListRows.liveRoleExists(database: database, roleId: roleId)) {
        return;
      }

      final existing = await OcptShotListRows.characterRowsOfShot(
        database: database,
        shotId: shotId,
      );
      if (existing.any((row) => row.roleId == roleId)) {
        return;
      }

      final sortKey = ocptFractionalKeyBetween(
        before: existing.isEmpty ? null : existing.last.sortKey,
      );

      final tombstone = await OcptShotListRows.characterRow(
        database: database,
        shotId: shotId,
        roleId: roleId,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      final rowId = ocptCompositeRowStampKey([shotId, roleId]);

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
          roleId: roleId,
          position: existing.length,
          sortKey: sortKey,
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Detaches role [roleId] from shot [shotId]. Does nothing if it isn't attached — this never
  /// creates a role, unlike [attachCharacter]: there is nothing left to detach from one that
  /// doesn't exist.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> detachCharacter({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String shotId,
    required String roleId,
  }) async {
    if (database.refusesUserWrite("detachCharacter")) {
      return;
    }

    await database.transaction(() async {
      final current = await OcptShotListRows.characterRow(
        database: database,
        shotId: shotId,
        roleId: roleId,
      );
      if (current == null || current.isDeleted) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShotCharactersTable,
        rowId: ocptCompositeRowStampKey([shotId, roleId]),
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Resolves [name] (normalised through `fountain_kit`'s `normalizeCharacterName`) to a live
  /// role's id in [database], or **creates** a hand-added silent role linked to [screenplayId]
  /// through [roleIndexService] when none exists
  /// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`, decision 1) — the
  /// resolve-or- create path the shot list's own add-character affordance calls before
  /// [attachCharacter], now that [attachCharacter] itself is roleId-native (the resolution lives in
  /// the caller, not in the service).
  ///
  /// The first in `sortKey` order wins on the rare chance more than one live role shares a name —
  /// the same deterministic tie-break `OcptRoleIndexService.reconcile` and the schema v3 migration
  /// use.
  ///
  /// Opens no transaction of its own: [OcptRoleIndexService.addRole] opens one when it actually
  /// mints a role, which simply runs as part of whichever transaction the caller is already inside
  /// (`ConnectionUser.transaction`'s own doc comment on nested transactions) — or on its own when
  /// the caller isn't inside one, exactly as reading is always safe to do outside a transaction.
  ///
  /// Returns null only if creating a fresh role is refused for having been handed a preview
  /// connection.
  static Future<String?> resolveOrCreateRoleId({
    required OcptRoleIndexService roleIndexService,
    required OcptProjectDatabase database,
    required String screenplayId,
    required String name,
  }) async {
    final normalizedName = normalizeCharacterName(name);

    final existingRole =
        await (database.select(database.ocptRolesTable)
              ..where((table) => table.name.equals(normalizedName) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.asc(table.sortKey)])
              ..limit(1))
            .getSingleOrNull();
    if (existingRole != null) {
      return existingRole.id;
    }

    return roleIndexService.addRole(
      database: database,
      screenplayId: screenplayId,
      name: normalizedName,
      kind: OcptRoleKind.silent,
    );
  }
}
