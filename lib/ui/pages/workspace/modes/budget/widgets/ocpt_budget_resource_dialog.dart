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
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
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
/// opens (the first group, [OcptBudgetResourceStatus.pending]), so there is no second field a
/// fresh resource could be missing the way a commitment is missing its poste until somebody picks
/// one.
///
/// **The `Group` is fixed, and the picker hidden, while creating.** `OcptBudgetFinancing`'s own
/// `+ Resource` control is three explicit gestures now, one per `OcptBudgetResourceGroupKind`
/// (*"Ajouter une caméra qui est valorisée n'est pas la même chose que d'ajouter du vrai argent qui
/// va servir à la production pour acheter à manger"*), so the kind a fresh resource is created as is
/// already decided before this dialog even opens, and [groupKind] carries it; offering the picker
/// again here would let the very gesture that named the kind be second-guessed one field later, for
/// no reason a reader could name. Editing is different: `_OcptResourceGroupKindPicker` stays, since
/// a production is free to reclassify a resource it already created, exactly as it is today.
///
/// **The `Amount` field's own label and helper text are worded for the kind picked**, per this
/// whole change's own point: a valuation and real money read the same in every other field, but not
/// in what the figure itself means — see `_amountFieldLabel`/`_amountFieldHelper`. The `Status`
/// **The `Status` picker reads in the kind's own vocabulary**, and this is the other half of the
/// same point: a subsidy is `Applied` for, `Notified`, `Secured`; a cash contribution `Requested`,
/// `Agreed`, `Contracted`; a contribution in kind `Promised`, `Valued`, `Signed`. Asking a
/// production to call a lent camera "applied for" was asking it to file a dossier at a commission
/// that does not exist. **Nothing is hidden or disabled by kind for all that** — the mode's
/// standing rule that the UI carries no conditional branch on the state of the data holds intact:
/// the picker always offers the same three steps, and only their words change with the kind
/// picked, `OcptBudgetResourceStatus`'s own doc comment. The field keeps its own helper worded per
/// kind too (`_statusFieldHelper`). Changing the kind of a resource being edited therefore never
/// invalidates its status: the step survives and simply re-words itself.
///
/// **Carries no tax basis or VAT rate field**, unlike every other form of this mode: see
/// `OcptBudgetResourceFormFields`'s own doc comment for why a financing resource asks for neither.
///
/// **`Person` is a picker offering [people] alongside its own explicit "no person" choice**,
/// mirroring `OcptBudgetShareDialog`'s own `Person` field exactly: a subsidy usually names nobody,
/// which is the ordinary, legitimate answer here, not an unfinished pick —
/// `OcptBudgetResourcesTable.personId`'s own doc comment.
///
/// Every field is collected locally and reported once, on `Save` — nothing here writes to the
/// project on its own, exactly as `OcptBudgetCommitmentDialog` collects and reports its own fields.
class OcptBudgetResourceDialog extends StatefulWidget {
  /// The resource being edited, or null while creating a new one.
  final OcptBudgetResource? existing;

  /// The kind a fresh resource is created as — ignored while [existing] is not null, whose own
  /// [OcptBudgetResource.groupKind] is read instead. See the class doc comment for why creation
  /// fixes the kind rather than asking again.
  final OcptBudgetResourceGroupKind groupKind;

  /// Every live person of the project's address book, offered by the `Person` picker alongside its
  /// own explicit "no person" choice.
  final List<OcptPerson> people;

  /// The project's currency, an ISO 4217 code, shown beside the `Amount` field.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetResourceDialog({
    super.key,
    required this.existing,
    required this.groupKind,
    required this.people,
    required this.currencyCode,
  });

  /// Shows the dialog and returns the fields the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetResourceFormFields?> show(
    BuildContext context, {
    required OcptBudgetResource? existing,
    required OcptBudgetResourceGroupKind groupKind,
    required List<OcptPerson> people,
    required String currencyCode,
  }) => showDialog<OcptBudgetResourceFormFields>(
    context: context,
    builder: (context) => OcptBudgetResourceDialog(
      existing: existing,
      groupKind: groupKind,
      people: people,
      currencyCode: currencyCode,
    ),
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

  /// The group kind currently picked — fixed to `widget.groupKind` for as long as this dialog is
  /// creating, since its own picker is not drawn then; see the class doc comment.
  late OcptBudgetResourceGroupKind _groupKind;

  /// The status currently picked.
  late OcptBudgetResourceStatus _status;

  /// Whether this resource is currently marked reimbursable.
  late bool _isReimbursable;

  /// The person currently picked, or null for "no person" — the normal case for a subsidy, see the
  /// class doc comment.
  String? _personId;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _groupKind = existing?.groupKind ?? widget.groupKind;
    _status = existing?.status ?? OcptBudgetResourceStatus.pending;
    _isReimbursable = existing?.isReimbursable ?? false;
    _personId = existing?.personId;

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
      title: Text(_titleOf(tr, isEditing: isEditing)),
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
              // The `Group` picker is only drawn while editing — see the class doc comment for why
              // a fresh resource's kind is fixed by the gesture that opened this dialog rather than
              // asked for again here.
              if (isEditing) ...[
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
              ],
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
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: _amountFieldLabel(tr),
                  helperText: _amountFieldHelper(tr),
                  helperMaxLines: 2,
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
                groupKind: _groupKind,
                value: _status,
                onChanged: (value) => setState(() => _status = value),
              ),
              const SizedBox(height: 4),
              Text(
                _statusFieldHelper(tr),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
              if (_groupKind == OcptBudgetResourceGroupKind.inKind) ...[
                const SizedBox(height: 4),
                Text(
                  tr.budgetResourceDialogReimbursableHelperInKind,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
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
        personId: _personId,
        label: _labelController.text.trim(),
        amountCents: amountCents,
        status: _status,
        isReimbursable: _isReimbursable,
        notes: _notesController.text.trim(),
      ),
    );
  }

  /// This dialog's own title: the kind-specific creation title while creating (`New subsidy`, `New
  /// cash contribution`, `New in-kind contribution`), the plain, kind-agnostic edit title
  /// otherwise — a resource being edited may have its kind changed right there in the form, so no
  /// one kind's name belongs in the title any more, unlike a fresh resource's.
  String _titleOf(Tr tr, {required bool isEditing}) {
    if (isEditing) {
      return tr.budgetResourceDialogEditTitle;
    }

    return switch (_groupKind) {
      OcptBudgetResourceGroupKind.subsidy => tr.budgetResourceDialogCreateSubsidyTitle,
      OcptBudgetResourceGroupKind.cash => tr.budgetResourceDialogCreateCashTitle,
      OcptBudgetResourceGroupKind.inKind => tr.budgetResourceDialogCreateInKindTitle,
    };
  }

  /// The `Amount` field's own label, worded for [_groupKind] — see the class doc comment: an
  /// in-kind contribution's figure is what it is *valued at*, never an amount to be received.
  String _amountFieldLabel(Tr tr) => switch (_groupKind) {
    OcptBudgetResourceGroupKind.inKind => tr.budgetResourceDialogValuedAtFieldLabel,
    OcptBudgetResourceGroupKind.subsidy || OcptBudgetResourceGroupKind.cash =>
      tr.budgetEntryDialogAmountFieldLabel,
  };

  /// The `Amount` field's own helper text, worded for [_groupKind] — this is the field the product
  /// owner could not tell apart by kind: what the figure actually means differs from one kind to
  /// the next, even though the field itself is asked of all three.
  String _amountFieldHelper(Tr tr) => switch (_groupKind) {
    OcptBudgetResourceGroupKind.subsidy => tr.budgetResourceDialogAmountHelperSubsidy,
    OcptBudgetResourceGroupKind.cash => tr.budgetResourceDialogAmountHelperCash,
    OcptBudgetResourceGroupKind.inKind => tr.budgetResourceDialogAmountHelperInKind,
  };

  /// **Why the choice is offered on an in-kind contribution at all, rather than forced off.**
  /// The common case is the one it reads against: a camera lent, a location made available, a
  /// vehicle — valued in the quote, never collected, so nothing can ever come back out. But a
  /// co-producer's contribution in industry — a lab, a post house, a rental company entering the
  /// contract — is recouped from the takings exactly as cash is, and that is the normal
  /// counterpart of their entering it at all. Forcing the choice off would have made this app
  /// unable to state an ordinary co-production, so the helper below states which case is which and
  /// leaves the decision where it belongs.
  /// The `Status` field's own helper text, worded for [_groupKind]. **No status is hidden or
  /// disabled by kind** — only the wording changes, never which of the three steps may be picked:
  /// the mode's standing rule that the UI carries no conditional branch on the state of the data.
  String _statusFieldHelper(Tr tr) => switch (_groupKind) {
    OcptBudgetResourceGroupKind.subsidy => tr.budgetResourceDialogStatusHelperSubsidy,
    OcptBudgetResourceGroupKind.cash => tr.budgetResourceDialogStatusHelperCash,
    OcptBudgetResourceGroupKind.inKind => tr.budgetResourceDialogStatusHelperInKind,
  };
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

/// The resource dialog's own `Status` picker: `OcptBudgetResourceStatus`'s own three steps as a
/// wrapped row of small, clickable chips, painted in [ocptBudgetResourceStatusAccentColor] — the
/// same colour and word the financing view's own status pill reads them in, mirroring
/// `OcptBudgetCommitmentDialog`'s own `_OcptCommitmentStatusPicker`.
///
/// **[groupKind] words the chips**, and re-words them the moment the picker above changes it: see
/// [OcptBudgetResourceDialog]'s own class doc comment.
class _OcptResourceStatusPicker extends StatelessWidget {
  /// The group the resource being edited sits in — what each of the three steps is called depends
  /// on it.
  final OcptBudgetResourceGroupKind groupKind;

  /// The picker's current value.
  final OcptBudgetResourceStatus value;

  /// Called with the value just picked.
  final ValueChanged<OcptBudgetResourceStatus> onChanged;

  /// Class constructor
  const _OcptResourceStatusPicker({
    required this.groupKind,
    required this.value,
    required this.onChanged,
  });

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
          ocptBudgetResourceStatusLabel(tr, groupKind, status),
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? accent : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
