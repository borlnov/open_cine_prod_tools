// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_allowance_form_body.dart';

/// The dialog that both **creates and edits** a defrayal — one shape for both, mirroring
/// `OcptBudgetResourceDialog`'s own structure exactly, [show] and all: a [Form], an `AlertDialog`
/// with `Cancel`/`Save` actions, dismissed through `OcptRouterManager.pop`, never `Navigator`.
///
/// **Reduced to a shell over [OcptBudgetAllowanceFormBody].** Every field, controller and
/// validator this dialog used to hold moved to that widget so the capture wizard can draw the very
/// same form under its own step counter and its own `Back`/`Save` buttons; this class keeps only
/// the title and the two actions.
class OcptBudgetAllowanceDialog extends StatefulWidget {
  /// The defrayal being edited, or null while creating a new one.
  final OcptBudgetAllowance? existing;

  /// Every live person of the project's address book, offered by the `Person` picker alongside its
  /// own explicit "no person" choice.
  final List<OcptPerson> people;

  /// Every live mileage rate of the project, read by `Use this person's own rate`.
  final List<OcptBudgetMileageRate> mileageRates;

  /// The project's currency, an ISO 4217 code, shown beside the `Unit price` field.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetAllowanceDialog({
    super.key,
    required this.existing,
    required this.people,
    required this.mileageRates,
    required this.currencyCode,
  });

  /// Create the [_OcptBudgetAllowanceDialogState] holding the state of the budget allowance dialog.
  @override
  State<OcptBudgetAllowanceDialog> createState() => _OcptBudgetAllowanceDialogState();

  /// Show the dialog and return the fields the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetAllowanceFormFields?> show(
    BuildContext context, {
    required OcptBudgetAllowance? existing,
    required List<OcptPerson> people,
    required List<OcptBudgetMileageRate> mileageRates,
    required String currencyCode,
  }) => showDialog<OcptBudgetAllowanceFormFields>(
    context: context,
    builder: (context) => OcptBudgetAllowanceDialog(
      existing: existing,
      people: people,
      mileageRates: mileageRates,
      currencyCode: currencyCode,
    ),
  );
}

/// The state of [OcptBudgetAllowanceDialog]: the form key it hands to
/// [OcptBudgetAllowanceFormBody] and the last draft that body reported.
class _OcptBudgetAllowanceDialogState extends State<OcptBudgetAllowanceDialog> {
  /// The form [OcptBudgetAllowanceFormBody] validates against, owned here since this shell is the
  /// one that decides when to validate it.
  final _formKey = GlobalKey<FormState>();

  /// The fields [OcptBudgetAllowanceFormBody] would submit right now, or null while it cannot be
  /// read at all — see [OcptBudgetAllowanceFormBody.onDraftChanged]'s own doc comment.
  OcptBudgetAllowanceFormFields? _draft;

  /// Build the budget allowance dialog as an [AlertDialog].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? tr.budgetAllowanceDialogCreateTitle
            : tr.budgetAllowanceDialogEditTitle,
      ),
      content: SizedBox(
        width: 420,
        child: OcptBudgetAllowanceFormBody(
          existing: widget.existing,
          people: widget.people,
          mileageRates: widget.mileageRates,
          currencyCode: widget.currencyCode,
          formKey: _formKey,
          onDraftChanged: (draft) => setState(() => _draft = draft),
        ),
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
  /// [OcptBudgetAllowanceFormBody] reported — mirrors what this dialog's own `_submit` did before
  /// it was split.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final draft = _draft;
    if (draft == null) {
      return;
    }

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetAllowanceFormFields>(draft);
  }
}
