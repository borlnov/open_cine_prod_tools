// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_family.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_gesture_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_gesture_labels.dart';

/// Step 1 — the fifteen answers, grouped by document.
class OcptBudgetNewGestureStep extends StatelessWidget {
  /// Whether the filter tag atop the list is drawn: a filter is in effect and has not been lifted.
  final bool showsFilterTag;

  /// The word the filter tag names the current filter by, or null.
  final String? filterLabel;

  /// The families to draw, in the order to draw them, each with the gestures it offers. A family
  /// with no offered gesture is not part of the list, so it is drawn no heading.
  final List<({OcptBudgetGestureFamily family, List<OcptBudgetGesture> gestures})> families;

  /// The gesture currently selected, or null.
  final OcptBudgetGesture? selectedGesture;

  /// Called when a card is tapped.
  final ValueChanged<OcptBudgetGesture> onGestureSelected;

  /// Called when the filter tag's `Show all` action is pressed.
  final VoidCallback onShowAllRequested;

  /// Class constructor
  const OcptBudgetNewGestureStep({
    super.key,
    required this.showsFilterTag,
    required this.filterLabel,
    required this.families,
    required this.selectedGesture,
    required this.onGestureSelected,
    required this.onShowAllRequested,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showsFilterTag)
        _OcptBudgetNewFilterTag(filterLabel: filterLabel, onShowAllRequested: onShowAllRequested),
      for (final entry in families) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: _OcptBudgetNewFamilyHeading(family: entry.family),
        ),
        for (final gesture in entry.gestures)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OcptBudgetNewGestureCard(
              gesture: gesture,
              isSelected: selectedGesture == gesture,
              onSelected: () => onGestureSelected(gesture),
            ),
          ),
      ],
    ],
  );
}

/// The filter tag atop a filtered step 1: what the list is narrowed to, and the `Show all` action
/// that lifts it whole. Drawn only while a filter is in effect — the mockup's own removable-tag
/// idiom the mode already uses for its poste filter.
class _OcptBudgetNewFilterTag extends StatelessWidget {
  /// The word the filter is named by, or null.
  final String? filterLabel;

  /// Called when `Show all` is pressed.
  final VoidCallback onShowAllRequested;

  /// Class constructor
  const _OcptBudgetNewFilterTag({required this.filterLabel, required this.onShowAllRequested});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            tr.budgetNewGestureFilterTag(filterLabel ?? ""),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        TextButton(
          key: const Key("ocptBudgetNewShowAllGesturesButton"),
          onPressed: onShowAllRequested,
          child: Text(tr.budgetNewShowAllGesturesAction),
        ),
      ],
    );
  }
}

/// One family's heading in step 1: its own name over its subtitle.
class _OcptBudgetNewFamilyHeading extends StatelessWidget {
  /// The family the heading names.
  final OcptBudgetGestureFamily family;

  /// Class constructor
  const _OcptBudgetNewFamilyHeading({required this.family});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ocptBudgetGestureFamilyLabel(tr, family), style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          ocptBudgetGestureFamilySubtitle(tr, family),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
