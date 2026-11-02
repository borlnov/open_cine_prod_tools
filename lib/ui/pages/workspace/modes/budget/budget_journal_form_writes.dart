// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart' show useResult;
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';

/// Write a form's fields through the cash journal service, for every view bloc that creates or
/// writes a journal entry: the cash journal's own, and the expenses view's `Pay` action.
///
/// These writes are shared, not owned: a journal entry, a financing resource, a taking and a share
/// can each be born in a view that is not theirs (an entry dialog offers to create the resource,
/// the taking or the share it names), and the row must be indistinguishable from one born in its
/// own view. They hold no state and emit nothing; the bloc that calls them reads the snapshot
/// again afterwards.
extension OcptBudgetJournalFormWrites on OcptBudgetJournalService {
  /// Write whatever [fields] collected about a journal entry's own voucher, once the entry itself
  /// exists: a fresh pick ([OcptBudgetEntryFormFields.pickedReceiptPath]) references it, replacing
  /// whatever the entry already carried; the dialog's own `Detach` action
  /// ([OcptBudgetEntryFormFields.isReceiptDetached]) drops it instead — never both at once, see
  /// that field's own doc comment. A no-op when the dialog asked for neither, which answers `ok`;
  /// otherwise answers what the write answered.
  @useResult
  Future<OcptDatabaseOutcome> writeEntryReceiptChange({
    required OcptProjectDatabase database,
    required String entryId,
    required OcptBudgetEntryFormFields fields,
  }) async {
    final pickedReceiptPath = fields.pickedReceiptPath;
    if (pickedReceiptPath != null) {
      final picked = await setEntryReceipt(
        database: database,
        entryId: entryId,
        path: pickedReceiptPath,
      );

      return OcptDatabaseOutcome(status: picked.status, extraInfo: picked.extraInfo);
    }

    if (fields.isReceiptDetached) {
      return clearEntryReceipt(database: database, entryId: entryId);
    }

    return const OcptDatabaseOutcome(status: OcptDatabaseStatus.ok);
  }
}
