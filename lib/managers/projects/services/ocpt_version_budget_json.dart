// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_production_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_reader.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';

/// The JSON shape of the budget rows in a version's payload: one serializer and one parser per
/// table, mirroring its columns.
abstract final class OcptVersionBudgetJson {
  /// Serializes one `budget_postes` row.
  static Map<String, dynamic> budgetPosteToJson(OcptBudgetPosteRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonKeys.codeKey: row.code,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.simpleLabelKey: row.simpleLabel,
    OcptVersionJsonProductionKeys.estimateToCompleteCentsKey: row.estimateToCompleteCents,
  };

  /// Parses one `budget_postes` row.
  static OcptBudgetPosteRow budgetPosteFromJson(Map<String, dynamic> json) => OcptBudgetPosteRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
    code: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.codeKey),
    label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
    simpleLabel: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.simpleLabelKey,
    ),
    estimateToCompleteCents: OcptVersionJsonReader.readNullableInt(
      json,
      OcptVersionJsonProductionKeys.estimateToCompleteCentsKey,
    ),
  );

  /// Serializes one `budget_lines` row.
  static Map<String, dynamic> budgetLineToJson(OcptBudgetLineRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonProductionKeys.posteIdKey: row.posteId,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.quantityMilliKey: row.quantityMilli,
    OcptVersionJsonProductionKeys.unitKey: row.unit,
    OcptVersionJsonProductionKeys.unitAmountCentsKey: row.unitAmountCents,
    OcptVersionJsonProductionKeys.isTaxInclusiveKey: row.isTaxInclusive,
    OcptVersionJsonProductionKeys.vatRateBasisPointsKey: row.vatRateBasisPoints,
    OcptVersionJsonProductionKeys.elementIdKey: row.elementId,
    OcptVersionJsonProductionKeys.inKindResourceIdKey: row.inKindResourceId,
    OcptVersionJsonProductionKeys.provisionKeyKey: row.provisionKey,
    OcptVersionJsonProductionKeys.provisionDigestKey: row.provisionDigest,
    OcptVersionJsonKeys.notesKey: row.notes,
  };

  /// Parses one `budget_lines` row.
  static OcptBudgetLineRow budgetLineFromJson(Map<String, dynamic> json) => OcptBudgetLineRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
    posteId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.posteIdKey),
    label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
    quantityMilli: OcptVersionJsonReader.readInt(
      json,
      OcptVersionJsonProductionKeys.quantityMilliKey,
    ),
    unit: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.unitKey),
    unitAmountCents: OcptVersionJsonReader.readInt(
      json,
      OcptVersionJsonProductionKeys.unitAmountCentsKey,
    ),
    isTaxInclusive: OcptVersionJsonReader.readBool(
      json,
      OcptVersionJsonProductionKeys.isTaxInclusiveKey,
    ),
    vatRateBasisPoints: OcptVersionJsonReader.readNullableInt(
      json,
      OcptVersionJsonProductionKeys.vatRateBasisPointsKey,
    ),
    elementId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.elementIdKey,
    ),
    inKindResourceId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.inKindResourceIdKey,
    ),
    provisionKey: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.provisionKeyKey,
    ),
    provisionDigest: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.provisionDigestKey,
    ),
    notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
  );

  /// Serializes one `budget_entries` row.
  static Map<String, dynamic> budgetEntryToJson(OcptBudgetEntryRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonProductionKeys.dateKey: row.date.toIso8601String(),
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.posteIdKey: row.posteId,
    OcptVersionJsonProductionKeys.debitCentsKey: row.debitCents,
    OcptVersionJsonProductionKeys.creditCentsKey: row.creditCents,
    OcptVersionJsonProductionKeys.isTaxInclusiveKey: row.isTaxInclusive,
    OcptVersionJsonProductionKeys.vatRateBasisPointsKey: row.vatRateBasisPoints,
    OcptVersionJsonProductionKeys.voucherNumberKey: row.voucherNumber,
    OcptVersionJsonProductionKeys.resourceIdKey: row.resourceId,
    OcptVersionJsonProductionKeys.revenueIdKey: row.revenueId,
    OcptVersionJsonProductionKeys.shareIdKey: row.shareId,
    OcptVersionJsonProductionKeys.commitmentIdKey: row.commitmentId,
    OcptVersionJsonKeys.personIdKey: row.personId,
  };

  /// Parses one `budget_entries` row.
  static OcptBudgetEntryRow budgetEntryFromJson(Map<String, dynamic> json) => OcptBudgetEntryRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
    date: OcptVersionJsonReader.readDateTime(json, OcptVersionJsonProductionKeys.dateKey),
    label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
    posteId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.posteIdKey,
    ),
    debitCents: OcptVersionJsonReader.readInt(json, OcptVersionJsonProductionKeys.debitCentsKey),
    creditCents: OcptVersionJsonReader.readInt(json, OcptVersionJsonProductionKeys.creditCentsKey),
    isTaxInclusive: OcptVersionJsonReader.readBool(
      json,
      OcptVersionJsonProductionKeys.isTaxInclusiveKey,
    ),
    vatRateBasisPoints: OcptVersionJsonReader.readNullableInt(
      json,
      OcptVersionJsonProductionKeys.vatRateBasisPointsKey,
    ),
    voucherNumber: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonProductionKeys.voucherNumberKey,
    ),
    resourceId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.resourceIdKey,
    ),
    revenueId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.revenueIdKey,
    ),
    shareId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.shareIdKey,
    ),
    commitmentId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.commitmentIdKey,
    ),
    personId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.personIdKey),
  );

  /// Serializes one `budget_commitments` row.
  static Map<String, dynamic> budgetCommitmentToJson(OcptBudgetCommitmentRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonProductionKeys.dueDateKey: row.dueDate?.toIso8601String(),
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.posteIdKey: row.posteId,
    OcptVersionJsonProductionKeys.amountCentsKey: row.amountCents,
    OcptVersionJsonProductionKeys.isTaxInclusiveKey: row.isTaxInclusive,
    OcptVersionJsonProductionKeys.vatRateBasisPointsKey: row.vatRateBasisPoints,
    OcptVersionJsonKeys.statusKey: row.status.name,
    OcptVersionJsonProductionKeys.commitmentLineIdKey: row.lineId,
  };

  /// Parses one `budget_commitments` row.
  static OcptBudgetCommitmentRow budgetCommitmentFromJson(Map<String, dynamic> json) =>
      OcptBudgetCommitmentRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
        dueDate: OcptVersionJsonReader.readNullableDateTime(
          json,
          OcptVersionJsonProductionKeys.dueDateKey,
        ),
        label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
        posteId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.posteIdKey),
        amountCents: OcptVersionJsonReader.readInt(
          json,
          OcptVersionJsonProductionKeys.amountCentsKey,
        ),
        isTaxInclusive: OcptVersionJsonReader.readBool(
          json,
          OcptVersionJsonProductionKeys.isTaxInclusiveKey,
        ),
        vatRateBasisPoints: OcptVersionJsonReader.readNullableInt(
          json,
          OcptVersionJsonProductionKeys.vatRateBasisPointsKey,
        ),
        status: OcptVersionJsonReader.readEnum(
          json,
          OcptVersionJsonKeys.statusKey,
          OcptBudgetCommitmentStatus.values.asNameMap(),
        ),
        lineId: OcptVersionJsonReader.readNullableString(
          json,
          OcptVersionJsonProductionKeys.commitmentLineIdKey,
        ),
      );

  /// Serializes one `budget_resources` row.
  static Map<String, dynamic> budgetResourceToJson(OcptBudgetResourceRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonProductionKeys.groupKindKey: row.groupKind.name,
    OcptVersionJsonKeys.personIdKey: row.personId,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.amountCentsKey: row.amountCents,
    OcptVersionJsonKeys.statusKey: row.status.name,
    OcptVersionJsonProductionKeys.isReimbursableKey: row.isReimbursable,
    OcptVersionJsonKeys.notesKey: row.notes,
  };

  /// Parses one `budget_resources` row.
  static OcptBudgetResourceRow budgetResourceFromJson(Map<String, dynamic> json) =>
      OcptBudgetResourceRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
        groupKind: OcptVersionJsonReader.readEnum(
          json,
          OcptVersionJsonProductionKeys.groupKindKey,
          OcptBudgetResourceGroupKind.values.asNameMap(),
        ),
        personId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.personIdKey),
        label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
        amountCents: OcptVersionJsonReader.readInt(
          json,
          OcptVersionJsonProductionKeys.amountCentsKey,
        ),
        status: OcptVersionJsonReader.readEnum(
          json,
          OcptVersionJsonKeys.statusKey,
          OcptBudgetResourceStatus.values.asNameMap(),
        ),
        isReimbursable: OcptVersionJsonReader.readBool(
          json,
          OcptVersionJsonProductionKeys.isReimbursableKey,
        ),
        notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
      );

  /// Serializes one `budget_mileage_rates` row.
  static Map<String, dynamic> budgetMileageRateToJson(OcptBudgetMileageRateRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.ratePerKmMilliCentsKey: row.ratePerKmMilliCents,
  };

  /// Parses one `budget_mileage_rates` row.
  static OcptBudgetMileageRateRow budgetMileageRateFromJson(Map<String, dynamic> json) =>
      OcptBudgetMileageRateRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
        label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
        ratePerKmMilliCents: OcptVersionJsonReader.readInt(
          json,
          OcptVersionJsonProductionKeys.ratePerKmMilliCentsKey,
        ),
      );

  /// Serializes one `budget_revenues` row.
  static Map<String, dynamic> budgetRevenueToJson(OcptBudgetRevenueRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonProductionKeys.dateKey: row.date.toIso8601String(),
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.amountCentsKey: row.amountCents,
    OcptVersionJsonKeys.statusKey: row.status.name,
    OcptVersionJsonKeys.notesKey: row.notes,
  };

  /// Parses one `budget_revenues` row.
  static OcptBudgetRevenueRow budgetRevenueFromJson(Map<String, dynamic> json) =>
      OcptBudgetRevenueRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
        date: OcptVersionJsonReader.readDateTime(json, OcptVersionJsonProductionKeys.dateKey),
        label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
        amountCents: OcptVersionJsonReader.readInt(
          json,
          OcptVersionJsonProductionKeys.amountCentsKey,
        ),
        status: OcptVersionJsonReader.readEnum(
          json,
          OcptVersionJsonKeys.statusKey,
          OcptBudgetRevenueStatus.values.asNameMap(),
        ),
        notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
      );

  /// Serializes one `budget_shares` row.
  static Map<String, dynamic> budgetShareToJson(OcptBudgetShareRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonKeys.personIdKey: row.personId,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.sharePermilleKey: row.sharePermille,
    OcptVersionJsonProductionKeys.reinvestPermilleKey: row.reinvestPermille,
    OcptVersionJsonKeys.notesKey: row.notes,
  };

  /// Parses one `budget_shares` row.
  static OcptBudgetShareRow budgetShareFromJson(Map<String, dynamic> json) => OcptBudgetShareRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
    personId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.personIdKey),
    label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
    sharePermille: OcptVersionJsonReader.readInt(
      json,
      OcptVersionJsonProductionKeys.sharePermilleKey,
    ),
    reinvestPermille: OcptVersionJsonReader.readInt(
      json,
      OcptVersionJsonProductionKeys.reinvestPermilleKey,
    ),
    notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
  );

  /// Serializes one `budget_allowances` row.
  static Map<String, dynamic> budgetAllowanceToJson(OcptBudgetAllowanceRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonKeys.personIdKey: row.personId,
    OcptVersionJsonKeys.kindKey: row.kind.name,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.dateKey: row.date?.toIso8601String(),
    OcptVersionJsonKeys.endDateKey: row.endDate?.toIso8601String(),
    OcptVersionJsonProductionKeys.quantityMilliKey: row.quantityMilli,
    OcptVersionJsonProductionKeys.unitAmountMilliCentsKey: row.unitAmountMilliCents,
    OcptVersionJsonKeys.notesKey: row.notes,
  };

  /// Parses one `budget_allowances` row.
  static OcptBudgetAllowanceRow budgetAllowanceFromJson(Map<String, dynamic> json) =>
      OcptBudgetAllowanceRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
        personId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.personIdKey),
        kind: OcptVersionJsonReader.readEnum(
          json,
          OcptVersionJsonKeys.kindKey,
          OcptBudgetAllowanceKind.values.asNameMap(),
        ),
        label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
        date: OcptVersionJsonReader.readNullableDateTime(
          json,
          OcptVersionJsonProductionKeys.dateKey,
        ),
        endDate: OcptVersionJsonReader.readNullableDateTime(json, OcptVersionJsonKeys.endDateKey),
        quantityMilli: OcptVersionJsonReader.readInt(
          json,
          OcptVersionJsonProductionKeys.quantityMilliKey,
        ),
        unitAmountMilliCents: OcptVersionJsonReader.readInt(
          json,
          OcptVersionJsonProductionKeys.unitAmountMilliCentsKey,
        ),
        notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
      );
}
