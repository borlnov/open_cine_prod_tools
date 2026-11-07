// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:uuid/uuid.dart';

/// What a person declares beyond their identity: the crew positions they hold, their skills and
/// the windows they are unavailable.
///
/// What `OcptPeopleService` forwards to; see `OcptPeopleAssetOps`.
abstract final class OcptPeopleDetailOps {
  /// Add a crew position assignment to person [personId], appended after their current positions,
  /// and return its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> addPosition({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String personId,
    required String positionId,
    required String customLabel,
  }) async {
    if (database.refusesUserWrite("addPosition")) {
      return null;
    }

    final existing = await _positionRowsOfPerson(database: database, personId: personId);
    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPersonPositionsTable,
        rowId: id,
        current: null,
        next: OcptPersonPositionRow(
          id: id,
          personId: personId,
          positionId: positionId,
          customLabel: customLabel,
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Update the fields of position assignment [id] in [database] that are passed as something
  /// other than [Value.absent].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updatePosition({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String id,
    Value<String> positionId = const Value.absent(),
    Value<String> customLabel = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updatePosition")) {
      return;
    }

    final companion = OcptPersonPositionsTableCompanion(
      positionId: positionId,
      customLabel: customLabel,
    );

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptPersonPositionsTable,
      )..where((table) => table.id.equals(id) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPersonPositionsTable,
        rowId: id,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Remove position assignment [id].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> removePosition({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String id,
  }) async {
    if (database.refusesUserWrite("removePosition")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptPersonPositionsTable,
      )..where((table) => table.id.equals(id))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPersonPositionsTable,
        rowId: id,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Reorder person [personId]'s positions to [orderedIds], which must be a permutation of their
  /// currently attached positions' ids. Only the ones that actually have to move are written.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> reorderPositions({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String personId,
    required List<String> orderedIds,
  }) async {
    if (database.refusesUserWrite("reorderPositions")) {
      return;
    }

    await database.transaction(() async {
      final rows = await _positionRowsOfPerson(database: database, personId: personId);
      final rowById = {for (final row in rows) row.id: row};
      final ids = orderedIds.where(rowById.containsKey).toList(growable: false);

      final plan = ocptFractionalKeyRekeyPlan([for (final id in ids) rowById[id]!.sortKey]);
      if (plan.isEmpty) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      for (final entry in plan.entries) {
        final current = rowById[ids[entry.key]]!;
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptPersonPositionsTable,
          rowId: current.id,
          current: current,
          next: current.copyWith(sortKey: entry.value),
          stamps: stamps,
        );
      }
      await stamps.flush(database);
    });
  }

  /// Add a skill to person [personId], appended after their current skills, and return its
  /// freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> addSkill({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String personId,
    required String label,
  }) async {
    if (database.refusesUserWrite("addSkill")) {
      return null;
    }

    final existing = await _skillRowsOfPerson(database: database, personId: personId);
    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPersonSkillsTable,
        rowId: id,
        current: null,
        next: OcptPersonSkillRow(
          id: id,
          personId: personId,
          label: label,
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Update skill [id]'s label.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateSkill({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String id,
    required String label,
  }) async {
    if (database.refusesUserWrite("updateSkill")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptPersonSkillsTable,
      )..where((table) => table.id.equals(id) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPersonSkillsTable,
        rowId: id,
        current: current,
        next: current.copyWith(label: label),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Remove skill [id].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> removeSkill({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String id,
  }) async {
    if (database.refusesUserWrite("removeSkill")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptPersonSkillsTable,
      )..where((table) => table.id.equals(id))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPersonSkillsTable,
        rowId: id,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Reorder person [personId]'s skills to [orderedIds], which must be a permutation of their
  /// currently attached skills' ids. Only the ones that actually have to move are written.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> reorderSkills({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String personId,
    required List<String> orderedIds,
  }) async {
    if (database.refusesUserWrite("reorderSkills")) {
      return;
    }

    await database.transaction(() async {
      final rows = await _skillRowsOfPerson(database: database, personId: personId);
      final rowById = {for (final row in rows) row.id: row};
      final ids = orderedIds.where(rowById.containsKey).toList(growable: false);

      final plan = ocptFractionalKeyRekeyPlan([for (final id in ids) rowById[id]!.sortKey]);
      if (plan.isEmpty) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      for (final entry in plan.entries) {
        final current = rowById[ids[entry.key]]!;
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptPersonSkillsTable,
          rowId: current.id,
          current: current,
          next: current.copyWith(sortKey: entry.value),
          stamps: stamps,
        );
      }
      await stamps.flush(database);
    });
  }

  /// Add an unavailability to person [personId], and return its freshly generated id.
  ///
  /// [endDate] is clamped up to [startDate] rather than refused: a range that ends before it
  /// starts is a slip of a date picker, and the caller has nothing useful to do with an error.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> addUnavailability({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String personId,
    required DateTime startDate,
    required DateTime endDate,
    required OcptDayPartSlot slot,
    int? startMinute,
    int? endMinute,
    required String reason,
  }) async {
    if (database.refusesUserWrite("addUnavailability")) {
      return null;
    }

    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPersonUnavailabilitiesTable,
        rowId: id,
        current: null,
        next: OcptPersonUnavailabilityRow(
          id: id,
          personId: personId,
          startDate: startDate,
          endDate: endDate.isBefore(startDate) ? startDate : endDate,
          slot: slot,
          startMinute: startMinute,
          endMinute: endMinute,
          reason: reason,
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Update the fields of unavailability [id] that are passed as something other than
  /// [Value.absent].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateUnavailability({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String id,
    Value<DateTime> startDate = const Value.absent(),
    Value<DateTime> endDate = const Value.absent(),
    Value<OcptDayPartSlot> slot = const Value.absent(),
    Value<int?> startMinute = const Value.absent(),
    Value<int?> endMinute = const Value.absent(),
    Value<String> reason = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateUnavailability")) {
      return;
    }

    final companion = OcptPersonUnavailabilitiesTableCompanion(
      startDate: startDate,
      endDate: endDate,
      slot: slot,
      startMinute: startMinute,
      endMinute: endMinute,
      reason: reason,
    );

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptPersonUnavailabilitiesTable,
      )..where((table) => table.id.equals(id) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPersonUnavailabilitiesTable,
        rowId: id,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Remove unavailability [id].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> removeUnavailability({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String id,
  }) async {
    if (database.refusesUserWrite("removeUnavailability")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptPersonUnavailabilitiesTable,
      )..where((table) => table.id.equals(id))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPersonUnavailabilitiesTable,
        rowId: id,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Get every live position row of person [personId], ordered by `sortKey`.
  static Future<List<OcptPersonPositionRow>> _positionRowsOfPerson({
    required OcptProjectDatabase database,
    required String personId,
  }) =>
      (database.select(database.ocptPersonPositionsTable)
            ..where((table) => table.personId.equals(personId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get every live skill row of person [personId], ordered by `sortKey`.
  static Future<List<OcptPersonSkillRow>> _skillRowsOfPerson({
    required OcptProjectDatabase database,
    required String personId,
  }) =>
      (database.select(database.ocptPersonSkillsTable)
            ..where((table) => table.personId.equals(personId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();
}
