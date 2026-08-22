// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// The dialog that both **creates and edits** a financing resource — one shape for both, mirroring
/// `OcptBudgetCommitmentDialog`'s own structure exactly, [show] and all: a [Form], an `AlertDialog`
/// with `Cancel`/`Save` actions, dismissed through `OcptRouterManager.pop`, never `Navigator`.
///
/// **`Label` is the dialog's own only required field**, unlike the commitment dialog's own two: a
/// resource's `Group` and `Status` both already carry a sensible default the moment the dialog
/// opens (the first group, [OcptBudgetResourceStatus.applied]), so there is no second field a
/// fresh resource could be missing the way a commitment is missing its poste until somebody picks
/// one.
///
/// **Carries no tax basis or VAT rate field**, unlike every other form of this mode: see
/// `OcptBudgetResourceFormFields`'s own doc comment for why a financing resource asks for neither.
///
/// Every field is collected locally and reported once, on `Save` — nothing here writes to the
/// project on its own, exactly as `OcptBudgetCommitmentDialog` collects and reports its own fields.
class OcptBudgetResourceDialog extends StatefulWidget {
  /// The resource being edited, or null while creating a new one.
  final OcptBudgetResource? existing;

  /// The project's currency, an ISO 4217 code, shown beside the `Amount` field.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetResourceDialog({super.key, required this.existing, required this.currencyCode});

  /// Shows the dialog and returns the fields the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetResourceFormFields?> show(
    BuildContext context, {
    required OcptBudgetResource? existing,
    required String currencyCode,
  }) => showDialog<OcptBudgetResourceFormFields>(
    context: context,
    builder: (context) => OcptBudgetResourceDialog(existing: existing, currencyCode: currencyCode),
  );

  @override
  State<OcptBudgetResourceDialog> createState() => _OcptBudgetResourceDialogState();
}

/// The state of [OcptBudgetResourceDialog].
class _OcptBudgetResourceDialogState extends State<OcptBudgetResourceDialog> {
  /// The form used to validate the entered label and amount.
  final _formKey = GlobalKey<FormState>();

  /// The controller of the label field.
  late final TextEditingController _labelController;

  /// The controller of the amount field.
  late final TextEditingController _amountController;

  /// The controller of the notes field.
  late final TextEditingController _notesController;

  /// The group kind currently picked.
  late OcptBudgetResourceGroupKind _groupKind;

  /// The status currently picked.
  late OcptBudgetResourceStatus _status;

  /// Whether this resource is currently marked reimbursable.
  late bool _isReimbursable;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _groupKind = existing?.groupKind ?? OcptBudgetResourceGroupKind.subsidy;
    _status = existing?.status ?? OcptBudgetResourceStatus.applied;
    _isReimbursable = existing?.isReimbursable ?? false;

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
      title: Text(isEditing ? tr.budgetResourceDialogEditTitle : tr.budgetResourceDialogCreateTitle),
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
              Text(
                tr.budgetResourceDialogGroupFieldLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              _OcptResourceGroupKindPicker(
                value: _groupKind,
                onChanged: (value) => setState(() => _groupKind = value),
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
              _OcptResourceStatusPicker(
                value: _status,
                onChanged: (value) => setState(() => _status = value),
              ),
              const SizedBox(height: 12),
              Text(
                tr.budgetResourceDialogReimbursableFieldLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              OcptBudgetBinaryChoice(
                value: _isReimbursable,
                trueLabel: tr.budgetResourceDialogReimbursableOption,
                falseLabel: tr.budgetResourceDialogNotReimbursableOption,
                onChanged: (value) => setState(() => _isReimbursable = value),
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

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetResourceFormFields>(
      OcptBudgetResourceFormFields(
        groupKind: _groupKind,
        label: _labelController.text.trim(),
        amountCents: amountCents,
        status: _status,
        isReimbursable: _isReimbursable,
        notes: _notesController.text.trim(),
      ),
    );
  }
}

/// The resource dialog's own `Group` picker: `OcptBudgetResourceGroupKind`'s own three values as a
/// wrapped row of small, clickable chips — mirrors `OcptBudgetCommitmentDialog`'s own status
/// picker, generic over a different enum.
class _OcptResourceGroupKindPicker extends StatelessWidget {
  /// The picker's current value.
  final OcptBudgetResourceGroupKind value;

  /// Called with the value just picked.
  final ValueChanged<OcptBudgetResourceGroupKind> onChanged;

  /// Class constructor
  const _OcptResourceGroupKindPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final kind in OcptBudgetResourceGroupKind.values) _segment(context, kind)],
  );

  /// One of the picker's own segments.
  Widget _segment(BuildContext context, OcptBudgetResourceGroupKind kind) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isActive = kind == value;

    return InkWell(
      onTap: isActive ? null : () => onChanged(kind),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : Colors.transparent,
          border: Border.all(color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Text(
          ocptBudgetResourceGroupKindLabel(tr, kind),
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// The resource dialog's own `Status` picker: `OcptBudgetResourceStatus`'s own four values as a
/// wrapped row of small, clickable chips, painted in [ocptBudgetResourceStatusAccentColor] — the
/// same colour and word the financing view's own status pill reads them in, mirroring
/// `OcptBudgetCommitmentDialog`'s own `_OcptCommitmentStatusPicker`.
class _OcptResourceStatusPicker extends StatelessWidget {
  /// The picker's current value.
  final OcptBudgetResourceStatus value;

  /// Called with the value just picked.
  final ValueChanged<OcptBudgetResourceStatus> onChanged;

  /// Class constructor
  const _OcptResourceStatusPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final status in OcptBudgetResourceStatus.values) _segment(context, status)],
  );

  /// One of the picker's own segments, filled in its own accent colour while active.
  Widget _segment(BuildContext context, OcptBudgetResourceStatus status) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isActive = status == value;
    final accent = ocptBudgetResourceStatusAccentColor(theme.colorScheme, status);

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
          ocptBudgetResourceStatusLabel(tr, status),
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? accent : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
