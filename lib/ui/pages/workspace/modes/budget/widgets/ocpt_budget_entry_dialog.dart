// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_asset_file_types.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_wizard_result.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_link_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_revenue_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_asset_file_line.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_match.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// Which of the wizard's own two screens `OcptBudgetEntryDialog` is currently drawing.
enum _OcptBudgetEntryWizardStep {
  /// Step 1, mockup `5a`: `Qu'est-ce que vous faites ?` — five cards, one
  /// `OcptBudgetEntryNature` each.
  nature,

  /// Step 2, mockup `5b`: the form, reduced to the one link field [nature] picks.
  form,
}

/// The dialog that both **creates and edits** a cash-journal entry, and, since this milestone, asks
/// in two steps rather than one form (mockups `5a`/`5b`) — `docs/architecture/budget.md` argues the
/// single-shape-for-both decision this class still carries out; this doc comment argues the wizard
/// itself, since that document's own capture-band section describes what died to make room for it.
///
/// **The class name, the file and [show]'s own shape are unchanged.** Every call site already goes
/// through [show]; only what happens between opening and closing it is new. The two steps are
/// private widgets of this file, switched on `_OcptBudgetEntryDialogState._step`.
///
/// ## When step 1 is shown, and when it is skipped
///
/// **Step 1 is shown whenever only the nature of the movement is known, and skipped whenever the
/// nature *and* its one link are both already known.** The moment a user is still deciding what
/// they are doing is exactly the moment step 1 earns its place; the moment they have already
/// pointed at the thing being settled, it would only be a screen to click past:
///
/// - Editing [existing] always opens step 2 directly, its nature **inferred** from whichever of
///   its own four link fields is set (none set reads as [OcptBudgetEntryNature.other] — the one
///   nature built for an entry naming nothing).
/// - A [prefill] naming a poste, a resource, a taking or a participant does the same: settling a
///   commitment, recording a receipt against a named resource or a named taking, paying a named
///   participant from that participant's own `⋮` menu all already know both.
/// - [initialNature] alone, no link named — a working surface's own header button, or the sharing
///   page's own `Verser une part` button pre-answering `payout` with no participant chosen yet —
///   opens step 1 with that card already selected, so `Continuer` is one click and any other answer
///   is one click away.
/// - Neither [existing], a linking [prefill] nor [initialNature]: step 1 opens with nothing
///   selected, `Continuer` withheld until a card is picked.
///
/// **The header's own `changer` link and step 2's own `Retour` both return to step 1 unconditionally
/// — even when it was skipped on the way in.** A user reconsidering what an edit actually is must
/// be able to say so; there is no third "back to the form without reconsidering" button, mirroring
/// the mockup's own two-button step 1 exactly. Picking a different nature there and pressing
/// `Continuer` again applies that nature's own fixed direction (see
/// [ocptBudgetEntryNatureDirectionOf]) to the movement; every one of the four link fields keeps
/// whatever it already held, so switching nature and switching back loses nothing.
///
/// ## The reconciliation strip
///
/// `ocptBudgetMatchSuggestionsOf` moved here from the capture band, offered on step 2 **only while
/// creating** ([existing] null) — mirroring the band, which only ever created. There is no event
/// that both updates an existing entry and settles a commitment as one write, so editing draws no
/// strip at all. The gate mirrors the band's own `_saveableDraft`: a positive amount and a
/// non-blank label, the very two things `Save` itself already requires, so accepting a suggestion
/// never produces an entry the very same click would have refused to save. Unlike the band, only
/// the single best-ranked suggestion is ever drawn — the mockup draws one strip, not an expander
/// over three.
///
/// `C'est ça` pops [show]'s own future with the accepted suggestion attached
/// (`OcptBudgetEntryWizardResult.acceptedSuggestion`) rather than turning it into a domain write
/// itself — see that class's own doc comment for why, and `budget_mode.dart`'s own handler for the
/// mapping this carries over unchanged.
///
/// Structured after `OcptProjectVersionCreateDialog`, exactly as before this milestone: a [Form]
/// validating the label before `Save` is honoured, an `AlertDialog`. `Date` is
/// `OcptPersonSheetDateField`; `Amount` is read through [ocptCostCentsOf]; the tax-inclusive choice
/// reuses [OcptBudgetBinaryChoice], as does the direction choice while [OcptBudgetEntryNature.other]
/// draws one at all.
///
/// **`Voucher number` only exists on an edit**, unchanged: creating an entry offers a muted line
/// instead, since `OcptBudgetJournalService.createEntry` mints one itself. **`Receipt` is offered on
/// both**, unchanged — see `OcptBudgetEntryFormFields.pickedReceiptPath`'s own doc comment for why
/// this dialog picks the file directly rather than through a bloc event.
class OcptBudgetEntryDialog extends StatefulWidget {
  /// The entry being edited, or null while creating a new one.
  final OcptBudgetEntry? existing;

  /// Seeds a fresh entry's own fields while [existing] is null. Naming a poste, a resource, a
  /// taking or a participant skips step 1 straight to step 2 — see the class doc comment.
  final OcptBudgetEntryFormFields? prefill;

  /// The nature step 1 opens with already selected, read only while [existing] is null and
  /// [prefill] names none of its own four links — see the class doc comment. Null draws step 1
  /// with nothing picked.
  final OcptBudgetEntryNature? initialNature;

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

  /// Every live commitment still owed, read only to rank and word the reconciliation strip's own
  /// suggestions against a debit — see [ocptBudgetMatchSuggestionsOf].
  final List<OcptBudgetCommitment> commitments;

  /// Every live defrayal, read only for the same reason.
  final List<OcptBudgetAllowance> allowances;

  /// What each financing resource has already received, keyed by its own id — read only for the
  /// same reason, against a credit.
  final Map<String, OcptBudgetCoveredTotal> receivedByResourceId;

  /// What each taking has already received, keyed by its own id — read only for the same reason.
  final Map<String, OcptBudgetCoveredTotal> receivedByRevenueId;

  /// The project's currency, an ISO 4217 code, shown beside the `Montant` field.
  final String currencyCode;

  /// The project's default VAT rate, in basis points, or null — what the `TVA` field's own hint
  /// reads while it is left empty, and what [ocptBudgetMatchSuggestionsOf] reads a commitment
  /// candidate's cash figure against.
  final int? defaultVatRateBasisPoints;

  /// Whether the mode's header currently reads simplified — read by [OcptBudgetEntryNature.other]'s
  /// own direction choice and by the `Poste du devis` field's own poste labels.
  final bool isSimplified;

  /// Class constructor
  const OcptBudgetEntryDialog({
    super.key,
    required this.existing,
    this.prefill,
    this.initialNature,
    this.existingReceipt,
    required this.postes,
    required this.resources,
    this.revenues = const [],
    this.shares = const [],
    this.commitments = const [],
    this.allowances = const [],
    this.receivedByResourceId = const {},
    this.receivedByRevenueId = const {},
    required this.currencyCode,
    required this.defaultVatRateBasisPoints,
    required this.isSimplified,
  });

  /// Shows the dialog and returns what the user confirmed, or null if they cancelled it — see
  /// [OcptBudgetEntryWizardResult]'s own doc comment for what a reconciliation acceptance adds to
  /// it.
  static Future<OcptBudgetEntryWizardResult?> show(
    BuildContext context, {
    required OcptBudgetEntry? existing,
    OcptBudgetEntryFormFields? prefill,
    OcptBudgetEntryNature? initialNature,
    OcptAssetRef? existingReceipt,
    required List<OcptBudgetPoste> postes,
    required List<OcptBudgetResource> resources,
    List<OcptBudgetRevenue> revenues = const [],
    List<OcptBudgetShare> shares = const [],
    List<OcptBudgetCommitment> commitments = const [],
    List<OcptBudgetAllowance> allowances = const [],
    Map<String, OcptBudgetCoveredTotal> receivedByResourceId = const {},
    Map<String, OcptBudgetCoveredTotal> receivedByRevenueId = const {},
    required String currencyCode,
    required int? defaultVatRateBasisPoints,
    required bool isSimplified,
  }) => showDialog<OcptBudgetEntryWizardResult>(
    context: context,
    builder: (context) => OcptBudgetEntryDialog(
      existing: existing,
      prefill: prefill,
      initialNature: initialNature,
      existingReceipt: existingReceipt,
      postes: postes,
      resources: resources,
      revenues: revenues,
      shares: shares,
      commitments: commitments,
      allowances: allowances,
      receivedByResourceId: receivedByResourceId,
      receivedByRevenueId: receivedByRevenueId,
      currencyCode: currencyCode,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      isSimplified: isSimplified,
    ),
  );

  @override
  State<OcptBudgetEntryDialog> createState() => _OcptBudgetEntryDialogState();
}

/// The `Recette` picker's own value standing for the taking `New taking…` has just collected but
/// nothing has created yet — unchanged from before this milestone.
const String _ocptNewRevenuePickedValue = "#new-revenue";

/// The `Recette` picker's own value standing for the `New taking…` action itself.
const String _ocptNewRevenueActionValue = "#new-revenue-action";

/// The state of [OcptBudgetEntryDialog]: the draft — one continuous set of controllers and fields
/// spanning both steps — and which step is currently drawn.
class _OcptBudgetEntryDialogState extends State<OcptBudgetEntryDialog> {
  /// The form validating the label field before `Save` is honoured.
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

  /// The poste currently picked, or null.
  String? _posteId;

  /// The financing resource currently picked, or null.
  String? _resourceId;

  /// The taking currently picked, or null.
  String? _revenueId;

  /// The share currently picked, or null.
  String? _shareId;

  /// The taking the `New taking…` entry just collected, waiting to be created along with this
  /// movement, or null — see [OcptBudgetEntryFormFields.newRevenue].
  OcptBudgetRevenueFormFields? _newRevenue;

  /// Whether the direction currently picked is a debit. Only ever changed through step 1's own
  /// nature choice (for the four fixed natures) or, for [OcptBudgetEntryNature.other], through
  /// step 2's own direction choice.
  late bool _isDebit;

  /// Whether the amount currently picked includes tax.
  late bool _isTaxInclusive;

  /// The path of a voucher file just picked through the native selector this dialog session, or
  /// null.
  String? _pickedReceiptPath;

  /// Whether the `Detach` action was used on the voucher already referenced.
  bool _isReceiptDetached = false;

  /// Which of the wizard's two screens is currently drawn.
  late _OcptBudgetEntryWizardStep _step;

  /// The nature currently selected on step 1, or in effect on step 2 — null only while step 1 is
  /// on screen and nothing has been picked yet.
  OcptBudgetEntryNature? _nature;

  /// The path currently shown for the `Justificatif` field — unchanged from before this milestone.
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
    _revenueId = existing?.revenueId ?? prefill?.revenueId;
    _shareId = existing?.shareId ?? prefill?.shareId;
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

    if (existing != null || _hasLink(_posteId, _resourceId, _revenueId, _shareId)) {
      _nature = _natureOfLinks(
        posteId: _posteId,
        resourceId: _resourceId,
        revenueId: _revenueId,
        shareId: _shareId,
      );
      _step = _OcptBudgetEntryWizardStep.form;
    } else {
      _nature = widget.initialNature;
      _step = _OcptBudgetEntryWizardStep.nature;
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

  /// Whether any of the four link fields names something — [initState]'s own gate for skipping
  /// step 1.
  bool _hasLink(String? posteId, String? resourceId, String? revenueId, String? shareId) =>
      posteId != null || resourceId != null || revenueId != null || shareId != null;

  /// The nature implied by which of the four link fields is set — [OcptBudgetEntryNature.other]
  /// while none is, exactly the nature built for that case. An entry never attaches to more than
  /// one of the four, so the order below only matters defensively.
  OcptBudgetEntryNature _natureOfLinks({
    required String? posteId,
    required String? resourceId,
    required String? revenueId,
    required String? shareId,
  }) {
    if (resourceId != null) {
      return OcptBudgetEntryNature.financing;
    }
    if (revenueId != null) {
      return OcptBudgetEntryNature.revenue;
    }
    if (shareId != null) {
      return OcptBudgetEntryNature.payout;
    }
    if (posteId != null) {
      return OcptBudgetEntryNature.expense;
    }
    return OcptBudgetEntryNature.other;
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: _buildTitle(context, tr),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: _step == _OcptBudgetEntryWizardStep.nature
              ? _buildNatureStep(context, tr)
              : _buildFormStep(context, tr),
        ),
      ),
      actions: _step == _OcptBudgetEntryWizardStep.nature
          ? _buildNatureActions(tr)
          : _buildFormActions(tr),
    );
  }

  /// The dialog's own title area: the create/edit title and `Étape X sur 2` on one row, and, on
  /// step 2 alone, the recalled nature with its own `changer` link underneath — mockup `5b`'s own
  /// header.
  Widget _buildTitle(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final stepNumber = _step == _OcptBudgetEntryWizardStep.nature ? 1 : 2;

    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(isEditing ? tr.budgetEntryDialogEditTitle : tr.budgetEntryDialogCreateTitle),
          ),
          Text(
            tr.budgetEntryWizardStepLabel(stepNumber),
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ];

    final nature = _nature;
    if (_step == _OcptBudgetEntryWizardStep.form && nature != null) {
      children.add(const SizedBox(height: 4));
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _ocptBudgetEntryNatureLabelOf(tr, nature),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            Text(
              " · ",
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            InkWell(
              key: const Key("ocptBudgetEntryWizardChangeNatureLink"),
              onTap: _handleBackToNature,
              mouseCursor: ocptClickableCursor,
              child: Text(
                tr.budgetEntryWizardChangeNatureAction,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  // ---------------------------------------------------------------------------------------------
  // Step 1 — mockup `5a`
  // ---------------------------------------------------------------------------------------------

  /// Step 1's own content: the five nature cards, one selected at most.
  Widget _buildNatureStep(BuildContext context, Tr tr) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final nature in OcptBudgetEntryNature.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _OcptBudgetEntryNatureCard(
            nature: nature,
            isSelected: _nature == nature,
            onSelected: () => setState(() => _nature = nature),
          ),
        ),
    ],
  );

  /// Step 1's own actions: `Annuler` closes the whole dialog; `Continuer` is withheld until a card
  /// is picked, and applies that nature's own fixed direction before moving to step 2.
  List<Widget> _buildNatureActions(Tr tr) => [
    TextButton(
      key: const Key("ocptBudgetEntryWizardCancelButton"),
      onPressed: _handleCancel,
      child: Text(tr.budgetEntryDialogCancelAction),
    ),
    FilledButton(
      key: const Key("ocptBudgetEntryWizardContinueButton"),
      onPressed: _nature == null ? null : _handleContinue,
      child: Text(tr.budgetEntryWizardContinueAction),
    ),
  ];

  /// `Annuler`: closes the dialog with nothing — the wizard's only escape hatch, mirroring the
  /// mockup's own two-button step 1 exactly (see the class doc comment for why there is no third
  /// "back to the form" button).
  void _handleCancel() => globalGetIt().get<OcptRouterManager>().pop();

  /// `Continuer`: applies [_nature]'s own fixed direction, if it has one, then moves to step 2.
  /// [OcptBudgetEntryNature.other] leaves [_isDebit] exactly as it was — its own direction is
  /// asked in step 2 instead.
  void _handleContinue() {
    final nature = _nature;
    if (nature == null) {
      return;
    }
    final fixedDirection = ocptBudgetEntryNatureDirectionOf(nature);
    setState(() {
      if (fixedDirection != null) {
        _isDebit = fixedDirection;
      }
      _step = _OcptBudgetEntryWizardStep.form;
    });
  }

  /// The header's own `changer` link and step 2's own `Retour` both call this: back to step 1,
  /// [_nature] left exactly as it is so the very same card starts selected.
  void _handleBackToNature() => setState(() => _step = _OcptBudgetEntryWizardStep.nature);

  // ---------------------------------------------------------------------------------------------
  // Step 2 — mockup `5b`
  // ---------------------------------------------------------------------------------------------

  /// Step 2's own content, in the mockup's own order: `Date`/`Montant`/`Base`, `Intitulé`, the one
  /// link field [_nature] picks, the reconciliation strip, `TVA`/`Justificatif`, the voucher area.
  Widget _buildFormStep(BuildContext context, Tr tr) {
    final currencySymbol = NumberFormat.simpleCurrency(name: widget.currencyCode).currencySymbol;
    final reconciliationStrip = _buildReconciliationStrip(context, tr);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateAmountBasisRow(tr, currencySymbol),
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
        _buildLinkField(context, tr),
        if (reconciliationStrip != null) ...[const SizedBox(height: 12), reconciliationStrip],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildVatField(tr)),
            const SizedBox(width: 12),
            Expanded(child: _buildReceiptField(context, tr, Theme.of(context))),
          ],
        ),
        const SizedBox(height: 12),
        _buildVoucherArea(context, tr, Theme.of(context)),
        if (_nature == OcptBudgetEntryNature.other) ...[
          const SizedBox(height: 12),
          _buildDirectionField(context, tr),
        ],
      ],
    );
  }

  /// Step 2's own actions: `Retour` returns to step 1 (see [_handleBackToNature]), `Enregistrer`
  /// validates and pops with the typed fields.
  List<Widget> _buildFormActions(Tr tr) => [
    TextButton(
      key: const Key("ocptBudgetEntryWizardBackButton"),
      onPressed: _handleBackToNature,
      child: Text(tr.budgetEntryDialogBackAction),
    ),
    FilledButton(
      key: const Key("ocptBudgetEntryWizardSaveButton"),
      onPressed: _submit,
      child: Text(tr.budgetEntryDialogConfirmAction),
    ),
  ];

  /// `Date`, `Montant` and `Base` on one row, mockup `5b`'s own top row.
  Widget _buildDateAmountBasisRow(Tr tr, String currencySymbol) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: OcptPersonSheetDateField(
          label: tr.budgetEntryDialogDateFieldLabel,
          value: _date,
          onChanged: (value) => setState(() => _date = value ?? _date),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: TextFormField(
          key: const Key("ocptBudgetEntryWizardAmountField"),
          controller: _amountController,
          decoration: InputDecoration(
            labelText: tr.budgetEntryDialogAmountFieldLabel,
            suffixText: currencySymbol,
          ),
          validator: (value) =>
              ocptCostCentsOf(value ?? "") == null ? tr.budgetEntryDialogAmountInvalidError : null,
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(width: 12),
      _buildTaxBasisField(context, tr),
    ],
  );

  /// `Base`: the tax-inclusive/exclusive choice, labelled the way every other bare control of this
  /// dialog already is.
  ///
  /// **Wrapped in [IntrinsicWidth]**, mirroring the capture band's own reasoning for its direction
  /// choice: [OcptBudgetBinaryChoice]'s own `Row` reads `MainAxisSize.max`, which would otherwise
  /// claim the whole width the outer `Row` offers a non-flexible child before `Date` and `Montant`
  /// (both `Expanded`) are even sized — a fixed pixel width was tried first and overflowed the
  /// moment the English wording ("Tax included"/"Tax excluded") ran longer than the French
  /// ("TTC"/"HT") the mockup drew.
  Widget _buildTaxBasisField(BuildContext context, Tr tr) => IntrinsicWidth(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.budgetEntryDialogTaxBasisFieldLabel.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        OcptBudgetBinaryChoice(
          value: _isTaxInclusive,
          trueLabel: tr.budgetLineTaxInclusiveOption,
          falseLabel: tr.budgetLineTaxExclusiveOption,
          onChanged: (value) => setState(() => _isTaxInclusive = value),
        ),
      ],
    ),
  );

  /// [OcptBudgetEntryNature.other]'s own direction choice — the one nature that still asks it, in
  /// step 2, at the very bottom of the form: see the class doc comment.
  Widget _buildDirectionField(BuildContext context, Tr tr) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr.budgetEntryDialogDirectionFieldLabel.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 4),
      OcptBudgetBinaryChoice(
        value: _isDebit,
        trueLabel: widget.isSimplified ? tr.budgetEntryDialogPaidOption : tr.budgetEntryDialogDebitOption,
        falseLabel: widget.isSimplified
            ? tr.budgetEntryDialogReceivedOption
            : tr.budgetEntryDialogCreditOption,
        onChanged: (value) => setState(() => _isDebit = value),
      ),
    ],
  );

  /// The one link field [_nature] picks — [OcptBudgetEntryLinkKind] says which.
  Widget _buildLinkField(BuildContext context, Tr tr) =>
      switch (ocptBudgetEntryNatureLinkKindOf(_nature ?? OcptBudgetEntryNature.other)) {
        OcptBudgetEntryLinkKind.poste => _buildPosteField(context, tr),
        OcptBudgetEntryLinkKind.financingResource => _buildResourceField(tr),
        OcptBudgetEntryLinkKind.taking => _buildRevenueField(context, tr),
        OcptBudgetEntryLinkKind.participant => _buildShareField(tr),
      };

  /// `Poste du devis` — offered under [OcptBudgetEntryNature.expense] and
  /// [OcptBudgetEntryNature.other] alike. **Its own "unanswered" item reads `Hors devis`, never a
  /// generic "no poste"** (settled 25 August, not to be re-decided): the very same label the
  /// expenses table draws for the very same synthetic row, so a reader who leaves this field blank
  /// sees, in the field itself, exactly where the entry will land.
  Widget _buildPosteField(BuildContext context, Tr tr) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<String?>(
        key: const Key("ocptBudgetEntryWizardPosteField"),
        initialValue: _posteId,
        decoration: InputDecoration(labelText: tr.budgetEntryDialogPosteFieldLabel),
        items: [
          DropdownMenuItem(child: Text(tr.budgetCostTrackingOffQuoteLabel)),
          for (final poste in widget.postes)
            DropdownMenuItem(
              value: poste.id,
              child: Text(ocptBudgetPosteDisplayLabel(poste, isSimplified: widget.isSimplified)),
            ),
        ],
        onChanged: (value) => setState(() => _posteId = value),
      ),
      const SizedBox(height: 4),
      Text(
        tr.budgetEntryWizardPosteFieldHint(tr.budgetCostTrackingOffQuoteLabel),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );

  /// `Ressource` — offered under [OcptBudgetEntryNature.financing] alone.
  Widget _buildResourceField(Tr tr) => DropdownButtonFormField<String?>(
    key: const Key("ocptBudgetEntryWizardResourceField"),
    initialValue: _resourceId,
    decoration: InputDecoration(labelText: tr.budgetEntryDialogResourceFieldLabel),
    items: [
      DropdownMenuItem(child: Text(tr.budgetEntryDialogNoResourceLabel)),
      for (final resource in widget.resources)
        DropdownMenuItem(value: resource.id, child: Text(resource.label)),
    ],
    onChanged: (value) => setState(() => _resourceId = value),
  );

  /// `Recette` — offered under [OcptBudgetEntryNature.revenue] alone. Carries the `New taking…`
  /// entry unchanged from before this milestone: see [_onRevenuePicked].
  Widget _buildRevenueField(BuildContext context, Tr tr) => DropdownButtonFormField<String?>(
    key: ValueKey("ocptBudgetEntryWizardRevenueField/$_revenueId/${_newRevenue?.label}"),
    initialValue: _revenueId,
    decoration: InputDecoration(labelText: tr.budgetEntryDialogRevenueFieldLabel),
    isExpanded: true,
    items: [
      DropdownMenuItem(child: Text(tr.budgetEntryDialogNoRevenueLabel)),
      for (final revenue in widget.revenues)
        DropdownMenuItem(
          value: revenue.id,
          child: Text(revenue.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      if (_newRevenue case final newRevenue?)
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
    onChanged: _onRevenuePicked,
  );

  /// `Participant` — offered under [OcptBudgetEntryNature.payout] alone.
  Widget _buildShareField(Tr tr) => DropdownButtonFormField<String?>(
    key: const Key("ocptBudgetEntryWizardShareField"),
    initialValue: _shareId,
    decoration: InputDecoration(labelText: tr.budgetEntryDialogShareFieldLabel),
    items: [
      DropdownMenuItem(child: Text(tr.budgetEntryDialogNoShareLabel)),
      for (final share in widget.shares) DropdownMenuItem(value: share.id, child: Text(share.label)),
    ],
    onChanged: (value) => setState(() => _shareId = value),
  );

  /// Applies the `Recette` picker's own choice — unchanged from before this milestone.
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

  /// `TVA` — unchanged from before this milestone.
  Widget _buildVatField(Tr tr) {
    final defaultVatRateBasisPoints = widget.defaultVatRateBasisPoints;
    final vatRateHint = defaultVatRateBasisPoints == null
        ? null
        : tr.budgetLineVatRateInheritedHint(ocptVatRatePercentTextOf(defaultVatRateBasisPoints));

    return TextFormField(
      controller: _vatRateController,
      decoration: InputDecoration(
        labelText: tr.budgetLineVatRateFieldLabel,
        hintText: vatRateHint,
        suffixText: tr.budgetLineVatRateSuffix,
      ),
    );
  }

  /// `Justificatif` — unchanged from before this milestone.
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

  /// Shows the native "open" dialog — unchanged from before this milestone.
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

  /// The voucher area: editable while editing an existing entry, a muted informational line while
  /// creating a new one — the muted line mockup `5b` draws at the very bottom of the form,
  /// unchanged from before this milestone.
  Widget _buildVoucherArea(BuildContext context, Tr tr, ThemeData theme) {
    final voucherController = _voucherController;
    if (voucherController != null) {
      return TextFormField(
        controller: voucherController,
        decoration: InputDecoration(labelText: tr.budgetEntryDialogVoucherFieldLabel),
      );
    }

    return Text(
      tr.budgetEntryDialogVoucherAutoHint,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  // ---------------------------------------------------------------------------------------------
  // The reconciliation strip
  // ---------------------------------------------------------------------------------------------

  /// What is currently typed, once it reads as saveable, or null while it does not — the same two
  /// fields `Save` itself requires, and null outright while [OcptBudgetEntryDialog.existing] is not
  /// null: see the class doc comment for why editing draws no strip at all.
  ({int amountCents, String wording})? get _saveableDraft {
    if (widget.existing != null) {
      return null;
    }
    final amountCents = ocptCostCentsOf(_amountController.text);
    final wording = _labelController.text.trim();
    if (amountCents == null || amountCents <= 0 || wording.isEmpty) {
      return null;
    }
    return (amountCents: amountCents, wording: wording);
  }

  /// [ocptBudgetMatchSuggestionsOf]'s own answer to the draft currently typed, or the empty list
  /// while [_saveableDraft] answers null.
  List<OcptBudgetMatchSuggestion> _suggestionsOf() {
    final draft = _saveableDraft;
    if (draft == null) {
      return const [];
    }

    return ocptBudgetMatchSuggestionsOf(
      isDebit: _isDebit,
      draftAmountCents: draft.amountCents,
      draftDate: _date,
      draftWording: draft.wording,
      commitments: widget.commitments,
      allowances: widget.allowances,
      resources: widget.resources,
      revenues: widget.revenues,
      receivedByResourceId: widget.receivedByResourceId,
      receivedByRevenueId: widget.receivedByRevenueId,
      projectVatRateBasisPoints: widget.defaultVatRateBasisPoints,
    );
  }

  /// The reconciliation strip itself, or null while [_suggestionsOf] found nothing worth offering —
  /// a tinted row carrying a kind badge, one sentence naming the match, and `C'est ça`.
  Widget? _buildReconciliationStrip(BuildContext context, Tr tr) {
    final suggestions = _suggestionsOf();
    if (suggestions.isEmpty) {
      return null;
    }

    final first = suggestions.first;
    return _OcptBudgetEntryWizardMatchStrip(
      badge: _badgeOf(tr, first.kind),
      sentence: _headlineOf(context, tr, first),
      acceptLabel: tr.budgetCaptureBandAcceptAction,
      onAccept: () => _handleAcceptSuggestion(first),
    );
  }

  /// [kind]'s own small badge word — the mockup's own `Engagé` pill, one per
  /// [OcptBudgetMatchCandidateKind].
  String _badgeOf(Tr tr, OcptBudgetMatchCandidateKind kind) => switch (kind) {
    OcptBudgetMatchCandidateKind.commitment => tr.budgetEntryWizardMatchBadgeCommitment,
    OcptBudgetMatchCandidateKind.defrayal => tr.budgetEntryWizardMatchBadgeDefrayal,
    OcptBudgetMatchCandidateKind.resource => tr.budgetEntryWizardMatchBadgeResource,
    OcptBudgetMatchCandidateKind.revenue => tr.budgetEntryWizardMatchBadgeRevenue,
  };

  /// [suggestion]'s own headline, per its [OcptBudgetMatchSuggestion.kind] — ported from the
  /// capture band's own `_headlineOf` verbatim: this widget words the suggestion, never the pure
  /// util, exactly as that class's own doc comment argued.
  String _headlineOf(BuildContext context, Tr tr, OcptBudgetMatchSuggestion suggestion) {
    final currencyCode = widget.currencyCode;

    switch (suggestion.kind) {
      case OcptBudgetMatchCandidateKind.commitment:
        final amountLabel = suggestion.outstandingCents == null
            ? ""
            : ocptBudgetAmountLabel(suggestion.outstandingCents!, currencyCode);
        final posteLabel = _commitmentPosteLabelOf(tr, suggestion);
        final date = suggestion.date;
        if (date == null) {
          return tr.budgetCaptureBandCommitmentHeadlineUndated(suggestion.label, amountLabel, posteLabel);
        }
        return tr.budgetCaptureBandCommitmentHeadlineDated(
          suggestion.label,
          amountLabel,
          posteLabel,
          DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date),
        );

      case OcptBudgetMatchCandidateKind.resource:
        return tr.budgetCaptureBandResourceHeadline(
          suggestion.label,
          ocptBudgetAmountLabel(suggestion.amountCents ?? 0, currencyCode),
          ocptBudgetAmountLabel(_receivedCentsOf(suggestion), currencyCode),
          ocptBudgetAmountLabel(suggestion.outstandingCents ?? 0, currencyCode),
        );

      case OcptBudgetMatchCandidateKind.revenue:
        return tr.budgetCaptureBandRevenueHeadline(
          suggestion.label,
          ocptBudgetAmountLabel(suggestion.amountCents ?? 0, currencyCode),
          ocptBudgetAmountLabel(_receivedCentsOf(suggestion), currencyCode),
          ocptBudgetAmountLabel(suggestion.outstandingCents ?? 0, currencyCode),
        );

      case OcptBudgetMatchCandidateKind.defrayal:
        return tr.budgetCaptureBandDefrayalHeadline(
          suggestion.label,
          ocptBudgetAmountLabel(suggestion.amountCents ?? 0, currencyCode),
        );
    }
  }

  /// What has already come in against [suggestion] — ported from the capture band's own
  /// `_receivedCentsOf` verbatim.
  int _receivedCentsOf(OcptBudgetMatchSuggestion suggestion) =>
      (suggestion.amountCents ?? 0) - (suggestion.outstandingCents ?? 0);

  /// The name of the poste a commitment suggestion is quoted against — ported from the capture
  /// band's own `_commitmentPosteLabelOf` verbatim.
  String _commitmentPosteLabelOf(Tr tr, OcptBudgetMatchSuggestion suggestion) {
    final commitment = widget.commitments
        .where((candidate) => candidate.id == suggestion.candidateId)
        .firstOrNull;
    final poste = widget.postes.where((poste) => poste.id == commitment?.posteId).firstOrNull;
    final label = poste?.label ?? "";
    final code = poste?.code ?? "";
    if (label.isEmpty) {
      return code.isEmpty ? tr.budgetPosteUnnamed : code;
    }
    return code.isEmpty ? label : "$code $label";
  }

  /// `C'est ça`: pops [OcptBudgetEntryDialog.show]'s own future with the plain draft and
  /// [suggestion] attached — see [OcptBudgetEntryWizardResult]'s own doc comment for why the
  /// enrichment itself happens in `budget_mode.dart` rather than here. The draft carries none of
  /// the four link fields, [OcptBudgetEntryDialog]'s own tax defaults and no VAT override,
  /// mirroring the capture band's own `_draftFieldsOrNull` exactly: naming the matched row is the
  /// caller's job, not this dialog's.
  void _handleAcceptSuggestion(OcptBudgetMatchSuggestion suggestion) {
    final draft = _saveableDraft;
    if (draft == null) {
      return;
    }

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetEntryWizardResult>(
      OcptBudgetEntryWizardResult(
        fields: OcptBudgetEntryFormFields(
          date: _date,
          label: draft.wording,
          posteId: null,
          resourceId: null,
          revenueId: null,
          shareId: null,
          isDebit: _isDebit,
          amountCents: draft.amountCents,
          isTaxInclusive: true,
          vatRateBasisPoints: null,
          voucherNumber: null,
          pickedReceiptPath: null,
          isReceiptDetached: false,
        ),
        acceptedSuggestion: suggestion,
      ),
    );
  }

  /// `Enregistrer`: validates the form and, if it passes, pops with every field collected — the
  /// suggestion, if the strip offered one and it was ignored, is simply not attached.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amountCents = ocptCostCentsOf(_amountController.text);
    if (amountCents == null) {
      return;
    }

    final voucherController = _voucherController;

    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetEntryWizardResult>(
      OcptBudgetEntryWizardResult(
        fields: OcptBudgetEntryFormFields(
          date: _date,
          label: _labelController.text.trim(),
          posteId: _posteId,
          resourceId: _resourceId,
          // The sentinel never leaves this dialog: a taking still to be created travels as
          // `newRevenue`, and the bloc writes its fresh id where this would have gone.
          revenueId: _revenueId == _ocptNewRevenuePickedValue ? null : _revenueId,
          newRevenue: _newRevenue,
          shareId: _shareId,
          isDebit: _isDebit,
          amountCents: amountCents,
          isTaxInclusive: _isTaxInclusive,
          vatRateBasisPoints: ocptVatRateBasisPointsOf(_vatRateController.text),
          voucherNumber: voucherController?.text.trim(),
          pickedReceiptPath: _pickedReceiptPath,
          isReceiptDetached: _isReceiptDetached,
        ),
        acceptedSuggestion: null,
      ),
    );
  }
}

/// [nature]'s own recalled label — the very same word its step 1 card reads in bold, factored out
/// so the title area's own `changer` line and the card itself never drift apart.
String _ocptBudgetEntryNatureLabelOf(Tr tr, OcptBudgetEntryNature nature) => switch (nature) {
  OcptBudgetEntryNature.expense => tr.budgetEntryNatureExpenseLabel,
  OcptBudgetEntryNature.financing => tr.budgetEntryNatureFinancingLabel,
  OcptBudgetEntryNature.revenue => tr.budgetEntryNatureRevenueLabel,
  OcptBudgetEntryNature.payout => tr.budgetEntryNaturePayoutLabel,
  OcptBudgetEntryNature.other => tr.budgetEntryNatureOtherLabel,
};

/// [nature]'s own muted hint — the sentence under its bold label on step 1's own card, naming its
/// fixed direction (or, for [OcptBudgetEntryNature.other], that there is none) and its one link.
String _ocptBudgetEntryNatureHintOf(Tr tr, OcptBudgetEntryNature nature) => switch (nature) {
  OcptBudgetEntryNature.expense => tr.budgetEntryNatureExpenseHint,
  OcptBudgetEntryNature.financing => tr.budgetEntryNatureFinancingHint,
  OcptBudgetEntryNature.revenue => tr.budgetEntryNatureRevenueHint,
  OcptBudgetEntryNature.payout => tr.budgetEntryNaturePayoutHint,
  OcptBudgetEntryNature.other => tr.budgetEntryNatureOtherHint(tr.budgetCostTrackingOffQuoteLabel),
};

/// One card of step 1 — a bold answer over its own muted hint, tinted `primary` while selected.
/// Mockup `5a`.
class _OcptBudgetEntryNatureCard extends StatelessWidget {
  /// The nature this card stands for.
  final OcptBudgetEntryNature nature;

  /// Whether this card is the one currently selected.
  final bool isSelected;

  /// Called when this card is tapped.
  final VoidCallback onSelected;

  /// Class constructor
  const _OcptBudgetEntryNatureCard({
    required this.nature,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      key: Key("ocptBudgetEntryNatureCard-${nature.name}"),
      onTap: onSelected,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusMedium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha) : null,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(ocptRadiusMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _ocptBudgetEntryNatureLabelOf(tr, nature),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _ocptBudgetEntryNatureHintOf(tr, nature),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reconciliation strip itself — a tinted row, mirroring the capture band's own suggestion row
/// with one addition: [badge], the kind pill mockup `5b` draws before the sentence.
class _OcptBudgetEntryWizardMatchStrip extends StatelessWidget {
  /// The matched candidate's own kind word — `Engagé`, `Financement`…
  final String badge;

  /// The sentence naming what this entry would settle.
  final String sentence;

  /// `C'est ça`'s own label.
  final String acceptLabel;

  /// Called when `C'est ça` is tapped.
  final VoidCallback onAccept;

  /// Class constructor
  const _OcptBudgetEntryWizardMatchStrip({
    required this.badge,
    required this.sentence,
    required this.acceptLabel,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(ocptRadiusSmall),
            ),
            child: Text(
              badge,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(sentence, style: theme.textTheme.bodySmall)),
          const SizedBox(width: 8),
          FilledButton(
            key: const Key("ocptBudgetEntryWizardAcceptButton"),
            onPressed: onAccept,
            child: Text(acceptLabel),
          ),
        ],
      ),
    );
  }
}
