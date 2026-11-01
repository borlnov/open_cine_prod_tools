// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:uuid/uuid.dart';

/// The links between a role and the elements it wears or carries: adding, editing and removing
/// one, and the links tombstoned along with a role.
///
/// What `OcptElementsService` forwards to; see `OcptElementsSceneLinkOps`.
abstract final class OcptElementsRoleLinkOps {
  /// Links role [roleId] to element [elementId], with optional [notes], and returns the id of the
  /// link — the one that already said so when there was one, a freshly generated one otherwise.
  ///
  /// `addSceneElement`'s sibling and follows exactly its rules: a pair the role already carries is
  /// a no-op rather than a second row, a link removed earlier is **revived** rather than
  /// duplicated, and a revived link keeps the note it held — so [notes] only ever seeds a row that
  /// is genuinely being inserted.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> addRoleElement({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String roleId,
    required String elementId,
    String notes = "",
  }) async {
    if (database.refusesUserWrite("addRoleElement")) {
      return null;
    }

    return database.transaction(() async {
      final existingLinks = await (database.select(
        database.ocptRoleElementsTable,
      )..where((table) => table.roleId.equals(roleId) & table.elementId.equals(elementId))).get();

      OcptRoleElementRow? droppedLink;
      for (final link in existingLinks) {
        if (!link.isDeleted) {
          return link.id;
        }

        droppedLink ??= link;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      if (droppedLink != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptRoleElementsTable,
          rowId: droppedLink.id,
          current: droppedLink,
          next: droppedLink.copyWith(isDeleted: false),
          stamps: stamps,
        );
        await stamps.flush(database);

        return droppedLink.id;
      }

      final id = const Uuid().v4();
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleElementsTable,
        rowId: id,
        current: null,
        next: OcptRoleElementRow(
          id: id,
          roleId: roleId,
          elementId: elementId,
          notes: notes,
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);

      return id;
    });
  }

  /// Updates the notes of role ↔ element link [id] in [database].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateRoleElement({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String id,
    required String notes,
  }) async {
    if (database.refusesUserWrite("updateRoleElement")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptRoleElementsTable,
      )..where((table) => table.id.equals(id) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleElementsTable,
        rowId: id,
        current: current,
        next: current.copyWith(notes: notes),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Removes the role ↔ element link [id].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> removeRoleElement({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String id,
  }) async {
    if (database.refusesUserWrite("removeRoleElement")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptRoleElementsTable,
      )..where((table) => table.id.equals(id))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleElementsTable,
        rowId: id,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones every `role_elements` row naming role [roleId], the cascade
  /// `OcptRoleIndexService.deleteRole` reaches for once it has decided the role goes.
  ///
  /// **Unguarded**, exactly as `OcptAssetsService`'s own cascades are: its only caller has already
  /// refused the write on a preview connection and is already inside the transaction removing the
  /// role, so a second guard here would only be able to disagree with the first. Stamps through
  /// [stamps] — that caller's own instance — rather than resolving a device id of its own.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  static Future<void> tombstoneRoleLinksOfRole({
    required OcptProjectDatabase database,
    required String roleId,
    required OcptRowStampService? stamps,
  }) async {
    final rows = await (database.select(
      database.ocptRoleElementsTable,
    )..where((table) => table.roleId.equals(roleId) & table.isDeleted.not())).get();

    for (final row in rows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleElementsTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }
  }
}
