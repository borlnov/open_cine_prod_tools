// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The floor plans view's own focus strip, along the bottom of the canvas
/// (`docs/plans/storyboard.md`, §4.3).
///
/// **Only the `Sequence` chip is functional in this milestone**: the mode is always in sequence
/// focus in M5 (no shot focus exists yet, so the chip cannot be un-picked), and it is drawn active
/// throughout. The per-shot chips, `prev`/`next` ghost tags and `←`/`→` shot-walking are M6 — left
/// out entirely rather than drawn inert, since a strip with nothing behind its own chips would say
/// less than no strip at all until M6 gives it shots to name.
class OcptFloorPlanFocusStrip extends StatelessWidget {
  /// Class constructor
  const OcptFloorPlanFocusStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha),
              borderRadius: BorderRadius.circular(ocptRadiusMedium),
              border: Border.all(color: theme.colorScheme.primary),
            ),
            child: Text(
              Tr.of(context).shotListFloorPlanFocusSequenceChipLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
