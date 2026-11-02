// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_reimbursements.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_attachment.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_family.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_choice_row.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// Step 2 — what the movement attaches to: a poste, a poste and one of its lines, a financing
/// resource, a participant or a person, according to the gesture picked on step 1.
class OcptBudgetNewAttachmentStep extends StatelessWidget {
  /// The gesture picked on step 1, or null.
  final OcptBudgetGesture? gesture;

  /// Every live poste of the project.
  final List<OcptBudgetPoste> postes;

  /// Every live financing resource of the project.
  final List<OcptBudgetResource> resources;

  /// Every live revenue-sharing participant of the project.
  final List<OcptBudgetShare> shares;

  /// Every live person of the project's address book.
  final List<OcptPerson> people;

  /// Every live commitment, read to keep `posteAndLine` from offering a line that already carries
  /// one.
  final List<OcptBudgetCommitment> commitments;

  /// Every live defrayal, read for the person picker's advanced figure.
  final List<OcptBudgetAllowance> allowances;

  /// What each financing resource has already received, keyed by its own id.
  final Map<String, OcptBudgetCoveredTotal> receivedByResourceId;

  /// What each defrayed person has already been reimbursed, keyed by their own id.
  final Map<String, OcptBudgetCoveredTotal> reimbursedByPersonId;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the mode's header currently reads simplified.
  final bool isSimplified;

  /// Whether a `poste`/`optionalPoste` answer has been given at all.
  final bool posteAnswered;

  /// The poste answered, or null.
  final String? posteId;

  /// The quote line answered, or null.
  final String? lineId;

  /// Whether `posteAndLine`'s own third answer, `Aucune`, was picked.
  final bool lineNoneAnswered;

  /// The financing resource answered, or null.
  final String? resourceId;

  /// The financing resource waiting to be created along with the movement, or null.
  final OcptBudgetResourceFormFields? pendingNewResource;

  /// The participant answered, or null.
  final String? shareId;

  /// The participant waiting to be created along with the movement, or null.
  final OcptBudgetShareFormFields? pendingNewShare;

  /// The person answered, or null.
  final String? personId;

  /// Called with the poste picked, null standing for the `Hors devis` answer.
  final ValueChanged<String?> onPosteSelected;

  /// Called when the `changer` link of `posteAndLine`'s poste recap is tapped.
  final VoidCallback onPosteChangeRequested;

  /// Called with the quote line picked.
  final ValueChanged<String> onLineSelected;

  /// Called when `posteAndLine`'s `Aucune` row is tapped.
  final VoidCallback onNoLineSelected;

  /// Called with the financing resource picked.
  final ValueChanged<String> onResourceSelected;

  /// Called when the trailing `create a resource` row is tapped.
  final VoidCallback onCreateResourceRequested;

  /// Called with the participant picked.
  final ValueChanged<String> onShareSelected;

  /// Called when the trailing `create a participant` row is tapped.
  final VoidCallback onCreateShareRequested;

  /// Called with the person picked.
  final ValueChanged<String> onPersonSelected;

  /// Class constructor
  const OcptBudgetNewAttachmentStep({
    super.key,
    required this.gesture,
    required this.postes,
    required this.resources,
    required this.shares,
    required this.people,
    required this.commitments,
    required this.allowances,
    required this.receivedByResourceId,
    required this.reimbursedByPersonId,
    required this.currencyCode,
    required this.isSimplified,
    required this.posteAnswered,
    required this.posteId,
    required this.lineId,
    required this.lineNoneAnswered,
    required this.resourceId,
    required this.pendingNewResource,
    required this.shareId,
    required this.pendingNewShare,
    required this.personId,
    required this.onPosteSelected,
    required this.onPosteChangeRequested,
    required this.onLineSelected,
    required this.onNoLineSelected,
    required this.onResourceSelected,
    required this.onCreateResourceRequested,
    required this.onShareSelected,
    required this.onCreateShareRequested,
    required this.onPersonSelected,
  });

  /// Build the budget new attachment step.
  @override
  Widget build(BuildContext context) {
    final gesture = this.gesture;
    if (gesture == null) {
      return const SizedBox.shrink();
    }

    return switch (ocptBudgetGestureAttachmentOf(gesture)) {
      OcptBudgetGestureAttachment.none => const SizedBox.shrink(),
      OcptBudgetGestureAttachment.poste => _OcptBudgetNewPosteAttachment(
        postes: postes,
        isSimplified: isSimplified,
        offersOffQuote: false,
        posteAnswered: posteAnswered,
        posteId: posteId,
        onPosteSelected: onPosteSelected,
      ),
      OcptBudgetGestureAttachment.optionalPoste => _OcptBudgetNewPosteAttachment(
        postes: postes,
        isSimplified: isSimplified,
        offersOffQuote: true,
        posteAnswered: posteAnswered,
        posteId: posteId,
        onPosteSelected: onPosteSelected,
      ),
      OcptBudgetGestureAttachment.posteAndLine => _OcptBudgetNewPosteAndLineAttachment(
        postes: postes,
        commitments: commitments,
        currencyCode: currencyCode,
        isSimplified: isSimplified,
        posteAnswered: posteAnswered,
        posteId: posteId,
        lineId: lineId,
        lineNoneAnswered: lineNoneAnswered,
        onPosteSelected: onPosteSelected,
        onPosteChangeRequested: onPosteChangeRequested,
        onLineSelected: onLineSelected,
        onNoLineSelected: onNoLineSelected,
      ),
      OcptBudgetGestureAttachment.financingResource => _OcptBudgetNewResourceAttachment(
        resources: resources,
        receivedByResourceId: receivedByResourceId,
        currencyCode: currencyCode,
        resourceId: resourceId,
        pendingNewResource: pendingNewResource,
        onResourceSelected: onResourceSelected,
        onCreateResourceRequested: onCreateResourceRequested,
      ),
      OcptBudgetGestureAttachment.participant => _OcptBudgetNewParticipantAttachment(
        shares: shares,
        shareId: shareId,
        pendingNewShare: pendingNewShare,
        onShareSelected: onShareSelected,
        onCreateShareRequested: onCreateShareRequested,
      ),
      OcptBudgetGestureAttachment.person => _OcptBudgetNewPersonAttachment(
        people: people,
        allowances: allowances,
        reimbursedByPersonId: reimbursedByPersonId,
        currencyCode: currencyCode,
        personId: personId,
        onPersonSelected: onPersonSelected,
      ),
    };
  }
}

/// Step 2's poste list — `poste` and `optionalPoste` alike, the latter ending in a `Hors devis`
/// row, and the first half of `posteAndLine`.
class _OcptBudgetNewPosteAttachment extends StatelessWidget {
  /// Every live poste of the project.
  final List<OcptBudgetPoste> postes;

  /// Whether the mode's header currently reads simplified.
  final bool isSimplified;

  /// Whether the trailing `Hors devis` row is offered.
  final bool offersOffQuote;

  /// Whether a poste answer has been given at all.
  final bool posteAnswered;

  /// The poste answered, or null.
  final String? posteId;

  /// Called with the poste picked, null standing for `Hors devis`.
  final ValueChanged<String?> onPosteSelected;

  /// Class constructor
  const _OcptBudgetNewPosteAttachment({
    required this.postes,
    required this.isSimplified,
    required this.offersOffQuote,
    required this.posteAnswered,
    required this.posteId,
    required this.onPosteSelected,
  });

  /// Build the budget new poste attachment as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final poste in postes)
          OcptBudgetNewChoiceRow(
            label: ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified),
            isSelected: posteAnswered && posteId == poste.id,
            onTap: () => onPosteSelected(poste.id),
          ),
        if (offersOffQuote)
          OcptBudgetNewChoiceRow(
            key: const Key("ocptBudgetNewOffQuoteChoice"),
            label: tr.budgetCostTrackingOffQuoteLabel,
            hint: tr.budgetEntryWizardPosteFieldHint(tr.budgetCostTrackingOffQuoteLabel),
            isSelected: posteAnswered && posteId == null,
            onTap: () => onPosteSelected(null),
          ),
      ],
    );
  }
}

/// Step 2 of `posteAndLine`: the poste list while no poste is answered, then the chosen poste's
/// recap over its own quote lines and the `Aucune` row.
class _OcptBudgetNewPosteAndLineAttachment extends StatelessWidget {
  /// Every live poste of the project.
  final List<OcptBudgetPoste> postes;

  /// Every live commitment, read to disable a line that already carries one.
  final List<OcptBudgetCommitment> commitments;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the mode's header currently reads simplified.
  final bool isSimplified;

  /// Whether a poste answer has been given at all.
  final bool posteAnswered;

  /// The poste answered, or null.
  final String? posteId;

  /// The quote line answered, or null.
  final String? lineId;

  /// Whether the `Aucune` row was picked.
  final bool lineNoneAnswered;

  /// Called with the poste picked.
  final ValueChanged<String?> onPosteSelected;

  /// Called when the recap's `changer` link is tapped.
  final VoidCallback onPosteChangeRequested;

  /// Called with the quote line picked.
  final ValueChanged<String> onLineSelected;

  /// Called when the `Aucune` row is tapped.
  final VoidCallback onNoLineSelected;

  /// Class constructor
  const _OcptBudgetNewPosteAndLineAttachment({
    required this.postes,
    required this.commitments,
    required this.currencyCode,
    required this.isSimplified,
    required this.posteAnswered,
    required this.posteId,
    required this.lineId,
    required this.lineNoneAnswered,
    required this.onPosteSelected,
    required this.onPosteChangeRequested,
    required this.onLineSelected,
    required this.onNoLineSelected,
  });

  /// Build the budget new poste and line attachment as a [Column].
  @override
  Widget build(BuildContext context) {
    if (!posteAnswered) {
      return _OcptBudgetNewPosteAttachment(
        postes: postes,
        isSimplified: isSimplified,
        offersOffQuote: false,
        posteAnswered: posteAnswered,
        posteId: posteId,
        onPosteSelected: onPosteSelected,
      );
    }

    final tr = Tr.of(context);
    final poste = postes.where((poste) => poste.id == posteId).firstOrNull;
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
                    : ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            InkWell(
              onTap: onPosteChangeRequested,
              mouseCursor: ocpt_theme.ocptClickableCursor,
              child: Text(
                tr.budgetEntryWizardChangeNatureAction,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final line in poste?.lines ?? const <OcptBudgetLine>[])
          OcptBudgetNewChoiceRow(
            label: line.label.isEmpty ? tr.budgetPosteUnnamed : line.label,
            hint: tr.budgetNewLinePickerHint(
              ocptBudgetAmountLabel(ocptBudgetLineTotalCents(line), currencyCode),
              commitments.any((commitment) => commitment.lineId == line.id)
                  ? tr.budgetNewLineAlreadyCommittedHint
                  : tr.budgetNewLineNotCommittedHint,
            ),
            isSelected: !lineNoneAnswered && lineId == line.id,
            isEnabled: !commitments.any((commitment) => commitment.lineId == line.id),
            onTap: () => onLineSelected(line.id),
          ),
        OcptBudgetNewChoiceRow(
          key: const Key("ocptBudgetNewNoLineChoice"),
          label: tr.budgetNewNoLineAnswer,
          hint: tr.budgetNewNoLineHint,
          isSelected: lineNoneAnswered,
          onTap: onNoLineSelected,
        ),
      ],
    );
  }
}

/// Step 2 of `financingResource`: the resources grouped by family, the one about to be created
/// and the trailing `create a resource` row.
class _OcptBudgetNewResourceAttachment extends StatelessWidget {
  /// Every live financing resource of the project.
  final List<OcptBudgetResource> resources;

  /// What each financing resource has already received, keyed by its own id.
  final Map<String, OcptBudgetCoveredTotal> receivedByResourceId;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The financing resource answered, or null.
  final String? resourceId;

  /// The financing resource waiting to be created along with the movement, or null.
  final OcptBudgetResourceFormFields? pendingNewResource;

  /// Called with the financing resource picked.
  final ValueChanged<String> onResourceSelected;

  /// Called when the trailing `create a resource` row is tapped.
  final VoidCallback onCreateResourceRequested;

  /// Class constructor
  const _OcptBudgetNewResourceAttachment({
    required this.resources,
    required this.receivedByResourceId,
    required this.currencyCode,
    required this.resourceId,
    required this.pendingNewResource,
    required this.onResourceSelected,
    required this.onCreateResourceRequested,
  });

  /// Build the budget new resource attachment as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final byFamily = <OcptBudgetResourceFamily, List<OcptBudgetResource>>{};
    for (final resource in resources) {
      (byFamily[OcptBudgetResourceFamily.of(resource.groupKind)] ??= []).add(resource);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final family in [
          OcptBudgetResourceFamily.subsidies,
          OcptBudgetResourceFamily.contributions,
        ])
          if (byFamily[family]?.isNotEmpty ?? false) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                ocptBudgetResourceFamilyLabel(tr, family),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            for (final resource in byFamily[family]!)
              OcptBudgetNewChoiceRow(
                label: resource.label.isEmpty ? tr.budgetPosteUnnamed : resource.label,
                hint: tr.budgetNewResourceChoiceHint(
                  ocptBudgetAmountLabel(resource.amountCents, currencyCode),
                  ocptBudgetAmountLabel(
                    receivedByResourceId[resource.id]?.amountCents ?? 0,
                    currencyCode,
                  ),
                  ocptBudgetAmountLabel(
                    ocptBudgetResourceOutstandingCents(
                      amountCents: resource.amountCents,
                      receivedCents: receivedByResourceId[resource.id]?.amountCents ?? 0,
                    ),
                    currencyCode,
                  ),
                ),
                isSelected: pendingNewResource == null && resourceId == resource.id,
                onTap: () => onResourceSelected(resource.id),
              ),
          ],
        if (pendingNewResource case final pendingNewResource?)
          OcptBudgetNewChoiceRow(
            key: const Key("ocptBudgetNewPendingResourceChoice"),
            label: tr.budgetNewWillCreateLabel(pendingNewResource.label),
            isSelected: true,
            onTap: () {},
          ),
        OcptBudgetNewChoiceRow(
          key: const Key("ocptBudgetNewCreateResourceChoice"),
          label: tr.budgetNewCreateResourceAction,
          isSelected: false,
          isCreationRow: true,
          onTap: onCreateResourceRequested,
        ),
      ],
    );
  }
}

/// Step 2 of `participant`: the participants, the one about to be created and the trailing
/// `create a participant` row.
class _OcptBudgetNewParticipantAttachment extends StatelessWidget {
  /// Every live revenue-sharing participant of the project.
  final List<OcptBudgetShare> shares;

  /// The participant answered, or null.
  final String? shareId;

  /// The participant waiting to be created along with the movement, or null.
  final OcptBudgetShareFormFields? pendingNewShare;

  /// Called with the participant picked.
  final ValueChanged<String> onShareSelected;

  /// Called when the trailing `create a participant` row is tapped.
  final VoidCallback onCreateShareRequested;

  /// Class constructor
  const _OcptBudgetNewParticipantAttachment({
    required this.shares,
    required this.shareId,
    required this.pendingNewShare,
    required this.onShareSelected,
    required this.onCreateShareRequested,
  });

  /// Build the budget new participant attachment as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final share in shares)
          OcptBudgetNewChoiceRow(
            label: share.label.isEmpty ? tr.budgetPosteUnnamed : share.label,
            isSelected: pendingNewShare == null && shareId == share.id,
            onTap: () => onShareSelected(share.id),
          ),
        if (pendingNewShare case final pendingNewShare?)
          OcptBudgetNewChoiceRow(
            key: const Key("ocptBudgetNewPendingShareChoice"),
            label: tr.budgetNewWillCreateLabel(pendingNewShare.label),
            isSelected: true,
            onTap: () {},
          ),
        OcptBudgetNewChoiceRow(
          key: const Key("ocptBudgetNewCreateShareChoice"),
          label: tr.budgetNewCreateParticipantAction,
          isSelected: false,
          isCreationRow: true,
          onTap: onCreateShareRequested,
        ),
      ],
    );
  }
}

/// Step 2 of `person`: the people of the address book, each with what they advanced, were
/// reimbursed and are still owed.
class _OcptBudgetNewPersonAttachment extends StatelessWidget {
  /// Every live person of the project's address book.
  final List<OcptPerson> people;

  /// Every live defrayal, read for the advanced figure.
  final List<OcptBudgetAllowance> allowances;

  /// What each defrayed person has already been reimbursed, keyed by their own id.
  final Map<String, OcptBudgetCoveredTotal> reimbursedByPersonId;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The person answered, or null.
  final String? personId;

  /// Called with the person picked.
  final ValueChanged<String> onPersonSelected;

  /// Class constructor
  const _OcptBudgetNewPersonAttachment({
    required this.people,
    required this.allowances,
    required this.reimbursedByPersonId,
    required this.currencyCode,
    required this.personId,
    required this.onPersonSelected,
  });

  /// Build the budget new person attachment as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final person in people)
          OcptBudgetNewChoiceRow(
            label: person.displayName,
            hint: tr.budgetNewPersonChoiceHint(
              ocptBudgetAmountLabel(
                ocptBudgetPersonAdvancedCents(person.id, allowances),
                currencyCode,
              ),
              ocptBudgetAmountLabel(
                reimbursedByPersonId[person.id]?.amountCents ?? 0,
                currencyCode,
              ),
              ocptBudgetAmountLabel(
                ocptBudgetPersonOutstandingCents(
                  advancedCents: ocptBudgetPersonAdvancedCents(person.id, allowances),
                  reimbursedCents: reimbursedByPersonId[person.id]?.amountCents ?? 0,
                ),
                currencyCode,
              ),
            ),
            isSelected: personId == person.id,
            onTap: () => onPersonSelected(person.id),
          ),
      ],
    );
  }
}
