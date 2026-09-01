// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The centered prompt shown instead of the project grid when there are no recent projects yet.
class OcptHomeEmptyState extends StatelessWidget {
  /// Whether the home page is at compact width — below it the button row gives way to a single
  /// hint line pointing at the page's floating action button and the header's `⋮` overflow menu,
  /// which is where those actions live at that width instead.
  final bool isCompact;

  /// Called when the user taps the "New project" action.
  ///
  /// Unused at compact width, where the page's own floating action button is the "New project"
  /// affordance instead.
  final VoidCallback onNewProject;

  /// Called when the user taps the "Open…" action.
  final VoidCallback onOpenProject;

  /// Called when the user taps the "Import…" action, opening `OcptHomeImportDialog`.
  final VoidCallback onImport;

  /// Class constructor
  const OcptHomeEmptyState({
    required this.isCompact,
    required this.onNewProject,
    required this.onOpenProject,
    required this.onImport,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.movie_creation_outlined,
              size: 56,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              tr.homeEmptyStateTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              tr.homeEmptyStateMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (isCompact) ...[
              const SizedBox(height: 8),
              Text(
                tr.homeEmptyStateCompactHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: onImport,
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(tr.homeImportAction),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onOpenProject,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(tr.homeOpenProjectAction),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onNewProject,
                    icon: const Icon(Icons.add),
                    label: Text(tr.homeNewProjectAction),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
