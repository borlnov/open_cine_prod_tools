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
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_link_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_date_amount_basis_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_dialog_values.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_direction_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_link_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_receipt_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_vat_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_revenue_dialog.dart';

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
              OcptBudgetEntryDateAmountBasisRow(
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
              OcptBudgetEntryLinkField(
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
                    child: OcptBudgetEntryVatField(
                      controller: _vatRateController,
                      defaultVatRateBasisPoints: widget.defaultVatRateBasisPoints,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OcptBudgetEntryReceiptField(
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
                OcptBudgetEntryDirectionField(
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
    if (value != ocptBudgetNewRevenueActionValue) {
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
      _revenueId = ocptBudgetNewRevenuePickedValue;
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
        revenueId: _revenueId == ocptBudgetNewRevenuePickedValue ? null : _revenueId,
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
