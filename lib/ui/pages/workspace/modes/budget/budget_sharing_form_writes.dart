// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:meta/meta.dart' show useResult;
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';

/// Write a form's fields through the revenue sharing service.
extension OcptBudgetSharingFormWrites on OcptBudgetSharingService {
  /// Write every field of [fields] onto revenue [revenueId].
  @useResult
  Future<OcptDatabaseOutcome> writeRevenueFields({
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
  /// alone, every other field is written straight after — and answer its fresh id, no id if the
  /// row could not be minted, or the failure of whichever of the two writes failed first.
  @useResult
  Future<OcptDatabaseResult<String>> createRevenueWithFields({
    required OcptProjectDatabase database,
    required OcptBudgetRevenueFormFields fields,
  }) async {
    final created = await createRevenue(database: database, date: fields.date, label: fields.label);
    if (created.isError) {
      return created;
    }

    final revenueId = created.value;
    if (revenueId != null) {
      final written = await writeRevenueFields(
        database: database,
        revenueId: revenueId,
        fields: fields,
      );
      if (written.isError) {
        return OcptDatabaseResult(status: written.status, extraInfo: written.extraInfo);
      }
    }

    return created;
  }

  /// Write every field of [fields] onto share [shareId].
  @useResult
  Future<OcptDatabaseOutcome> writeShareFields({
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
  /// other field is written straight after — and answer its fresh id, no id if the row could not
  /// be minted, or the failure of whichever of the two writes failed first.
  @useResult
  Future<OcptDatabaseResult<String>> createShareWithFields({
    required OcptProjectDatabase database,
    required OcptBudgetShareFormFields fields,
  }) async {
    final created = await createShare(database: database, label: fields.label);
    if (created.isError) {
      return created;
    }

    final shareId = created.value;
    if (shareId != null) {
      final written = await writeShareFields(database: database, shareId: shareId, fields: fields);
      if (written.isError) {
        return OcptDatabaseResult(status: written.status, extraInfo: written.extraInfo);
      }
    }

    return created;
  }
}
