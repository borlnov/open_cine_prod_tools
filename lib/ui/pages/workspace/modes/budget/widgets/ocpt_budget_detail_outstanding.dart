// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// The outstanding amount, in large type — what the detail panel's whole grammar builds up to.
class OcptBudgetDetailOutstanding extends StatelessWidget {
  /// The block's own label.
  final String label;

  /// The block's own value, already formatted.
  final String value;

  /// Class constructor
  const OcptBudgetDetailOutstanding({super.key, required this.label, required this.value});

  /// Build the budget detail panel outstanding as a [Container].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
