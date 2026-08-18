// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The gap between the longest label and the shortcut hint following it, so the two never read as
/// one sentence even on the narrowest menu.
const double _shortcutGap = 24;

/// The content of a toolbar `⋮` menu entry that also has a keyboard shortcut: its [label], then
/// [shortcut] pushed to the right edge and dimmed, the way a desktop menu states the shortcut of
/// the action it offers.
///
/// Meant as the `child` of a [PopupMenuItem] built by a production mode's own overflow entries; an
/// entry with no shortcut stays a plain [Text] and needs nothing from this file. The label is what
/// the entry is about, so it is the part that takes the remaining width and ellipsizes; the
/// shortcut is short by nature and always shown whole.
///
/// Formatting [shortcut] itself is the caller's job — `ocptPrimaryShortcutLabel` in
/// `lib/ui/utils/ocpt_shortcut_labels.dart` is what states the platform's modifier.
class OcptToolbarMenuItemLabel extends StatelessWidget {
  /// The entry's own label: what the action does.
  final String label;

  /// The keyboard shortcut triggering that same action, already formatted for the platform.
  final String shortcut;

  /// Class constructor
  const OcptToolbarMenuItemLabel({super.key, required this.label, required this.shortcut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: _shortcutGap),
        Text(
          shortcut,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
