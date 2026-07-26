// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The workspace shell's thin, discreet toolbar: the back action leading to the projects list, the
/// open project's title (with a dot marking unsaved changes), a trailing slot for the active
/// mode's own controls ([actions]), and an overflow `⋮` menu built from [overflowEntries].
///
/// Everything mode-specific (save, an editing-mode toggle, format controls, tab selectors, export
/// entries…) is the active mode's own job to build and hand in through [actions] /
/// [overflowEntries]; this widget only knows the mode-agnostic chrome around them.
class OcptWorkspaceToolbar extends StatelessWidget {
  /// The title shown at the left of the toolbar (the open project's name).
  final String title;

  /// Whether there are unsaved changes, shown as a dot next to the title.
  final bool isDirty;

  /// Called when the back action is clicked.
  final VoidCallback onBack;

  /// The active mode's own controls, right-aligned before the overflow menu.
  final List<Widget> actions;

  /// The `⋮` overflow menu's entries. An empty list renders no `⋮` button at all.
  final List<PopupMenuEntry<void>> overflowEntries;

  /// Class constructor
  const OcptWorkspaceToolbar({
    super.key,
    required this.title,
    required this.isDirty,
    required this.onBack,
    this.actions = const [],
    this.overflowEntries = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              tooltip: tr.editorBackToProjectsTooltip,
              onPressed: onBack,
            ),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (isDirty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Tooltip(
                  message: tr.editorUnsavedChangesTooltip,
                  child: Text(
                    "●",
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            const Spacer(),
            ...actions,
            if (overflowEntries.isNotEmpty)
              PopupMenuButton<void>(
                icon: const Icon(Icons.more_vert, size: 20),
                tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                itemBuilder: (context) => overflowEntries,
              ),
          ],
        ),
      ),
    );
  }
}
