// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// The dialog that both **creates and edits** a commitment — one shape for both, mirroring
/// `OcptBudgetEntryDialog`'s own structure exactly, [show] and all: a [Form], an `AlertDialog` with
/// `Cancel`/`Save` actions, dismissed through `OcptRouterManager.pop`, never `Navigator`.
///
/// **Two fields gate `Save`, not one.** `Label` is the entry dialog's own only required field, but a
/// commitment always prices a poste (`OcptBudgetCommitment.posteId`'s own doc comment), so `Poste`
/// is required here too — the button is **withheld** (a null `onPressed`, this dialog's own
/// discipline for a control that cannot yet be honoured) rather than merely shown disabled with no
/// explanation, and a muted line under the actions names whichever of the two is still missing.
///
/// **`Poste` is only pickable while creating.** `OcptBudgetJournalService.updateCommitment` carries
/// no `posteId` parameter at all (`OcptBudgetCommitmentFormFields.posteId`'s own doc comment): once
/// a commitment exists, its own poste is fixed, exactly as a quote line's is. Editing an existing
/// commitment therefore shows its poste as a plain, muted label rather than a picker.
///
/// **The `VAT` field's empty reading agrees with `OcptBudgetEntryDialog`'s own, for the very same
/// reason**: this dialog submits a whole record at once, through one explicit `Save` action, so an
/// empty or unparseable field reads as "inherit the project's rate", never as "clear the override
/// typed on purpose" — the stray-keystroke risk a keystroke-by-keystroke autosave would carry does
/// not exist here.
class OcptBudgetCommitmentDialog extends StatefulWidget {
  /// The commitment being edited, or null while creating a new one.
  final OcptBudgetCommitment? existing;

  /// Every live poste of the project, offered by the `Poste` picker while creating.
  final List<OcptBudgetPoste> postes;

  /// The project's currency, an ISO 4217 code, shown beside the `Amount` field.
  final String currencyCode;

  /// The project's default VAT rate, in basis points, or null — what the `VAT` field's own hint
  /// reads while it is left empty.
  final int? defaultVatRateBasisPoints;

  /// Whether the mode's header currently reads simplified — switches a poste's own displayed name
  /// exactly as every other view of this mode does.
  final bool isSimplified;

  /// Class constructor
  const OcptBudgetCommitmentDialog({
    super.key,
    required this.existing,
    required this.postes,
    required this.currencyCode,
    required this.defaultVatRateBasisPoints,
    required this.isSimplified,
  });

  /// Shows the dialog and returns the fields the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetCommitmentFormFields?> show(
    BuildContext context, {
    required OcptBudgetCommitment? existing,
    required List<OcptBudgetPoste> postes,
    required String currencyCode,
    required int? defaultVatRateBasisPoints,
    required bool isSimplified,
  }) => showDialog<OcptBudgetCommitmentFormFields>(
    context: context,
    builder: (context) => OcptBudgetCommitmentDialog(
      existing: existing,
      postes: postes,
      currencyCode: currencyCode,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      isSimplified: isSimplified,
    ),
  );

  @override
  State<OcptBudgetCommitmentDialog> createState() => _OcptBudgetCommitmentDialogState();
}

/// The state of [OcptBudgetCommitmentDialog].
class _OcptBudgetCommitmentDialogState extends State<OcptBudgetCommitmentDialog> {
  /// The form used to validate the entered amount.
  final _formKey = GlobalKey<FormState>();

  /// The controller of the label field.
  late final TextEditingController _labelController;

  /// The controller of the amount field.
  late final TextEditingController _amountController;

  /// The controller of the VAT rate override field.
  late final TextEditingController _vatRateController;

  /// The due date currently picked, or null.
  DateTime? _dueDate;

  /// The poste currently picked, or null while nobody has picked one yet — see the class doc
  /// comment for why this stays pickable only while creating.
  String? _posteId;

  /// Whether the amount currently picked includes tax.
  late bool _isTaxInclusive;

  /// The status currently picked.
  late OcptBudgetCommitmentStatus _status;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _dueDate = existing?.dueDate;
    _posteId = existing?.posteId;
    _isTaxInclusive = existing?.amount.isTaxInclusive ?? true;
    _status = existing?.status ?? OcptBudgetCommitmentStatus.quoteAccepted;

    _labelController = TextEditingController(text: existing?.label ?? "")..addListener(_onFieldsChanged);
    _amountController = TextEditingController(text: ocptCostTextOf(existing?.amount.amountCents));
    _vatRateController = TextEditingController(
      text: ocptVatRatePercentTextOf(existing?.amount.vatRateBasisPoints),
    );
  }

  @override
  void dispose() {
    _labelController.removeListener(_onFieldsChanged);
    _labelController.dispose();
    _amountController.dispose();
    _vatRateController.dispose();
    super.dispose();
  }

  /// Rebuilds so the `Save` action and its own missing-fields hint react to every keystroke of the
  /// label, exactly as [_posteId] already does through `setState` on every pick.
  void _onFieldsChanged() => setState(() {});

  /// Whether both of the dialog's own required fields are filled — see the class doc comment.
  bool get _canSubmit => _labelController.text.trim().isNotEmpty && _posteId != null;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final currencySymbol = NumberFormat.simpleCurrency(name: widget.currencyCode).currencySymbol;
    final vatRateHint = _effectiveDefaultVatRateHint(tr);
    final missingFieldsHint = _missingFieldsHintOf(tr);

    return AlertDialog(
      title: Text(isEditing ? tr.budgetCommitmentDialogEditTitle : tr.budgetCommitmentDialogCreateTitle),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OcptPersonSheetDateField(
                label: tr.budgetCommitmentDialogDueDateFieldLabel,
                value: _dueDate,
                onChanged: (value) => setState(() => _dueDate = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelController,
                autofocus: true,
                decoration: InputDecoration(labelText: tr.budgetEntryDialogLabelFieldLabel),
              ),
              const SizedBox(height: 12),
              _buildPosteField(tr),
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
              OcptBudgetBinaryChoice(
                value: _isTaxInclusive,
                trueLabel: tr.budgetLineTaxInclusiveOption,
                falseLabel: tr.budgetLineTaxExclusiveOption,
                onChanged: (value) => setState(() => _isTaxInclusive = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vatRateController,
                decoration: InputDecoration(
                  labelText: tr.budgetLineVatRateFieldLabel,
                  hintText: vatRateHint,
                  suffixText: tr.budgetLineVatRateSuffix,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr.budgetCommitmentDialogStatusFieldLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              _OcptCommitmentStatusPicker(
                value: _status,
                onChanged: (value) => setState(() => _status = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (missingFieldsHint != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              missingFieldsHint,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.budgetEntryDialogCancelAction),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(tr.budgetEntryDialogConfirmAction),
        ),
      ],
    );
  }

  /// The `Poste` field: a picker, whether the dialog is creating a commitment or editing one.
  ///
  /// **Editable in both, unlike a quote line's own poste** — see
  /// `OcptBudgetJournalService.updateCommitment`'s own doc comment: a commitment's poste is an
  /// attribution typed once against a ten-poste nomenclature, exactly the field somebody gets
  /// wrong, and this table's flat `sortKey` makes changing it an ordinary field write rather than
  /// the regrouping a line's own would be.
  Widget _buildPosteField(Tr tr) => DropdownButtonFormField<String>(
    initialValue: _posteId,
    decoration: InputDecoration(labelText: tr.budgetEntryDialogPosteFieldLabel),
    items: [
      for (final poste in widget.postes)
        DropdownMenuItem(
          value: poste.id,
          child: Text(ocptBudgetPosteDisplayLabel(poste, isSimplified: widget.isSimplified)),
        ),
    ],
    onChanged: (value) => setState(() => _posteId = value),
  );

  /// The `VAT` field's own hint while it is left empty — mirrors `OcptBudgetEntryDialog`'s own
  /// reading exactly.
  String? _effectiveDefaultVatRateHint(Tr tr) {
    final defaultVatRateBasisPoints = widget.defaultVatRateBasisPoints;
    if (defaultVatRateBasisPoints == null) {
      return null;
    }

    return tr.budgetLineVatRateInheritedHint(ocptVatRatePercentTextOf(defaultVatRateBasisPoints));
  }

  /// Which of the two required fields (or both) is still missing, worded for the muted hint next to
  /// `Save` — null once both are filled, at which point [_canSubmit] is true and there is nothing
  /// left to explain.
  String? _missingFieldsHintOf(Tr tr) {
    final missingLabel = _labelController.text.trim().isEmpty;
    final missingPoste = _posteId == null;

    if (missingLabel && missingPoste) {
      return tr.budgetCommitmentDialogMissingLabelAndPosteHint;
    }
    if (missingLabel) {
      return tr.budgetCommitmentDialogMissingLabelHint;
    }
    if (missingPoste) {
      return tr.budgetCommitmentDialogMissingPosteHint;
    }

    return null;
  }

  /// Validates the form and, if it passes, pops the dialog returning every field collected.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amountCents = ocptCostCentsOf(_amountController.text);
    final posteId = _posteId;
    if (amountCents == null || posteId == null) {
      return;
    }

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetCommitmentFormFields>(
      OcptBudgetCommitmentFormFields(
        dueDate: _dueDate,
        label: _labelController.text.trim(),
        posteId: posteId,
        amountCents: amountCents,
        isTaxInclusive: _isTaxInclusive,
        vatRateBasisPoints: ocptVatRateBasisPointsOf(_vatRateController.text),
        status: _status,
      ),
    );
  }
}

/// The commitment dialog's own `Status` picker: `OcptBudgetCommitmentStatus`'s own four values as a
/// wrapped row of small, clickable chips — the same colour and word every badge of the
/// committed-spending view itself paints them in (`ocptBudgetCommitmentStatusLabel`/
/// `ocptBudgetCommitmentStatusAccentColor`), so picking one here and reading it back there never
/// disagree. A [Wrap] rather than [OcptBudgetBinaryChoice]'s own plain [Row]: four segments, unlike
/// two, may not fit one line at a narrow dialog width.
class _OcptCommitmentStatusPicker extends StatelessWidget {
  /// The picker's current value.
  final OcptBudgetCommitmentStatus value;

  /// Called with the value just picked.
  final ValueChanged<OcptBudgetCommitmentStatus> onChanged;

  /// Class constructor
  const _OcptCommitmentStatusPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final status in OcptBudgetCommitmentStatus.values) _segment(context, status)],
  );

  /// One of the picker's own segments, filled in its own accent colour while active.
  Widget _segment(BuildContext context, OcptBudgetCommitmentStatus status) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isActive = status == value;
    final accent = ocptBudgetCommitmentStatusAccentColor(theme.colorScheme, status);

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
          ocptBudgetCommitmentStatusLabel(tr, status),
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? accent : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
