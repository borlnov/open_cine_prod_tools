// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_database_outcome_abort.dart';
import 'package:open_cine_prod_tools/managers/ocpt_database_result_abort.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:uuid/uuid.dart';

/// CRUD over the budget mode's financing plan: the `budget_resources` catalogue and the
/// `budget_mileage_rates` a production names for itself.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **No seeding of any kind, unlike `OcptBudgetQuoteService`'s own ten CNC accounts.** This app
/// names no financing resource of its own — a subsidy or a cash contribution is entirely the
/// production's own business — and, as `OcptBudgetMileageRatesTable`'s own doc comment argues, it
/// states no mileage scale either: both tables come out of [loadResources]/[loadMileageRates]
/// exactly as empty as the project that has never been read from before them.
///
/// **Both tables order flat by their own `sortKey`**, like `OcptBudgetAccountsTable`'s own
/// catalogue: neither a resource nor a rate belongs inside another row the way a quote line belongs
/// inside its account.
class OcptBudgetFinancingService extends AbsOcptService {
  /// {@macro open_cine_prod_tools.serviceDeviceIdGetter}
  final OcptDeviceIdGetter deviceId;

  /// The service writing the counterpart quote line of an in-kind resource.
  final OcptBudgetQuoteService _quoteService;

  /// Class constructor
  const OcptBudgetFinancingService({
    required super.logger,
    required this.deviceId,
    required OcptBudgetQuoteService quoteService,
  }) : _quoteService = quoteService;

  /// Load every live resource of [database], in `sortKey` order.
  @useResult
  Future<OcptDatabaseResult<List<OcptBudgetResource>>> loadResources({
    required OcptProjectDatabase database,
  }) => guardResult("loadResources", () async {
    final rows = await _liveResourceRows(database);
    return [for (final row in rows) OcptBudgetResource.fromRow(row)];
  });

  /// Create a new resource named [label], appended at the end of the financing plan, and return
  /// its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseResult<String>> createResource({
    required OcptProjectDatabase database,
    required String label,
  }) => guardResult("createResource", () async {
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
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
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
  });

  /// Create the resource [fields] describes and answer its fresh id: [createResource] mints the row
  /// from a label alone, then every other field is written and the counterpart quote line is kept
  /// in step, all in one transaction. Either the resource and its line are both written or neither
  /// is.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseResult<String>> createResourceWithFields({
    required OcptProjectDatabase database,
    required OcptBudgetResourceFormFields fields,
  }) => guardResult("createResourceWithFields", () async {
    if (database.refusesUserWrite("createResourceWithFields")) {
      return null;
    }

    return database.transaction(() async {
      final resourceId = await createResource(
        database: database,
        label: fields.label,
      ).valueOrAbort();
      if (resourceId == null) {
        return null;
      }

      await _writeFieldsAndReconcile(database: database, resourceId: resourceId, fields: fields);

      return resourceId;
    });
  });

  /// Write every field of [fields] onto resource [resourceId] and keep its counterpart quote line
  /// in step, in one transaction: either both are written or neither is.
  ///
  /// **Exactly one counterpart line exists whenever [fields] describes an in-kind contribution,
  /// and none does otherwise** (`docs/architecture/budget.md`, "A balanced in-kind contribution"):
  /// - not in kind (or never was): the existing line, if any, is tombstoned.
  /// - in kind, no line yet: one is minted, quantity 1, tax-inclusive, frozen at 0 % VAT, the
  ///   figure and label read off [fields].
  /// - in kind, a line in the same account: its label and amount follow the contribution.
  /// - in kind, a line in a **different** account: deleted and re-minted there, never moved in
  ///   place, since `budget_lines.sortKey` is fractional within its own account.
  ///
  /// An in-kind contribution with no account chosen writes nothing for the line, rather than mint
  /// an orphaned one.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> writeResourceFields({
    required OcptProjectDatabase database,
    required String resourceId,
    required OcptBudgetResourceFormFields fields,
  }) => guardOutcome("writeResourceFields", () async {
    if (database.refusesUserWrite("writeResourceFields")) {
      return;
    }

    await database.transaction(
      () => _writeFieldsAndReconcile(database: database, resourceId: resourceId, fields: fields),
    );
  });

  /// Update the fields of resource [resourceId] in [database] that are passed as something other
  /// than [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderResource] and [deleteResource].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> updateResource({
    required OcptProjectDatabase database,
    required String resourceId,
    Value<OcptBudgetResourceGroupKind> groupKind = const Value.absent(),
    Value<String?> personId = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<int> amountCents = const Value.absent(),
    Value<OcptBudgetResourceStatus> status = const Value.absent(),
    Value<bool> isReimbursable = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) => guardOutcome("updateResource", () async {
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
  });

  /// Move resource [resourceId] to [newPosition] (0-based) within the financing plan's own flat
  /// `sortKey` order, by giving it a `sortKey` sitting between the two resources it lands between.
  /// Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> reorderResource({
    required OcptProjectDatabase database,
    required String resourceId,
    required int newPosition,
  }) => guardOutcome("reorderResource", () async {
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
  });

  /// Tombstone resource [resourceId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> deleteResource({
    required OcptProjectDatabase database,
    required String resourceId,
  }) => guardOutcome("deleteResource", () async {
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
  });

  /// Load every live mileage rate of [database], in `sortKey` order.
  @useResult
  Future<OcptDatabaseResult<List<OcptBudgetMileageRate>>> loadMileageRates({
    required OcptProjectDatabase database,
  }) => guardResult("loadMileageRates", () async {
    final rows = await _liveMileageRateRows(database);
    return [for (final row in rows) OcptBudgetMileageRate.fromRow(row)];
  });

  /// Create a new mileage rate named [label], appended at the end of the list, and return its
  /// freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseResult<String>> createMileageRate({
    required OcptProjectDatabase database,
    required String label,
  }) => guardResult("createMileageRate", () async {
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
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          isDeleted: false,
          label: label,
          ratePerKmMilliCents: 0,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  });

  /// Update the fields of mileage rate [rateId] in [database] that are passed as something other
  /// than [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderMileageRate] and [deleteMileageRate].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> updateMileageRate({
    required OcptProjectDatabase database,
    required String rateId,
    Value<String> label = const Value.absent(),
    Value<int> ratePerKmMilliCents = const Value.absent(),
  }) => guardOutcome("updateMileageRate", () async {
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
  });

  /// Move mileage rate [rateId] to [newPosition] (0-based) within the list's own flat `sortKey`
  /// order, by giving it a `sortKey` sitting between the two rates it lands between. Writes
  /// **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> reorderMileageRate({
    required OcptProjectDatabase database,
    required String rateId,
    required int newPosition,
  }) => guardOutcome("reorderMileageRate", () async {
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
  });

  /// Tombstone mileage rate [rateId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> deleteMileageRate({
    required OcptProjectDatabase database,
    required String rateId,
  }) => guardOutcome("deleteMileageRate", () async {
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
  });

  /// Write [fields] onto resource [resourceId], then reconcile its counterpart line, aborting the
  /// enclosing transaction on the first write that failed.
  Future<void> _writeFieldsAndReconcile({
    required OcptProjectDatabase database,
    required String resourceId,
    required OcptBudgetResourceFormFields fields,
  }) => database.transaction(() async {
    await updateResource(
      database: database,
      resourceId: resourceId,
      groupKind: Value(fields.groupKind),
      personId: Value(fields.personId),
      label: Value(fields.label),
      amountCents: Value(fields.amountCents),
      status: Value(fields.status),
      isReimbursable: Value(fields.isReimbursable),
      notes: Value(fields.notes),
    ).okOrAbort();

    final existing =
        await (database.select(database.ocptBudgetLinesTable)
              ..where((table) => table.inKindResourceId.equals(resourceId) & table.isDeleted.not())
              ..limit(1))
            .getSingleOrNull();

    if (fields.groupKind != OcptBudgetResourceGroupKind.inKind) {
      if (existing != null) {
        await _quoteService.deleteLine(database: database, lineId: existing.id).okOrAbort();
      }
      return;
    }

    final desiredAccountId = fields.accountId;
    if (desiredAccountId == null) {
      return;
    }

    if (existing != null && existing.accountId == desiredAccountId) {
      await _quoteService
          .updateLine(
            database: database,
            lineId: existing.id,
            label: Value(fields.label),
            unitAmountCents: Value(fields.amountCents),
          )
          .okOrAbort();
      return;
    }

    if (existing != null) {
      await _quoteService.deleteLine(database: database, lineId: existing.id).okOrAbort();
    }

    await _quoteService
        .createLine(
          database: database,
          accountId: desiredAccountId,
          label: fields.label,
          quantityMilli: const Value(1000),
          unitAmountCents: Value(fields.amountCents),
          isTaxInclusive: const Value(true),
          vatRateBasisPoints: const Value(0),
          inKindResourceId: Value(resourceId),
        )
        .valueOrAbort();
  });

  /// Get every live resource row of [database], ordered by `sortKey`.
  Future<List<OcptBudgetResourceRow>> _liveResourceRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetResourcesTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get the live resource row [resourceId], or null if it doesn't exist or has been tombstoned.
  Future<OcptBudgetResourceRow?> _liveResourceRowOrNull({
    required OcptProjectDatabase database,
    required String resourceId,
  }) => (database.select(
    database.ocptBudgetResourcesTable,
  )..where((table) => table.id.equals(resourceId) & table.isDeleted.not())).getSingleOrNull();

  /// Get every live mileage rate row of [database], ordered by `sortKey`.
  Future<List<OcptBudgetMileageRateRow>> _liveMileageRateRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetMileageRatesTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get the live mileage rate row [rateId], or null if it doesn't exist or has been tombstoned.
  Future<OcptBudgetMileageRateRow?> _liveMileageRateRowOrNull({
    required OcptProjectDatabase database,
    required String rateId,
  }) => (database.select(
    database.ocptBudgetMileageRatesTable,
  )..where((table) => table.id.equals(rateId) & table.isDeleted.not())).getSingleOrNull();
}
