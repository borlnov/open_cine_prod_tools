// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_mileage_rate_amount.dart';

/// The dialog that both **creates and edits** a defrayal — one shape for both, mirroring
/// `OcptBudgetResourceDialog`'s own structure exactly, [show] and all: a [Form], an `AlertDialog`
/// with `Cancel`/`Save` actions, dismissed through `OcptRouterManager.pop`, never `Navigator`.
///
/// **`Quantity` and `Unit price` are the only required fields**, and neither has a sensible default
/// to fall back on: a defrayal of nothing at nothing is a row nobody meant to write. The wording,
/// the person and the dates are all legitimately empty — a defrayal naming nobody is a real line of
/// a régie budget, and one carrying no date is a real, ordinary state.
///
/// **The `Nature` picker re-words the `Quantity` helper**, since the unit changes with it:
/// kilometres for a journey, nights for a stay, meals for a meal. Nothing is hidden or disabled by
/// nature — the mode's standing rule that the UI carries no conditional branch on the state of the
/// data — only the wording moves, exactly as `OcptBudgetResourceDialog`'s own status picker does.
///
/// **`Use this person's own rate` pre-fills, it never decides.** Picking somebody whose own
/// `commuteKmMilli` and `mileageRateId` are recorded offers one click that writes that distance and
/// that rate into the two fields; both stay ordinary editable fields afterwards, and neither is
/// read again. This is the whole of what a person's stored commute is for now — see
/// `OcptBudgetAllowancesTable`'s own doc comment for the shoot that made deducing it wrong.
///
/// **`End date` is offered whatever the nature**, and its helper says what it is for rather than
/// the picker refusing it: only a stay normally spans two dates, but a production knows its own
/// business better than this dialog does.
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

  /// Shows the dialog and returns the fields the user confirmed, or null if they cancelled it.
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

  @override
  State<OcptBudgetAllowanceDialog> createState() => _OcptBudgetAllowanceDialogState();
}

/// The state of [OcptBudgetAllowanceDialog].
class _OcptBudgetAllowanceDialogState extends State<OcptBudgetAllowanceDialog> {
  /// The form used to validate the entered quantity and unit price.
  final _formKey = GlobalKey<FormState>();

  /// The controller of the wording field.
  late final TextEditingController _labelController;

  /// The controller of the quantity field.
  late final TextEditingController _quantityController;

  /// The controller of the unit price field.
  late final TextEditingController _unitPriceController;

  /// The controller of the notes field.
  late final TextEditingController _notesController;

  /// The nature currently picked.
  late OcptBudgetAllowanceKind _kind;

  /// The person currently picked, or null for "no person".
  String? _personId;

  /// The date currently picked, or null.
  DateTime? _date;

  /// The end date currently picked, or null.
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _kind = existing?.kind ?? OcptBudgetAllowanceKind.travel;
    _personId = existing?.personId;
    _date = existing?.date;
    _endDate = existing?.endDate;
    _labelController = TextEditingController(text: existing?.label ?? "");
    _quantityController = TextEditingController(
      text: existing == null ? "" : ocptBudgetQuantityLabel(existing.quantityMilli),
    );
    _unitPriceController = TextEditingController(
      text: existing == null ? "" : ocptMileageRateTextOf(existing.unitAmountMilliCents),
    );
    _notesController = TextEditingController(text: existing?.notes ?? "");
  }

  @override
  void dispose() {
    _labelController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final prefill = _prefillOf();

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? tr.budgetAllowanceDialogCreateTitle
            : tr.budgetAllowanceDialogEditTitle,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _personId,
                  decoration: InputDecoration(labelText: tr.budgetShareDialogPersonFieldLabel),
                  items: [
                    // The explicit "no person" choice: a defrayal belonging to the production
                    // rather than to one person is a real line of a régie budget.
                    DropdownMenuItem<String?>(child: Text(tr.budgetRegieAllowanceNoPerson)),
                    for (final person in widget.people)
                      DropdownMenuItem(value: person.id, child: Text(person.displayName)),
                  ],
                  onChanged: (value) => setState(() => _personId = value),
                ),
                if (prefill != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _applyPrefill(prefill),
                      child: Text(tr.budgetAllowanceDialogRatePrefillAction),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  tr.budgetAllowanceDialogKindFieldLabel.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                _OcptAllowanceKindPicker(
                  value: _kind,
                  onChanged: (value) => setState(() => _kind = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _labelController,
                  decoration: InputDecoration(labelText: tr.budgetEntryDialogLabelFieldLabel),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: tr.budgetAllowanceDialogQuantityFieldLabel,
                    helperText: _quantityHelper(tr),
                    helperMaxLines: 2,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => ocptBudgetQuantityMilliOf(value ?? "") == null
                      ? tr.budgetEntryDialogAmountInvalidError
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitPriceController,
                  decoration: InputDecoration(
                    labelText: tr.budgetAllowanceDialogUnitPriceFieldLabel,
                    suffixText: widget.currencyCode,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => ocptMileageRateMilliCentsOf(value ?? "") == null
                      ? tr.budgetEntryDialogAmountInvalidError
                      : null,
                ),
                const SizedBox(height: 12),
                OcptPersonSheetDateField(
                  label: tr.budgetAllowanceDialogDateFieldLabel,
                  value: _date,
                  onChanged: (value) => setState(() => _date = value),
                ),
                const SizedBox(height: 12),
                OcptPersonSheetDateField(
                  label: tr.budgetAllowanceDialogEndDateFieldLabel,
                  value: _endDate,
                  onChanged: (value) => setState(() => _endDate = value),
                ),
                const SizedBox(height: 4),
                Text(
                  tr.budgetAllowanceDialogEndDateHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(labelText: tr.budgetLineNotesFieldLabel),
                  maxLines: 2,
                ),
              ],
            ),
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

  /// The distance and rate the person currently picked would pre-fill, or null while they have
  /// neither — or while nobody is picked at all.
  ///
  /// **Both halves have to be there for the offer to make sense**: a commute with no rate cannot
  /// price itself, and a rate with no commute has no distance to apply to.
  (int, int)? _prefillOf() {
    final personId = _personId;
    if (personId == null) {
      return null;
    }

    final person = widget.people.where((candidate) => candidate.id == personId).firstOrNull;
    final commuteKmMilli = person?.commuteKmMilli;
    final rateId = person?.mileageRateId;
    if (commuteKmMilli == null || rateId == null) {
      return null;
    }

    final rate = widget.mileageRates.where((candidate) => candidate.id == rateId).firstOrNull;

    return rate == null ? null : (commuteKmMilli, rate.ratePerKmMilliCents);
  }

  /// Writes [prefill]'s own distance and rate into the two fields, and moves the nature to
  /// [OcptBudgetAllowanceKind.travel] — which is the only thing a mileage scale can price.
  void _applyPrefill((int, int) prefill) {
    setState(() {
      _kind = OcptBudgetAllowanceKind.travel;
      _quantityController.text = ocptBudgetQuantityLabel(prefill.$1);
      _unitPriceController.text = ocptMileageRateTextOf(prefill.$2);
    });
  }

  /// The `Quantity` field's own helper, worded for [_kind] — the unit changes with the nature.
  String _quantityHelper(Tr tr) => switch (_kind) {
    OcptBudgetAllowanceKind.travel => tr.budgetAllowanceDialogQuantityHelperTravel,
    OcptBudgetAllowanceKind.accommodation => tr.budgetAllowanceDialogQuantityHelperAccommodation,
    OcptBudgetAllowanceKind.meal => tr.budgetAllowanceDialogQuantityHelperMeal,
    OcptBudgetAllowanceKind.other => tr.budgetAllowanceDialogQuantityHelperOther,
  };

  /// Validates the form and, if it passes, pops the dialog returning every field collected.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final quantityMilli = ocptBudgetQuantityMilliOf(_quantityController.text);
    final unitAmountMilliCents = ocptMileageRateMilliCentsOf(_unitPriceController.text);
    if (quantityMilli == null || unitAmountMilliCents == null) {
      return;
    }

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetAllowanceFormFields>(
      OcptBudgetAllowanceFormFields(
        personId: _personId,
        kind: _kind,
        label: _labelController.text.trim(),
        date: _date,
        endDate: _endDate,
        quantityMilli: quantityMilli,
        unitAmountMilliCents: unitAmountMilliCents,
        notes: _notesController.text.trim(),
      ),
    );
  }
}

/// The defrayal dialog's own `Nature` picker: `OcptBudgetAllowanceKind`'s own four values as a
/// wrapped row of small, clickable chips — mirrors `OcptBudgetResourceDialog`'s own group picker,
/// generic over a different enum.
class _OcptAllowanceKindPicker extends StatelessWidget {
  /// The picker's current value.
  final OcptBudgetAllowanceKind value;

  /// Called with the value just picked.
  final ValueChanged<OcptBudgetAllowanceKind> onChanged;

  /// Class constructor
  const _OcptAllowanceKindPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final kind in OcptBudgetAllowanceKind.values) _segment(context, kind)],
  );

  /// One of the picker's own segments.
  Widget _segment(BuildContext context, OcptBudgetAllowanceKind kind) {
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
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Text(
          ocptBudgetAllowanceKindLabel(tr, kind),
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
