// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';

/// A small status badge — the resource/revenue `Dossier` fact, held apart from the money.
class OcptBudgetFicheBadge extends StatelessWidget {
  /// The badge's own text.
  final String text;

  /// The badge's own accent colour.
  final Color color;

  /// Class constructor
  const OcptBudgetFicheBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
    ),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
    ),
  );
}
