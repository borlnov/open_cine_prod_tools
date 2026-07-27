// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// One read-only field row shared by the right dock's inspector and metadata panels: an
/// uppercase, `onSurfaceVariant` label over a rounded `surfaceContainer` value box, following the
/// mock-up's field idiom.
class OcptEditorDockField extends StatelessWidget {
  /// The field's label, upper-cased for display.
  final String label;

  /// The field's value, already formatted for display (a dash for a missing value, not an empty
  /// string).
  final String value;

  /// Class constructor
  const OcptEditorDockField({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
