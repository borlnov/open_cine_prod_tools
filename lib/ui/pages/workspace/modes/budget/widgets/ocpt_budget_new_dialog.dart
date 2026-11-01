// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_asset_file_types.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_match_suggestion.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_new_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_responsive.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_attachment.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_family.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_attachment_answers.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_attachment_step.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_breakdown_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_filled_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_form_primary_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_form_step.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_fullscreen.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_gesture_labels.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_gesture_step.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_movement_rules.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_step.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_text_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_title.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_resource_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_share_dialog.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The dialog's own fixed width, in logical pixels, above [ocptCompactWidthBreakpoint] — wide
/// enough for the widest step (the breakdown selector's own table) without wrapping. Below the
/// breakpoint the wizard drops this width altogether and renders full-screen instead (`build`).
const double _ocptNewDialogWidth = 520;

/// The families in their own natural order — the order every route but the one it promotes reads
/// them in, and the order the dashboard reads all five in.
const List<OcptBudgetGestureFamily> _ocptNewNaturalFamilyOrder = [
  OcptBudgetGestureFamily.quote,
  OcptBudgetGestureFamily.cashMovement,
  OcptBudgetGestureFamily.financingPlan,
  OcptBudgetGestureFamily.allowances,
  OcptBudgetGestureFamily.revenueSharing,
];

/// The budget mode's own capture wizard — the one door every document's own creation now goes
/// through, `+ Nouveau` in the header opening it on all five routes and every contextual shortcut
/// opening it pre-answered, skipping whichever of its own three steps it already knows.
///
/// **Three steps, or two** (`ocptBudgetGestureStepCountOf`): step 1 offers the fifteen answers,
/// grouped under the five document headings the mode's own chips already read; step 2 asks what the
/// movement attaches to, for every gesture that attaches to anything at all; step 3 is the money,
/// or the form. The step counter always tells the truth — `Étape 1 sur 2` where that is the truth —
/// and the trail above steps 2 and 3 recalls what has been answered so far, ending in a `changer`
/// link back to step 1, exactly as `OcptBudgetEntryDialog`'s own header already does for its own
/// two steps.
///
/// **Answers already given survive going back and forward again.** Every field this state holds is
/// read, never cleared, by `Retour` or by `changer` — switching the gesture picked on step 1 keeps
/// whatever step 2 or step 3 had already collected, exactly the reading
/// `OcptBudgetEntryDialog`'s own class doc comment already argues for its own nature switch.
class OcptBudgetNewDialog extends StatefulWidget {
  /// The document group moved to the top of step 1, its own first answer arriving pre-selected — or
  /// null for the dashboard's own natural order, nothing pre-selected.
  final OcptBudgetGestureFamily? promotedFamily;

  /// The gestures step 1 offers, or null to offer them all — the semantic filter the route it was
  /// opened from carries (`budget_wizard_flows.dart`'s own `_wizardGesturesForView`): the expenses route
  /// hands the ones that spend, the resources route the ones that bring money in, each drawer page
  /// its own family. A family with no offered gesture draws no heading at all, and the reader can
  /// lift the filter whole from inside step 1 (`Show all`), after which every family is shown in
  /// the natural order. Null everywhere step 1 is skipped, and on the dashboard, which filters
  /// nothing.
  final Set<OcptBudgetGesture>? allowedGestures;

  /// The word the filter tag names the current filter by — the route's own segment label, resolved
  /// by the mode — or null while [allowedGestures] is null. Read only to draw the tag.
  final String? filterLabel;

  /// The gesture step 1 opens with already selected, or null to open with nothing picked — read
  /// only while [entryPrefill] and [commitmentPrefill] are both null, per the class doc comment.
  final OcptBudgetGesture? initialGesture;

  /// Skips step 1 **and** step 2 straight to step 3's own movement form, [initialGesture] naming
  /// which of the seven `cashMovement` gestures it already answers and this field naming the link
  /// already known — a commitment's own `Pay`, a resource's or a taking's own `Receive`, a
  /// participant's own payout, a contribution's own repayment.
  final OcptBudgetEntryFormFields? entryPrefill;

  /// Skips step 1 **and** step 2 straight to step 3's own `OcptBudgetCommitmentFormBody` — a quote
  /// line's own `Commit this line…`, [initialGesture] always [OcptBudgetGesture.commitSpend] here.
  final OcptBudgetCommitmentFormFields? commitmentPrefill;

  /// The quote line [commitmentPrefill] was promoted from, or null while it hangs off the poste
  /// alone — carried the way `OcptBudgetCommitmentCreationConfirmedEvent.lineId` is, apart from the
  /// prefill itself.
  final String? commitmentPrefillLineId;

  /// Whether step 3 offers the lettrage strip at all. **True everywhere but the direct pay of a
  /// quote line**, which opens the wizard on an amount and a wording that necessarily belong to no
  /// existing commitment — the line has not been promoted — so every candidate the strip could rank
  /// is a *different* object, and offering to reroute the payment onto one only asks the reader to
  /// reject a rapprochement they never meant. The generic `+` capture keeps it: there, the movement
  /// is free-typed and the strip is what stops the same euro being both committed and paid.
  final bool offersLettrage;

  /// Every live poste of the project.
  final List<OcptBudgetPoste> postes;

  /// Every live financing resource of the project.
  final List<OcptBudgetResource> resources;

  /// Every live taking of the project.
  final List<OcptBudgetRevenue> revenues;

  /// Every live revenue-sharing participant of the project.
  final List<OcptBudgetShare> shares;

  /// Every live person of the project's address book.
  final List<OcptPerson> people;

  /// Every live breakdown element no live quote line prices yet — the breakdown selector's own
  /// catalogue.
  final List<OcptElement> unpricedElements;

  /// Every live commitment, read to rank the lettrage strip's own offers and to keep the
  /// `posteAndLine` attachment from offering a line that already carries one.
  final List<OcptBudgetCommitment> commitments;

  /// Every live journal entry, read the same way.
  final List<OcptBudgetEntry> entries;

  /// Every live defrayal, read the same way.
  final List<OcptBudgetAllowance> allowances;

  /// Every live mileage rate of the project, offered by the défraiement form's own rate pre-fill.
  final List<OcptBudgetMileageRate> mileageRates;

  /// What each financing resource has already received, keyed by its own id.
  final Map<String, OcptBudgetCoveredTotal> receivedByResourceId;

  /// What each taking has already received, keyed by its own id.
  final Map<String, OcptBudgetCoveredTotal> receivedByRevenueId;

  /// What each defrayed person has already been reimbursed, keyed by their own id — the person
  /// picker's own third figure, mirroring [receivedByResourceId].
  final Map<String, OcptBudgetCoveredTotal> reimbursedByPersonId;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// Whether the mode's header currently reads simplified.
  final bool isSimplified;

  /// Class constructor
  const OcptBudgetNewDialog({
    super.key,
    this.promotedFamily,
    this.allowedGestures,
    this.filterLabel,
    this.initialGesture,
    this.entryPrefill,
    this.commitmentPrefill,
    this.commitmentPrefillLineId,
    this.offersLettrage = true,
    required this.postes,
    required this.resources,
    required this.revenues,
    required this.shares,
    required this.people,
    required this.unpricedElements,
    required this.commitments,
    required this.entries,
    required this.allowances,
    required this.mileageRates,
    required this.receivedByResourceId,
    required this.receivedByRevenueId,
    required this.reimbursedByPersonId,
    required this.currencyCode,
    required this.defaultVatRateBasisPoints,
    required this.isSimplified,
  });

  /// Shows the wizard and returns what the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetNewOutcome?> show(
    BuildContext context, {
    OcptBudgetGestureFamily? promotedFamily,
    Set<OcptBudgetGesture>? allowedGestures,
    String? filterLabel,
    OcptBudgetGesture? initialGesture,
    OcptBudgetEntryFormFields? entryPrefill,
    OcptBudgetCommitmentFormFields? commitmentPrefill,
    String? commitmentPrefillLineId,
    bool offersLettrage = true,
    required List<OcptBudgetPoste> postes,
    required List<OcptBudgetResource> resources,
    required List<OcptBudgetRevenue> revenues,
    required List<OcptBudgetShare> shares,
    required List<OcptPerson> people,
    required List<OcptElement> unpricedElements,
    List<OcptBudgetCommitment> commitments = const [],
    List<OcptBudgetEntry> entries = const [],
    List<OcptBudgetAllowance> allowances = const [],
    List<OcptBudgetMileageRate> mileageRates = const [],
    Map<String, OcptBudgetCoveredTotal> receivedByResourceId = const {},
    Map<String, OcptBudgetCoveredTotal> receivedByRevenueId = const {},
    Map<String, OcptBudgetCoveredTotal> reimbursedByPersonId = const {},
    required String currencyCode,
    required int? defaultVatRateBasisPoints,
    required bool isSimplified,
  }) => showDialog<OcptBudgetNewOutcome>(
    context: context,
    builder: (context) => OcptBudgetNewDialog(
      promotedFamily: promotedFamily,
      allowedGestures: allowedGestures,
      filterLabel: filterLabel,
      initialGesture: initialGesture,
      entryPrefill: entryPrefill,
      commitmentPrefill: commitmentPrefill,
      commitmentPrefillLineId: commitmentPrefillLineId,
      offersLettrage: offersLettrage,
      postes: postes,
      resources: resources,
      revenues: revenues,
      shares: shares,
      people: people,
      unpricedElements: unpricedElements,
      commitments: commitments,
      entries: entries,
      allowances: allowances,
      mileageRates: mileageRates,
      receivedByResourceId: receivedByResourceId,
      receivedByRevenueId: receivedByRevenueId,
      reimbursedByPersonId: reimbursedByPersonId,
      currencyCode: currencyCode,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      isSimplified: isSimplified,
    ),
  );

  @override
  State<OcptBudgetNewDialog> createState() => _OcptBudgetNewDialogState();
}

/// The state of [OcptBudgetNewDialog]: every answer, controller and draft the three steps share,
/// the navigation between the steps and the outcome each gesture ends in. The steps themselves are
/// widgets that only draw what this state hands them and report back through callbacks.
class _OcptBudgetNewDialogState extends State<OcptBudgetNewDialog> {
  /// The form step 3 validates against, whichever of its own bodies is currently drawn — reused
  /// across gestures, since only one is ever mounted at a time.
  final _formKey = GlobalKey<FormState>();

  /// Which screen is currently drawn.
  late OcptBudgetNewStep _step;

  /// The gesture currently selected on step 1, or in effect past it.
  OcptBudgetGesture? _gesture;

  /// Whether the reader has lifted [OcptBudgetNewDialog.allowedGestures] with `Show all` — every
  /// family then shows, in the natural order, exactly as the dashboard's own unfiltered step 1
  /// does.
  bool _showAll = false;

  /// Step 2's own answer, kept whole even while a different gesture is in effect.
  final _answers = OcptBudgetNewAttachmentAnswers();

  // Step 3's own movement form — the seven `cashMovement` gestures alone.

  /// The movement's wording field controller.
  late final TextEditingController _labelController;

  /// The movement's amount field controller.
  late final TextEditingController _amountController;

  /// The movement's VAT rate field controller.
  late final TextEditingController _vatRateController;

  /// The movement's date.
  late DateTime _date;

  /// Whether the movement is a debit (money going out).
  late bool _isDebit;

  /// Whether the movement's amount is tax inclusive.
  late bool _isTaxInclusive;

  /// The receipt picked for the movement, or null.
  String? _pickedReceiptPath;

  /// Whether the receipt the movement came with was detached.
  bool _isReceiptDetached = false;

  /// Which of the lettrage strip's own ranked candidates is currently picked, by index into
  /// `ocptBudgetNewLettrageSuggestionsOf`'s own answer, or null for `Aucun`.
  ///
  /// **Null by default — reconciliation is opt-in, never automatic.** Pre-selecting the top
  /// candidate would silently reroute the movement into settling it: a repayment pre-filled against
  /// a contribution would settle a same-amount défraiement instead, and a fresh taking would be
  /// absorbed into an existing row rather than minting its own. The strip proposes; the reader
  /// chooses, and until they do the movement is written exactly as its own gesture says.
  int? _selectedSuggestionIndex;

  // Step 3's own drafts for every gesture backed by an embeddable form body.

  /// The quote line form's draft, or null while it is not valid.
  OcptBudgetLineFormFields? _lineDraft;

  /// The commitment form's draft, or null while it is not valid.
  OcptBudgetCommitmentFormFields? _commitmentDraft;

  /// What the commitment form still misses, or null once it misses nothing.
  String? _commitmentMissingHint;

  /// The resource form's draft, or null while it is not valid.
  OcptBudgetResourceFormFields? _resourceDraft;

  /// The taking form's draft, or null while it is not valid.
  OcptBudgetRevenueFormFields? _revenueDraft;

  /// The defrayal form's draft, or null while it is not valid.
  OcptBudgetAllowanceFormFields? _allowanceDraft;

  /// The participant form's draft, or null while it is not valid.
  OcptBudgetShareFormFields? _shareDraft;

  /// Step 3's own breakdown selector — `addQuoteLinesFromBreakdown` alone. Its quantity
  /// controllers are disposed with this state.
  final _breakdown = OcptBudgetNewBreakdownSelection();

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final entryPrefill = widget.entryPrefill;
    final commitmentPrefill = widget.commitmentPrefill;

    _date = entryPrefill?.date ?? DateTime(now.year, now.month, now.day);
    _isDebit = entryPrefill?.isDebit ?? true;
    _isTaxInclusive = entryPrefill?.isTaxInclusive ?? true;
    _labelController = TextEditingController(text: entryPrefill?.label ?? "");
    _amountController = TextEditingController(text: ocptCostTextOf(entryPrefill?.amountCents));
    _vatRateController = TextEditingController(
      text: ocptVatRatePercentTextOf(entryPrefill?.vatRateBasisPoints),
    );

    if (entryPrefill != null) {
      _answers.posteId = entryPrefill.posteId;
      _answers.posteAnswered = true;
      _answers.resourceId = entryPrefill.resourceId;
      _answers.revenueId = entryPrefill.revenueId;
      _answers.shareId = entryPrefill.shareId;
      _answers.personId = entryPrefill.personId;
      _gesture = widget.initialGesture;
      _step = OcptBudgetNewStep.form;
    } else if (commitmentPrefill != null) {
      _answers.posteId = commitmentPrefill.posteId;
      _answers.posteAnswered = true;
      _answers.lineId = widget.commitmentPrefillLineId;
      _gesture = OcptBudgetGesture.commitSpend;
      _step = OcptBudgetNewStep.form;
    } else {
      _gesture = widget.initialGesture;
      _step = OcptBudgetNewStep.gesture;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    _vatRateController.dispose();
    _breakdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    final stepContent = switch (_step) {
      OcptBudgetNewStep.gesture => OcptBudgetNewGestureStep(
        showsFilterTag: !_showAll && widget.allowedGestures != null,
        filterLabel: widget.filterLabel,
        families: [
          for (final family in _orderedFamilies)
            if (_visibleGesturesOf(family).isNotEmpty)
              (family: family, gestures: _visibleGesturesOf(family)),
        ],
        selectedGesture: _gesture,
        onGestureSelected: (gesture) => setState(() => _gesture = gesture),
        onShowAllRequested: () => setState(() => _showAll = true),
      ),
      OcptBudgetNewStep.attachment => OcptBudgetNewAttachmentStep(
        gesture: _gesture,
        postes: widget.postes,
        resources: widget.resources,
        shares: widget.shares,
        people: widget.people,
        commitments: widget.commitments,
        allowances: widget.allowances,
        receivedByResourceId: widget.receivedByResourceId,
        reimbursedByPersonId: widget.reimbursedByPersonId,
        currencyCode: widget.currencyCode,
        isSimplified: widget.isSimplified,
        posteAnswered: _answers.posteAnswered,
        posteId: _answers.posteId,
        lineId: _answers.lineId,
        lineNoneAnswered: _answers.lineNoneAnswered,
        resourceId: _answers.resourceId,
        pendingNewResource: _answers.pendingNewResource,
        shareId: _answers.shareId,
        pendingNewShare: _answers.pendingNewShare,
        personId: _answers.personId,
        onPosteSelected: (posteId) => setState(() => _answers.selectPoste(posteId)),
        onPosteChangeRequested: () => setState(_answers.clearPoste),
        onLineSelected: (lineId) => setState(() => _answers.selectLine(lineId)),
        onNoLineSelected: () => setState(_answers.selectNoLine),
        onResourceSelected: (resourceId) => setState(() => _answers.selectResource(resourceId)),
        onCreateResourceRequested: () => unawaited(_handleCreateResourceRequested()),
        onShareSelected: (shareId) => setState(() => _answers.selectShare(shareId)),
        onCreateShareRequested: () => unawaited(_handleCreateShareRequested()),
        onPersonSelected: (personId) => setState(() => _answers.personId = personId),
      ),
      OcptBudgetNewStep.form => OcptBudgetNewFormStep(
        gesture: _gesture,
        formKey: _formKey,
        postes: widget.postes,
        people: widget.people,
        mileageRates: widget.mileageRates,
        commitments: widget.commitments,
        currencyCode: widget.currencyCode,
        defaultVatRateBasisPoints: widget.defaultVatRateBasisPoints,
        isSimplified: widget.isSimplified,
        commitmentPrefill: widget.commitmentPrefill ?? _answers.commitmentPrefillIn(widget.postes),
        onLineDraftChanged: (draft) => setState(() => _lineDraft = draft),
        onCommitmentDraftChanged: (draft) => setState(() => _commitmentDraft = draft),
        onCommitmentMissingHintChanged: (hint) => setState(() => _commitmentMissingHint = hint),
        onResourceDraftChanged: (draft) => setState(() => _resourceDraft = draft),
        onRevenueDraftChanged: (draft) => setState(() => _revenueDraft = draft),
        onAllowanceDraftChanged: (draft) => setState(() => _allowanceDraft = draft),
        onShareDraftChanged: (draft) => setState(() => _shareDraft = draft),
        labelController: _labelController,
        amountController: _amountController,
        vatRateController: _vatRateController,
        date: _date,
        isTaxInclusive: _isTaxInclusive,
        isDebit: _isDebit,
        lettrageSuggestions: _formStepSuggestions(),
        selectedSuggestionIndex: _selectedSuggestionIndex,
        pickedReceiptPath: _pickedReceiptPath,
        onDraftTextChanged: () => setState(() {}),
        onDateChanged: (value) => setState(() => _date = value ?? _date),
        onTaxInclusiveChanged: (value) => setState(() => _isTaxInclusive = value),
        onDirectionChanged: (value) => setState(() => _isDebit = value),
        onSuggestionSelected: (index) => setState(() => _selectedSuggestionIndex = index),
        onReceiptRemoved: () => setState(() {
          _pickedReceiptPath = null;
          _isReceiptDetached = true;
        }),
        onReceiptPickRequested: _pickReceipt,
        unpricedElements: widget.unpricedElements,
        breakdownQuery: _breakdown.query,
        breakdownSelectedIds: _breakdown.selectedIds,
        breakdownBulkPosteId: _breakdown.bulkPosteId,
        breakdownPosteIdOf: _breakdown.posteFor,
        breakdownQuantityControllerOf: _breakdown.quantityControllerOf,
        onBreakdownBulkPosteChanged: (posteId) => setState(() => _breakdown.setBulkPoste(posteId)),
        onBreakdownQueryChanged: (value) => setState(() => _breakdown.query = value),
        onBreakdownElementCheckedChanged: (element, {required isChecked}) =>
            setState(() => _breakdown.setChecked(element, isChecked: isChecked)),
        onBreakdownElementPosteChanged: (elementId, posteId) =>
            setState(() => _breakdown.setPosteOverride(elementId, posteId)),
        onBreakdownQuantityChanged: _breakdown.setQuantityText,
      ),
    };
    final stepActions = switch (_step) {
      OcptBudgetNewStep.gesture => _gestureActionsOf(tr),
      OcptBudgetNewStep.attachment => _attachmentActionsOf(tr),
      OcptBudgetNewStep.form => _formActionsOf(tr),
    };
    final title = OcptBudgetNewTitle(
      step: _step,
      gesture: _gesture,
      trailSegments: _trailSegmentsOf(tr),
      offersChangeLink: !_openedOnFormDirectly,
      onChangeGestureRequested: () => setState(() => _step = OcptBudgetNewStep.gesture),
    );

    if (ocptIsCompactWidth(MediaQuery.sizeOf(context).width)) {
      return OcptBudgetNewFullscreen(
        title: title,
        stepContent: stepContent,
        stepActions: stepActions,
        showsTrail: _step != OcptBudgetNewStep.gesture && _gesture != null,
        onCancelRequested: _handleCancel,
      );
    }

    return AlertDialog(
      title: title,
      content: SizedBox(
        width: _ocptNewDialogWidth,
        child: SingleChildScrollView(child: stepContent),
      ),
      actions: stepActions,
    );
  }

  /// The trail's segments above steps 2 and 3 — what has been answered so far — or null on step 1
  /// and while no gesture is picked, where no trail is drawn.
  List<String>? _trailSegmentsOf(Tr tr) {
    final gesture = _gesture;
    if (_step == OcptBudgetNewStep.gesture || gesture == null) {
      return null;
    }

    final segments = <String>[ocptBudgetGestureAnswerLabel(tr, gesture)];
    if (_step == OcptBudgetNewStep.form) {
      final attachmentLabel = _attachmentAnswerLabel(tr, gesture);
      if (attachmentLabel != null) {
        segments.add(attachmentLabel);
      }
    }
    return segments;
  }

  /// The words step 2's own answer reads on the trail, or null while [gesture] attaches to nothing
  /// or nothing has been answered yet.
  String? _attachmentAnswerLabel(Tr tr, OcptBudgetGesture gesture) {
    switch (ocptBudgetGestureAttachmentOf(gesture)) {
      case OcptBudgetGestureAttachment.none:
        return null;
      case OcptBudgetGestureAttachment.poste:
      case OcptBudgetGestureAttachment.optionalPoste:
        return _posteLabelOf(tr, _answers.posteId);
      case OcptBudgetGestureAttachment.posteAndLine:
        final posteLabel = _posteLabelOf(tr, _answers.posteId);
        if (_answers.lineNoneAnswered) {
          return posteLabel;
        }
        final line = _answers.lineIn(widget.postes);
        return line == null ? posteLabel : "$posteLabel › ${line.label}";
      case OcptBudgetGestureAttachment.financingResource:
        final pendingNewResource = _answers.pendingNewResource;
        if (pendingNewResource != null) {
          return pendingNewResource.label;
        }
        return widget.resources
            .where((resource) => resource.id == _answers.resourceId)
            .firstOrNull
            ?.label;
      case OcptBudgetGestureAttachment.participant:
        final pendingNewShare = _answers.pendingNewShare;
        if (pendingNewShare != null) {
          return pendingNewShare.label;
        }
        return widget.shares.where((share) => share.id == _answers.shareId).firstOrNull?.label;
      case OcptBudgetGestureAttachment.person:
        return widget.people
            .where((person) => person.id == _answers.personId)
            .firstOrNull
            ?.displayName;
    }
  }

  /// The display label of the poste [posteId], or the off-quote label while it is null.
  String _posteLabelOf(Tr tr, String? posteId) {
    if (posteId == null) {
      return tr.budgetCostTrackingOffQuoteLabel;
    }
    final poste = widget.postes.where((poste) => poste.id == posteId).firstOrNull;
    return poste == null
        ? tr.budgetPosteUnnamed
        : ocptBudgetPosteDisplayLabel(poste, isSimplified: widget.isSimplified);
  }

  // Step 1 — the fifteen answers, grouped by document

  /// The families in the order step 1 draws them: the promoted one first, unless `Show all` lifted
  /// the filter.
  List<OcptBudgetGestureFamily> get _orderedFamilies {
    // `Show all` drops the promotion too, so the lifted list reads in the plain natural order — the
    // quote first, exactly the dashboard's own unfiltered step 1.
    final promoted = _showAll ? null : widget.promotedFamily;
    if (promoted == null) {
      return _ocptNewNaturalFamilyOrder;
    }
    return [
      promoted,
      for (final family in _ocptNewNaturalFamilyOrder)
        if (family != promoted) family,
    ];
  }

  /// [family]'s own gestures that step 1 currently offers — every one of them while the filter is
  /// lifted or absent, only the offered ones otherwise. A family with none is drawn no heading.
  List<OcptBudgetGesture> _visibleGesturesOf(OcptBudgetGestureFamily family) {
    final allowed = _showAll ? null : widget.allowedGestures;
    return [
      for (final gesture in OcptBudgetGesture.values)
        if (ocptBudgetGestureFamilyOf(gesture) == family &&
            (allowed == null || allowed.contains(gesture)))
          gesture,
    ];
  }

  /// The actions of step 1: `Cancel`, and `Continue` once a gesture is picked.
  List<Widget> _gestureActionsOf(Tr tr) => [
    OcptBudgetNewTextAction(
      buttonKey: const Key("ocptBudgetNewCancelButton"),
      label: tr.budgetEntryDialogCancelAction,
      onPressed: _handleCancel,
    ),
    OcptBudgetNewFilledAction(
      buttonKey: const Key("ocptBudgetNewContinueButton"),
      label: tr.budgetEntryWizardContinueAction,
      onPressed: _gesture == null ? null : _handleGestureContinue,
    ),
  ];

  /// Closes the wizard without an outcome.
  void _handleCancel() => globalGetIt().get<OcptRouterManager>().pop();

  /// Leaves step 1 for the attachment step, or straight for the form when the gesture attaches to
  /// nothing.
  void _handleGestureContinue() {
    final gesture = _gesture;
    if (gesture == null) {
      return;
    }

    setState(() {
      final direction = ocptBudgetGestureNatureOf(gesture) == null
          ? null
          : ocptBudgetEntryNatureDirectionOf(ocptBudgetGestureNatureOf(gesture)!);
      if (direction != null) {
        _isDebit = direction;
      }
      _step = ocptBudgetGestureAttachmentOf(gesture) == OcptBudgetGestureAttachment.none
          ? OcptBudgetNewStep.form
          : OcptBudgetNewStep.attachment;
    });
  }

  // Step 2 — the attachment

  /// Asks for the financing resource to create along with the movement, then keeps it pending.
  Future<void> _handleCreateResourceRequested() async {
    final fields = await OcptBudgetResourceDialog.show(
      context,
      existing: null,
      groupKind: OcptBudgetResourceGroupKind.cash,
      people: widget.people,
      currencyCode: widget.currencyCode,
      postes: widget.postes,
      isSimplified: widget.isSimplified,
      // Both gestures reaching this row (`recordFinancingReceipt`, `repayContribution`) move real
      // money, so the resource missing here is a contribution — cash or in-kind, the one question
      // left for its own dialog to ask.
      offerCashOrInKindChoice: true,
    );
    if (fields == null || !mounted) {
      return;
    }

    setState(() => _answers.selectPendingResource(fields));
  }

  /// Asks for the participant to create along with the movement, then keeps it pending.
  Future<void> _handleCreateShareRequested() async {
    final fields = await OcptBudgetShareDialog.show(context, existing: null, people: widget.people);
    if (fields == null || !mounted) {
      return;
    }

    setState(() => _answers.selectPendingShare(fields));
  }

  /// The actions of step 2: `Back`, and `Continue` once the attachment is answered.
  List<Widget> _attachmentActionsOf(Tr tr) => [
    OcptBudgetNewTextAction(
      buttonKey: const Key("ocptBudgetNewBackButton"),
      label: tr.budgetEntryDialogBackAction,
      onPressed: () => setState(() => _step = OcptBudgetNewStep.gesture),
    ),
    OcptBudgetNewFilledAction(
      buttonKey: const Key("ocptBudgetNewAttachmentContinueButton"),
      label: tr.budgetEntryWizardContinueAction,
      onPressed: _answers.isAnsweredFor(_gesture)
          ? () => setState(() => _step = OcptBudgetNewStep.form)
          : null,
    ),
  ];

  // Step 3 — the money, or the form

  /// Whether the wizard opened straight on the form, a prefilled shortcut — a commitment's own
  /// `Pay`, a receipt, a payout, a repayment, the direct pay of a quote line, or `Commit this
  /// line…` — skipping steps 1 and 2 (`initState`). There is then no step behind the form to return
  /// to, so it offers `Cancel`, which closes the wizard, rather than `Back`, and its own trail
  /// carries no `changer` link either: the reader came to do one thing, and closes the view if they
  /// no longer want it, rather than being walked back through steps they never saw.
  bool get _openedOnFormDirectly => widget.entryPrefill != null || widget.commitmentPrefill != null;

  /// The actions of step 3: `Cancel` or `Back`, and the primary action of the gesture in effect.
  List<Widget> _formActionsOf(Tr tr) {
    final gesture = _gesture;
    final attachment = gesture == null
        ? OcptBudgetGestureAttachment.none
        : ocptBudgetGestureAttachmentOf(gesture);

    return [
      if (_openedOnFormDirectly)
        OcptBudgetNewTextAction(
          buttonKey: const Key("ocptBudgetNewFormCancelButton"),
          label: tr.budgetEntryDialogCancelAction,
          onPressed: _handleCancel,
        )
      else
        OcptBudgetNewTextAction(
          buttonKey: const Key("ocptBudgetNewFormBackButton"),
          label: tr.budgetEntryDialogBackAction,
          onPressed: () => setState(
            () => _step = attachment == OcptBudgetGestureAttachment.none
                ? OcptBudgetNewStep.gesture
                : OcptBudgetNewStep.attachment,
          ),
        ),
      OcptBudgetNewFormPrimaryAction(
        gesture: gesture,
        breakdownSelectedCount: _breakdown.selectedIds.length,
        onPressed: gesture == null ? null : _primaryFormPressedOf(gesture),
      ),
    ];
  }

  /// What the primary action of step 3 does for [gesture], or null while it is withheld.
  VoidCallback? _primaryFormPressedOf(OcptBudgetGesture gesture) {
    if (gesture == OcptBudgetGesture.addQuoteLinesFromBreakdown) {
      return _breakdown.isReady ? _submitBreakdown : null;
    }

    return switch (gesture) {
      OcptBudgetGesture.addQuoteLine => _lineDraft == null ? null : _submitLine,
      OcptBudgetGesture.commitSpend =>
        _commitmentMissingHint != null || _commitmentDraft == null ? null : _submitCommitment,
      OcptBudgetGesture.planSubsidy ||
      OcptBudgetGesture.planContribution => _resourceDraft == null ? null : _submitResource,
      OcptBudgetGesture.planTaking => _revenueDraft == null ? null : _submitRevenue,
      OcptBudgetGesture.defrayPerson => _allowanceDraft == null ? null : _submitAllowance,
      OcptBudgetGesture.addSharingParticipant => _shareDraft == null ? null : _submitShare,
      _ => _submitMovement,
    };
  }

  /// Closes the wizard with [outcome].
  void _pop(OcptBudgetNewOutcome outcome) =>
      globalGetIt().get<OcptRouterManager>().pop<OcptBudgetNewOutcome>(outcome);

  /// Confirms the quote line form.
  void _submitLine() {
    final draft = _lineDraft;
    final posteId = _answers.posteId;
    if (!(_formKey.currentState?.validate() ?? false) || draft == null || posteId == null) {
      return;
    }
    _pop(OcptBudgetNewLineOutcome(posteId: posteId, fields: draft));
  }

  /// Confirms the commitment form.
  void _submitCommitment() {
    final draft = _commitmentDraft;
    if (!(_formKey.currentState?.validate() ?? false) || draft == null) {
      return;
    }
    _pop(
      OcptBudgetNewCommitmentOutcome(
        fields: draft,
        lineId:
            widget.commitmentPrefillLineId ?? (_answers.lineNoneAnswered ? null : _answers.lineId),
      ),
    );
  }

  /// Confirms the resource form.
  void _submitResource() {
    final draft = _resourceDraft;
    if (!(_formKey.currentState?.validate() ?? false) || draft == null) {
      return;
    }
    _pop(OcptBudgetNewResourceOutcome(fields: draft));
  }

  /// Confirms the taking form.
  void _submitRevenue() {
    final draft = _revenueDraft;
    if (!(_formKey.currentState?.validate() ?? false) || draft == null) {
      return;
    }
    _pop(OcptBudgetNewRevenueOutcome(fields: draft));
  }

  /// Confirms the defrayal form.
  void _submitAllowance() {
    final draft = _allowanceDraft;
    if (!(_formKey.currentState?.validate() ?? false) || draft == null) {
      return;
    }
    _pop(OcptBudgetNewAllowanceOutcome(fields: draft));
  }

  /// Confirms the participant form.
  void _submitShare() {
    final draft = _shareDraft;
    if (!(_formKey.currentState?.validate() ?? false) || draft == null) {
      return;
    }
    _pop(OcptBudgetNewShareOutcome(fields: draft));
  }

  /// Confirms the breakdown selector, creating one quote line per checked element.
  void _submitBreakdown() {
    final outcome = _breakdown.outcome();
    if (outcome != null) {
      _pop(outcome);
    }
  }

  /// Opens the file selector for the movement's receipt and keeps the picked path.
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

  /// The lettrage candidates the movement form offers, but only while the gesture in effect is a
  /// cash movement; empty otherwise.
  List<OcptBudgetMatchSuggestion> _formStepSuggestions() {
    final gesture = _gesture;
    if (gesture == null || ocptBudgetGestureNatureOf(gesture) == null) {
      return const [];
    }
    return _lettrageSuggestionsOf();
  }

  /// The ranked lettrage candidates for the movement typed so far.
  List<OcptBudgetMatchSuggestion> _lettrageSuggestionsOf() => ocptBudgetNewLettrageSuggestionsOf(
    offersLettrage: widget.offersLettrage,
    amountText: _amountController.text,
    wording: _labelController.text,
    isDebit: _isDebit,
    date: _date,
    commitments: widget.commitments,
    entries: widget.entries,
    allowances: widget.allowances,
    resources: widget.resources,
    revenues: widget.revenues,
    receivedByResourceId: widget.receivedByResourceId,
    receivedByRevenueId: widget.receivedByRevenueId,
    projectVatRateBasisPoints: widget.defaultVatRateBasisPoints,
  );

  /// Confirms the movement form, settling the accepted lettrage candidate when there is one.
  void _submitMovement() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amountCents = ocptCostCentsOf(_amountController.text);
    if (amountCents == null) {
      return;
    }

    final suggestions = _lettrageSuggestionsOf();
    final selectedIndex = _selectedSuggestionIndex;
    final acceptedSuggestion = selectedIndex != null && selectedIndex < suggestions.length
        ? suggestions[selectedIndex]
        : null;

    if (acceptedSuggestion != null) {
      _pop(
        OcptBudgetEntryWizardResult(
          fields: OcptBudgetEntryFormFields(
            date: _date,
            label: _labelController.text.trim(),
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
          ),
          acceptedSuggestion: acceptedSuggestion,
        ),
      );
      return;
    }

    _pop(
      OcptBudgetEntryWizardResult(
        fields: ocptBudgetNewMovementFieldsOf(
          gesture: _gesture!,
          answers: _answers,
          date: _date,
          wording: _labelController.text,
          isDebit: _isDebit,
          amountCents: amountCents,
          isTaxInclusive: _isTaxInclusive,
          vatRateText: _vatRateController.text,
          pickedReceiptPath: _pickedReceiptPath,
          isReceiptDetached: _isReceiptDetached,
        ),
        acceptedSuggestion: null,
      ),
    );
  }
}
