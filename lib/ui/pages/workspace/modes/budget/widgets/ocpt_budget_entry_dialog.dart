// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_asset_file_types.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_link_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_revenue_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_asset_file_line.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The dialog that **edits** a cash-journal entry already on the books — creating one moved to the
/// capture wizard, `OcptBudgetNewDialog`, whose own step 3 draws `OcptBudgetMovementFormBody` for
/// every one of the seven `cashMovement` gestures instead.
///
/// **What used to be this dialog's own step 1 is gone, with everything that served it alone**: the
/// six nature cards, `Continuer`, the header's own `changer` link, and the reconciliation strip
/// (`OcptBudgetEntryDialog` only ever drew that strip while creating, which this dialog no longer
/// does at all). [existing] is now required — this dialog opens on one screen, the very form its
/// own former step 2 already drew, its nature read once, silently, off whichever of [existing]'s
/// own links is set (`ocptBudgetEntryNatureOfLinks`), exactly as before.
///
/// **[OcptBudgetEntryLinkKind.person] is reachable here**: the
/// capture wizard's own `reimbursePerson` gesture can write an entry naming a person, and this
/// dialog has to be able to edit it back rather than throwing the moment it tries. [people] is
/// there for exactly that: the `Personne` field mirrors the `Participant` field verbatim.
///
/// Structured after `OcptProjectVersionCreateDialog`: a [Form] validating the label before `Save`
/// is honoured, an `AlertDialog`. `Date` is `OcptPersonSheetDateField`; `Amount` is read through
/// [ocptCostCentsOf]; the tax-inclusive choice reuses [OcptBudgetBinaryChoice], as does the
/// direction choice while [OcptBudgetEntryNature.other] draws one at all.
///
/// **`Voucher number` and `Receipt` are both always offered**: an edit always opens with an entry
/// already on the books, so neither the auto-mint hint nor an unreachable receipt field has a
/// reason to exist here — see [OcptBudgetEntryFormFields.pickedReceiptPath]'s own doc comment for
/// why this dialog picks the file directly rather than through a bloc event.
class OcptBudgetEntryDialog extends StatefulWidget {
  /// The entry being edited.
  final OcptBudgetEntry existing;

  /// [existing]'s own voucher, if it carries one, or null.
  final OcptAssetRef? existingReceipt;

  /// Every live poste of the project, offered by the `Poste du devis` field.
  final List<OcptBudgetPoste> postes;

  /// Every live financing resource of the project, offered by the `Ressource` field.
  final List<OcptBudgetResource> resources;

  /// Every live taking of the project, offered by the `Recette` field.
  final List<OcptBudgetRevenue> revenues;

  /// Every live share of the project, offered by the `Participant` field.
  final List<OcptBudgetShare> shares;

  /// Every live person of the project's address book, offered by the `Personne` field.
  final List<OcptPerson> people;

  /// The project's currency, an ISO 4217 code, shown beside the `Montant` field.
  final String currencyCode;

  /// The project's default VAT rate, in basis points, or null — what the `TVA` field's own hint
  /// reads while it is left empty.
  final int? defaultVatRateBasisPoints;

  /// Whether the mode's header currently reads simplified — read by
  /// [OcptBudgetEntryNature.other]'s own direction choice and by the `Poste du devis` field's own
  /// poste labels.
  final bool isSimplified;

  /// Class constructor
  const OcptBudgetEntryDialog({
    super.key,
    required this.existing,
    this.existingReceipt,
    required this.postes,
    required this.resources,
    this.revenues = const [],
    this.shares = const [],
    this.people = const [],
    required this.currencyCode,
    required this.defaultVatRateBasisPoints,
    required this.isSimplified,
  });

  /// Shows the dialog and returns the fields the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetEntryFormFields?> show(
    BuildContext context, {
    required OcptBudgetEntry existing,
    OcptAssetRef? existingReceipt,
    required List<OcptBudgetPoste> postes,
    required List<OcptBudgetResource> resources,
    List<OcptBudgetRevenue> revenues = const [],
    List<OcptBudgetShare> shares = const [],
    List<OcptPerson> people = const [],
    required String currencyCode,
    required int? defaultVatRateBasisPoints,
    required bool isSimplified,
  }) => showDialog<OcptBudgetEntryFormFields>(
    context: context,
    builder: (context) => OcptBudgetEntryDialog(
      existing: existing,
      existingReceipt: existingReceipt,
      postes: postes,
      resources: resources,
      revenues: revenues,
      shares: shares,
      people: people,
      currencyCode: currencyCode,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      isSimplified: isSimplified,
    ),
  );

  @override
  State<OcptBudgetEntryDialog> createState() => _OcptBudgetEntryDialogState();
}

/// The `Recette` picker's own value standing for the taking `New taking…` has just collected but
/// nothing has created yet.
const String _ocptNewRevenuePickedValue = "#new-revenue";

/// The `Recette` picker's own value standing for the `New taking…` action itself.
const String _ocptNewRevenueActionValue = "#new-revenue-action";

/// The state of [OcptBudgetEntryDialog]: the draft — one continuous set of controllers and fields.
class _OcptBudgetEntryDialogState extends State<OcptBudgetEntryDialog> {
  /// The form validating the label field before `Save` is honoured.
  final _formKey = GlobalKey<FormState>();

  /// The controller of the label field.
  late final TextEditingController _labelController;

  /// The controller of the amount field.
  late final TextEditingController _amountController;

  /// The controller of the VAT rate override field.
  late final TextEditingController _vatRateController;

  /// The controller of the voucher number field.
  late final TextEditingController _voucherController;

  /// The date currently picked.
  late DateTime _date;

  /// The poste currently picked, or null.
  String? _posteId;

  /// The financing resource currently picked, or null.
  String? _resourceId;

  /// The taking currently picked, or null.
  String? _revenueId;

  /// The share currently picked, or null.
  String? _shareId;

  /// The person currently picked, or null.
  String? _personId;

  /// The taking the `New taking…` entry just collected, waiting to be created along with this
  /// movement, or null — see [OcptBudgetEntryFormFields.newRevenue].
  OcptBudgetRevenueFormFields? _newRevenue;

  /// Whether the direction currently picked is a debit. Only ever changed through
  /// [OcptBudgetEntryNature.other]'s own direction choice — every other nature fixes it.
  late bool _isDebit;

  /// Whether the amount currently picked includes tax.
  late bool _isTaxInclusive;

  /// The path of a voucher file just picked through the native selector this dialog session, or
  /// null.
  String? _pickedReceiptPath;

  /// Whether the `Detach` action was used on the voucher already referenced.
  bool _isReceiptDetached = false;

  /// `widget.existing`'s own nature, read once off whichever of its own links is set — never
  /// changed afterwards, this dialog offering no way to reconsider it.
  late final OcptBudgetEntryNature _nature;

  /// The path currently shown for the `Justificatif` field.
  String? get _displayedReceiptPath {
    final pickedReceiptPath = _pickedReceiptPath;
    if (pickedReceiptPath != null) {
      return pickedReceiptPath;
    }
    if (_isReceiptDetached) {
      return null;
    }
    return widget.existingReceipt?.path;
  }

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _date = existing.date;
    _posteId = existing.posteId;
    _resourceId = existing.resourceId;
    _revenueId = existing.revenueId;
    _shareId = existing.shareId;
    _personId = existing.personId;
    _isDebit = existing.debitCents > 0;
    _isTaxInclusive = existing.isTaxInclusive;

    _labelController = TextEditingController(text: existing.label);
    _amountController = TextEditingController(
      text: ocptCostTextOf(existing.debitCents > 0 ? existing.debitCents : existing.creditCents),
    );
    _vatRateController = TextEditingController(
      text: ocptVatRatePercentTextOf(existing.vatRateBasisPoints),
    );
    _voucherController = TextEditingController(text: existing.voucherNumber);

    _nature = ocptBudgetEntryNatureOfLinks(
      isDebit: _isDebit,
      posteId: _posteId,
      resourceId: _resourceId,
      revenueId: _revenueId,
      shareId: _shareId,
      personId: _personId,
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    _vatRateController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final currencySymbol = NumberFormat.simpleCurrency(name: widget.currencyCode).currencySymbol;

    return AlertDialog(
      title: Text(tr.budgetEntryDialogEditTitle),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OcptEntryDateAmountBasisRow(
                date: _date,
                onDateChanged: (value) => setState(() => _date = value ?? _date),
                amountController: _amountController,
                onAmountChanged: () => setState(() {}),
                currencySymbol: currencySymbol,
                isTaxInclusive: _isTaxInclusive,
                onTaxBasisChanged: (value) => setState(() => _isTaxInclusive = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelController,
                autofocus: true,
                decoration: InputDecoration(labelText: tr.budgetEntryDialogLabelFieldLabel),
                validator: (value) =>
                    (value ?? "").trim().isEmpty ? tr.budgetEntryDialogLabelRequiredError : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _OcptEntryLinkField(
                nature: _nature,
                postes: widget.postes,
                resources: widget.resources,
                revenues: widget.revenues,
                shares: widget.shares,
                people: widget.people,
                isSimplified: widget.isSimplified,
                posteId: _posteId,
                resourceId: _resourceId,
                revenueId: _revenueId,
                newRevenue: _newRevenue,
                shareId: _shareId,
                personId: _personId,
                onPosteChanged: (value) => setState(() => _posteId = value),
                onResourceChanged: (value) => setState(() => _resourceId = value),
                onRevenueChanged: _onRevenuePicked,
                onShareChanged: (value) => setState(() => _shareId = value),
                onPersonChanged: (value) => setState(() => _personId = value),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _OcptEntryVatField(
                      controller: _vatRateController,
                      defaultVatRateBasisPoints: widget.defaultVatRateBasisPoints,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OcptEntryReceiptField(
                      displayedReceiptPath: _displayedReceiptPath,
                      existingReceipt: widget.existingReceipt,
                      onRemoved: () => setState(() {
                        _pickedReceiptPath = null;
                        _isReceiptDetached = true;
                      }),
                      onPickRequested: _pickReceipt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _voucherController,
                decoration: InputDecoration(labelText: tr.budgetEntryDialogVoucherFieldLabel),
              ),
              if (_nature == OcptBudgetEntryNature.other) ...[
                const SizedBox(height: 12),
                _OcptEntryDirectionField(
                  isDebit: _isDebit,
                  isSimplified: widget.isSimplified,
                  onChanged: (value) => setState(() => _isDebit = value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.budgetEntryDialogCancelAction),
        ),
        FilledButton(
          key: const Key("ocptBudgetEntryWizardSaveButton"),
          onPressed: _submit,
          child: Text(tr.budgetEntryDialogConfirmAction),
        ),
      ],
    );
  }

  /// Applies the `Recette` picker's own choice.
  Future<void> _onRevenuePicked(String? value) async {
    if (value != _ocptNewRevenueActionValue) {
      setState(() => _revenueId = value);
      return;
    }

    final fields = await OcptBudgetRevenueDialog.show(
      context,
      existing: null,
      currencyCode: widget.currencyCode,
    );
    if (fields == null || !mounted) {
      return;
    }

    setState(() {
      _newRevenue = fields;
      _revenueId = _ocptNewRevenuePickedValue;
    });
  }

  /// Shows the native "open" dialog.
  Future<void> _pickReceipt() async {
    final label = Tr.of(context).budgetEntryDialogReceiptFieldLabel;
    final selection = await globalGetIt().get<FileSelectorManager>().openSelector(
      allowedExtensions: ocptDocumentFileExtensions,
      label: label,
    );

    final file = selection.value;
    if (!selection.status.isSuccess || file == null || file.path.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _pickedReceiptPath = file.path;
      _isReceiptDetached = false;
    });
  }

  /// `Enregistrer`: validates the form and, if it passes, pops with every field collected.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amountCents = ocptCostCentsOf(_amountController.text);
    if (amountCents == null) {
      return;
    }

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetEntryFormFields>(
      OcptBudgetEntryFormFields(
        date: _date,
        label: _labelController.text.trim(),
        posteId: _posteId,
        resourceId: _resourceId,
        // The sentinel never leaves this dialog: a taking still to be created travels as
        // `newRevenue`, and the bloc writes its fresh id where this would have gone.
        revenueId: _revenueId == _ocptNewRevenuePickedValue ? null : _revenueId,
        newRevenue: _newRevenue,
        shareId: _shareId,
        personId: _personId,
        isDebit: _isDebit,
        amountCents: amountCents,
        isTaxInclusive: _isTaxInclusive,
        vatRateBasisPoints: ocptVatRateBasisPointsOf(_vatRateController.text),
        voucherNumber: _voucherController.text.trim(),
        pickedReceiptPath: _pickedReceiptPath,
        isReceiptDetached: _isReceiptDetached,
      ),
    );
  }
}

/// `Date`, `Montant` and `Base` on one row.
class _OcptEntryDateAmountBasisRow extends StatelessWidget {
  /// The date currently picked.
  final DateTime date;

  /// Called with the date just picked, or null when it was cleared.
  final ValueChanged<DateTime?> onDateChanged;

  /// The controller of the amount field.
  final TextEditingController amountController;

  /// Called on every keystroke in the amount field.
  final VoidCallback onAmountChanged;

  /// The currency symbol drawn after the amount.
  final String currencySymbol;

  /// Whether the amount currently picked includes tax.
  final bool isTaxInclusive;

  /// Called with the tax basis just picked.
  final ValueChanged<bool> onTaxBasisChanged;

  /// Class constructor
  const _OcptEntryDateAmountBasisRow({
    required this.date,
    required this.onDateChanged,
    required this.amountController,
    required this.onAmountChanged,
    required this.currencySymbol,
    required this.isTaxInclusive,
    required this.onTaxBasisChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: OcptPersonSheetDateField(
            label: tr.budgetEntryDialogDateFieldLabel,
            value: date,
            onChanged: onDateChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          // `Amount`'s own label sits above the field, dense, exactly as `Date` and `Base` carry
          // theirs — a `labelText` inside the decoration would float the label into the box and drop
          // the field lower than its two `CrossAxisAlignment.start` siblings, which is what left the
          // three misaligned.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr.budgetEntryDialogAmountFieldLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                key: const Key("ocptBudgetEntryWizardAmountField"),
                controller: amountController,
                decoration: InputDecoration(isDense: true, suffixText: currencySymbol),
                validator: (value) => ocptCostCentsOf(value ?? "") == null
                    ? tr.budgetEntryDialogAmountInvalidError
                    : null,
                onChanged: (_) => onAmountChanged(),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _OcptEntryTaxBasisField(isTaxInclusive: isTaxInclusive, onChanged: onTaxBasisChanged),
      ],
    );
  }
}

/// `Base`: the tax-inclusive/exclusive choice.
///
/// **Wrapped in [IntrinsicWidth]**: [OcptBudgetBinaryChoice]'s own `Row` reads
/// `MainAxisSize.max`, which would otherwise claim the whole width the outer `Row` offers a
/// non-flexible child before `Date` and `Montant` (both `Expanded`) are even sized.
class _OcptEntryTaxBasisField extends StatelessWidget {
  /// Whether the amount currently picked includes tax.
  final bool isTaxInclusive;

  /// Called with the tax basis just picked.
  final ValueChanged<bool> onChanged;

  /// Class constructor
  const _OcptEntryTaxBasisField({required this.isTaxInclusive, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.budgetEntryDialogTaxBasisFieldLabel.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          OcptBudgetBinaryChoice(
            value: isTaxInclusive,
            trueLabel: tr.budgetLineTaxInclusiveOption,
            falseLabel: tr.budgetLineTaxExclusiveOption,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// [OcptBudgetEntryNature.other]'s own direction choice — the one nature that still asks it.
class _OcptEntryDirectionField extends StatelessWidget {
  /// Whether the direction currently picked is a debit.
  final bool isDebit;

  /// Whether the simplified wording applies.
  final bool isSimplified;

  /// Called with the direction just picked.
  final ValueChanged<bool> onChanged;

  /// Class constructor
  const _OcptEntryDirectionField({
    required this.isDebit,
    required this.isSimplified,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.budgetEntryDialogDirectionFieldLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        OcptBudgetBinaryChoice(
          value: isDebit,
          trueLabel: isSimplified
              ? tr.budgetEntryDialogPaidOption
              : tr.budgetEntryDialogDebitOption,
          falseLabel: isSimplified
              ? tr.budgetEntryDialogReceivedOption
              : tr.budgetEntryDialogCreditOption,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The one link field [nature] picks — [OcptBudgetEntryLinkKind] says which.
class _OcptEntryLinkField extends StatelessWidget {
  /// The entry's nature, which fixes the link field drawn.
  final OcptBudgetEntryNature nature;

  /// Every live poste.
  final List<OcptBudgetPoste> postes;

  /// Every live financing resource.
  final List<OcptBudgetResource> resources;

  /// Every live taking.
  final List<OcptBudgetRevenue> revenues;

  /// Every live share.
  final List<OcptBudgetShare> shares;

  /// Every person.
  final List<OcptPerson> people;

  /// Whether the simplified naming applies to the poste labels.
  final bool isSimplified;

  /// The poste currently picked, or null.
  final String? posteId;

  /// The financing resource currently picked, or null.
  final String? resourceId;

  /// The taking currently picked, or null.
  final String? revenueId;

  /// The taking the `New taking…` entry just collected, or null.
  final OcptBudgetRevenueFormFields? newRevenue;

  /// The share currently picked, or null.
  final String? shareId;

  /// The person currently picked, or null.
  final String? personId;

  /// Called with the poste just picked.
  final ValueChanged<String?> onPosteChanged;

  /// Called with the financing resource just picked.
  final ValueChanged<String?> onResourceChanged;

  /// Called with the taking just picked, or with the `New taking…` sentinel.
  final ValueChanged<String?> onRevenueChanged;

  /// Called with the share just picked.
  final ValueChanged<String?> onShareChanged;

  /// Called with the person just picked.
  final ValueChanged<String?> onPersonChanged;

  /// Class constructor
  const _OcptEntryLinkField({
    required this.nature,
    required this.postes,
    required this.resources,
    required this.revenues,
    required this.shares,
    required this.people,
    required this.isSimplified,
    required this.posteId,
    required this.resourceId,
    required this.revenueId,
    required this.newRevenue,
    required this.shareId,
    required this.personId,
    required this.onPosteChanged,
    required this.onResourceChanged,
    required this.onRevenueChanged,
    required this.onShareChanged,
    required this.onPersonChanged,
  });

  @override
  Widget build(BuildContext context) => switch (ocptBudgetEntryNatureLinkKindOf(nature)) {
    OcptBudgetEntryLinkKind.poste => _OcptEntryPosteField(
      postes: postes,
      isSimplified: isSimplified,
      posteId: posteId,
      onChanged: onPosteChanged,
    ),
    OcptBudgetEntryLinkKind.financingResource => _OcptEntryResourceField(
      resources: resources,
      resourceId: resourceId,
      onChanged: onResourceChanged,
    ),
    OcptBudgetEntryLinkKind.taking => _OcptEntryRevenueField(
      revenues: revenues,
      revenueId: revenueId,
      newRevenue: newRevenue,
      onChanged: onRevenueChanged,
    ),
    OcptBudgetEntryLinkKind.participant => _OcptEntryShareField(
      shares: shares,
      shareId: shareId,
      onChanged: onShareChanged,
    ),
    OcptBudgetEntryLinkKind.person => _OcptEntryPersonField(
      people: people,
      personId: personId,
      onChanged: onPersonChanged,
    ),
  };
}

/// `Poste du devis` — offered under [OcptBudgetEntryNature.expense] and
/// [OcptBudgetEntryNature.other] alike. **Its own "unanswered" item reads `Hors devis`, never a
/// generic "no poste"**: the very same label the expenses table draws for the very same synthetic
/// row, so a reader who leaves this field blank sees, in the field itself, exactly where the
/// entry will land.
class _OcptEntryPosteField extends StatelessWidget {
  /// Every live poste.
  final List<OcptBudgetPoste> postes;

  /// Whether the simplified naming applies to the poste labels.
  final bool isSimplified;

  /// The poste currently picked, or null.
  final String? posteId;

  /// Called with the poste just picked.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const _OcptEntryPosteField({
    required this.postes,
    required this.isSimplified,
    required this.posteId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          key: const Key("ocptBudgetEntryWizardPosteField"),
          initialValue: posteId,
          decoration: InputDecoration(labelText: tr.budgetEntryDialogPosteFieldLabel),
          items: [
            DropdownMenuItem(child: Text(tr.budgetCostTrackingOffQuoteLabel)),
            for (final poste in postes)
              DropdownMenuItem(
                value: poste.id,
                child: Text(ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified)),
              ),
          ],
          onChanged: onChanged,
        ),
        const SizedBox(height: 4),
        Text(
          tr.budgetEntryWizardPosteFieldHint(tr.budgetCostTrackingOffQuoteLabel),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// `Ressource` — offered under [OcptBudgetEntryNature.financing] and
/// [OcptBudgetEntryNature.repayment] alike.
class _OcptEntryResourceField extends StatelessWidget {
  /// Every live financing resource.
  final List<OcptBudgetResource> resources;

  /// The financing resource currently picked, or null.
  final String? resourceId;

  /// Called with the financing resource just picked.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const _OcptEntryResourceField({
    required this.resources,
    required this.resourceId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return DropdownButtonFormField<String?>(
      key: const Key("ocptBudgetEntryWizardResourceField"),
      initialValue: resourceId,
      decoration: InputDecoration(labelText: tr.budgetEntryDialogResourceFieldLabel),
      items: [
        DropdownMenuItem(child: Text(tr.budgetEntryDialogNoResourceLabel)),
        for (final resource in resources)
          DropdownMenuItem(value: resource.id, child: Text(resource.label)),
      ],
      onChanged: onChanged,
    );
  }
}

/// `Recette` — offered under [OcptBudgetEntryNature.revenue] alone. Carries the `New taking…`
/// entry: see `_OcptBudgetEntryDialogState._onRevenuePicked`.
class _OcptEntryRevenueField extends StatelessWidget {
  /// Every live taking.
  final List<OcptBudgetRevenue> revenues;

  /// The taking currently picked, or null.
  final String? revenueId;

  /// The taking the `New taking…` entry just collected, or null.
  final OcptBudgetRevenueFormFields? newRevenue;

  /// Called with the taking just picked, or with the `New taking…` sentinel.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const _OcptEntryRevenueField({
    required this.revenues,
    required this.revenueId,
    required this.newRevenue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return DropdownButtonFormField<String?>(
      key: ValueKey("ocptBudgetEntryWizardRevenueField/$revenueId/${newRevenue?.label}"),
      initialValue: revenueId,
      decoration: InputDecoration(labelText: tr.budgetEntryDialogRevenueFieldLabel),
      isExpanded: true,
      items: [
        DropdownMenuItem(child: Text(tr.budgetEntryDialogNoRevenueLabel)),
        for (final revenue in revenues)
          DropdownMenuItem(
            value: revenue.id,
            child: Text(revenue.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        if (newRevenue case final newRevenue?)
          DropdownMenuItem(
            value: _ocptNewRevenuePickedValue,
            child: Text(
              tr.budgetEntryDialogNewRevenuePicked(newRevenue.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        DropdownMenuItem(
          value: _ocptNewRevenueActionValue,
          child: Text(tr.budgetEntryDialogNewRevenueAction),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

/// `Participant` — offered under [OcptBudgetEntryNature.payout] alone.
class _OcptEntryShareField extends StatelessWidget {
  /// Every live share.
  final List<OcptBudgetShare> shares;

  /// The share currently picked, or null.
  final String? shareId;

  /// Called with the share just picked.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const _OcptEntryShareField({
    required this.shares,
    required this.shareId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return DropdownButtonFormField<String?>(
      key: const Key("ocptBudgetEntryWizardShareField"),
      initialValue: shareId,
      decoration: InputDecoration(labelText: tr.budgetEntryDialogShareFieldLabel),
      items: [
        DropdownMenuItem(child: Text(tr.budgetEntryDialogNoShareLabel)),
        for (final share in shares) DropdownMenuItem(value: share.id, child: Text(share.label)),
      ],
      onChanged: onChanged,
    );
  }
}

/// `Personne` — offered under [OcptBudgetEntryNature.personReimbursement] alone. Mirrors
/// [_OcptEntryShareField] verbatim: the field that gives [OcptBudgetEntryLinkKind.person] a real
/// screen instead of a thrown error.
class _OcptEntryPersonField extends StatelessWidget {
  /// Every person.
  final List<OcptPerson> people;

  /// The person currently picked, or null.
  final String? personId;

  /// Called with the person just picked.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const _OcptEntryPersonField({
    required this.people,
    required this.personId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return DropdownButtonFormField<String?>(
      key: const Key("ocptBudgetEntryWizardPersonField"),
      initialValue: personId,
      decoration: InputDecoration(labelText: tr.budgetEntryDialogPersonFieldLabel),
      items: [
        DropdownMenuItem(child: Text(tr.budgetEntryDialogNoPersonLabel)),
        for (final person in people)
          DropdownMenuItem(value: person.id, child: Text(person.displayName)),
      ],
      onChanged: onChanged,
    );
  }
}

/// `TVA`.
class _OcptEntryVatField extends StatelessWidget {
  /// The controller of the VAT rate override field.
  final TextEditingController controller;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// Class constructor
  const _OcptEntryVatField({required this.controller, required this.defaultVatRateBasisPoints});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final defaultVatRateBasisPoints = this.defaultVatRateBasisPoints;
    final vatRateHint = defaultVatRateBasisPoints == null
        ? null
        : tr.budgetLineVatRateInheritedHint(ocptVatRatePercentTextOf(defaultVatRateBasisPoints));

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: tr.budgetLineVatRateFieldLabel,
        hintText: vatRateHint,
        suffixText: tr.budgetLineVatRateSuffix,
      ),
    );
  }
}

/// `Justificatif`.
class _OcptEntryReceiptField extends StatelessWidget {
  /// The path currently shown, or null while no voucher is attached.
  final String? displayedReceiptPath;

  /// The voucher already referenced by the entry, or null.
  final OcptAssetRef? existingReceipt;

  /// Called when the voucher's own remove action is used.
  final VoidCallback onRemoved;

  /// Called when the attach or replace button is pressed.
  final VoidCallback onPickRequested;

  /// Class constructor
  const _OcptEntryReceiptField({
    required this.displayedReceiptPath,
    required this.existingReceipt,
    required this.onRemoved,
    required this.onPickRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final displayedReceiptPath = this.displayedReceiptPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.budgetEntryDialogReceiptFieldLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        if (displayedReceiptPath != null)
          OcptAssetFileLine(
            asset: OcptAssetRef(
              id: existingReceipt?.id ?? "",
              kind: OcptAssetKind.receipt,
              path: displayedReceiptPath,
              label: "",
              addedAt: existingReceipt?.addedAt ?? DateTime.now(),
              personId: null,
              locationId: null,
              elementId: null,
              validFrom: null,
              validUntil: null,
            ),
            onRemoved: onRemoved,
          )
        else
          Text(
            tr.budgetEntryDialogReceiptEmptyHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onPickRequested,
            child: Text(
              displayedReceiptPath == null
                  ? tr.budgetEntryDialogReceiptAttachAction
                  : tr.budgetEntryDialogReceiptReplaceAction,
            ),
          ),
        ),
      ],
    );
  }
}
