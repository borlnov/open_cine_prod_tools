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

/// The state of [OcptBudgetRevenueDialog]: the form key it hands to [OcptBudgetRevenueFormBody] and
/// the last draft that body reported.
class _OcptBudgetRevenueDialogState extends State<OcptBudgetRevenueDialog> {
  /// The form [OcptBudgetRevenueFormBody] validates against, owned here since this shell is the
  /// one that decides when to validate it.
  final _formKey = GlobalKey<FormState>();

  /// The fields [OcptBudgetRevenueFormBody] would submit right now, or null while it cannot be read
  /// at all — see [OcptBudgetRevenueFormBody.onDraftChanged]'s own doc comment.
  OcptBudgetRevenueFormFields? _draft;

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

  /// Validates the form and, if it passes, pops the dialog returning the last draft
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

/// The whole of [OcptBudgetRevenueDialog]'s own form, embeddable outside a dialog — the capture
/// wizard draws this same body under its own step counter, rather than an `AlertDialog`'s `content`.
///
/// **`Label` is the dialog's own only required field, alongside `Date`**, mirroring the financing
/// resource form: `Status` already carries a sensible default the moment the dialog opens
/// ([OcptBudgetRevenueStatus.expected]), so there is no second field a fresh taking could be
/// missing.
///
/// **Carries no `amountCents` figure the sharing view treats as anything but what was announced.**
/// `OcptBudgetRevenue.amountCents` is what the taking is *expected* to bring in — what it actually
/// brought in is read off the journal (`OcptBudgetSnapshot.receivedByRevenueId`), exactly as
/// `OcptBudgetResourceFormBody`'s own doc comment already argues for a financing resource.
///
/// **The host owns the submit gesture.** [formKey] is put on this body's own [Form], and
/// [onDraftChanged] fires with the fields this body would submit right now — or null while the
/// `Amount` field's own figure does not parse, the one way this body can be unreadable — every time
/// a field changes, `initState` included so a host that never touches a pre-filled edit still has a
/// draft to submit. The host validates [formKey] and uses the last reported draft on its own
/// `Save`; this body never pops anything itself.
class OcptBudgetRevenueFormBody extends StatefulWidget {
  /// The revenue being edited, or null while creating a new one.
  final OcptBudgetRevenue? existing;

  /// The project's currency, an ISO 4217 code, shown beside the `Amount` field.
  final String currencyCode;

  /// The form this body's own [Form] validates against — the host's to create and to validate.
  final GlobalKey<FormState> formKey;

  /// Called with the fields this body would submit right now, or null while it cannot be read at
  /// all — see the class doc comment.
  final ValueChanged<OcptBudgetRevenueFormFields?> onDraftChanged;

  /// Class constructor
  const OcptBudgetRevenueFormBody({
    super.key,
    required this.existing,
    required this.currencyCode,
    required this.formKey,
    required this.onDraftChanged,
  });

  @override
  State<OcptBudgetRevenueFormBody> createState() => _OcptBudgetRevenueFormBodyState();
}

/// The state of [OcptBudgetRevenueFormBody].
class _OcptBudgetRevenueFormBodyState extends State<OcptBudgetRevenueFormBody> {
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

    _labelController = TextEditingController(text: existing?.label ?? "")..addListener(_report);
    _amountController = TextEditingController(text: ocptCostTextOf(existing?.amountCents))
      ..addListener(_report);
    _notesController = TextEditingController(text: existing?.notes ?? "")..addListener(_report);

    // The host's own `Save` may be reached before any field is touched — an edit left exactly as
    // it opened — so the very first draft has to travel without waiting on a keystroke.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _report();
      }
    });
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Reports [_currentDraft] to the host — every controller listener and every picker's own
  /// `onChanged` call this after applying its own change.
  void _report() => widget.onDraftChanged(_currentDraft);

  /// The fields this body would submit right now, or null while the `Amount` field's own figure
  /// does not parse.
  OcptBudgetRevenueFormFields? get _currentDraft {
    final amountCents = ocptCostCentsOf(_amountController.text);
    if (amountCents == null) {
      return null;
    }

    return OcptBudgetRevenueFormFields(
      date: _date,
      label: _labelController.text.trim(),
      amountCents: amountCents,
      status: _status,
      notes: _notesController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final currencySymbol = NumberFormat.simpleCurrency(name: widget.currencyCode).currencySymbol;

    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OcptPersonSheetDateField(
              label: tr.budgetEntryDialogDateFieldLabel,
              value: _date,
              onChanged: (value) {
                setState(() => _date = value ?? _date);
                _report();
              },
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
              onChanged: (value) {
                setState(() => _status = value);
                _report();
              },
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
    );
  }
}

/// The revenue form's own `Status` picker: `OcptBudgetRevenueStatus`'s own three values as a
/// wrapped row of small, clickable chips, painted in [ocptBudgetRevenueStatusAccentColor] —
/// mirrors `OcptBudgetResourceFormBody`'s own `_OcptResourceStatusPicker`.
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
