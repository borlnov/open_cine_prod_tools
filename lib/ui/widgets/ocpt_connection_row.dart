// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// One row of a relay connection card: a label, its read-only value, an optional [trailing]
/// control (the token's own reveal/hide toggle) and a copy button.
class OcptConnectionRow extends StatelessWidget {
  /// The label naming what [value] is.
  final String label;

  /// The value shown, read-only.
  final String value;

  /// Called when the copy button is pressed.
  final VoidCallback onCopyPressed;

  /// An extra control shown before the copy button, or null.
  final Widget? trailing;

  /// Class constructor
  const OcptConnectionRow({
    super.key,
    required this.label,
    required this.value,
    required this.onCopyPressed,
    this.trailing,
  });

  /// Build the connection row as a [Row].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final trailing = this.trailing;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
        IconButton(
          tooltip: tr.sharingCopyTooltip,
          icon: const Icon(Icons.copy_outlined),
          onPressed: onCopyPressed,
        ),
      ],
    );
  }
}
