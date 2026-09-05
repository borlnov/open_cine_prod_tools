// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';

/// A small read-out pill, tinted with [color] — the sharing page's own top-bar chips (`① Configure`
/// / `② Invite`, `Not paired` / `In sync`), on the exact model of `OcptShotStatusPill`: a read-out,
/// never a control.
class OcptSharingChip extends StatelessWidget {
  /// The text shown inside the chip.
  final String label;

  /// The colour tinting both the chip's background wash and its own text.
  final Color color;

  /// Class constructor
  const OcptSharingChip({required this.label, required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
