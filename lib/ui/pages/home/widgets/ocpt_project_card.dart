// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_state.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_home_relative_time.dart';

/// A single project tile in the home page's project grid.
///
/// Shows a poster-like tinted area with the project's initial letter (a placeholder ahead of real
/// thumbnails), the project name, its file path, and how long ago it was last opened. When
/// [OcptHomeRecentProjectEntry.exists] is false, the whole card is greyed out, tapping it is
/// disabled, and a tooltip explains why; it can still be removed from the list through the
/// overflow menu.
class OcptProjectCard extends StatelessWidget {
  /// The recent project shown by this card.
  final OcptHomeRecentProjectEntry entry;

  /// Called when the card is tapped, unless [OcptHomeRecentProjectEntry.exists] is false.
  final VoidCallback onTap;

  /// Called when "Remove from list" is chosen from the overflow menu.
  final VoidCallback onRemove;

  /// Class constructor
  const OcptProjectCard({required this.entry, required this.onTap, required this.onRemove, super.key});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final exists = entry.exists;

    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey(entry.project.path),
        onTap: exists ? onTap : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: colorScheme.primaryContainer,
                      child: Center(
                        child: Text(
                          entry.project.name.isEmpty ? "?" : entry.project.name[0].toUpperCase(),
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<void>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                      itemBuilder: (context) => [
                        PopupMenuItem<void>(
                          onTap: onRemove,
                          child: Text(tr.homeRemoveFromListAction),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.project.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    entry.project.path,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatHomeRelativeTime(context, entry.project.lastOpenedAt),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (exists) {
      return card;
    }

    return Tooltip(
      message: tr.homeMissingFileTooltip,
      child: Opacity(opacity: 0.5, child: card),
    );
  }
}
