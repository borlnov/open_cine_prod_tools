// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line_form_fields.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// The small form the entry wizard's own `addQuoteLine` gesture ends on — an intitulé, a quantité
/// and a prix unitaire, priced against whichever poste step 2 already named — so a quote line can
/// be **born filled** rather than created blank and edited inline in the tree, the shape
/// `OcptBudgetLineCreatedEvent.fields` non-null now writes in one call.
///
/// **Reads no `posteId` at all.** Which poste this line prices is the wizard's own step 2 answer
/// (`OcptBudgetGestureAttachment.poste`), not a fact this body asks about a second time — the host
/// hands the line's own poste to `OcptBudgetLineCreatedEvent` directly, exactly as it already hands
/// it a bare `posteId` today.
///
/// **No dialog of its own, and nothing opens it yet.** This groundwork only builds the form the
/// wizard's own step 3 will embed; the wizard itself is a later task. `Label`, `Quantity`, `Unit`
/// and `Unit price` reuse the very same field labels the poste inspector's own inline editor
/// already shows for a quote line (`tr.budgetLineLabelFieldLabel` and its three siblings), so a
/// line typed here reads no differently from one typed inline.
///
/// **The host owns the submit gesture**, the same contract every one of the five dialog bodies
/// split for this milestone carries: [formKey] is put on this body's own [Form], and
/// [onDraftChanged] fires with the fields this body would submit right now — or null while
/// `Quantity` or `Unit price` does not parse, the one way this body can be unreadable — every time
/// a field changes, `initState` included so a host that opens this body pre-scrolled to a default
/// still has a draft to submit. The host validates [formKey] and uses the last reported draft on
/// its own `Save`; this body never pops or dispatches anything itself.
class OcptBudgetLineFormBody extends StatefulWidget {
  /// The project's currency, an ISO 4217 code, shown beside the `Unit price` field.
  final String currencyCode;

  /// The form this body's own [Form] validates against — the host's to create and to validate.
  final GlobalKey<FormState> formKey;

  /// Called with the fields this body would submit right now, or null while it cannot be read at
  /// all — see the class doc comment.
  final ValueChanged<OcptBudgetLineFormFields?> onDraftChanged;

  /// Class constructor
  const OcptBudgetLineFormBody({
    super.key,
    required this.currencyCode,
    required this.formKey,
    required this.onDraftChanged,
  });

  @override
  State<OcptBudgetLineFormBody> createState() => _OcptBudgetLineFormBodyState();
}

/// The state of [OcptBudgetLineFormBody].
class _OcptBudgetLineFormBodyState extends State<OcptBudgetLineFormBody> {
  /// The controller of the label field.
  late final TextEditingController _labelController;

  /// The controller of the quantity field.
  late final TextEditingController _quantityController;

  /// The controller of the unit field.
  late final TextEditingController _unitController;

  /// The controller of the unit price field.
  late final TextEditingController _unitPriceController;

  @override
  void initState() {
    super.initState();

    _labelController = TextEditingController()..addListener(_report);
    _quantityController = TextEditingController()..addListener(_report);
    _unitController = TextEditingController()..addListener(_report);
    _unitPriceController = TextEditingController()..addListener(_report);

    // The host's own `Save` may be reached before any field is touched, exactly as the other four
    // form bodies this milestone split — so the very first draft has to travel without waiting on
    // a keystroke, even though this one starts with nothing worth submitting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _report();
      }
    });
  }

  @override
  void dispose() {
    _labelController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  /// Reports [_currentDraft] to the host — every controller listener calls this after applying its
  /// own change.
  void _report() => widget.onDraftChanged(_currentDraft);

  /// The fields this body would submit right now, or null while `Quantity` or `Unit price` does
  /// not parse.
  OcptBudgetLineFormFields? get _currentDraft {
    final quantityMilli = ocptBudgetQuantityMilliOf(_quantityController.text);
    final unitAmountCents = ocptCostCentsOf(_unitPriceController.text);
    if (quantityMilli == null || unitAmountCents == null) {
      return null;
    }

    return OcptBudgetLineFormFields(
      label: _labelController.text.trim(),
      quantityMilli: quantityMilli,
      unit: _unitController.text.trim(),
      unitAmountCents: unitAmountCents,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final currencySymbol = NumberFormat.simpleCurrency(name: widget.currencyCode).currencySymbol;

    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _labelController,
              autofocus: true,
              decoration: InputDecoration(labelText: tr.budgetLineLabelFieldLabel),
              validator: (value) =>
                  (value ?? "").trim().isEmpty ? tr.budgetEntryDialogLabelRequiredError : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(labelText: tr.budgetLineQuantityFieldLabel),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => ocptBudgetQuantityMilliOf(value ?? "") == null
                        ? tr.budgetEntryDialogAmountInvalidError
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitController,
                    decoration: InputDecoration(
                      labelText: tr.budgetLineUnitFieldLabel,
                      hintText: tr.budgetLineUnitFieldHint,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitPriceController,
              decoration: InputDecoration(
                labelText: tr.budgetLineUnitPriceFieldLabel,
                suffixText: currencySymbol,
              ),
              validator: (value) =>
                  ocptCostCentsOf(value ?? "") == null ? tr.budgetEntryDialogAmountInvalidError : null,
            ),
          ],
        ),
      ),
    );
  }
}
