// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

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
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line_form_fields.dart';
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
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_family.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_allowance_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_commitment_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_line_form_body.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_resource_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_revenue_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_share_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_asset_file_line.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_match.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// The dialog's own fixed width, in logical pixels — wide enough for the widest step (the
/// breakdown selector's own table) without wrapping.
const double _ocptNewDialogWidth = 520;

/// Which of the wizard's own three screens is currently drawn — mirrors
/// `_OcptBudgetEntryWizardStep`, one member wider.
enum _OcptBudgetNewStep {
  /// Step 1: the fifteen answers, grouped by document.
  gesture,

  /// Step 2: what the movement attaches to — skipped outright for a gesture whose
  /// `OcptBudgetGestureAttachment` is `none`.
  attachment,

  /// Step 3: the money, or the form.
  form,
}

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
/// movement attaches to, for every gesture that attaches to anything at all; step 3 is the money, or
/// the form. The step counter always tells the truth — `Étape 1 sur 2` where that is the truth —
/// and the trail above steps 2 and 3 recalls what has been answered so far, ending in a `changer`
/// link back to step 1, exactly as `OcptBudgetEntryDialog`'s own header already does for its own two
/// steps.
///
/// **Answers already given survive going back and forward again.** Every field this state holds is
/// read, never cleared, by `Retour` or by `changer` — switching the gesture picked on step 1 keeps
/// whatever step 2 or step 3 had already collected, exactly the reading
/// `OcptBudgetEntryDialog`'s own class doc comment already argues for its own nature switch.
class OcptBudgetNewDialog extends StatefulWidget {
  /// The document group moved to the top of step 1, its own first answer arriving pre-selected — or
  /// null for the dashboard's own natural order, nothing pre-selected.
  final OcptBudgetGestureFamily? promotedFamily;

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
    this.initialGesture,
    this.entryPrefill,
    this.commitmentPrefill,
    this.commitmentPrefillLineId,
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
    required this.currencyCode,
    required this.defaultVatRateBasisPoints,
    required this.isSimplified,
  });

  /// Shows the wizard and returns what the user confirmed, or null if they cancelled it.
  static Future<OcptBudgetNewOutcome?> show(
    BuildContext context, {
    OcptBudgetGestureFamily? promotedFamily,
    OcptBudgetGesture? initialGesture,
    OcptBudgetEntryFormFields? entryPrefill,
    OcptBudgetCommitmentFormFields? commitmentPrefill,
    String? commitmentPrefillLineId,
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
    required String currencyCode,
    required int? defaultVatRateBasisPoints,
    required bool isSimplified,
  }) => showDialog<OcptBudgetNewOutcome>(
    context: context,
    builder: (context) => OcptBudgetNewDialog(
      promotedFamily: promotedFamily,
      initialGesture: initialGesture,
      entryPrefill: entryPrefill,
      commitmentPrefill: commitmentPrefill,
      commitmentPrefillLineId: commitmentPrefillLineId,
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
      currencyCode: currencyCode,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      isSimplified: isSimplified,
    ),
  );

  @override
  State<OcptBudgetNewDialog> createState() => _OcptBudgetNewDialogState();
}

class _OcptBudgetNewDialogState extends State<OcptBudgetNewDialog> {
  /// The form step 3 validates against, whichever of its own bodies is currently drawn — reused
  /// across gestures, since only one is ever mounted at a time.
  final _formKey = GlobalKey<FormState>();

  /// Which screen is currently drawn.
  late _OcptBudgetNewStep _step;

  /// The gesture currently selected on step 1, or in effect past it.
  OcptBudgetGesture? _gesture;

  // -----------------------------------------------------------------------------------------
  // Step 2's own answer — every field kept even while a different gesture is in effect, so
  // switching the gesture and switching back loses nothing.
  // -----------------------------------------------------------------------------------------

  /// The poste answered under `poste`/`optionalPoste`/`posteAndLine`, or null.
  String? _posteId;

  /// Whether a `poste`/`optionalPoste` answer has been given at all — `optionalPoste`'s own `Hors
  /// devis` answers this true while leaving [_posteId] null, which a bare null cannot tell apart
  /// from "nothing chosen yet".
  bool _posteAnswered = false;

  /// The quote line answered under `posteAndLine`, or null.
  String? _lineId;

  /// Whether `posteAndLine`'s own third answer, `Aucune`, was picked.
  bool _lineNoneAnswered = false;

  /// The financing resource answered under `financingResource`, or null.
  String? _resourceId;

  /// The taking answered under `taking`, or null.
  String? _revenueId;

  /// The participant answered under `participant`, or null.
  String? _shareId;

  /// The person answered under `person`, or null.
  String? _personId;

  /// The financing resource step 2's own trailing row just collected, waiting to be created along
  /// with the movement, or null.
  OcptBudgetResourceFormFields? _pendingNewResource;

  /// The taking step 2's own trailing row just collected, or null.
  OcptBudgetRevenueFormFields? _pendingNewRevenue;

  /// The participant step 2's own trailing row just collected, or null.
  OcptBudgetShareFormFields? _pendingNewShare;

  // -----------------------------------------------------------------------------------------
  // Step 3's own movement form — the seven `cashMovement` gestures alone.
  // -----------------------------------------------------------------------------------------

  late final TextEditingController _labelController;
  late final TextEditingController _amountController;
  late final TextEditingController _vatRateController;
  late DateTime _date;
  late bool _isDebit;
  late bool _isTaxInclusive;
  String? _pickedReceiptPath;
  bool _isReceiptDetached = false;

  /// Which of the lettrage strip's own ranked candidates is currently picked, by index into
  /// [_lettrageSuggestionsOf]'s own answer, or null for `Aucun`.
  int? _selectedSuggestionIndex = 0;

  // -----------------------------------------------------------------------------------------
  // Step 3's own drafts for every gesture backed by an embeddable form body.
  // -----------------------------------------------------------------------------------------

  OcptBudgetLineFormFields? _lineDraft;
  OcptBudgetCommitmentFormFields? _commitmentDraft;
  String? _commitmentMissingHint;
  OcptBudgetResourceFormFields? _resourceDraft;
  OcptBudgetRevenueFormFields? _revenueDraft;
  OcptBudgetAllowanceFormFields? _allowanceDraft;
  OcptBudgetShareFormFields? _shareDraft;

  // -----------------------------------------------------------------------------------------
  // Step 3's own breakdown selector — `addQuoteLinesFromBreakdown` alone.
  // -----------------------------------------------------------------------------------------

  final Set<String> _breakdownSelectedIds = {};
  final Map<String, int> _breakdownQuantityMilliByElementId = {};
  final Map<String, TextEditingController> _breakdownQuantityControllers = {};
  String _breakdownQuery = "";

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
      _posteId = entryPrefill.posteId;
      _posteAnswered = true;
      _resourceId = entryPrefill.resourceId;
      _revenueId = entryPrefill.revenueId;
      _shareId = entryPrefill.shareId;
      _personId = entryPrefill.personId;
      _gesture = widget.initialGesture;
      _step = _OcptBudgetNewStep.form;
    } else if (commitmentPrefill != null) {
      _posteId = commitmentPrefill.posteId;
      _posteAnswered = true;
      _lineId = widget.commitmentPrefillLineId;
      _gesture = OcptBudgetGesture.commitSpend;
      _step = _OcptBudgetNewStep.form;
    } else {
      _gesture = widget.initialGesture;
      _step = _OcptBudgetNewStep.gesture;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    _vatRateController.dispose();
    for (final controller in _breakdownQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: _buildTitle(context, tr),
      content: SizedBox(
        width: _ocptNewDialogWidth,
        child: SingleChildScrollView(
          child: switch (_step) {
            _OcptBudgetNewStep.gesture => _buildGestureStep(context, tr),
            _OcptBudgetNewStep.attachment => _buildAttachmentStep(context, tr),
            _OcptBudgetNewStep.form => _buildFormStep(context, tr),
          },
        ),
      ),
      actions: switch (_step) {
        _OcptBudgetNewStep.gesture => _buildGestureActions(tr),
        _OcptBudgetNewStep.attachment => _buildAttachmentActions(tr),
        _OcptBudgetNewStep.form => _buildFormActions(context, tr),
      },
    );
  }

  // ===============================================================================================
  // Title & trail
  // ===============================================================================================

  Widget _buildTitle(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final gesture = _gesture;
    final stepCount = gesture == null ? null : ocptBudgetGestureStepCountOf(gesture);
    final stepNumber = switch (_step) {
      _OcptBudgetNewStep.gesture => 1,
      _OcptBudgetNewStep.attachment => 2,
      _OcptBudgetNewStep.form => stepCount ?? 3,
    };

    final children = <Widget>[
      Row(
        children: [
          Expanded(child: Text(tr.budgetNewDialogTitle)),
          Text(
            stepCount == null
                ? tr.budgetNewStepLabelUnknown(stepNumber)
                : tr.budgetNewStepLabel(stepNumber, stepCount),
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ];

    if (_step != _OcptBudgetNewStep.gesture && gesture != null) {
      children.add(const SizedBox(height: 4));
      children.add(_buildTrail(context, tr, gesture));
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  /// The trail above steps 2 and 3: what has been answered so far, ending in a `changer` link back
  /// to step 1 — mirrors `OcptBudgetEntryDialog`'s own header trail, extended with step 2's own
  /// answer while step 3 is on screen.
  Widget _buildTrail(BuildContext context, Tr tr, OcptBudgetGesture gesture) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final segments = <String>[_ocptBudgetGestureAnswerLabel(tr, gesture)];
    if (_step == _OcptBudgetNewStep.form) {
      final attachmentLabel = _attachmentAnswerLabel(context, tr, gesture);
      if (attachmentLabel != null) {
        segments.add(attachmentLabel);
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            segments.join(" › "),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mutedStyle,
          ),
        ),
        Text(" · ", style: mutedStyle),
        InkWell(
          key: const Key("ocptBudgetNewChangeGestureLink"),
          onTap: () => setState(() => _step = _OcptBudgetNewStep.gesture),
          mouseCursor: ocptClickableCursor,
          child: Text(
            tr.budgetEntryWizardChangeNatureAction,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }

  /// The words step 2's own answer reads on the trail, or null while [gesture] attaches to nothing
  /// or nothing has been answered yet.
  String? _attachmentAnswerLabel(BuildContext context, Tr tr, OcptBudgetGesture gesture) {
    switch (ocptBudgetGestureAttachmentOf(gesture)) {
      case OcptBudgetGestureAttachment.none:
        return null;
      case OcptBudgetGestureAttachment.poste:
      case OcptBudgetGestureAttachment.optionalPoste:
        return _posteLabelOf(tr, _posteId);
      case OcptBudgetGestureAttachment.posteAndLine:
        final posteLabel = _posteLabelOf(tr, _posteId);
        if (_lineNoneAnswered) {
          return posteLabel;
        }
        final line = _lineById(_lineId);
        return line == null ? posteLabel : "$posteLabel › ${line.label}";
      case OcptBudgetGestureAttachment.financingResource:
        final pendingNewResource = _pendingNewResource;
        if (pendingNewResource != null) {
          return pendingNewResource.label;
        }
        return widget.resources.where((resource) => resource.id == _resourceId).firstOrNull?.label;
      case OcptBudgetGestureAttachment.taking:
        final pendingNewRevenue = _pendingNewRevenue;
        if (pendingNewRevenue != null) {
          return pendingNewRevenue.label;
        }
        return widget.revenues.where((revenue) => revenue.id == _revenueId).firstOrNull?.label;
      case OcptBudgetGestureAttachment.participant:
        final pendingNewShare = _pendingNewShare;
        if (pendingNewShare != null) {
          return pendingNewShare.label;
        }
        return widget.shares.where((share) => share.id == _shareId).firstOrNull?.label;
      case OcptBudgetGestureAttachment.person:
        return widget.people.where((person) => person.id == _personId).firstOrNull?.displayName;
    }
  }

  String _posteLabelOf(Tr tr, String? posteId) {
    if (posteId == null) {
      return tr.budgetCostTrackingOffQuoteLabel;
    }
    final poste = widget.postes.where((poste) => poste.id == posteId).firstOrNull;
    return poste == null
        ? tr.budgetPosteUnnamed
        : ocptBudgetPosteDisplayLabel(poste, isSimplified: widget.isSimplified);
  }

  // ===============================================================================================
  // Step 1 — the fifteen answers, grouped by document
  // ===============================================================================================

  List<OcptBudgetGestureFamily> get _orderedFamilies {
    final promoted = widget.promotedFamily;
    if (promoted == null) {
      return _ocptNewNaturalFamilyOrder;
    }
    return [promoted, for (final family in _ocptNewNaturalFamilyOrder) if (family != promoted) family];
  }

  Widget _buildGestureStep(BuildContext context, Tr tr) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final family in _orderedFamilies) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: _buildFamilyHeading(context, tr, family),
        ),
        for (final gesture in OcptBudgetGesture.values)
          if (ocptBudgetGestureFamilyOf(gesture) == family)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OcptBudgetNewGestureCard(
                gesture: gesture,
                isSelected: _gesture == gesture,
                onSelected: () => setState(() => _gesture = gesture),
              ),
            ),
      ],
    ],
  );

  Widget _buildFamilyHeading(BuildContext context, Tr tr, OcptBudgetGestureFamily family) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_ocptBudgetGestureFamilyLabel(tr, family), style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          _ocptBudgetGestureFamilySubtitle(tr, family),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  List<Widget> _buildGestureActions(Tr tr) => [
    TextButton(
      key: const Key("ocptBudgetNewCancelButton"),
      onPressed: _handleCancel,
      child: Text(tr.budgetEntryDialogCancelAction),
    ),
    FilledButton(
      key: const Key("ocptBudgetNewContinueButton"),
      onPressed: _gesture == null ? null : _handleGestureContinue,
      child: Text(tr.budgetEntryWizardContinueAction),
    ),
  ];

  void _handleCancel() => globalGetIt().get<OcptRouterManager>().pop();

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
          ? _OcptBudgetNewStep.form
          : _OcptBudgetNewStep.attachment;
    });
  }

  // ===============================================================================================
  // Step 2 — the attachment
  // ===============================================================================================

  Widget _buildAttachmentStep(BuildContext context, Tr tr) {
    final gesture = _gesture;
    if (gesture == null) {
      return const SizedBox.shrink();
    }

    return switch (ocptBudgetGestureAttachmentOf(gesture)) {
      OcptBudgetGestureAttachment.none => const SizedBox.shrink(),
      OcptBudgetGestureAttachment.poste => _buildPosteAttachment(context, tr, offersOffQuote: false),
      OcptBudgetGestureAttachment.optionalPoste => _buildPosteAttachment(
        context,
        tr,
        offersOffQuote: true,
      ),
      OcptBudgetGestureAttachment.posteAndLine => _buildPosteAndLineAttachment(context, tr),
      OcptBudgetGestureAttachment.financingResource => _buildResourceAttachment(context, tr),
      OcptBudgetGestureAttachment.taking => _buildRevenueAttachment(context, tr),
      OcptBudgetGestureAttachment.participant => _buildParticipantAttachment(context, tr),
      OcptBudgetGestureAttachment.person => _buildPersonAttachment(context, tr),
    };
  }

  Widget _buildPosteAttachment(BuildContext context, Tr tr, {required bool offersOffQuote}) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final poste in widget.postes)
        _OcptBudgetNewChoiceRow(
          label: ocptBudgetPosteDisplayLabel(poste, isSimplified: widget.isSimplified),
          isSelected: _posteAnswered && _posteId == poste.id,
          onTap: () => setState(() {
            _posteId = poste.id;
            _posteAnswered = true;
          }),
        ),
      if (offersOffQuote)
        _OcptBudgetNewChoiceRow(
          key: const Key("ocptBudgetNewOffQuoteChoice"),
          label: tr.budgetCostTrackingOffQuoteLabel,
          hint: tr.budgetEntryWizardPosteFieldHint(tr.budgetCostTrackingOffQuoteLabel),
          isSelected: _posteAnswered && _posteId == null,
          onTap: () => setState(() {
            _posteId = null;
            _posteAnswered = true;
          }),
        ),
    ],
  );

  Widget _buildPosteAndLineAttachment(BuildContext context, Tr tr) {
    if (!_posteAnswered) {
      return _buildPosteAttachment(context, tr, offersOffQuote: false);
    }

    final poste = widget.postes.where((poste) => poste.id == _posteId).firstOrNull;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                poste == null
                    ? tr.budgetPosteUnnamed
                    : ocptBudgetPosteDisplayLabel(poste, isSimplified: widget.isSimplified),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            InkWell(
              onTap: () => setState(() {
                _posteAnswered = false;
                _lineId = null;
                _lineNoneAnswered = false;
              }),
              mouseCursor: ocptClickableCursor,
              child: Text(
                tr.budgetEntryWizardChangeNatureAction,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final line in poste?.lines ?? const <OcptBudgetLine>[])
          _OcptBudgetNewChoiceRow(
            label: line.label.isEmpty ? tr.budgetPosteUnnamed : line.label,
            hint: tr.budgetNewLinePickerHint(
              ocptBudgetAmountLabel(ocptBudgetLineTotalCents(line), widget.currencyCode),
              widget.commitments.any((commitment) => commitment.lineId == line.id)
                  ? tr.budgetNewLineAlreadyCommittedHint
                  : tr.budgetNewLineNotCommittedHint,
            ),
            isSelected: !_lineNoneAnswered && _lineId == line.id,
            isEnabled: !widget.commitments.any((commitment) => commitment.lineId == line.id),
            onTap: () => setState(() {
              _lineId = line.id;
              _lineNoneAnswered = false;
            }),
          ),
        _OcptBudgetNewChoiceRow(
          key: const Key("ocptBudgetNewNoLineChoice"),
          label: tr.budgetNewNoLineAnswer,
          hint: tr.budgetNewNoLineHint,
          isSelected: _lineNoneAnswered,
          onTap: () => setState(() {
            _lineId = null;
            _lineNoneAnswered = true;
          }),
        ),
      ],
    );
  }

  Widget _buildResourceAttachment(BuildContext context, Tr tr) {
    final byFamily = <OcptBudgetResourceFamily, List<OcptBudgetResource>>{};
    for (final resource in widget.resources) {
      (byFamily[OcptBudgetResourceFamily.of(resource.groupKind)] ??= []).add(resource);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final family in [OcptBudgetResourceFamily.subsidies, OcptBudgetResourceFamily.contributions])
          if (byFamily[family]?.isNotEmpty ?? false) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                ocptBudgetResourceFamilyLabel(tr, family),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            for (final resource in byFamily[family]!)
              _OcptBudgetNewChoiceRow(
                label: resource.label.isEmpty ? tr.budgetPosteUnnamed : resource.label,
                hint: tr.budgetNewResourceChoiceHint(
                  ocptBudgetAmountLabel(resource.amountCents, widget.currencyCode),
                  ocptBudgetAmountLabel(
                    widget.receivedByResourceId[resource.id]?.amountCents ?? 0,
                    widget.currencyCode,
                  ),
                  ocptBudgetAmountLabel(
                    ocptBudgetResourceOutstandingCents(
                      amountCents: resource.amountCents,
                      receivedCents: widget.receivedByResourceId[resource.id]?.amountCents ?? 0,
                    ),
                    widget.currencyCode,
                  ),
                ),
                isSelected: _pendingNewResource == null && _resourceId == resource.id,
                onTap: () => setState(() {
                  _resourceId = resource.id;
                  _pendingNewResource = null;
                }),
              ),
          ],
        if (_pendingNewResource case final pendingNewResource?)
          _OcptBudgetNewChoiceRow(
            key: const Key("ocptBudgetNewPendingResourceChoice"),
            label: tr.budgetNewWillCreateLabel(pendingNewResource.label),
            isSelected: true,
            onTap: () {},
          ),
        _OcptBudgetNewChoiceRow(
          key: const Key("ocptBudgetNewCreateResourceChoice"),
          label: tr.budgetNewCreateResourceAction,
          isSelected: false,
          isCreationRow: true,
          onTap: () => unawaited(_handleCreateResourceRequested(context)),
        ),
      ],
    );
  }

  Future<void> _handleCreateResourceRequested(BuildContext context) async {
    final fields = await OcptBudgetResourceDialog.show(
      context,
      existing: null,
      groupKind: OcptBudgetResourceGroupKind.cash,
      people: widget.people,
      currencyCode: widget.currencyCode,
      // Both gestures reaching this row (`recordFinancingReceipt`, `repayContribution`) move real
      // money, so the resource missing here is a contribution — cash or in-kind, the one question
      // left for its own dialog to ask.
      offerCashOrInKindChoice: true,
    );
    if (fields == null || !mounted) {
      return;
    }

    setState(() {
      _pendingNewResource = fields;
      _resourceId = null;
    });
  }

  Widget _buildRevenueAttachment(BuildContext context, Tr tr) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final revenue in widget.revenues)
        _OcptBudgetNewChoiceRow(
          label: revenue.label.isEmpty ? tr.budgetPosteUnnamed : revenue.label,
          hint: tr.budgetNewRevenueChoiceHint(
            ocptBudgetAmountLabel(revenue.amountCents, widget.currencyCode),
            ocptBudgetAmountLabel(
              widget.receivedByRevenueId[revenue.id]?.amountCents ?? 0,
              widget.currencyCode,
            ),
          ),
          isSelected: _pendingNewRevenue == null && _revenueId == revenue.id,
          onTap: () => setState(() {
            _revenueId = revenue.id;
            _pendingNewRevenue = null;
          }),
        ),
      if (_pendingNewRevenue case final pendingNewRevenue?)
        _OcptBudgetNewChoiceRow(
          key: const Key("ocptBudgetNewPendingRevenueChoice"),
          label: tr.budgetNewWillCreateLabel(pendingNewRevenue.label),
          isSelected: true,
          onTap: () {},
        ),
      _OcptBudgetNewChoiceRow(
        key: const Key("ocptBudgetNewCreateRevenueChoice"),
        label: tr.budgetEntryDialogNewRevenueAction,
        isSelected: false,
        isCreationRow: true,
        onTap: () => unawaited(_handleCreateRevenueRequested(context)),
      ),
    ],
  );

  Future<void> _handleCreateRevenueRequested(BuildContext context) async {
    final fields = await OcptBudgetRevenueDialog.show(
      context,
      existing: null,
      currencyCode: widget.currencyCode,
    );
    if (fields == null || !mounted) {
      return;
    }

    setState(() {
      _pendingNewRevenue = fields;
      _revenueId = null;
    });
  }

  Widget _buildParticipantAttachment(BuildContext context, Tr tr) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final share in widget.shares)
        _OcptBudgetNewChoiceRow(
          label: share.label.isEmpty ? tr.budgetPosteUnnamed : share.label,
          isSelected: _pendingNewShare == null && _shareId == share.id,
          onTap: () => setState(() {
            _shareId = share.id;
            _pendingNewShare = null;
          }),
        ),
      if (_pendingNewShare case final pendingNewShare?)
        _OcptBudgetNewChoiceRow(
          key: const Key("ocptBudgetNewPendingShareChoice"),
          label: tr.budgetNewWillCreateLabel(pendingNewShare.label),
          isSelected: true,
          onTap: () {},
        ),
      _OcptBudgetNewChoiceRow(
        key: const Key("ocptBudgetNewCreateShareChoice"),
        label: tr.budgetNewCreateParticipantAction,
        isSelected: false,
        isCreationRow: true,
        onTap: () => unawaited(_handleCreateShareRequested(context)),
      ),
    ],
  );

  Future<void> _handleCreateShareRequested(BuildContext context) async {
    final fields = await OcptBudgetShareDialog.show(context, existing: null, people: widget.people);
    if (fields == null || !mounted) {
      return;
    }

    setState(() {
      _pendingNewShare = fields;
      _shareId = null;
    });
  }

  Widget _buildPersonAttachment(BuildContext context, Tr tr) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final person in widget.people)
        _OcptBudgetNewChoiceRow(
          label: person.displayName,
          isSelected: _personId == person.id,
          onTap: () => setState(() => _personId = person.id),
        ),
    ],
  );

  bool get _isAttachmentAnswered {
    final gesture = _gesture;
    if (gesture == null) {
      return false;
    }

    return switch (ocptBudgetGestureAttachmentOf(gesture)) {
      OcptBudgetGestureAttachment.none => true,
      OcptBudgetGestureAttachment.poste || OcptBudgetGestureAttachment.optionalPoste => _posteAnswered,
      OcptBudgetGestureAttachment.posteAndLine =>
        _posteAnswered && (_lineId != null || _lineNoneAnswered),
      OcptBudgetGestureAttachment.financingResource =>
        _resourceId != null || _pendingNewResource != null,
      OcptBudgetGestureAttachment.taking => _revenueId != null || _pendingNewRevenue != null,
      OcptBudgetGestureAttachment.participant => _shareId != null || _pendingNewShare != null,
      OcptBudgetGestureAttachment.person => _personId != null,
    };
  }

  List<Widget> _buildAttachmentActions(Tr tr) => [
    TextButton(
      key: const Key("ocptBudgetNewBackButton"),
      onPressed: () => setState(() => _step = _OcptBudgetNewStep.gesture),
      child: Text(tr.budgetEntryDialogBackAction),
    ),
    FilledButton(
      key: const Key("ocptBudgetNewAttachmentContinueButton"),
      onPressed: _isAttachmentAnswered ? () => setState(() => _step = _OcptBudgetNewStep.form) : null,
      child: Text(tr.budgetEntryWizardContinueAction),
    ),
  ];

  // ===============================================================================================
  // Step 3 — the money, or the form
  // ===============================================================================================

  Widget _buildFormStep(BuildContext context, Tr tr) {
    final gesture = _gesture;
    if (gesture == null) {
      return const SizedBox.shrink();
    }

    if (ocptBudgetGestureNatureOf(gesture) != null) {
      return _buildMovementForm(context, tr);
    }

    return switch (gesture) {
      OcptBudgetGesture.addQuoteLine => OcptBudgetLineFormBody(
        currencyCode: widget.currencyCode,
        formKey: _formKey,
        onDraftChanged: (draft) => setState(() => _lineDraft = draft),
      ),
      OcptBudgetGesture.addQuoteLinesFromBreakdown => _buildBreakdownStep(context, tr),
      OcptBudgetGesture.commitSpend => OcptBudgetCommitmentFormBody(
        existing: null,
        prefill: widget.commitmentPrefill ?? _commitmentPrefillOf(),
        postes: widget.postes,
        currencyCode: widget.currencyCode,
        defaultVatRateBasisPoints: widget.defaultVatRateBasisPoints,
        isSimplified: widget.isSimplified,
        formKey: _formKey,
        onDraftChanged: (draft) => setState(() => _commitmentDraft = draft),
        onMissingFieldsHintChanged: (hint) => setState(() => _commitmentMissingHint = hint),
        // Step 2 has already asked the poste (`posteAndLine`, or `commitmentPrefill`'s own
        // shortcut) — drawing the picker again here would ask the same question twice.
        posteAlreadyAnswered: true,
      ),
      OcptBudgetGesture.planSubsidy => OcptBudgetResourceFormBody(
        existing: null,
        groupKind: OcptBudgetResourceGroupKind.subsidy,
        people: widget.people,
        currencyCode: widget.currencyCode,
        formKey: _formKey,
        onDraftChanged: (draft) => setState(() => _resourceDraft = draft),
      ),
      OcptBudgetGesture.planContribution => OcptBudgetResourceFormBody(
        existing: null,
        groupKind: OcptBudgetResourceGroupKind.cash,
        people: widget.people,
        currencyCode: widget.currencyCode,
        formKey: _formKey,
        onDraftChanged: (draft) => setState(() => _resourceDraft = draft),
        // `planContribution` collapses cash and in-kind into one gesture — the picker is the one
        // question left for this step to ask, offering only the two.
        offerCashOrInKindChoice: true,
      ),
      OcptBudgetGesture.planTaking => OcptBudgetRevenueFormBody(
        existing: null,
        currencyCode: widget.currencyCode,
        formKey: _formKey,
        onDraftChanged: (draft) => setState(() => _revenueDraft = draft),
      ),
      OcptBudgetGesture.defrayPerson => OcptBudgetAllowanceFormBody(
        existing: null,
        people: widget.people,
        mileageRates: widget.mileageRates,
        currencyCode: widget.currencyCode,
        formKey: _formKey,
        onDraftChanged: (draft) => setState(() => _allowanceDraft = draft),
      ),
      OcptBudgetGesture.addSharingParticipant => OcptBudgetShareFormBody(
        existing: null,
        people: widget.people,
        formKey: _formKey,
        onDraftChanged: (draft) => setState(() => _shareDraft = draft),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  /// `commitSpend`'s own prefill when reached through the ordinary three-step flow (a poste, and
  /// optionally a line, just answered in step 2) — mirrors `budget_mode.dart`'s own
  /// `_handleLineCommitRequested`, everything the line already states carried across.
  OcptBudgetCommitmentFormFields? _commitmentPrefillOf() {
    final posteId = _posteId;
    if (posteId == null && !_posteAnswered) {
      return null;
    }

    final line = _lineNoneAnswered ? null : _lineById(_lineId);
    return OcptBudgetCommitmentFormFields(
      dueDate: null,
      label: line?.label ?? "",
      posteId: posteId ?? "",
      amountCents: line == null ? 0 : ocptBudgetLineTotalCents(line),
      isTaxInclusive: line?.unitPrice.isTaxInclusive ?? true,
      vatRateBasisPoints: line?.unitPrice.vatRateBasisPoints,
      status: OcptBudgetCommitmentStatus.quoteAccepted,
    );
  }

  OcptBudgetLine? _lineById(String? lineId) {
    if (lineId == null) {
      return null;
    }
    for (final poste in widget.postes) {
      final line = poste.lines.where((line) => line.id == lineId).firstOrNull;
      if (line != null) {
        return line;
      }
    }
    return null;
  }

  List<Widget> _buildFormActions(BuildContext context, Tr tr) {
    final gesture = _gesture;
    final attachment = gesture == null
        ? OcptBudgetGestureAttachment.none
        : ocptBudgetGestureAttachmentOf(gesture);

    return [
      TextButton(
        key: const Key("ocptBudgetNewFormBackButton"),
        onPressed: () => setState(
          () => _step = attachment == OcptBudgetGestureAttachment.none
              ? _OcptBudgetNewStep.gesture
              : _OcptBudgetNewStep.attachment,
        ),
        child: Text(tr.budgetEntryDialogBackAction),
      ),
      _buildPrimaryFormAction(context, tr),
    ];
  }

  Widget _buildPrimaryFormAction(BuildContext context, Tr tr) {
    final gesture = _gesture;
    if (gesture == null) {
      return const SizedBox.shrink();
    }

    if (gesture == OcptBudgetGesture.addQuoteLinesFromBreakdown) {
      return FilledButton(
        key: const Key("ocptBudgetNewCreateLinesButton"),
        onPressed: _breakdownSelectedIds.isEmpty ? null : _submitBreakdown,
        child: Text(tr.budgetNewCreateLinesAction(_breakdownSelectedIds.length)),
      );
    }

    final onPressed = switch (gesture) {
      OcptBudgetGesture.addQuoteLine => _lineDraft == null ? null : _submitLine,
      OcptBudgetGesture.commitSpend => _commitmentMissingHint != null || _commitmentDraft == null
          ? null
          : _submitCommitment,
      OcptBudgetGesture.planSubsidy || OcptBudgetGesture.planContribution =>
        _resourceDraft == null ? null : _submitResource,
      OcptBudgetGesture.planTaking => _revenueDraft == null ? null : _submitRevenue,
      OcptBudgetGesture.defrayPerson => _allowanceDraft == null ? null : _submitAllowance,
      OcptBudgetGesture.addSharingParticipant => _shareDraft == null ? null : _submitShare,
      _ => _submitMovement,
    };

    return FilledButton(
      key: const Key("ocptBudgetNewSaveButton"),
      onPressed: onPressed,
      child: Text(tr.budgetEntryDialogConfirmAction),
    );
  }

  void _pop(OcptBudgetNewOutcome outcome) =>
      globalGetIt().get<OcptRouterManager>().pop<OcptBudgetNewOutcome>(outcome);

  void _submitLine() {
    final draft = _lineDraft;
    final posteId = _posteId;
    if (!(_formKey.currentState?.validate() ?? false) || draft == null || posteId == null) {
      return;
    }
    _pop(OcptBudgetNewLineOutcome(posteId: posteId, fields: draft));
  }

  void _submitCommitment() {
    final draft = _commitmentDraft;
    if (!(_formKey.currentState?.validate() ?? false) || draft == null) {
      return;
    }
    _pop(
      OcptBudgetNewCommitmentOutcome(
        fields: draft,
        lineId: widget.commitmentPrefillLineId ?? (_lineNoneAnswered ? null : _lineId),
      ),
    );
  }

  void _submitResource() {
    final draft = _resourceDraft;
    if (!(_formKey.currentState?.validate() ?? false) || draft == null) {
      return;
    }
    _pop(OcptBudgetNewResourceOutcome(fields: draft));
  }

  void _submitRevenue() {
    final draft = _revenueDraft;
    if (!(_formKey.currentState?.validate() ?? false) || draft == null) {
      return;
    }
    _pop(OcptBudgetNewRevenueOutcome(fields: draft));
  }

  void _submitAllowance() {
    final draft = _allowanceDraft;
    if (!(_formKey.currentState?.validate() ?? false) || draft == null) {
      return;
    }
    _pop(OcptBudgetNewAllowanceOutcome(fields: draft));
  }

  void _submitShare() {
    final draft = _shareDraft;
    if (!(_formKey.currentState?.validate() ?? false) || draft == null) {
      return;
    }
    _pop(OcptBudgetNewShareOutcome(fields: draft));
  }

  // -----------------------------------------------------------------------------------------
  // The movement form — the seven `cashMovement` gestures.
  // -----------------------------------------------------------------------------------------

  Widget _buildMovementForm(BuildContext context, Tr tr) {
    final currencySymbol = NumberFormat.simpleCurrency(name: widget.currencyCode).currencySymbol;
    final suggestions = _lettrageSuggestionsOf();

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateAmountBasisRow(context, tr, currencySymbol),
          const SizedBox(height: 12),
          _labelAbove(
            context,
            label: tr.budgetEntryDialogLabelFieldLabel,
            child: TextFormField(
              key: const Key("ocptBudgetNewLabelField"),
              controller: _labelController,
              autofocus: true,
              decoration: const InputDecoration(isDense: true),
              validator: (value) =>
                  (value ?? "").trim().isEmpty ? tr.budgetEntryDialogLabelRequiredError : null,
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildLettrageStrip(context, tr, suggestions),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildVatField(context, tr)),
              const SizedBox(width: 12),
              Expanded(child: _buildReceiptField(context, tr)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tr.budgetEntryDialogVoucherAutoHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (_gesture == OcptBudgetGesture.recordOtherMovement) ...[
            const SizedBox(height: 12),
            _buildDirectionField(context, tr),
          ],
        ],
      ),
    );
  }

  /// The field's own label above it, dense — the one idiom every field of step 3 shares
  /// (`docs/plans/budget-capture-wizard.md`).
  Widget _labelAbove(BuildContext context, {required String label, required Widget child}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildDateAmountBasisRow(BuildContext context, Tr tr, String currencySymbol) => Row(
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
        child: _labelAbove(
          context,
          label: tr.budgetEntryDialogAmountFieldLabel,
          child: TextFormField(
            key: const Key("ocptBudgetNewAmountField"),
            controller: _amountController,
            decoration: InputDecoration(isDense: true, suffixText: currencySymbol),
            validator: (value) =>
                ocptCostCentsOf(value ?? "") == null ? tr.budgetEntryDialogAmountInvalidError : null,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
      const SizedBox(width: 12),
      IntrinsicWidth(
        child: _labelAbove(
          context,
          label: tr.budgetEntryDialogTaxBasisFieldLabel,
          child: OcptBudgetBinaryChoice(
            value: _isTaxInclusive,
            trueLabel: tr.budgetLineTaxInclusiveOption,
            falseLabel: tr.budgetLineTaxExclusiveOption,
            onChanged: (value) => setState(() => _isTaxInclusive = value),
          ),
        ),
      ),
    ],
  );

  Widget _buildDirectionField(BuildContext context, Tr tr) => _labelAbove(
    context,
    label: tr.budgetEntryDialogDirectionFieldLabel,
    child: OcptBudgetBinaryChoice(
      value: _isDebit,
      trueLabel: widget.isSimplified ? tr.budgetEntryDialogPaidOption : tr.budgetEntryDialogDebitOption,
      falseLabel: widget.isSimplified
          ? tr.budgetEntryDialogReceivedOption
          : tr.budgetEntryDialogCreditOption,
      onChanged: (value) => setState(() => _isDebit = value),
    ),
  );

  Widget _buildVatField(BuildContext context, Tr tr) {
    final defaultVatRateBasisPoints = widget.defaultVatRateBasisPoints;
    final vatRateHint = defaultVatRateBasisPoints == null
        ? null
        : tr.budgetLineVatRateInheritedHint(ocptVatRatePercentTextOf(defaultVatRateBasisPoints));

    return _labelAbove(
      context,
      label: tr.budgetLineVatRateFieldLabel,
      child: TextFormField(
        controller: _vatRateController,
        decoration: InputDecoration(isDense: true, hintText: vatRateHint, suffixText: tr.budgetLineVatRateSuffix),
      ),
    );
  }

  Widget _buildReceiptField(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final pickedReceiptPath = _pickedReceiptPath;

    return _labelAbove(
      context,
      label: tr.budgetEntryDialogReceiptFieldLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pickedReceiptPath != null)
            OcptAssetFileLine(
              asset: OcptAssetRef(
                id: "",
                kind: OcptAssetKind.receipt,
                path: pickedReceiptPath,
                label: "",
                addedAt: DateTime.now(),
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
                pickedReceiptPath == null
                    ? tr.budgetEntryDialogReceiptAttachAction
                    : tr.budgetEntryDialogReceiptReplaceAction,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  // -----------------------------------------------------------------------------------------
  // The lettrage strip
  // -----------------------------------------------------------------------------------------

  ({int amountCents, String wording})? get _saveableDraft {
    final amountCents = ocptCostCentsOf(_amountController.text);
    final wording = _labelController.text.trim();
    if (amountCents == null || amountCents <= 0 || wording.isEmpty) {
      return null;
    }
    return (amountCents: amountCents, wording: wording);
  }

  List<OcptBudgetMatchSuggestion> _lettrageSuggestionsOf() {
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
      entries: widget.entries,
      allowances: widget.allowances,
      resources: widget.resources,
      revenues: widget.revenues,
      receivedByResourceId: widget.receivedByResourceId,
      receivedByRevenueId: widget.receivedByRevenueId,
      projectVatRateBasisPoints: widget.defaultVatRateBasisPoints,
    );
  }

  /// The lettrage strip: what accepting one of [suggestions] does, why each was ranked, and every
  /// candidate reachable, `Aucun` included — never a single best guess with no way to say
  /// otherwise. It stops the same money being counted twice: without it, a user records the payment,
  /// forgets to settle the commitment it was for, and the poste reads both committed and paid for the
  /// very same transfer.
  Widget _buildLettrageStrip(BuildContext context, Tr tr, List<OcptBudgetMatchSuggestion> suggestions) {
    final theme = Theme.of(context);
    final selectedIndex = _selectedSuggestionIndex;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.budgetNewLettrageTitle,
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final (index, suggestion) in suggestions.indexed)
            _buildLettrageCandidateRow(context, tr, index, suggestion, selectedIndex == index),
          _buildLettrageNoneRow(context, tr, selectedIndex == null),
        ],
      ),
    );
  }

  Widget _buildLettrageCandidateRow(
    BuildContext context,
    Tr tr,
    int index,
    OcptBudgetMatchSuggestion suggestion,
    bool isSelected,
  ) {
    final theme = Theme.of(context);

    return InkWell(
      key: Key("ocptBudgetNewLettrageCandidate$index"),
      onTap: () => setState(() => _selectedSuggestionIndex = index),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 16,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_lettrageHeadlineOf(context, tr, suggestion), style: theme.textTheme.bodySmall),
                  Text(
                    _lettrageReasonsOf(tr, suggestion),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLettrageNoneRow(BuildContext context, Tr tr, bool isSelected) {
    final theme = Theme.of(context);

    return InkWell(
      key: const Key("ocptBudgetNewLettrageNone"),
      onTap: () => setState(() => _selectedSuggestionIndex = null),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 16,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(tr.budgetNewLettrageNoneAction, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  String _lettrageReasonsOf(Tr tr, OcptBudgetMatchSuggestion suggestion) {
    final reasons = [
      if (suggestion.matchesAmount) tr.budgetNewLettrageReasonAmount,
      if (suggestion.matchesDate) tr.budgetNewLettrageReasonDate,
      if (suggestion.matchesWording) tr.budgetNewLettrageReasonWording,
    ];
    return reasons.join(" · ");
  }

  String _lettrageHeadlineOf(BuildContext context, Tr tr, OcptBudgetMatchSuggestion suggestion) {
    final currencyCode = widget.currencyCode;

    switch (suggestion.kind) {
      case OcptBudgetMatchCandidateKind.commitment:
        final amountLabel = suggestion.outstandingCents == null
            ? ""
            : ocptBudgetAmountLabel(suggestion.outstandingCents!, currencyCode);
        final posteLabel = _commitmentPosteLabelOf(tr, suggestion);
        final date = suggestion.date;
        if (date == null) {
          return tr.budgetEntryMatchCommitmentHeadlineUndated(suggestion.label, amountLabel, posteLabel);
        }
        return tr.budgetEntryMatchCommitmentHeadlineDated(
          suggestion.label,
          amountLabel,
          posteLabel,
          DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date),
        );

      case OcptBudgetMatchCandidateKind.resource:
        return tr.budgetEntryMatchResourceHeadline(
          suggestion.label,
          ocptBudgetAmountLabel(suggestion.amountCents ?? 0, currencyCode),
          ocptBudgetAmountLabel(_receivedCentsOf(suggestion), currencyCode),
          ocptBudgetAmountLabel(suggestion.outstandingCents ?? 0, currencyCode),
        );

      case OcptBudgetMatchCandidateKind.revenue:
        return tr.budgetEntryMatchRevenueHeadline(
          suggestion.label,
          ocptBudgetAmountLabel(suggestion.amountCents ?? 0, currencyCode),
          ocptBudgetAmountLabel(_receivedCentsOf(suggestion), currencyCode),
          ocptBudgetAmountLabel(suggestion.outstandingCents ?? 0, currencyCode),
        );

      case OcptBudgetMatchCandidateKind.defrayal:
        return tr.budgetEntryMatchDefrayalHeadline(
          suggestion.label,
          ocptBudgetAmountLabel(suggestion.amountCents ?? 0, currencyCode),
        );
    }
  }

  int _receivedCentsOf(OcptBudgetMatchSuggestion suggestion) =>
      (suggestion.amountCents ?? 0) - (suggestion.outstandingCents ?? 0);

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
    final acceptedSuggestion =
        selectedIndex != null && selectedIndex < suggestions.length ? suggestions[selectedIndex] : null;

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
      OcptBudgetEntryWizardResult(fields: _movementFieldsOf(amountCents), acceptedSuggestion: null),
    );
  }

  OcptBudgetEntryFormFields _movementFieldsOf(int amountCents) {
    final gesture = _gesture!;

    return OcptBudgetEntryFormFields(
      date: _date,
      label: _labelController.text.trim(),
      posteId: gesture == OcptBudgetGesture.recordExpense || gesture == OcptBudgetGesture.recordOtherMovement
          ? _posteId
          : null,
      resourceId: gesture == OcptBudgetGesture.recordFinancingReceipt ||
              gesture == OcptBudgetGesture.repayContribution
          ? (_pendingNewResource == null ? _resourceId : null)
          : null,
      revenueId: gesture == OcptBudgetGesture.recordTakingReceipt
          ? (_pendingNewRevenue == null ? _revenueId : null)
          : null,
      shareId: gesture == OcptBudgetGesture.payParticipantShare
          ? (_pendingNewShare == null ? _shareId : null)
          : null,
      personId: gesture == OcptBudgetGesture.reimbursePerson ? _personId : null,
      newResource: gesture == OcptBudgetGesture.recordFinancingReceipt ||
              gesture == OcptBudgetGesture.repayContribution
          ? _pendingNewResource
          : null,
      newRevenue: gesture == OcptBudgetGesture.recordTakingReceipt ? _pendingNewRevenue : null,
      newShare: gesture == OcptBudgetGesture.payParticipantShare ? _pendingNewShare : null,
      isDebit: _isDebit,
      amountCents: amountCents,
      isTaxInclusive: _isTaxInclusive,
      vatRateBasisPoints: ocptVatRateBasisPointsOf(_vatRateController.text),
      voucherNumber: null,
      pickedReceiptPath: _pickedReceiptPath,
      isReceiptDetached: _isReceiptDetached,
    );
  }

  // ===============================================================================================
  // The breakdown selector — `addQuoteLinesFromBreakdown`
  // ===============================================================================================

  Widget _buildBreakdownStep(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final query = _breakdownQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.unpricedElements
        : [
            for (final element in widget.unpricedElements)
              if (element.name.toLowerCase().contains(query)) element,
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: tr.budgetLineFromElementSearchHint,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _breakdownQuery = value),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              tr.budgetLineFromElementEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final element in filtered) _buildBreakdownRow(context, tr, element),
      ],
    );
  }

  Widget _buildBreakdownRow(BuildContext context, Tr tr, OcptElement element) {
    final theme = Theme.of(context);
    final isSelected = _breakdownSelectedIds.contains(element.id);
    final controller = _breakdownQuantityControllers.putIfAbsent(
      element.id,
      () => TextEditingController(
        text: ocptBudgetQuantityLabel(_breakdownDefaultQuantityMilliOf(element)),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            key: Key("ocptBudgetNewBreakdownCheckbox-${element.id}"),
            value: isSelected,
            onChanged: (checked) => setState(() {
              if (checked ?? false) {
                _breakdownSelectedIds.add(element.id);
                _breakdownQuantityMilliByElementId[element.id] =
                    ocptBudgetQuantityMilliOf(controller.text) ??
                    _breakdownDefaultQuantityMilliOf(element);
              } else {
                _breakdownSelectedIds.remove(element.id);
                _breakdownQuantityMilliByElementId.remove(element.id);
              }
            }),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(element.name.isEmpty ? tr.resourcesElementUnnamed : element.name),
                Text(
                  tr.budgetNewBreakdownSceneCountHint(element.sceneLinks.length),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              key: Key("ocptBudgetNewBreakdownQuantity-${element.id}"),
              controller: controller,
              enabled: isSelected,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true),
              onChanged: (value) {
                final quantityMilli = ocptBudgetQuantityMilliOf(value);
                if (quantityMilli != null) {
                  _breakdownQuantityMilliByElementId[element.id] = quantityMilli;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The quantity a fresh row of the breakdown selector is born with, in thousandths — the number
  /// of scenes [element] appears in. A suggestion, never a truth: right for a rostrum hired by the
  /// day, wrong for a backdrop built once, corrected in the table before creating rather than
  /// decided by the app.
  int _breakdownDefaultQuantityMilliOf(OcptElement element) =>
      (element.sceneLinks.isEmpty ? 1 : element.sceneLinks.length) * 1000;

  void _submitBreakdown() {
    final posteId = _posteId;
    if (posteId == null || _breakdownSelectedIds.isEmpty) {
      return;
    }

    _pop(
      OcptBudgetNewLinesFromBreakdownOutcome(
        posteId: posteId,
        lines: [
          for (final elementId in _breakdownSelectedIds)
            (
              elementId: elementId,
              quantityMilli: _breakdownQuantityMilliByElementId[elementId] ?? 1000,
            ),
        ],
      ),
    );
  }
}

/// One card of step 1 — a bold answer over its own muted hint, tinted `primary` while selected.
/// Mirrors `_OcptBudgetEntryNatureCard`, one card per [OcptBudgetGesture] rather than per
/// `OcptBudgetEntryNature`.
class _OcptBudgetNewGestureCard extends StatelessWidget {
  final OcptBudgetGesture gesture;
  final bool isSelected;
  final VoidCallback onSelected;

  const _OcptBudgetNewGestureCard({
    required this.gesture,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      key: Key("ocptBudgetNewGestureCard-${gesture.name}"),
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
              _ocptBudgetGestureAnswerLabel(tr, gesture),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _ocptBudgetGestureHint(tr, gesture),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable row of step 2 — a plain list row, tinted `primary` while selected, an optional
/// muted hint underneath.
class _OcptBudgetNewChoiceRow extends StatelessWidget {
  final String label;
  final String? hint;
  final bool isSelected;
  final bool isEnabled;
  final bool isCreationRow;
  final VoidCallback onTap;

  const _OcptBudgetNewChoiceRow({
    super.key,
    required this.label,
    this.hint,
    required this.isSelected,
    this.isEnabled = true,
    this.isCreationRow = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = !isEnabled
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
        : (isCreationRow ? theme.colorScheme.primary : theme.colorScheme.onSurface);

    return InkWell(
      onTap: isEnabled ? onTap : null,
      mouseCursor: isEnabled ? ocptClickableCursor : SystemMouseCursors.forbidden,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha) : null,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Row(
          children: [
            if (isCreationRow) ...[
              Icon(Icons.add, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: isCreationRow || isSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  if (hint case final hint?)
                    Text(
                      hint,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [gesture]'s own bold answer label — the fifteen answers, per the class doc comment's table.
String _ocptBudgetGestureAnswerLabel(Tr tr, OcptBudgetGesture gesture) => switch (gesture) {
  OcptBudgetGesture.addQuoteLine => tr.budgetNewGestureAddQuoteLineLabel,
  OcptBudgetGesture.addQuoteLinesFromBreakdown => tr.budgetNewGestureAddQuoteLinesFromBreakdownLabel,
  OcptBudgetGesture.commitSpend => tr.budgetNewGestureCommitSpendLabel,
  OcptBudgetGesture.recordExpense => tr.budgetNewGestureRecordExpenseLabel,
  OcptBudgetGesture.recordFinancingReceipt => tr.budgetNewGestureRecordFinancingReceiptLabel,
  OcptBudgetGesture.recordTakingReceipt => tr.budgetNewGestureRecordTakingReceiptLabel,
  OcptBudgetGesture.reimbursePerson => tr.budgetNewGestureReimbursePersonLabel,
  OcptBudgetGesture.payParticipantShare => tr.budgetNewGesturePayParticipantShareLabel,
  OcptBudgetGesture.repayContribution => tr.budgetNewGestureRepayContributionLabel,
  OcptBudgetGesture.recordOtherMovement => tr.budgetNewGestureRecordOtherMovementLabel,
  OcptBudgetGesture.planSubsidy => tr.budgetNewGesturePlanSubsidyLabel,
  OcptBudgetGesture.planContribution => tr.budgetNewGesturePlanContributionLabel,
  OcptBudgetGesture.planTaking => tr.budgetNewGesturePlanTakingLabel,
  OcptBudgetGesture.defrayPerson => tr.budgetNewGestureDefrayPersonLabel,
  OcptBudgetGesture.addSharingParticipant => tr.budgetNewGestureAddSharingParticipantLabel,
};

/// [gesture]'s own muted hint — one sentence, every answer carrying its own, not just the complex
/// ones.
String _ocptBudgetGestureHint(Tr tr, OcptBudgetGesture gesture) => switch (gesture) {
  OcptBudgetGesture.addQuoteLine => tr.budgetNewGestureAddQuoteLineHint,
  OcptBudgetGesture.addQuoteLinesFromBreakdown => tr.budgetNewGestureAddQuoteLinesFromBreakdownHint,
  OcptBudgetGesture.commitSpend => tr.budgetNewGestureCommitSpendHint,
  OcptBudgetGesture.recordExpense => tr.budgetNewGestureRecordExpenseHint,
  OcptBudgetGesture.recordFinancingReceipt => tr.budgetNewGestureRecordFinancingReceiptHint,
  OcptBudgetGesture.recordTakingReceipt => tr.budgetNewGestureRecordTakingReceiptHint,
  OcptBudgetGesture.reimbursePerson => tr.budgetNewGestureReimbursePersonHint,
  OcptBudgetGesture.payParticipantShare => tr.budgetNewGesturePayParticipantShareHint,
  OcptBudgetGesture.repayContribution => tr.budgetNewGestureRepayContributionHint,
  OcptBudgetGesture.recordOtherMovement => tr.budgetNewGestureRecordOtherMovementHint,
  OcptBudgetGesture.planSubsidy => tr.budgetNewGesturePlanSubsidyHint,
  OcptBudgetGesture.planContribution => tr.budgetNewGesturePlanContributionHint,
  OcptBudgetGesture.planTaking => tr.budgetNewGesturePlanTakingHint,
  OcptBudgetGesture.defrayPerson => tr.budgetNewGestureDefrayPersonHint,
  OcptBudgetGesture.addSharingParticipant => tr.budgetNewGestureAddSharingParticipantHint,
};

/// [family]'s own heading — the five documents, in the design's own order.
String _ocptBudgetGestureFamilyLabel(Tr tr, OcptBudgetGestureFamily family) => switch (family) {
  OcptBudgetGestureFamily.quote => tr.budgetNewFamilyQuoteLabel,
  OcptBudgetGestureFamily.cashMovement => tr.budgetNewFamilyCashMovementLabel,
  OcptBudgetGestureFamily.financingPlan => tr.budgetNewFamilyFinancingPlanLabel,
  OcptBudgetGestureFamily.allowances => tr.budgetNewFamilyAllowancesLabel,
  OcptBudgetGestureFamily.revenueSharing => tr.budgetNewFamilyRevenueSharingLabel,
};

/// [family]'s own subtitle — the one line stating its tense, telling `J'ai encaissé un financement`
/// apart from `Inscrire une subvention attendue`.
String _ocptBudgetGestureFamilySubtitle(Tr tr, OcptBudgetGestureFamily family) => switch (family) {
  OcptBudgetGestureFamily.quote => tr.budgetNewFamilyQuoteSubtitle,
  OcptBudgetGestureFamily.cashMovement => tr.budgetNewFamilyCashMovementSubtitle,
  OcptBudgetGestureFamily.financingPlan => tr.budgetNewFamilyFinancingPlanSubtitle,
  OcptBudgetGestureFamily.allowances => tr.budgetNewFamilyAllowancesSubtitle,
  OcptBudgetGestureFamily.revenueSharing => tr.budgetNewFamilyRevenueSharingSubtitle,
};
