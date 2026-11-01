// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_revenue_form_body.dart';

/// The dialog that both **creates and edits** a revenue sharing taking — one shape for both,
/// mirroring `OcptBudgetResourceDialog`'s own structure exactly: a [Form], an `AlertDialog` with
/// `Cancel`/`Save` actions, dismissed through `OcptRouterManager.pop`, never `Navigator`.
///
/// **Reduced to a shell over [OcptBudgetRevenueFormBody].** Every field, controller and validator
/// this dialog used to hold moved to that widget so the capture wizard can draw the very same form
/// under its own step counter and its own `Back`/`Save` buttons; this class keeps only the title
/// and the two actions.
class OcptBudgetRevenueDialog extends StatefulWidget {
  /// The revenue being edited, or null while creating a new one.
  final OcptBudgetRevenue? existing;

  /// The project's currency, an ISO 4217 code, shown beside the `Amount` field.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetRevenueDialog({super.key, required this.existing, required this.currencyCode});

  /// Create the [_OcptBudgetRevenueDialogState] holding the state of the budget revenue dialog.
  @override
  State<OcptBudgetRevenueDialog> createState() => _OcptBudgetRevenueDialogState();

  /// Show the dialog and return the fields the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetRevenueFormFields?> show(
    BuildContext context, {
    required OcptBudgetRevenue? existing,
    required String currencyCode,
  }) => showDialog<OcptBudgetRevenueFormFields>(
    context: context,
    builder: (context) => OcptBudgetRevenueDialog(existing: existing, currencyCode: currencyCode),
  );
}

/// The state of [OcptBudgetRevenueDialog]: the form key it hands to [OcptBudgetRevenueFormBody] and
/// the last draft that body reported.
class _OcptBudgetRevenueDialogState extends State<OcptBudgetRevenueDialog> {
  /// The form [OcptBudgetRevenueFormBody] validates against, owned here since this shell is the
  /// one that decides when to validate it.
  final _formKey = GlobalKey<FormState>();

  /// The fields [OcptBudgetRevenueFormBody] would submit right now, or null while it cannot be read
  /// at all — see [OcptBudgetRevenueFormBody.onDraftChanged]'s own doc comment.
  OcptBudgetRevenueFormFields? _draft;

  /// Build the budget revenue dialog as an [AlertDialog].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? tr.budgetRevenueDialogEditTitle : tr.budgetRevenueDialogCreateTitle),
      content: OcptBudgetRevenueFormBody(
        existing: widget.existing,
        currencyCode: widget.currencyCode,
        formKey: _formKey,
        onDraftChanged: (draft) => setState(() => _draft = draft),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.budgetEntryDialogCancelAction),
        ),
        FilledButton(onPressed: _submit, child: Text(tr.budgetEntryDialogConfirmAction)),
      ],
    );
  }

  /// Validate the form and, if it passes, pop the dialog returning the last draft
  /// [OcptBudgetRevenueFormBody] reported — mirrors what this dialog's own `_submit` did before it
  /// was split.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final draft = _draft;
    if (draft == null) {
      return;
    }

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetRevenueFormFields>(draft);
  }
}
