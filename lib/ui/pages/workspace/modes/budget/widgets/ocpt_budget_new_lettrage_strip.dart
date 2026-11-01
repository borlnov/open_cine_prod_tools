// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_match_suggestion.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_match_candidate_kind.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The lettrage strip: what accepting one of [suggestions] does, why each was ranked, and every
/// candidate reachable, `Aucun` included — never a single best guess with no way to say
/// otherwise. It stops the same money being counted twice: without it, a user records the
/// payment, forgets to settle the commitment it was for, and the poste reads both committed and
/// paid for the very same transfer.
class OcptBudgetNewLettrageStrip extends StatelessWidget {
  /// The ranked candidates the strip offers.
  final List<OcptBudgetMatchSuggestion> suggestions;

  /// Which candidate is currently picked, by index into [suggestions], or null for `Aucun`.
  final int? selectedIndex;

  /// Every live commitment, read to name a commitment candidate's poste.
  final List<OcptBudgetCommitment> commitments;

  /// Every live poste of the project, read to name a commitment candidate's poste.
  final List<OcptBudgetPoste> postes;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called with the index of the candidate picked, or null for `Aucun`.
  final ValueChanged<int?> onSelected;

  /// Class constructor
  const OcptBudgetNewLettrageStrip({
    super.key,
    required this.suggestions,
    required this.selectedIndex,
    required this.commitments,
    required this.postes,
    required this.currencyCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

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
            _OcptBudgetNewLettrageCandidateRow(
              index: index,
              headline: _headlineOf(context, tr, suggestion),
              reasons: _reasonsOf(tr, suggestion),
              isSelected: selectedIndex == index,
              onTap: () => onSelected(index),
            ),
          _OcptBudgetNewLettrageNoneRow(
            isSelected: selectedIndex == null,
            onTap: () => onSelected(null),
          ),
        ],
      ),
    );
  }

  /// The reasons [suggestion] was ranked, joined into one muted line.
  String _reasonsOf(Tr tr, OcptBudgetMatchSuggestion suggestion) {
    final reasons = [
      if (suggestion.matchesAmount) tr.budgetNewLettrageReasonAmount,
      if (suggestion.matchesDate) tr.budgetNewLettrageReasonDate,
      if (suggestion.matchesWording) tr.budgetNewLettrageReasonWording,
    ];
    return reasons.join(" · ");
  }

  /// The headline sentence naming [suggestion] and the figures that matter for its kind.
  String _headlineOf(BuildContext context, Tr tr, OcptBudgetMatchSuggestion suggestion) {
    switch (suggestion.kind) {
      case OcptBudgetMatchCandidateKind.commitment:
        final amountLabel = suggestion.outstandingCents == null
            ? ""
            : ocptBudgetAmountLabel(suggestion.outstandingCents!, currencyCode);
        final posteLabel = _commitmentPosteLabelOf(tr, suggestion);
        final date = suggestion.date;
        if (date == null) {
          return tr.budgetEntryMatchCommitmentHeadlineUndated(
            suggestion.label,
            amountLabel,
            posteLabel,
          );
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

  /// What [suggestion] has already received, in cents.
  int _receivedCentsOf(OcptBudgetMatchSuggestion suggestion) =>
      (suggestion.amountCents ?? 0) - (suggestion.outstandingCents ?? 0);

  /// The label of the poste the commitment behind [suggestion] hangs off.
  String _commitmentPosteLabelOf(Tr tr, OcptBudgetMatchSuggestion suggestion) {
    final commitment = commitments
        .where((candidate) => candidate.id == suggestion.candidateId)
        .firstOrNull;
    final poste = postes.where((poste) => poste.id == commitment?.posteId).firstOrNull;
    final label = poste?.label ?? "";
    final code = poste?.code ?? "";
    if (label.isEmpty) {
      return code.isEmpty ? tr.budgetPosteUnnamed : code;
    }
    return code.isEmpty ? label : "$code $label";
  }
}

/// One ranked candidate of the lettrage strip, as a radio-style row.
class _OcptBudgetNewLettrageCandidateRow extends StatelessWidget {
  /// The candidate's index into the strip's suggestions.
  final int index;

  /// The headline sentence naming the candidate.
  final String headline;

  /// The reasons the candidate was ranked, on one muted line.
  final String reasons;

  /// Whether the candidate is the one currently picked.
  final bool isSelected;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptBudgetNewLettrageCandidateRow({
    required this.index,
    required this.headline,
    required this.reasons,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      key: Key("ocptBudgetNewLettrageCandidate$index"),
      onTap: onTap,
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
                  Text(headline, style: theme.textTheme.bodySmall),
                  Text(
                    reasons,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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

/// The lettrage strip's `Aucun` row, picked while no candidate is.
class _OcptBudgetNewLettrageNoneRow extends StatelessWidget {
  /// Whether `Aucun` is the current pick.
  final bool isSelected;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptBudgetNewLettrageNoneRow({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return InkWell(
      key: const Key("ocptBudgetNewLettrageNone"),
      onTap: onTap,
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
}
