// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_step.dart';

/// The wizard's title: its own name and the step counter, then — on steps 2 and 3 — the trail
/// recalling what has been answered so far.
class OcptBudgetNewTitle extends StatelessWidget {
  /// Which screen is currently drawn.
  final OcptBudgetNewStep step;

  /// The gesture currently selected, or null while none is.
  final OcptBudgetGesture? gesture;

  /// The answers the trail recalls, joined with ` › `, or null while the trail is not drawn
  /// (step 1, or no gesture picked yet).
  final List<String>? trailSegments;

  /// Whether the trail ends in a `changer` link back to step 1. False on a prefilled shortcut,
  /// which offers no way back to a step 1 the reader never chose.
  final bool offersChangeLink;

  /// Called when the `changer` link is tapped.
  final VoidCallback onChangeGestureRequested;

  /// Class constructor
  const OcptBudgetNewTitle({
    super.key,
    required this.step,
    required this.gesture,
    required this.trailSegments,
    required this.offersChangeLink,
    required this.onChangeGestureRequested,
  });

  /// Build the budget new title as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final gesture = this.gesture;
    final stepCount = gesture == null ? null : ocptBudgetGestureStepCountOf(gesture);
    final stepNumber = switch (step) {
      OcptBudgetNewStep.gesture => 1,
      OcptBudgetNewStep.attachment => 2,
      OcptBudgetNewStep.form => stepCount ?? 3,
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

    final trailSegments = this.trailSegments;
    if (step != OcptBudgetNewStep.gesture && gesture != null && trailSegments != null) {
      children.add(const SizedBox(height: 4));
      children.add(
        _OcptBudgetNewTrail(
          segments: trailSegments,
          offersChangeLink: offersChangeLink,
          onChangeGestureRequested: onChangeGestureRequested,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// The trail above steps 2 and 3: what has been answered so far, ending in a `changer` link back
/// to step 1 — mirrors `OcptBudgetEntryDialog`'s own header trail, extended with step 2's own
/// answer while step 3 is on screen.
class _OcptBudgetNewTrail extends StatelessWidget {
  /// The answers recalled, joined with ` › `.
  final List<String> segments;

  /// Whether the trail ends in the `changer` link.
  final bool offersChangeLink;

  /// Called when the `changer` link is tapped.
  final VoidCallback onChangeGestureRequested;

  /// Class constructor
  const _OcptBudgetNewTrail({
    required this.segments,
    required this.offersChangeLink,
    required this.onChangeGestureRequested,
  });

  /// Build the budget new trail as a [Row].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

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
        // A prefilled shortcut recalls what it answered for the reader, but offers no way back to a
        // step 1 they never chose. The trail is then a summary alone.
        if (offersChangeLink) ...[
          Text(" · ", style: mutedStyle),
          InkWell(
            key: const Key("ocptBudgetNewChangeGestureLink"),
            onTap: onChangeGestureRequested,
            mouseCursor: ocpt_theme.ocptClickableCursor,
            child: Text(
              tr.budgetEntryWizardChangeNatureAction,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ],
    );
  }
}
