// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';

/// The width the grid lays its two columns out at.
const double _ocptWorkspaceExportGridWidth = 600;

/// The height the grid is bounded to, so it scrolls within the dialog rather than growing it past
/// the window whenever a mode offers many documents.
///
/// A ceiling rather than a size: a mode offering one document opens a panel one card tall, the
/// grid shrink-wrapping whatever it holds until it reaches this.
const double _ocptWorkspaceExportGridMaxHeight = 420;

/// The width/height ratio of one card, tuned for a document name, its description (or
/// unavailability reason) over up to three lines, and a trailing format label.
const double _ocptWorkspaceExportCardAspectRatio = 2.5;

/// The opacity an unavailable card is drawn at, greying it without hiding it.
const double _ocptWorkspaceExportUnavailableOpacity = 0.5;

/// The panel every production mode's toolbar `Export` button opens: a scrolling two-column grid of
/// cards, one per document the active mode knows how to print, generic over that mode's own export
/// enum [T].
///
/// It only asks: clicking an available card pops with its [OcptWorkspaceExportEntry.value] and
/// nothing else, through `OcptRouterManager.pop`, never `Navigator`. It knows nothing about any
/// export options dialog or any export itself — the mode that opened it reads the popped value and
/// takes it from there, once this dialog is already on its way out of the tree.
///
/// A card whose [OcptWorkspaceExportEntry.unavailableReason] is non-null is greyed and inert, its
/// description replaced by that reason, and never hidden: the panel is a presentation of what this
/// mode knows how to print, and a card that disappeared would make it lie about what exists.
///
/// [title] and [message] are plain strings handed in by the caller, the wording of both being
/// per-mode.
class OcptWorkspaceExportDialog<T> extends StatelessWidget {
  /// The dialog's title.
  final String title;

  /// The sentence under the title saying what this panel is.
  final String message;

  /// The documents offered, one card each, in the given order.
  final List<OcptWorkspaceExportEntry<T>> entries;

  /// Class constructor
  const OcptWorkspaceExportDialog({
    required this.title,
    required this.message,
    required this.entries,
    super.key,
  });

  /// Shows the dialog and returns the [OcptWorkspaceExportEntry.value] of the card the user picked,
  /// or null if they cancelled it or picked no card at all.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String message,
    required List<OcptWorkspaceExportEntry<T>> entries,
  }) => showDialog<T>(
    context: context,
    builder: (context) =>
        OcptWorkspaceExportDialog<T>(title: title, message: message, entries: entries),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: _ocptWorkspaceExportGridWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _ocptWorkspaceExportGridMaxHeight),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: _ocptWorkspaceExportCardAspectRatio,
                children: [for (final entry in entries) _OcptWorkspaceExportCard<T>(entry: entry)],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop<T>(),
          child: Text(tr.editorPageSetupCancelAction),
        ),
      ],
    );
  }
}

/// One card of [OcptWorkspaceExportDialog], the whole surface clickable when [entry] is available.
class _OcptWorkspaceExportCard<T> extends StatelessWidget {
  /// The document this card describes.
  final OcptWorkspaceExportEntry<T> entry;

  /// Class constructor
  const _OcptWorkspaceExportCard({required this.entry, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = entry.isAvailable;

    return Opacity(
      opacity: isAvailable ? 1 : _ocptWorkspaceExportUnavailableOpacity,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          mouseCursor: ocptClickableCursor,
          onTap: isAvailable
              ? () => globalGetIt().get<OcptRouterManager>().pop<T>(entry.value)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.formatLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    entry.unavailableReason ?? entry.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
