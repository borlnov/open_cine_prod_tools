// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/utils/ocpt_percent_permille.dart';

/// The dialog that both **creates and edits** a revenue sharing share — one shape for both,
/// mirroring `OcptBudgetResourceDialog`'s own structure exactly: a [Form], an `AlertDialog` with
/// `Cancel`/`Save` actions, dismissed through `OcptRouterManager.pop`, never `Navigator`.
///
/// **`Label` is the dialog's own only required field.** `Person`, `Share` and `Reinvest` all carry
/// a sensible default the moment the dialog opens (no person, 0 %, 0 %), so there is no second
/// field a fresh share could be missing.
///
/// **`Person` is a picker offering [people] alongside its own explicit "no person" choice** —
/// `OcptBudgetShare.personId`'s own doc comment: a role such as "Production" is a real participant
/// naming no one person, so null is the ordinary, legitimate answer here, not an unfinished pick.
///
/// **`Share` and `Reinvest` are typed as percentages and stored as per mille**, through
/// [ocptPercentPermilleOf]/[ocptPermillePercentTextOf] (`lib/utils/ocpt_percent_permille.dart`) —
/// see that file's own doc comment for why neither `ocptCostCentsOf` nor
/// `ocptVatRateBasisPointsOf`/`ocptMileageRateMilliCentsOf` fit this one scale.
///
/// **The sum of every live share's own `Share` is never checked here.** `OcptBudgetSharesTable`'s
/// own doc comment and `OcptBudgetSharing`'s own class doc comment both argue why the app states
/// the mismatch rather than refusing the write — this dialog is not the place that argument would
/// live even if it did check, since a single share's own field can never tell whether the *others*
/// still sum correctly.
///
/// Every field is collected locally and reported once, on `Save` — nothing here writes to the
/// project on its own.
class OcptBudgetShareDialog extends StatefulWidget {
  /// The share being edited, or null while creating a new one.
  final OcptBudgetShare? existing;

  /// Every live person of the project's address book, offered by the `Person` picker alongside its
  /// own explicit "no person" choice.
  final List<OcptPerson> people;

  /// Class constructor
  const OcptBudgetShareDialog({super.key, required this.existing, required this.people});

  /// Shows the dialog and returns the fields the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetShareFormFields?> show(
    BuildContext context, {
    required OcptBudgetShare? existing,
    required List<OcptPerson> people,
  }) => showDialog<OcptBudgetShareFormFields>(
    context: context,
    builder: (context) => OcptBudgetShareDialog(existing: existing, people: people),
  );

  @override
  State<OcptBudgetShareDialog> createState() => _OcptBudgetShareDialogState();
}

/// The state of [OcptBudgetShareDialog].
class _OcptBudgetShareDialogState extends State<OcptBudgetShareDialog> {
  /// The form used to validate the entered fields.
  final _formKey = GlobalKey<FormState>();

  /// The controller of the label field.
  late final TextEditingController _labelController;

  /// The controller of the share field.
  late final TextEditingController _shareController;

  /// The controller of the reinvest field.
  late final TextEditingController _reinvestController;

  /// The controller of the notes field.
  late final TextEditingController _notesController;

  /// The person currently picked, or null for "no person" — the normal case, see the class doc
  /// comment.
  String? _personId;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _personId = existing?.personId;

    _labelController = TextEditingController(text: existing?.label ?? "");
    _shareController = TextEditingController(text: ocptPermillePercentTextOf(existing?.sharePermille ?? 0));
    _reinvestController = TextEditingController(
      text: ocptPermillePercentTextOf(existing?.reinvestPermille ?? 0),
    );
    _notesController = TextEditingController(text: existing?.notes ?? "");
  }

  @override
  void dispose() {
    _labelController.dispose();
    _shareController.dispose();
    _reinvestController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? tr.budgetShareDialogEditTitle : tr.budgetShareDialogCreateTitle),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _labelController,
                autofocus: true,
                decoration: InputDecoration(labelText: tr.budgetEntryDialogLabelFieldLabel),
                validator: (value) =>
                    (value ?? "").trim().isEmpty ? tr.budgetEntryDialogLabelRequiredError : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _personId,
                decoration: InputDecoration(labelText: tr.budgetShareDialogPersonFieldLabel),
                items: [
                  DropdownMenuItem(child: Text(tr.budgetShareDialogNoPersonLabel)),
                  for (final person in widget.people)
                    DropdownMenuItem(value: person.id, child: Text(person.displayName)),
                ],
                onChanged: (value) => setState(() => _personId = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _shareController,
                decoration: InputDecoration(
                  labelText: tr.budgetShareDialogShareFieldLabel,
                  suffixText: tr.budgetLineVatRateSuffix,
                ),
                validator: (value) => ocptPercentPermilleOf(value ?? "") == null
                    ? tr.budgetShareDialogPercentInvalidError
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reinvestController,
                decoration: InputDecoration(
                  labelText: tr.budgetShareDialogReinvestFieldLabel,
                  suffixText: tr.budgetLineVatRateSuffix,
                ),
                validator: (value) => ocptPercentPermilleOf(value ?? "") == null
                    ? tr.budgetShareDialogPercentInvalidError
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: tr.budgetLineNotesFieldLabel),
              ),
            ],
          ),
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

  /// Validates the form and, if it passes, pops the dialog returning every field collected.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final sharePermille = ocptPercentPermilleOf(_shareController.text);
    final reinvestPermille = ocptPercentPermilleOf(_reinvestController.text);
    if (sharePermille == null || reinvestPermille == null) {
      return;
    }

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetShareFormFields>(
      OcptBudgetShareFormFields(
        personId: _personId,
        label: _labelController.text.trim(),
        sharePermille: sharePermille,
        reinvestPermille: reinvestPermille,
        notes: _notesController.text.trim(),
      ),
    );
  }
}
