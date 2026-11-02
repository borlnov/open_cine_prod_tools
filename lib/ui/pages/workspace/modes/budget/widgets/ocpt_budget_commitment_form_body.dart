// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_commitment_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The whole of [OcptBudgetCommitmentDialog]'s own form, embeddable outside a dialog — the capture
/// wizard draws this same body under its own step counter, rather than an `AlertDialog`'s
/// `content`.
///
/// **Two fields gate `Save`, not one.** `Label` is the entry dialog's own only required field, but
/// a commitment always prices an account (`OcptBudgetCommitment.accountId`'s own doc comment), so
/// `Poste` is required here too — [onMissingFieldsHintChanged] is how this body tells its host,
/// since the host owns `Save` (see [OcptBudgetCommitmentDialog]'s own class doc comment for why
/// that could not simply be read off [onDraftChanged] instead).
///
/// **`Poste` is a picker whether creating or editing** — a production is free to reclassify a
/// commitment against a different account at any time
/// (`OcptBudgetJournalService.updateCommitment`'s own doc comment). The one host that already
/// knows the answer before this body even opens is the capture wizard's own step 3:
/// [accountAlreadyAnswered] lets it withhold the field outright rather than ask the very question
/// its own step 2 just answered one screen above — the account still seeds from [prefill] either
/// way, so the value already collected travels through untouched.
///
/// **The `VAT` field's empty reading agrees with `OcptBudgetEntryDialog`'s own, for the very same
/// reason**: this body submits a whole record at once, through one explicit `Save` action, so an
/// empty or unparseable field reads as "inherit the project's rate", never as "clear the override
/// typed on purpose" — the stray-keystroke risk a keystroke-by-keystroke autosave would carry does
/// not exist here.
///
/// **The host owns the submit gesture.** [formKey] is put on this body's own [Form].
/// [onDraftChanged] fires with the fields this body would submit right now — or null while `Amount`
/// does not parse *or* `Label`/`Poste` is still missing — every time a field changes, `initState`
/// included so a host that never touches a pre-filled edit still has a draft to submit. The host
/// validates [formKey] and uses the last reported draft on its own `Save`; this body never pops
/// anything itself.
class OcptBudgetCommitmentFormBody extends StatefulWidget {
  /// The commitment being edited, or null while creating a new one.
  final OcptBudgetCommitment? existing;

  /// Seeds a fresh commitment's own fields while [existing] is null, or null to start from this
  /// body's own defaults.
  final OcptBudgetCommitmentFormFields? prefill;

  /// Every live account of the project, offered by the `Poste` picker while creating.
  final List<OcptBudgetAccount> accounts;

  /// The project's currency, an ISO 4217 code, shown beside the `Amount` field.
  final String currencyCode;

  /// The project's default VAT rate, in basis points, or null — what the `VAT` field's own hint
  /// reads while it is left empty.
  final int? defaultVatRateBasisPoints;

  /// Whether the mode's header currently reads simplified — switches an account's own displayed
  /// name exactly as every other view of this mode does.
  final bool isSimplified;

  /// The form this body's own [Form] validates against — the host's to create and to validate.
  final GlobalKey<FormState> formKey;

  /// Called with the fields this body would submit right now, or null while it cannot be read at
  /// all — see the class doc comment.
  final ValueChanged<OcptBudgetCommitmentFormFields?> onDraftChanged;

  /// Called with which of `Label`/`Poste` is still missing, worded for a muted hint next to `Save`
  /// — null once both are filled. See [OcptBudgetCommitmentDialog]'s own class doc comment for why
  /// this travels apart from [onDraftChanged].
  final ValueChanged<String?> onMissingFieldsHintChanged;

  /// Withholds the `Poste` picker outright when true — see the class doc comment. Defaults to
  /// false, [OcptBudgetCommitmentDialog]'s own reading, which always draws the picker.
  final bool accountAlreadyAnswered;

  /// Class constructor
  const OcptBudgetCommitmentFormBody({
    super.key,
    required this.existing,
    this.prefill,
    required this.accounts,
    required this.currencyCode,
    required this.defaultVatRateBasisPoints,
    required this.isSimplified,
    required this.formKey,
    required this.onDraftChanged,
    required this.onMissingFieldsHintChanged,
    this.accountAlreadyAnswered = false,
  });

  /// Create the [_OcptBudgetCommitmentFormBodyState] holding the state of the budget commitment
  /// form body.
  @override
  State<OcptBudgetCommitmentFormBody> createState() => _OcptBudgetCommitmentFormBodyState();
}

/// The state of [OcptBudgetCommitmentFormBody].
class _OcptBudgetCommitmentFormBodyState extends State<OcptBudgetCommitmentFormBody> {
  /// The controller of the label field.
  late final TextEditingController _labelController;

  /// The controller of the amount field.
  late final TextEditingController _amountController;

  /// The controller of the VAT rate override field.
  late final TextEditingController _vatRateController;

  /// The due date currently picked, or null.
  DateTime? _dueDate;

  /// The account currently picked, or null while nobody has picked one yet — see the class doc
  /// comment for why this stays pickable only while creating.
  String? _accountId;

  /// Whether the amount currently picked includes tax.
  late bool _isTaxInclusive;

  /// The status currently picked.
  late OcptBudgetCommitmentStatus _status;

  /// Get the fields this body would submit right now, or null while `Amount` does not parse or
  /// `Label`/`Poste` is still missing.
  OcptBudgetCommitmentFormFields? get _currentDraft {
    final amountCents = ocptCostCentsOf(_amountController.text);
    final accountId = _accountId;
    final label = _labelController.text.trim();
    if (amountCents == null || accountId == null || label.isEmpty) {
      return null;
    }

    return OcptBudgetCommitmentFormFields(
      dueDate: _dueDate,
      label: label,
      accountId: accountId,
      amountCents: amountCents,
      isTaxInclusive: _isTaxInclusive,
      vatRateBasisPoints: ocptVatRateBasisPointsOf(_vatRateController.text),
      status: _status,
    );
  }

  /// Fill the fields from the existing commitment or the prefill, and send the first draft after
  /// the first frame.
  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    final prefill = widget.prefill;

    _dueDate = existing?.dueDate ?? prefill?.dueDate;
    _accountId = existing?.accountId ?? prefill?.accountId;
    _isTaxInclusive = existing?.amount.isTaxInclusive ?? prefill?.isTaxInclusive ?? true;
    _status = existing?.status ?? prefill?.status ?? OcptBudgetCommitmentStatus.quoteAccepted;

    _labelController = TextEditingController(text: existing?.label ?? prefill?.label ?? "")
      ..addListener(_report);
    _amountController = TextEditingController(
      text: ocptCostTextOf(existing?.amount.amountCents ?? prefill?.amountCents),
    )..addListener(_report);
    _vatRateController = TextEditingController(
      text: ocptVatRatePercentTextOf(
        existing?.amount.vatRateBasisPoints ?? prefill?.vatRateBasisPoints,
      ),
    )..addListener(_report);

    // The host's own `Save` may be reached before any field is touched — an edit left exactly as
    // it opened — so the very first draft and hint have to travel without waiting on a keystroke.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _report();
      }
    });
  }

  /// Build the budget commitment form body as a [Form].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final currencySymbol = NumberFormat.simpleCurrency(name: widget.currencyCode).currencySymbol;
    final vatRateHint = _effectiveDefaultVatRateHint(tr);

    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OcptPersonSheetDateField(
              label: tr.budgetCommitmentDialogDueDateFieldLabel,
              value: _dueDate,
              onChanged: (value) {
                setState(() => _dueDate = value);
                _report();
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _labelController,
              autofocus: true,
              decoration: InputDecoration(labelText: tr.budgetEntryDialogLabelFieldLabel),
            ),
            const SizedBox(height: 12),
            if (!widget.accountAlreadyAnswered) ...[
              _OcptCommitmentAccountField(
                accounts: widget.accounts,
                isSimplified: widget.isSimplified,
                value: _accountId,
                onChanged: (value) {
                  setState(() => _accountId = value);
                  _report();
                },
              ),
              const SizedBox(height: 12),
            ],
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
            OcptBudgetBinaryChoice(
              value: _isTaxInclusive,
              trueLabel: tr.budgetLineTaxInclusiveOption,
              falseLabel: tr.budgetLineTaxExclusiveOption,
              onChanged: (value) {
                setState(() => _isTaxInclusive = value);
                _report();
              },
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
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            _OcptCommitmentStatusPicker(
              value: _status,
              onChanged: (value) {
                setState(() => _status = value);
                _report();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Report both [_currentDraft] and [_missingFieldsHintOf] to the host — every controller
  /// listener and every picker's own `onChanged` call this after applying its own change.
  void _report() {
    widget.onDraftChanged(_currentDraft);
    widget.onMissingFieldsHintChanged(_missingFieldsHintOf());
  }

  /// Get the `VAT` field's own hint while it is left empty — mirrors `OcptBudgetEntryDialog`'s own
  /// reading exactly.
  String? _effectiveDefaultVatRateHint(Tr tr) {
    final defaultVatRateBasisPoints = widget.defaultVatRateBasisPoints;
    if (defaultVatRateBasisPoints == null) {
      return null;
    }

    return tr.budgetLineVatRateInheritedHint(ocptVatRatePercentTextOf(defaultVatRateBasisPoints));
  }

  /// Tell which of the two required fields (or both) is still missing, worded for the muted hint
  /// next to
  /// `Save` — null once both are filled, at which point [_currentDraft] no longer reads null for
  /// want of either.
  String? _missingFieldsHintOf() {
    final tr = Tr.of(context);
    final missingLabel = _labelController.text.trim().isEmpty;
    final missingAccount = _accountId == null;

    if (missingLabel && missingAccount) {
      return tr.budgetCommitmentDialogMissingLabelAndAccountHint;
    }
    if (missingLabel) {
      return tr.budgetCommitmentDialogMissingLabelHint;
    }
    if (missingAccount) {
      return tr.budgetCommitmentDialogMissingAccountHint;
    }

    return null;
  }

  /// Dispose [_labelController], [_amountController] and [_vatRateController].
  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    _vatRateController.dispose();
    super.dispose();
  }
}

/// The commitment form's own `Status` picker: `OcptBudgetCommitmentStatus`'s own four values as a
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

  /// Build the commitment status picker as a [Wrap].
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final status in OcptBudgetCommitmentStatus.values) _segment(context, status)],
  );

  /// Build one of the picker's own segments, filled in its own accent colour while active.
  Widget _segment(BuildContext context, OcptBudgetCommitmentStatus status) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isActive = status == value;
    final accent = ocptBudgetCommitmentStatusAccentColor(theme.colorScheme, status);

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

/// The commitment form's own `Poste` field: a picker, drawn whenever
/// [OcptBudgetCommitmentFormBody.accountAlreadyAnswered] is false — whether the dialog is creating
/// a commitment or editing one.
///
/// **Editable in both, unlike a quote line's own account** — see
/// `OcptBudgetJournalService.updateCommitment`'s own doc comment: a commitment's account is an
/// attribution typed once against a ten-account nomenclature, exactly the field somebody gets
/// wrong, and this table's flat `sortKey` makes changing it an ordinary field write rather than
/// the regrouping a line's own would be.
class _OcptCommitmentAccountField extends StatelessWidget {
  /// The accounts the picker offers.
  final List<OcptBudgetAccount> accounts;

  /// Whether the simplified naming applies to the account labels.
  final bool isSimplified;

  /// The picked account id, or null while none is picked.
  final String? value;

  /// Called with the picked account id.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const _OcptCommitmentAccountField({
    required this.accounts,
    required this.isSimplified,
    required this.value,
    required this.onChanged,
  });

  /// Build the commitment account field as a [DropdownButtonFormField].
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: Tr.of(context).budgetEntryDialogAccountFieldLabel),
    items: [
      for (final account in accounts)
        DropdownMenuItem(
          value: account.id,
          child: Text(ocptBudgetAccountDisplayLabel(account, isSimplified: isSimplified)),
        ),
    ],
    onChanged: onChanged,
  );
}
