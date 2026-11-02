// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';

/// Write a form's fields through the revenue sharing service.
extension OcptBudgetSharingFormWrites on OcptBudgetSharingService {
  /// Write every field of [fields] onto revenue [revenueId].
  Future<void> writeRevenueFields({
    required OcptProjectDatabase database,
    required String revenueId,
    required OcptBudgetRevenueFormFields fields,
  }) => updateRevenue(
    database: database,
    revenueId: revenueId,
    date: Value(fields.date),
    label: Value(fields.label),
    amountCents: Value(fields.amountCents),
    status: Value(fields.status),
    notes: Value(fields.notes),
  );

  /// Create the taking [fields] describes — [createRevenue] mints the row from a date and a label
  /// alone, every other field is written straight after — and answer its fresh id, or null if the
  /// row could not be minted.
  Future<String?> createRevenueWithFields({
    required OcptProjectDatabase database,
    required OcptBudgetRevenueFormFields fields,
  }) async {
    final revenueId = await createRevenue(
      database: database,
      date: fields.date,
      label: fields.label,
    );
    if (revenueId != null) {
      await writeRevenueFields(database: database, revenueId: revenueId, fields: fields);
    }

    return revenueId;
  }

  /// Write every field of [fields] onto share [shareId].
  Future<void> writeShareFields({
    required OcptProjectDatabase database,
    required String shareId,
    required OcptBudgetShareFormFields fields,
  }) => updateShare(
    database: database,
    shareId: shareId,
    personId: Value(fields.personId),
    label: Value(fields.label),
    sharePermille: Value(fields.sharePermille),
    reinvestPermille: Value(fields.reinvestPermille),
    notes: Value(fields.notes),
  );

  /// Create the share [fields] describes — [createShare] mints the row from a label alone, every
  /// other field is written straight after — and answer its fresh id, or null if the row could not
  /// be minted.
  Future<String?> createShareWithFields({
    required OcptProjectDatabase database,
    required OcptBudgetShareFormFields fields,
  }) async {
    final shareId = await createShare(database: database, label: fields.label);
    if (shareId != null) {
      await writeShareFields(database: database, shareId: shareId, fields: fields);
    }

    return shareId;
  }
}
