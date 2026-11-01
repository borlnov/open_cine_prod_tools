// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_revenue_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The whole of [OcptBudgetRevenueDialog]'s own form, embeddable outside a dialog — the capture
/// wizard draws this same body under its own step counter, rather than an `AlertDialog`'s
/// `content`.
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

  /// Create the [_OcptBudgetRevenueFormBodyState] holding the state of the budget revenue form
  /// body.
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

  /// Fill the fields from the existing revenue, and send the first draft after the first frame.
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

  /// Build the budget revenue form body as a [Form].
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
              validator: (value) => ocptCostCentsOf(value ?? "") == null
                  ? tr.budgetEntryDialogAmountInvalidError
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              tr.budgetCommitmentDialogStatusFieldLabel.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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

  /// Reports [_currentDraft] to the host — every controller listener and every picker's own
  /// `onChanged` call this after applying its own change.
  void _report() => widget.onDraftChanged(_currentDraft);

  /// Dispose [_labelController], [_amountController] and [_notesController].
  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
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

  /// Build the revenue status picker as a [Wrap].
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
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? accent.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
              : Colors.transparent,
          border: Border.all(color: isActive ? accent : theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
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
