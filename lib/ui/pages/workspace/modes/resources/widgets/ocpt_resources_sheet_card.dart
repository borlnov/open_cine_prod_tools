// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The card chrome shared by every section of a resources sheet — `OcptPersonSheet`'s and
/// `OcptRoleSheet`'s alike: a title on the left, an optional muted hint on the right (the positions
/// card's "A function may cover a single slot"), and the section's own content underneath.
///
/// Built on the stock [Card] so its background, border and radius come from the studio design
/// system's own `CardThemeData` (`lib/constants/ocpt_theme.dart`) rather than being redeclared
/// here; only the body padding, which no component theme states, is this widget's own.
class OcptResourcesSheetCard extends StatelessWidget {
  /// The card's title, always shown.
  final String title;

  /// A short, muted line shown to the right of [title] on the same row, or null for a card with
  /// nothing further to say there.
  final String? hint;

  /// The card's own content, under the header row.
  final Widget child;

  /// Class constructor
  const OcptResourcesSheetCard({super.key, required this.title, this.hint, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = this.hint;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      hint,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 9),
            child,
          ],
        ),
      ),
    );
  }
}
