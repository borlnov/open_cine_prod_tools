// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over the budget mode's financing plan: the `budget_resources` catalogue and the
/// `budget_mileage_rates` a production names for itself.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **No seeding of any kind, unlike `OcptBudgetQuoteService`'s own ten CNC postes.** This app names
/// no financing resource of its own — a subsidy or a cash contribution is entirely the production's
/// own business — and, as `OcptBudgetMileageRatesTable`'s own doc comment argues, it states no
/// mileage scale either: both tables come out of [loadResources]/[loadMileageRates] exactly as
/// empty as the project that has never been read from before them.
///
/// **Both tables order flat by their own `sortKey`**, like `OcptBudgetPostesTable`'s own catalogue:
/// neither a resource nor a rate belongs inside another row the way a quote line belongs inside its
/// poste.
class OcptBudgetFinancingService {
  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter].
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptBudgetFinancingService({required this.deviceId});

  /// Loads every live resource of [database], in `sortKey` order.
  Future<List<OcptBudgetResource>> loadResources({required OcptProjectDatabase database}) async {
    final rows = await _liveResourceRows(database);
    return [for (final row in rows) OcptBudgetResource.fromRow(row)];
  }

  /// Creates a new resource named [label], appended at the end of the financing plan, and returns
  /// its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createResource({
    required OcptProjectDatabase database,
    required String label,
  }) async {
    if (database.refusesUserWrite("createResource")) {
      return null;
    }

    final existing = await _liveResourceRows(database);
    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetResourcesTable,
        rowId: id,
        current: null,
        next: OcptBudgetResourceRow(
          id: id,
          sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
          isDeleted: false,
          groupKind: OcptBudgetResourceGroupKind.subsidy,
          label: label,
          amountCents: 0,
          status: OcptBudgetResourceStatus.pending,
          isReimbursable: false,
          notes: '',
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates the fields of resource [resourceId] in [database] that are passed as something other
  /// than [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderResource] and [deleteResource].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateResource({
    required OcptProjectDatabase database,
    required String resourceId,
    Value<OcptBudgetResourceGroupKind> groupKind = const Value.absent(),
    Value<String?> personId = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<int> amountCents = const Value.absent(),
    Value<OcptBudgetResourceStatus> status = const Value.absent(),
    Value<bool> isReimbursable = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateResource")) {
      return;
    }

    final companion = OcptBudgetResourcesTableCompanion(
      groupKind: groupKind,
      personId: personId,
      label: label,
      amountCents: amountCents,
      status: status,
      isReimbursable: isReimbursable,
      notes: notes,
    );

    await database.transaction(() async {
      final current = await _liveResourceRowOrNull(database: database, resourceId: resourceId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetResourcesTable,
        rowId: resourceId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves resource [resourceId] to [newPosition] (0-based) within the financing plan's own flat
  /// `sortKey` order, by giving it a `sortKey` sitting between the two resources it lands between.
  /// Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderResource({
    required OcptProjectDatabase database,
    required String resourceId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderResource")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveResourceRowOrNull(database: database, resourceId: resourceId);
      if (current == null) {
        return;
      }

      final others = (await _liveResourceRows(database))
        ..removeWhere((row) => row.id == resourceId);

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
        table: database.ocptBudgetResourcesTable,
        rowId: resourceId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones resource [resourceId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteResource({
    required OcptProjectDatabase database,
    required String resourceId,
  }) async {
    if (database.refusesUserWrite("deleteResource")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveResourceRowOrNull(database: database, resourceId: resourceId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetResourcesTable,
        rowId: resourceId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Loads every live mileage rate of [database], in `sortKey` order.
  Future<List<OcptBudgetMileageRate>> loadMileageRates({
    required OcptProjectDatabase database,
  }) async {
    final rows = await _liveMileageRateRows(database);
    return [for (final row in rows) OcptBudgetMileageRate.fromRow(row)];
  }

  /// Creates a new mileage rate named [label], appended at the end of the list, and returns its
  /// freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createMileageRate({
    required OcptProjectDatabase database,
    required String label,
  }) async {
    if (database.refusesUserWrite("createMileageRate")) {
      return null;
    }

    final existing = await _liveMileageRateRows(database);
    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetMileageRatesTable,
        rowId: id,
        current: null,
        next: OcptBudgetMileageRateRow(
          id: id,
          sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
          isDeleted: false,
          label: label,
          ratePerKmMilliCents: 0,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates the fields of mileage rate [rateId] in [database] that are passed as something other
  /// than [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderMileageRate] and [deleteMileageRate].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateMileageRate({
    required OcptProjectDatabase database,
    required String rateId,
    Value<String> label = const Value.absent(),
    Value<int> ratePerKmMilliCents = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateMileageRate")) {
      return;
    }

    final companion = OcptBudgetMileageRatesTableCompanion(
      label: label,
      ratePerKmMilliCents: ratePerKmMilliCents,
    );

    await database.transaction(() async {
      final current = await _liveMileageRateRowOrNull(database: database, rateId: rateId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetMileageRatesTable,
        rowId: rateId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves mileage rate [rateId] to [newPosition] (0-based) within the list's own flat `sortKey`
  /// order, by giving it a `sortKey` sitting between the two rates it lands between. Writes
  /// **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderMileageRate({
    required OcptProjectDatabase database,
    required String rateId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderMileageRate")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveMileageRateRowOrNull(database: database, rateId: rateId);
      if (current == null) {
        return;
      }

      final others = (await _liveMileageRateRows(database))..removeWhere((row) => row.id == rateId);

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
        table: database.ocptBudgetMileageRatesTable,
        rowId: rateId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones mileage rate [rateId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteMileageRate({
    required OcptProjectDatabase database,
    required String rateId,
  }) async {
    if (database.refusesUserWrite("deleteMileageRate")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveMileageRateRowOrNull(database: database, rateId: rateId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetMileageRatesTable,
        rowId: rateId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Every live resource row of [database], ordered by `sortKey`.
  Future<List<OcptBudgetResourceRow>> _liveResourceRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetResourcesTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// The live resource row [resourceId], or null if it doesn't exist or has been tombstoned.
  Future<OcptBudgetResourceRow?> _liveResourceRowOrNull({
    required OcptProjectDatabase database,
    required String resourceId,
  }) => (database.select(database.ocptBudgetResourcesTable)
        ..where((table) => table.id.equals(resourceId) & table.isDeleted.not()))
      .getSingleOrNull();

  /// Every live mileage rate row of [database], ordered by `sortKey`.
  Future<List<OcptBudgetMileageRateRow>> _liveMileageRateRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetMileageRatesTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// The live mileage rate row [rateId], or null if it doesn't exist or has been tombstoned.
  Future<OcptBudgetMileageRateRow?> _liveMileageRateRowOrNull({
    required OcptProjectDatabase database,
    required String rateId,
  }) => (database.select(database.ocptBudgetMileageRatesTable)
        ..where((table) => table.id.equals(rateId) & table.isDeleted.not()))
      .getSingleOrNull();
}
