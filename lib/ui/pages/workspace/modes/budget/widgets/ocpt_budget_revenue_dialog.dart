// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// The dialog that both **creates and edits** a revenue sharing taking — one shape for both,
/// mirroring `OcptBudgetResourceDialog`'s own structure exactly: a [Form], an `AlertDialog` with
/// `Cancel`/`Save` actions, dismissed through `OcptRouterManager.pop`, never `Navigator`.
///
/// **`Label` is the dialog's own only required field, alongside `Date`**, mirroring the financing
/// resource dialog: `Status` already carries a sensible default the moment the dialog opens
/// ([OcptBudgetRevenueStatus.expected]), so there is no second field a fresh taking could be
/// missing.
///
/// **Carries no `amountCents` figure the sharing view treats as anything but what was announced.**
/// `OcptBudgetRevenue.amountCents` is what the taking is *expected* to bring in — what it actually
/// brought in is read off the journal (`OcptBudgetSnapshot.receivedByRevenueId`), exactly as
/// `OcptBudgetResourceDialog`'s own doc comment already argues for a financing resource.
///
/// Every field is collected locally and reported once, on `Save` — nothing here writes to the
/// project on its own.
class OcptBudgetRevenueDialog extends StatefulWidget {
  /// The revenue being edited, or null while creating a new one.
  final OcptBudgetRevenue? existing;

  /// The project's currency, an ISO 4217 code, shown beside the `Amount` field.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetRevenueDialog({super.key, required this.existing, required this.currencyCode});

  /// Shows the dialog and returns the fields the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetRevenueFormFields?> show(
    BuildContext context, {
    required OcptBudgetRevenue? existing,
    required String currencyCode,
  }) => showDialog<OcptBudgetRevenueFormFields>(
    context: context,
    builder: (context) => OcptBudgetRevenueDialog(existing: existing, currencyCode: currencyCode),
  );

  @override
  State<OcptBudgetRevenueDialog> createState() => _OcptBudgetRevenueDialogState();
}

/// The state of [OcptBudgetRevenueDialog].
class _OcptBudgetRevenueDialogState extends State<OcptBudgetRevenueDialog> {
  /// The form used to validate the entered label and amount.
  final _formKey = GlobalKey<FormState>();

  /// The controller of the label field.
  late final TextEditingController _labelController;

  /// The controller of the amount field.
  late final TextEditingController _amountController;

  /// The controller of the notes field.
  late final TextEditingController _notesController;

  /// The date currently picked — today for a new taking.
  late DateTime _date;

  /// The status currently picked.
  late OcptBudgetRevenueStatus _status;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    final now = DateTime.now();

    _date = existing?.date ?? DateTime(now.year, now.month, now.day);
    _status = existing?.status ?? OcptBudgetRevenueStatus.expected;

    _labelController = TextEditingController(text: existing?.label ?? "");
    _amountController = TextEditingController(text: ocptCostTextOf(existing?.amountCents));
    _notesController = TextEditingController(text: existing?.notes ?? "");
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final currencySymbol = NumberFormat.simpleCurrency(name: widget.currencyCode).currencySymbol;

    return AlertDialog(
      title: Text(isEditing ? tr.budgetRevenueDialogEditTitle : tr.budgetRevenueDialogCreateTitle),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OcptPersonSheetDateField(
                label: tr.budgetEntryDialogDateFieldLabel,
                value: _date,
                onChanged: (value) => setState(() => _date = value ?? _date),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelController,
                autofocus: true,
                decoration: InputDecoration(labelText: tr.budgetEntryDialogLabelFieldLabel),
                validator: (value) =>
                    (value ?? "").trim().isEmpty ? tr.budgetEntryDialogLabelRequiredError : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: tr.budgetEntryDialogAmountFieldLabel,
                  suffixText: currencySymbol,
                ),
                validator: (value) =>
                    ocptCostCentsOf(value ?? "") == null ? tr.budgetEntryDialogAmountInvalidError : null,
              ),
              const SizedBox(height: 12),
              Text(
                tr.budgetCommitmentDialogStatusFieldLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              _OcptRevenueStatusPicker(
                value: _status,
                onChanged: (value) => setState(() => _status = value),
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

    final amountCents = ocptCostCentsOf(_amountController.text);
    if (amountCents == null) {
      return;
    }

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetRevenueFormFields>(
      OcptBudgetRevenueFormFields(
        date: _date,
        label: _labelController.text.trim(),
        amountCents: amountCents,
        status: _status,
        notes: _notesController.text.trim(),
      ),
    );
  }
}

/// The revenue dialog's own `Status` picker: `OcptBudgetRevenueStatus`'s own three values as a
/// wrapped row of small, clickable chips, painted in [ocptBudgetRevenueStatusAccentColor] —
/// mirrors `OcptBudgetResourceDialog`'s own `_OcptResourceStatusPicker`.
class _OcptRevenueStatusPicker extends StatelessWidget {
  /// The picker's current value.
  final OcptBudgetRevenueStatus value;

  /// Called with the value just picked.
  final ValueChanged<OcptBudgetRevenueStatus> onChanged;

  /// Class constructor
  const _OcptRevenueStatusPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final status in OcptBudgetRevenueStatus.values) _segment(context, status)],
  );

  /// One of the picker's own segments, filled in its own accent colour while active.
  Widget _segment(BuildContext context, OcptBudgetRevenueStatus status) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isActive = status == value;
    final accent = ocptBudgetRevenueStatusAccentColor(theme.colorScheme, status);

    return InkWell(
      onTap: isActive ? null : () => onChanged(status),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? accent.withValues(alpha: ocptSelectedStateAlpha) : Colors.transparent,
          border: Border.all(color: isActive ? accent : theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Text(
          ocptBudgetRevenueStatusLabel(tr, status),
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? accent : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
