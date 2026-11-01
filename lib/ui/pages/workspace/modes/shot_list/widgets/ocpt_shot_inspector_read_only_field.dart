// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// One read-only field row of the shot inspector and metadata panels: an uppercase,
/// `onSurfaceVariant` label over a rounded `surfaceContainer` value box.
///
/// Deliberately not imported from the screenplay editor's own `OcptEditorDockField`, which
/// follows the exact same idiom: the two production modes stay independent of one another.
class OcptShotInspectorReadOnlyField extends StatelessWidget {
  /// The field's label, upper-cased for display.
  final String label;

  /// The field's value, already formatted for display (a dash for a missing value, not an empty
  /// string).
  final String value;

  /// Class constructor
  const OcptShotInspectorReadOnlyField({super.key, required this.label, required this.value});

  /// Build the shot inspector read only field as a [Padding].
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
              borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
            ),
            child: Text(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
