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
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_asset_file_line.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// The dialog that both **creates and edits** a cash-journal entry — one shape for both, the
/// decision taken for this milestone (`docs/architecture/budget.md`). Use [show] to display it and
/// get the collected [OcptBudgetEntryFormFields] back, or null if the user cancelled. Dismissed
/// through `OcptRouterManager.pop`, never `Navigator`, exactly like every other dialog of the app.
///
/// Structured after `OcptProjectVersionCreateDialog`: a [Form] validating the one required field
/// (`Label`) before `Save` is honoured, an `AlertDialog` with `Cancel`/`Save` actions. Every other
/// field reuses an idiom already established elsewhere in the mode rather than inventing a new one:
/// `Date` is `OcptPersonSheetDateField` (the person sheet's own date-field idiom); `Amount` is read
/// through [ocptCostCentsOf], the project's currency shown beside it as `suffixText`, exactly as the
/// quote line's own unit-price field; the tax-inclusive choice and the debit/credit direction both
/// reuse [OcptBudgetBinaryChoice], the poste inspector's own two-segment choice lifted here once a
/// second (then a third) call site needed the very same shape; and the `VAT` field's own hint,
/// while a rate is known, reuses `Tr.budgetLineVatRateInheritedHint` verbatim.
///
/// **The `VAT` field's empty reading is the one place this dialog disagrees with the poste
/// inspector's own line card**: see [OcptBudgetEntryFormFields.vatRateBasisPoints]'s own doc comment
/// for the argument — a keystroke-by-keystroke autosave and a single, deliberate `Save` action read
/// an empty field differently, and this dialog is the latter.
///
/// **`Voucher number` only exists on an edit.** Creating an entry offers no such field at all — a
/// muted line says the reference is minted automatically — since `OcptBudgetJournalService
/// .createEntry` mints one itself; editing an existing entry can retype it, since a user may need it
/// to match a paper trail the minted reference doesn't.
///
/// **`Receipt` is a different thing from `Voucher number`**: the latter is a typed accounting
/// reference (`J-014`), the former is the actual file — a till receipt, an invoice PDF, a bank slip
/// — evidencing the movement (ADR 0013). Offered on both a fresh entry and an edit alike, unlike
/// `Voucher number`. This dialog only ever **picks** the path, through
/// `globalGetIt().get<FileSelectorManager>()` directly — a plain read of a file the OS dialog
/// already reports, with nothing to decode and no `assets` row to mint — deferring the write itself
/// to whichever of [OcptBudgetEntryFormFields.pickedReceiptPath]/`.isReceiptDetached` `_submit`
/// hands back: the bloc's own entry-writing handlers are the only place a voucher is actually
/// minted or tombstoned, in the very same handler that creates or updates the entry. This is the one
/// place in the app calling that manager directly rather than through a bloc event — deliberately
/// so, since every other field here already collects locally and writes once on `Save`, and a
/// voucher pick is no different: the resources mode's own photo/document pickers
/// (`OcptResourcesBloc._pickFilePath`) write immediately because *that* gesture has no `Save` step
/// of its own to defer to.
///
/// **[prefill] seeds a fresh entry's own fields without editing one already stored.** The
/// committed-spending view's own `Settle` action opens this dialog to record a commitment's
/// payment: today's date, the commitment's own label, poste, amount, tax basis and rate, as a debit
/// — [prefill] carries exactly that, read the moment `initState` runs, same as [existing] would be.
/// [existing] wins whenever both are given, though the mode never actually hands in both: settling
/// a commitment always opens a **fresh** entry, never an existing one.
///
/// **`Resource` is a second picker beside `Poste`**, offering [resources] alongside its own
/// explicit "no resource" choice — null, the normal case for the great majority of entries, since
/// only a movement actually settling a financing resource ever names one. Read and written exactly
/// like `Poste`: an entry may carry both, either or neither, the two questions ("what does this
/// price?" and "what does this settle?") being independent of one another. This is what lets the
/// financing view's own `Record a receipt` gesture open this very dialog pre-filled with a resource
/// already picked, and lets an ordinary entry be edited to name one after the fact.
class OcptBudgetEntryDialog extends StatefulWidget {
  /// The entry being edited, or null while creating a new one.
  final OcptBudgetEntry? existing;

  /// Seeds a fresh entry's own fields while [existing] is null — see the class doc comment.
  final OcptBudgetEntryFormFields? prefill;

  /// [existing]'s own voucher, if it carries one, or null — always null while [existing] is
  /// itself null, there being nothing yet to reference. Read once, in `initState`, exactly as
  /// [existing]'s own fields are.
  final OcptAssetRef? existingReceipt;

  /// Every live poste of the project, offered by the `Poste` picker alongside its own explicit "no
  /// poste" choice.
  final List<OcptBudgetPoste> postes;

  /// Every live financing resource of the project, offered by the `Resource` picker alongside its
  /// own explicit "no resource" choice — see the class doc comment.
  final List<OcptBudgetResource> resources;

  /// The project's currency, an ISO 4217 code, shown beside the `Amount` field.
  final String currencyCode;

  /// The project's default VAT rate, in basis points, or null — what the `VAT` field's own hint
  /// reads while it is left empty.
  final int? defaultVatRateBasisPoints;

  /// Whether the mode's header currently reads simplified — the `Direction` choice's own two labels
  /// read as the plain thing that happened ("I paid"/"I received") rather than `Debit`/`Credit`.
  final bool isSimplified;

  /// Class constructor
  const OcptBudgetEntryDialog({
    super.key,
    required this.existing,
    this.prefill,
    this.existingReceipt,
    required this.postes,
    required this.resources,
    required this.currencyCode,
    required this.defaultVatRateBasisPoints,
    required this.isSimplified,
  });

  /// Shows the dialog and returns the fields the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetEntryFormFields?> show(
    BuildContext context, {
    required OcptBudgetEntry? existing,
    OcptBudgetEntryFormFields? prefill,
    OcptAssetRef? existingReceipt,
    required List<OcptBudgetPoste> postes,
    required List<OcptBudgetResource> resources,
    required String currencyCode,
    required int? defaultVatRateBasisPoints,
    required bool isSimplified,
  }) => showDialog<OcptBudgetEntryFormFields>(
    context: context,
    builder: (context) => OcptBudgetEntryDialog(
      existing: existing,
      prefill: prefill,
      existingReceipt: existingReceipt,
      postes: postes,
      resources: resources,
      currencyCode: currencyCode,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      isSimplified: isSimplified,
    ),
  );

  @override
  State<OcptBudgetEntryDialog> createState() => _OcptBudgetEntryDialogState();
}

/// The state of [OcptBudgetEntryDialog].
class _OcptBudgetEntryDialogState extends State<OcptBudgetEntryDialog> {
  /// The form used to validate the entered label and amount.
  final _formKey = GlobalKey<FormState>();

  /// The controller of the label field.
  late final TextEditingController _labelController;

  /// The controller of the amount field.
  late final TextEditingController _amountController;

  /// The controller of the VAT rate override field.
  late final TextEditingController _vatRateController;

  /// The controller of the voucher number field — only built, and only shown, while
  /// [OcptBudgetEntryDialog.existing] is not null.
  TextEditingController? _voucherController;

  /// The date currently picked — today for a new entry.
  late DateTime _date;

  /// The poste currently picked, or null for "no poste".
  String? _posteId;

  /// The financing resource currently picked, or null for "no resource" — the normal case, see the
  /// class doc comment.
  String? _resourceId;

  /// Whether the direction currently picked is a debit (money that left the account).
  late bool _isDebit;

  /// Whether the amount currently picked includes tax.
  late bool _isTaxInclusive;

  /// The path of a voucher file just picked through the native selector this dialog session, or
  /// null while nothing new was picked — see `OcptBudgetEntryFormFields.pickedReceiptPath`'s own
  /// doc comment for what this becomes once [_submit] hands it back.
  String? _pickedReceiptPath;

  /// Whether the `Detach` action was used on the voucher `widget.existingReceipt` already
  /// referenced — see `OcptBudgetEntryFormFields.isReceiptDetached`'s own doc comment.
  bool _isReceiptDetached = false;

  /// The path currently shown for the `Receipt` field: a fresh pick first, then whatever
  /// `widget.existingReceipt` carries unless [_isReceiptDetached] dropped it, or null while there is
  /// nothing to show at all.
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
    final prefill = widget.prefill;
    final now = DateTime.now();

    _date = existing?.date ?? prefill?.date ?? DateTime(now.year, now.month, now.day);
    _posteId = existing?.posteId ?? prefill?.posteId;
    _resourceId = existing?.resourceId ?? prefill?.resourceId;
    _isDebit = existing != null ? existing.debitCents > 0 : (prefill?.isDebit ?? true);
    _isTaxInclusive = existing?.isTaxInclusive ?? prefill?.isTaxInclusive ?? true;

    _labelController = TextEditingController(text: existing?.label ?? prefill?.label ?? "");
    _amountController = TextEditingController(
      text: existing != null
          ? ocptCostTextOf(existing.debitCents > 0 ? existing.debitCents : existing.creditCents)
          : ocptCostTextOf(prefill?.amountCents),
    );
    _vatRateController = TextEditingController(
      text: ocptVatRatePercentTextOf(existing?.vatRateBasisPoints ?? prefill?.vatRateBasisPoints),
    );
    if (existing != null) {
      _voucherController = TextEditingController(text: existing.voucherNumber);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    _vatRateController.dispose();
    _voucherController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final currencySymbol = NumberFormat.simpleCurrency(name: widget.currencyCode).currencySymbol;
    final vatRateHint = _effectiveDefaultVatRateHint(tr);

    return AlertDialog(
      title: Text(isEditing ? tr.budgetEntryDialogEditTitle : tr.budgetEntryDialogCreateTitle),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr.budgetEntryDialogDirectionFieldLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              OcptBudgetBinaryChoice(
                value: _isDebit,
                trueLabel: widget.isSimplified
                    ? tr.budgetEntryDialogPaidOption
                    : tr.budgetEntryDialogDebitOption,
                falseLabel: widget.isSimplified
                    ? tr.budgetEntryDialogReceivedOption
                    : tr.budgetEntryDialogCreditOption,
                onChanged: (value) => setState(() => _isDebit = value),
              ),
              const SizedBox(height: 12),
              OcptPersonSheetDateField(
                label: tr.budgetEntryDialogDateFieldLabel,
                value: _date,
                onChanged: (value) => setState(() => _date = value ?? _date),
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
              DropdownButtonFormField<String?>(
                initialValue: _posteId,
                decoration: InputDecoration(labelText: tr.budgetEntryDialogPosteFieldLabel),
                items: [
                  DropdownMenuItem(child: Text(tr.budgetCashJournalNoPosteLabel)),
                  for (final poste in widget.postes)
                    DropdownMenuItem(
                      value: poste.id,
                      child: Text(
                        ocptBudgetPosteDisplayLabel(poste, isSimplified: widget.isSimplified),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _posteId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _resourceId,
                decoration: InputDecoration(labelText: tr.budgetEntryDialogResourceFieldLabel),
                items: [
                  DropdownMenuItem(child: Text(tr.budgetEntryDialogNoResourceLabel)),
                  for (final resource in widget.resources)
                    DropdownMenuItem(value: resource.id, child: Text(resource.label)),
                ],
                onChanged: (value) => setState(() => _resourceId = value),
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
              _buildVoucherField(context, tr, theme),
              const SizedBox(height: 12),
              _buildReceiptField(context, tr, theme),
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

  /// The `VAT` field's own hint while it is left empty: the project's default rate, formatted
  /// exactly as the poste inspector's own line card's inherited hint is, or null while the project
  /// carries no rate at all — mirroring `_OcptBudgetLineFields`'s own reading, over
  /// `widget.defaultVatRateBasisPoints` alone since this dialog carries no line-level rate of its
  /// own to pair it with.
  String? _effectiveDefaultVatRateHint(Tr tr) {
    final defaultVatRateBasisPoints = widget.defaultVatRateBasisPoints;
    if (defaultVatRateBasisPoints == null) {
      return null;
    }

    return tr.budgetLineVatRateInheritedHint(ocptVatRatePercentTextOf(defaultVatRateBasisPoints));
  }

  /// The `Voucher number` field: editable while editing an existing entry, a muted informational
  /// line while creating a new one — see the class doc comment.
  Widget _buildVoucherField(BuildContext context, Tr tr, ThemeData theme) {
    final voucherController = _voucherController;
    if (voucherController != null) {
      return TextFormField(
        controller: voucherController,
        decoration: InputDecoration(labelText: tr.budgetEntryDialogVoucherFieldLabel),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.budgetEntryDialogVoucherFieldLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          tr.budgetEntryDialogVoucherAutoHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// The `Receipt` field: whichever file is currently shown ([_displayedReceiptPath]) — reusing
  /// `OcptAssetFileLine` exactly as the resources mode's own permit card does, wrapping the path in
  /// a transient `OcptAssetRef` since this file's own `existsSync` check needs nothing else off it
  /// — with an `Attach`/`Replace` action underneath, offered whether creating or editing (unlike
  /// `Voucher number`, see the class doc comment).
  Widget _buildReceiptField(BuildContext context, Tr tr, ThemeData theme) {
    final displayedReceiptPath = _displayedReceiptPath;

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
              id: widget.existingReceipt?.id ?? "",
              kind: OcptAssetKind.receipt,
              path: displayedReceiptPath,
              label: "",
              addedAt: widget.existingReceipt?.addedAt ?? DateTime.now(),
              personId: null,
              locationId: null,
              elementId: null,
              validFrom: null,
              validUntil: null,
            ),
            onRemoved: () => setState(() {
              _pickedReceiptPath = null;
              _isReceiptDetached = true;
            }),
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
            onPressed: _pickReceipt,
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

  /// Shows the native "open" dialog and, if a file was picked, records its path locally — see the
  /// class doc comment for why this dialog calls `FileSelectorManager` directly rather than through
  /// a bloc event: nothing is written to the project until [_submit].
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

  /// Validates the form and, if it passes, pops the dialog returning every field collected.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amountCents = ocptCostCentsOf(_amountController.text);
    if (amountCents == null) {
      return;
    }

    final voucherController = _voucherController;

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetEntryFormFields>(
      OcptBudgetEntryFormFields(
        date: _date,
        label: _labelController.text.trim(),
        posteId: _posteId,
        resourceId: _resourceId,
        isDebit: _isDebit,
        amountCents: amountCents,
        isTaxInclusive: _isTaxInclusive,
        vatRateBasisPoints: ocptVatRateBasisPointsOf(_vatRateController.text),
        voucherNumber: voucherController?.text.trim(),
        pickedReceiptPath: _pickedReceiptPath,
        isReceiptDetached: _isReceiptDetached,
      ),
    );
  }
}
