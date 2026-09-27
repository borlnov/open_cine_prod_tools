// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The project settings page's "Project file" section card: the currently open project's absolute
/// file path, an action opening its containing folder in the platform's own file manager, and an
/// action moving the file elsewhere.
///
/// The **first** card on the page, ahead of `OcptProjectSettingsCurrencySection`: where the
/// project's own file lives is a more fundamental fact about it than any setting stored inside it.
/// Like every other section on this page it only ever asks — [onShowInFolderRequested] and
/// [onMoveRequested] are nullable callbacks the page supplies or withholds, this widget carries no
/// opinion of its own about when either should be offered.
class OcptProjectSettingsFileSection extends StatelessWidget {
  /// The absolute path to the currently open project's file, shown as selectable text.
  final String filePath;

  /// Called when `Show in folder` is tapped, or null to withhold that action — mobile, where there
  /// is no platform file manager this app can hand a path to.
  final VoidCallback? onShowInFolderRequested;

  /// Called when `Move…` is tapped, or null to withhold that action — mobile (no native save-file
  /// dialog there), or [moveWithheldHint] explaining why on desktop.
  final VoidCallback? onMoveRequested;

  /// Explains why [onMoveRequested] is withheld, shown under the path when it is — null when
  /// [onMoveRequested] is offered, or when it is withheld for a reason obvious enough to need no
  /// explanation (mobile, where no affordance needing one is even attempted).
  final String? moveWithheldHint;

  /// Class constructor
  const OcptProjectSettingsFileSection({
    required this.filePath,
    required this.onShowInFolderRequested,
    required this.onMoveRequested,
    this.moveWithheldHint,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.projectSettingsFileSectionTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SelectableText(filePath),
            if (moveWithheldHint != null) ...[
              const SizedBox(height: 8),
              Text(
                moveWithheldHint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 12,
              children: [
                if (onShowInFolderRequested != null)
                  OutlinedButton(
                    onPressed: onShowInFolderRequested,
                    child: Text(tr.projectSettingsShowInFolderAction),
                  ),
                if (onMoveRequested != null)
                  OutlinedButton(
                    onPressed: onMoveRequested,
                    child: Text(tr.projectSettingsMoveAction),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
