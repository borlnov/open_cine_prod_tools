// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';

/// Writes a form's fields through the cash journal service, for every view bloc that creates or
/// writes a journal entry: the cash journal's own, and the expenses view's `Pay` action.
///
/// These writes are shared, not owned: a journal entry, a financing resource, a taking and a share
/// can each be born in a view that is not theirs (an entry dialog offers to create the resource,
/// the taking or the share it names), and the row must be indistinguishable from one born in its
/// own view. They hold no state and emit nothing; the bloc that calls them reads the snapshot
/// again afterwards.
extension OcptBudgetJournalFormWrites on OcptBudgetJournalService {
  /// Writes whatever [fields] collected about a journal entry's own voucher, once the entry itself
  /// exists: a fresh pick ([OcptBudgetEntryFormFields.pickedReceiptPath]) references it, replacing
  /// whatever the entry already carried; the dialog's own `Detach` action
  /// ([OcptBudgetEntryFormFields.isReceiptDetached]) drops it instead — never both at once, see
  /// that field's own doc comment. A no-op when the dialog asked for neither.
  Future<void> writeEntryReceiptChange({
    required OcptProjectDatabase database,
    required String entryId,
    required OcptBudgetEntryFormFields fields,
  }) async {
    final pickedReceiptPath = fields.pickedReceiptPath;
    if (pickedReceiptPath != null) {
      await setEntryReceipt(database: database, entryId: entryId, path: pickedReceiptPath);
      return;
    }

    if (fields.isReceiptDetached) {
      await clearEntryReceipt(database: database, entryId: entryId);
    }
  }
}

/// Writes a form's fields through the financing service.
extension OcptBudgetFinancingFormWrites on OcptBudgetFinancingService {
  /// Writes every field of [fields] onto resource [resourceId] — shared by the creation of a
  /// resource (right after minting the row) and its update.
  Future<void> writeResourceFields({
    required OcptProjectDatabase database,
    required String resourceId,
    required OcptBudgetResourceFormFields fields,
  }) => updateResource(
    database: database,
    resourceId: resourceId,
    groupKind: Value(fields.groupKind),
    personId: Value(fields.personId),
    label: Value(fields.label),
    amountCents: Value(fields.amountCents),
    status: Value(fields.status),
    isReimbursable: Value(fields.isReimbursable),
    notes: Value(fields.notes),
  );

  /// Creates the resource [fields] describes — [createResource] mints the row from a label alone,
  /// every other field is written straight after — and answers its fresh id, or null if the row
  /// could not be minted.
  Future<String?> createResourceWithFields({
    required OcptProjectDatabase database,
    required OcptBudgetResourceFormFields fields,
  }) async {
    final resourceId = await createResource(database: database, label: fields.label);
    if (resourceId != null) {
      await writeResourceFields(database: database, resourceId: resourceId, fields: fields);
    }

    return resourceId;
  }
}

/// Writes a form's fields through the revenue sharing service.
extension OcptBudgetSharingFormWrites on OcptBudgetSharingService {
  /// Writes every field of [fields] onto revenue [revenueId].
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

  /// Creates the taking [fields] describes — [createRevenue] mints the row from a date and a label
  /// alone, every other field is written straight after — and answers its fresh id, or null if the
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

  /// Writes every field of [fields] onto share [shareId].
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

  /// Creates the share [fields] describes — [createShare] mints the row from a label alone, every
  /// other field is written straight after — and answers its fresh id, or null if the row could not
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
