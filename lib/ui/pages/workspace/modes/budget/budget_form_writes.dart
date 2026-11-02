// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:meta/meta.dart' show useResult;
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';

/// Write a form's fields through the financing service.
extension OcptBudgetFinancingFormWrites on OcptBudgetFinancingService {
  /// Write every field of [fields] onto resource [resourceId] — shared by the creation of a
  /// resource (right after minting the row) and its update.
  @useResult
  Future<OcptDatabaseOutcome> writeResourceFields({
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

  /// Create the resource [fields] describes — [createResource] mints the row from a label alone,
  /// every other field is written straight after — and answer its fresh id, no id if the row
  /// could not be minted, or the failure of whichever of the two writes failed first.
  @useResult
  Future<OcptDatabaseResult<String>> createResourceWithFields({
    required OcptProjectDatabase database,
    required OcptBudgetResourceFormFields fields,
  }) async {
    final created = await createResource(database: database, label: fields.label);
    if (created.isError) {
      return created;
    }

    final resourceId = created.value;
    if (resourceId != null) {
      final written = await writeResourceFields(
        database: database,
        resourceId: resourceId,
        fields: fields,
      );
      if (written.isError) {
        return OcptDatabaseResult(status: written.status, extraInfo: written.extraInfo);
      }
    }

    return created;
  }
}
