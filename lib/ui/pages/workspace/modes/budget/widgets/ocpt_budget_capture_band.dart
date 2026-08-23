// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_match.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// The width the amount field is drawn at — the mode's own standing amount-column width
/// (`_ocptCostTrackingAmountColumnWidth` and its five siblings across the mode's own tables),
/// reused here for the very same figure.
const double _ocptBudgetCaptureBandAmountFieldWidth = 108;

/// The width the date field is drawn at in the wide layout, wide enough for a long localized date
/// (`1 September 2026`) without wrapping.
const double _ocptBudgetCaptureBandDateFieldWidth = 170;

/// The narrowest the fields row is drawn on one line — under this, the amount and the wording
/// share a first line and the date and `Save` share a second, mirroring `OcptBudgetHeader`'s own
/// `_ocptBudgetHeaderTitleMinWidth` idiom of falling back to a second line rather than clipping.
const double _ocptBudgetCaptureBandFieldsMinWidth = 760;

/// The budget mode's own capture band: the daily gesture the mode exists for — record what just
/// arrived, in one line, and let the app propose what it settles.
///
/// Mounted by `budget_mode.dart`'s own `_buildCentre`, between `OcptBudgetHeader` and the routed
/// widget, on `OcptBudgetDocument.expenses` and `OcptBudgetDocument.resources` alone, at their own
/// top level (`docs/plans/budget-mode-ux.md` §3, §4.3, §5 — M3). **Withheld whole, not disabled,**
/// under a previewed version: `budget_mode.dart` simply does not build it, the way every other
/// affordance without a live project to write to is withheld across the app.
///
/// **A `StatefulWidget` holding its own draft.** The amount, the wording, the date and the
/// direction typed here are transient UI state, never the bloc's: nothing here is a keystroke event
/// or a new state field, exactly the reasoning that already keeps `OcptBudgetEntryDialog`'s own
/// fields local to itself. The band never writes to the project — see the class's own three
/// callbacks below.
///
/// **The suggestion is recomputed live**, on every keystroke, by calling
/// [ocptBudgetMatchSuggestionsOf] — M1's own pure ranking rule, consumed here and never duplicated
/// — the moment the amount reads as a positive figure and the wording is non-blank. It is shown as
/// soon as those two are filled, not after a first save: waiting for `Save` would ask the user to
/// commit to an entry before ever seeing what it might settle.
///
/// **Wording the suggestion is this widget's job, not the util's** — `OcptBudgetHeader`'s own
/// `_buildAlertCard` is this mode's established precedent for the shape: a pure structure
/// ([OcptBudgetMatchSuggestion]) produced by a util, worded here with [Tr] and
/// [ocptBudgetAmountLabel]. `docs/plans/budget-mode-ux.md` §4.3 once phrased this the other way
/// round ("taking its suggestion as a resolved labels object so it never sees a `Tr`"); that
/// sentence is superseded by the alerts precedent, which is this mode's actual established shape
/// and which already respects the standing rule in full — no manager, service or util here ever
/// sees a `Tr`, [ocptBudgetMatchSuggestionsOf] included.
///
/// **What each answer does is entirely the caller's.** [onEntryCaptured], [onSuggestionAccepted]
/// and [onOtherRequested] each hand back the very same [OcptBudgetEntryFormFields] built from what
/// is currently typed — no poste, resource, revenue or share named, tax-inclusive, no VAT override,
/// exactly `OcptBudgetEntryDialog`'s own fresh-entry defaults — naming no domain object at all: the
/// mode is the one place with the state (the commitments, the postes) to decide, per
/// [OcptBudgetMatchSuggestion.kind], which event to dispatch and which fields to add to it (a
/// commitment's own `posteId`/tax basis, a resource's or revenue's own id, or, for a defrayal, its
/// own label in place of the draft's). This band only ever reports what was typed and, for
/// [onSuggestionAccepted], which candidate was picked.
///
/// **The band clears itself the moment any of the three is called** — every controller emptied,
/// the date back to today, the direction back to [initialIsDebit] — win or lose, exactly as a save
/// gesture with no queue behind it should: `docs/plans/budget-mode-ux.md` §3's own "nothing queues,
/// so nothing has to remember that it was queued."
class OcptBudgetCaptureBand extends StatefulWidget {
  /// The direction the band starts on, and returns to once it clears — `false` (a credit) on
  /// `OcptBudgetDocument.resources`, `true` (a debit) everywhere else the band is offered. The
  /// toggle itself stays reachable on both documents: a credit typed from expenses is simply a
  /// credit.
  final bool initialIsDebit;

  /// Every live commitment still owed, offered as a candidate against a debit — see
  /// [ocptBudgetMatchSuggestionsOf]'s own doc comment for the filter it applies. Also read here to
  /// resolve a commitment suggestion's own poste name.
  final List<OcptBudgetCommitment> commitments;

  /// Every live defrayal, offered as a candidate against a debit.
  final List<OcptBudgetAllowance> allowances;

  /// Every live financing resource, offered as a candidate against a credit.
  final List<OcptBudgetResource> resources;

  /// Every live taking, offered as a candidate against a credit.
  final List<OcptBudgetRevenue> revenues;

  /// What each financing resource has already received, keyed by its own id.
  final Map<String, OcptBudgetCoveredTotal> receivedByResourceId;

  /// What each taking has already received, keyed by its own id.
  final Map<String, OcptBudgetCoveredTotal> receivedByRevenueId;

  /// The project's own default VAT rate, in basis points, or null — what a commitment's cash figure
  /// is read against.
  final int? projectVatRateBasisPoints;

  /// Every live poste of the project, read only to resolve a commitment suggestion's own poste
  /// name.
  final List<OcptBudgetPoste> postes;

  /// The project's currency, an ISO 4217 code — the amount field's own `suffixText`, and every
  /// amount the suggestion's own wording states.
  final String currencyCode;

  /// Called with the typed fields when `Save` is pressed and the suggestion, if any, is ignored —
  /// an ordinary entry naming no poste, resource, revenue or share, which is already a legal state
  /// (`docs/architecture/budget.md`'s own reading of "off quote").
  final ValueChanged<OcptBudgetEntryFormFields>? onEntryCaptured;

  /// Called with the accepted [OcptBudgetMatchSuggestion] and the typed fields when `C'est ça` is
  /// pressed, on the first suggestion or on one of the discreet expander's own.
  final void Function(OcptBudgetMatchSuggestion suggestion, OcptBudgetEntryFormFields fields)?
  onSuggestionAccepted;

  /// Called with the typed fields when `Autre chose…` is pressed — the mode opens
  /// `OcptBudgetEntryDialog` prefilled with them.
  final ValueChanged<OcptBudgetEntryFormFields>? onOtherRequested;

  /// Class constructor
  const OcptBudgetCaptureBand({
    super.key,
    required this.initialIsDebit,
    required this.commitments,
    required this.allowances,
    required this.resources,
    required this.revenues,
    required this.receivedByResourceId,
    required this.receivedByRevenueId,
    required this.projectVatRateBasisPoints,
    required this.postes,
    required this.currencyCode,
    required this.onEntryCaptured,
    required this.onSuggestionAccepted,
    required this.onOtherRequested,
  });

  @override
  State<OcptBudgetCaptureBand> createState() => _OcptBudgetCaptureBandState();
}

/// The state of [OcptBudgetCaptureBand]: the draft itself, and the discreet expander's own state.
class _OcptBudgetCaptureBandState extends State<OcptBudgetCaptureBand> {
  /// The form validating the wording and the amount, mirroring `OcptBudgetEntryDialog`'s own.
  final _formKey = GlobalKey<FormState>();

  /// The controller of the amount field.
  final TextEditingController _amountController = TextEditingController();

  /// The controller of the wording field.
  final TextEditingController _wordingController = TextEditingController();

  /// The date currently picked — today while nothing else was picked.
  late DateTime _date;

  /// Whether the draft currently reads as a debit (money going out) or a credit (money coming in).
  late bool _isDebit;

  /// Whether the discreet expander offering the suggestions past the first is open.
  bool _isMoreExpanded = false;

  @override
  void initState() {
    super.initState();
    _isDebit = widget.initialIsDebit;
    _date = _today();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _wordingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final currencySymbol = NumberFormat.simpleCurrency(name: widget.currencyCode).currencySymbol;
    final suggestions = _suggestionsOf();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _ocptBudgetCaptureBandFieldsMinWidth;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTitleRow(tr, theme, isWide),
                  const SizedBox(height: 12),
                  _buildFieldsRow(tr, currencySymbol, isWide),
                  const SizedBox(height: 10),
                  _buildUnderBand(context, tr, theme, suggestions),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The title row: the band's own question on the left, the direction choice on the right —
  /// always worded plainly, never through `OcptBudgetBinaryChoice`'s `isSimplified` pair: this band
  /// **is** the plain-language gesture, so it does not vary with the header's own switch.
  ///
  /// Shares [_buildFieldsRow]'s own [isWide] threshold: under it, the direction choice moves under
  /// the title rather than beside it — not, on its own, something a centre pane this mode actually
  /// narrows to would ever need (`OcptBudgetHeader`'s own narrow case, a right dock open on an
  /// ordinary window, still leaves ample room for both side by side), but a free-standing safety
  /// net all the same, at no cost beyond reusing the very flag [_buildFieldsRow] already needs.
  Widget _buildTitleRow(Tr tr, ThemeData theme, bool isWide) {
    final title = Text(
      tr.budgetCaptureBandTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall,
    );
    // `IntrinsicWidth`, because `OcptBudgetBinaryChoice`'s own `Row` reads `MainAxisSize.max` —
    // every other call site sits inside a full-width `Column`, where that is exactly the wanted
    // behaviour; here, beside a title rather than alone on its own line, it would otherwise claim
    // the whole width the `Row` layout algorithm offers a non-flexible child before the sibling
    // title is even sized.
    final choice = IntrinsicWidth(
      child: OcptBudgetBinaryChoice(
        value: _isDebit,
        trueLabel: tr.budgetCaptureBandOutOption,
        falseLabel: tr.budgetCaptureBandInOption,
        onChanged: (value) => setState(() => _isDebit = value),
      ),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: 12),
          choice,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, const SizedBox(height: 8), choice],
    );
  }

  /// The fields row: amount, wording, date, `Save` — nothing else, per the class doc comment. Wide
  /// enough centre panes draw the four side by side; narrower ones (the right dock open on an
  /// ordinary window, mirroring `OcptBudgetHeader`'s own narrow case) fall back to two lines rather
  /// than clipping.
  Widget _buildFieldsRow(Tr tr, String currencySymbol, bool isWide) {
    final amountField = _buildAmountField(tr, currencySymbol);
    final wordingField = _buildWordingField(tr);
    final dateField = OcptPersonSheetDateField(
      label: tr.budgetEntryDialogDateFieldLabel,
      value: _date,
      onChanged: (value) => setState(() => _date = value ?? _date),
    );
    final saveButton = FilledButton(
      key: const Key("ocptBudgetCaptureBandSaveButton"),
      onPressed: _handleSave,
      child: Text(tr.budgetEntryDialogConfirmAction),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: _ocptBudgetCaptureBandAmountFieldWidth, child: amountField),
          const SizedBox(width: 12),
          Expanded(child: wordingField),
          const SizedBox(width: 12),
          SizedBox(width: _ocptBudgetCaptureBandDateFieldWidth, child: dateField),
          const SizedBox(width: 12),
          Padding(padding: const EdgeInsets.only(top: 4), child: saveButton),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: _ocptBudgetCaptureBandAmountFieldWidth, child: amountField),
            const SizedBox(width: 12),
            Expanded(child: wordingField),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: dateField),
            const SizedBox(width: 12),
            saveButton,
          ],
        ),
      ],
    );
  }

  /// The amount field — read through [ocptCostCentsOf], the currency shown as `suffixText`,
  /// exactly as `OcptBudgetEntryDialog`'s own amount field. Submitting through the keyboard is
  /// `Save`: the gesture this band exists for should never need a mouse.
  Widget _buildAmountField(Tr tr, String currencySymbol) => TextFormField(
    key: const Key("ocptBudgetCaptureBandAmountField"),
    controller: _amountController,
    decoration: InputDecoration(
      labelText: tr.budgetEntryDialogAmountFieldLabel,
      suffixText: currencySymbol,
    ),
    validator: (value) =>
        ocptCostCentsOf(value ?? "") == null ? tr.budgetEntryDialogAmountInvalidError : null,
    onChanged: (_) => setState(() {}),
    onFieldSubmitted: (_) => _handleSave(),
  );

  /// The wording field — the band's only free-text field, mirroring `OcptBudgetEntryDialog`'s own
  /// `Label`. Submitting through the keyboard is `Save`, mirroring the amount field.
  Widget _buildWordingField(Tr tr) => TextFormField(
    key: const Key("ocptBudgetCaptureBandWordingField"),
    controller: _wordingController,
    decoration: InputDecoration(labelText: tr.budgetEntryDialogLabelFieldLabel),
    validator: (value) =>
        (value ?? "").trim().isEmpty ? tr.budgetEntryDialogLabelRequiredError : null,
    onChanged: (_) => setState(() {}),
    onFieldSubmitted: (_) => _handleSave(),
  );

  /// The under-band row: the first suggestion (with the discreet expander past it, if
  /// [ocptBudgetMatchSuggestionsOf] found more than one), or the muted hint that there is nothing
  /// else to fill in here while none was found.
  Widget _buildUnderBand(
    BuildContext context,
    Tr tr,
    ThemeData theme,
    List<OcptBudgetMatchSuggestion> suggestions,
  ) {
    if (suggestions.isEmpty) {
      return Text(
        tr.budgetCaptureBandNoSuggestionHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final first = suggestions.first;
    final rest = suggestions.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OcptBudgetCaptureBandSuggestionRow(
          headline: _headlineOf(context, tr, first),
          why: _whyOf(tr, first),
          onAccept: () => _handleAccept(first),
          onOther: _handleOther,
          acceptKey: Key("ocptBudgetCaptureBandAcceptButton-${first.candidateId}"),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 6),
          _OcptBudgetCaptureBandMoreExpander(
            count: rest.length,
            isExpanded: _isMoreExpanded,
            onToggle: () => setState(() => _isMoreExpanded = !_isMoreExpanded),
          ),
          if (_isMoreExpanded)
            for (final suggestion in rest)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _OcptBudgetCaptureBandSuggestionRow(
                  headline: _headlineOf(context, tr, suggestion),
                  why: _whyOf(tr, suggestion),
                  onAccept: () => _handleAccept(suggestion),
                  onOther: null,
                  acceptKey: Key("ocptBudgetCaptureBandAcceptButton-${suggestion.candidateId}"),
                ),
              ),
        ],
      ],
    );
  }

  /// [suggestion]'s own headline, per its [OcptBudgetMatchSuggestion.kind] — see the class doc
  /// comment for why this widget, not [ocptBudgetMatchSuggestionsOf], words it.
  ///
  /// **The defrayal case is the one asymmetry**: every other kind's headline names the matched row
  /// and its own figures, leaving the entry's own wording to the draft; a defrayal carries no
  /// "paid" state at all (`ocptBudgetMatchSuggestionsOf`'s own doc comment — no `settledEntryId`,
  /// no link a `budget_entries` row could name), so its headline says plainly that accepting only
  /// records the movement under the defrayal's own wording, never that anything is being marked
  /// settled.
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
          return tr.budgetCaptureBandCommitmentHeadlineUndated(
            suggestion.label,
            amountLabel,
            posteLabel,
          );
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

  /// What has already come in against [suggestion] — its own full amount minus what is still
  /// outstanding, both of which [ocptBudgetMatchSuggestionsOf] always answers for a resource or a
  /// revenue.
  int _receivedCentsOf(OcptBudgetMatchSuggestion suggestion) =>
      (suggestion.amountCents ?? 0) - (suggestion.outstandingCents ?? 0);

  /// The name of the poste a commitment suggestion is quoted against — looked up through
  /// [OcptBudgetCaptureBand.commitments], since [OcptBudgetMatchSuggestion] itself carries no
  /// poste id of its own.
  ///
  /// **Read as the nomenclature writes it, `code` then `label`** — `5 Décors et costumes`, not
  /// `Décors et costumes` alone: the number is how a production actually names a poste out loud,
  /// and it is what the validated screen states. A poste carrying no code of its own falls back to
  /// its label alone, and one carrying neither to `budgetPosteUnnamed`, exactly as every other
  /// reading of a poste's own name in this mode does.
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

  /// [suggestion]'s own muted *why* line, one clause per true fact among
  /// [OcptBudgetMatchSuggestion.matchesAmount], [.matchesDate] and [.matchesWording] — always at
  /// least one, since [ocptBudgetMatchSuggestionsOf] drops a candidate agreeing with the draft on
  /// none of the three.
  String _whyOf(Tr tr, OcptBudgetMatchSuggestion suggestion) {
    final clauses = [
      if (suggestion.matchesAmount) tr.budgetCaptureBandWhyAmountClause,
      if (suggestion.matchesDate) tr.budgetCaptureBandWhyDateClause,
      if (suggestion.matchesWording) tr.budgetCaptureBandWhyWordingClause,
    ];
    if (clauses.isEmpty) {
      return "";
    }

    final joined = clauses.join(", ");
    return "${joined[0].toUpperCase()}${joined.substring(1)}.";
  }

  /// Today, at midnight — [_date]'s own starting value, and what it returns to once the band
  /// clears.
  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// The draft read back as [OcptBudgetEntryFormFields], or null while the amount does not read as
  /// a figure or the wording is blank — every field beyond date/label/direction/amount left at
  /// `OcptBudgetEntryDialog`'s own fresh-entry defaults (no poste, resource, revenue or share, tax
  /// inclusive, no VAT override): naming a domain object is the caller's job, not this band's, see
  /// the class doc comment.
  OcptBudgetEntryFormFields? _draftFieldsOrNull() {
    final amountCents = ocptCostCentsOf(_amountController.text);
    final label = _wordingController.text.trim();
    if (amountCents == null || label.isEmpty) {
      return null;
    }

    return OcptBudgetEntryFormFields(
      date: _date,
      label: label,
      posteId: null,
      resourceId: null,
      revenueId: null,
      shareId: null,
      isDebit: _isDebit,
      amountCents: amountCents,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: null,
      pickedReceiptPath: null,
      isReceiptDetached: false,
    );
  }

  /// [ocptBudgetMatchSuggestionsOf]'s own answer to the draft currently typed, or the empty list
  /// while the amount does not read as a positive figure or the wording is blank — the class doc
  /// comment's own gate.
  List<OcptBudgetMatchSuggestion> _suggestionsOf() {
    final amountCents = ocptCostCentsOf(_amountController.text);
    final wording = _wordingController.text.trim();
    if (amountCents == null || amountCents <= 0 || wording.isEmpty) {
      return const [];
    }

    return ocptBudgetMatchSuggestionsOf(
      isDebit: _isDebit,
      draftAmountCents: amountCents,
      draftDate: _date,
      draftWording: wording,
      commitments: widget.commitments,
      allowances: widget.allowances,
      resources: widget.resources,
      revenues: widget.revenues,
      receivedByResourceId: widget.receivedByResourceId,
      receivedByRevenueId: widget.receivedByRevenueId,
      projectVatRateBasisPoints: widget.projectVatRateBasisPoints,
    );
  }

  /// `Save`: validates the form, reports the typed fields through [OcptBudgetCaptureBand
  /// .onEntryCaptured], then clears — the suggestion, if any was shown, is ignored.
  void _handleSave() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final fields = _draftFieldsOrNull();
    if (fields == null) {
      return;
    }

    widget.onEntryCaptured?.call(fields);
    _clear();
  }

  /// `Autre chose…`: reports the typed fields through [OcptBudgetCaptureBand.onOtherRequested],
  /// then clears — the mode opens `OcptBudgetEntryDialog` prefilled with them.
  void _handleOther() {
    final fields = _draftFieldsOrNull();
    if (fields == null) {
      return;
    }

    widget.onOtherRequested?.call(fields);
    _clear();
  }

  /// `C'est ça`, on [suggestion]: reports it and the typed fields through [OcptBudgetCaptureBand
  /// .onSuggestionAccepted], then clears.
  void _handleAccept(OcptBudgetMatchSuggestion suggestion) {
    final fields = _draftFieldsOrNull();
    if (fields == null) {
      return;
    }

    widget.onSuggestionAccepted?.call(suggestion, fields);
    _clear();
  }

  /// Empties every controller and resets the date, the direction and the expander — see the class
  /// doc comment for why every answer clears the band whole.
  void _clear() {
    setState(() {
      _amountController.clear();
      _wordingController.clear();
      _date = _today();
      _isDebit = widget.initialIsDebit;
      _isMoreExpanded = false;
    });
    _formKey.currentState?.reset();
  }
}

/// One suggestion row of [OcptBudgetCaptureBand]'s own under-band: the headline naming what would
/// be settled, the muted *why* line under it, `C'est ça` always offered and `Autre chose…` offered
/// only on the first (through [onOther] being null on every row the discreet expander adds) — see
/// `_OcptBudgetCaptureBandState._buildUnderBand`'s own doc comment.
class _OcptBudgetCaptureBandSuggestionRow extends StatelessWidget {
  /// The suggestion's own headline, already resolved — see
  /// `_OcptBudgetCaptureBandState._headlineOf`.
  final String headline;

  /// The suggestion's own muted *why* line, already resolved and never empty — see
  /// `_OcptBudgetCaptureBandState._whyOf`.
  final String why;

  /// Called when `C'est ça` is clicked.
  final VoidCallback onAccept;

  /// Called when `Autre chose…` is clicked, or null to withhold the control on this row — see the
  /// class doc comment.
  final VoidCallback? onOther;

  /// The key `C'est ça` is drawn with — suffixed by the suggestion's own candidate id, so more than
  /// one row on screen at once (the first, and the discreet expander's own) never share one.
  final Key acceptKey;

  /// Class constructor
  const _OcptBudgetCaptureBandSuggestionRow({
    required this.headline,
    required this.why,
    required this.onAccept,
    required this.onOther,
    required this.acceptKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(headline, style: theme.textTheme.bodyMedium),
                Text(
                  why,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (onOther case final onOther?) ...[
            TextButton(
              key: const Key("ocptBudgetCaptureBandOtherButton"),
              onPressed: onOther,
              child: Text(tr.budgetCaptureBandOtherAction),
            ),
            const SizedBox(width: 4),
          ],
          FilledButton(
            key: acceptKey,
            onPressed: onAccept,
            child: Text(tr.budgetCaptureBandAcceptAction),
          ),
        ],
      ),
    );
  }
}

/// The discreet expander offering the suggestions past the first, when
/// [ocptBudgetMatchSuggestionsOf] found more than one — a plain [InkWell], never a `MenuAnchor`
/// (`CLAUDE.md`'s own standing pitfall about a `MenuItemButton` inside a `Wrap`, sidestepped
/// outright by not using a menu here at all).
class _OcptBudgetCaptureBandMoreExpander extends StatelessWidget {
  /// How many suggestions the expander offers past the first.
  final int count;

  /// Whether they are currently shown.
  final bool isExpanded;

  /// Called when the row is clicked.
  final VoidCallback onToggle;

  /// Class constructor
  const _OcptBudgetCaptureBandMoreExpander({
    required this.count,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      key: const Key("ocptBudgetCaptureBandMoreToggle"),
      onTap: onToggle,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              tr.budgetCaptureBandMoreSuggestionsToggle(count),
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
