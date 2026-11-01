// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The fiche's own breadcrumb: `segments`, chevron-separated, muted — the way back up to the
/// document this object lives in.
class OcptBudgetFicheBreadcrumb extends StatelessWidget {
  /// The breadcrumb's own segments, from the outermost ancestor to the object itself.
  final List<String> segments;

  /// Class constructor
  const OcptBudgetFicheBreadcrumb({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < segments.length; index++) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 14, color: theme.colorScheme.onSurfaceVariant),
            ),
          Text(segments[index], maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ],
      ],
    );
  }
}
