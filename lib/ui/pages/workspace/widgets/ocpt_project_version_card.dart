// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_summary_line.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

/// One entry of the `Versions` dock tab: a project version the user created, with what it holds
/// and what can be done with it.
///
/// Three states, exactly one at a time:
///
/// - **current** — the working copy descends from this version. It carries the `Current` badge,
///   says so plainly, and is neither clickable nor deletable: there is nothing to preview (it is
///   what is on screen) and deleting it would leave the project descending from nothing.
/// - **previewed** — this version is the one currently on screen read-only. It carries the
///   `Preview` badge in the workspace's warning colour, and clicking it goes back to the working
///   copy. Deleting it is refused too (`OcptProjectsManager.deleteProjectVersion` refuses it as
///   well), since the preview reads from a database hydrated out of that very row.
/// - **any other** — clicking it enters its read-only preview, and `Delete` starts the inline
///   confirmation this card shows itself, instead of a dialog: the question is about this card,
///   and the mock-up asks it where the answer applies.
///
/// `Restore this version` is deliberately absent: restoring rewrites the project, and it lands
/// with the restore operation itself.
class OcptProjectVersionCard extends StatelessWidget {
  /// The version this card shows.
  final OcptProjectVersion version;

  /// Whether [version] is the one currently being previewed read-only.
  final bool isPreviewed;

  /// Whether this card currently shows its inline delete confirmation instead of its actions.
  final bool isConfirmingDeletion;

  /// Called when the card is clicked, or null when clicking it does nothing (the current
  /// version's card).
  final VoidCallback? onTap;

  /// Called when `Delete` is clicked, which only asks for confirmation; null on a card that may
  /// not be deleted.
  final VoidCallback? onDeleteRequested;

  /// Called when the inline confirmation's `Delete` is clicked, which deletes for good.
  final VoidCallback onDeleteConfirmed;

  /// Called when the inline confirmation's `Cancel` is clicked.
  final VoidCallback onDeleteCancelled;

  /// Class constructor
  const OcptProjectVersionCard({
    super.key,
    required this.version,
    required this.isPreviewed,
    required this.isConfirmingDeletion,
    required this.onTap,
    required this.onDeleteRequested,
    required this.onDeleteConfirmed,
    required this.onDeleteCancelled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, theme, tr),
              const SizedBox(height: 6),
              Text(
                ocptProjectVersionSummaryLine(context, version),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (version.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(version.note, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              if (isConfirmingDeletion)
                _buildDeleteConfirmation(context, theme, tr)
              else
                _buildFooter(context, theme, tr),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the card's first line: the status dot, the version's name, and its badge if it has
  /// one.
  Widget _buildHeader(BuildContext context, ThemeData theme, Tr tr) {
    final accentColor = _accentColor(context, theme);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            version.name,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (_badgeLabel(tr) case final badgeLabel?) ...[
          const SizedBox(width: 8),
          _OcptProjectVersionBadge(label: badgeLabel, color: accentColor),
        ],
      ],
    );
  }

  /// Builds what the card says under its counters when it isn't confirming a deletion: the hint
  /// telling the user what clicking it does, and the `Delete` action when it may be deleted.
  Widget _buildFooter(BuildContext context, ThemeData theme, Tr tr) => Row(
    children: [
      Expanded(
        child: Text(
          switch ((version.isCurrent, isPreviewed)) {
            (true, _) => tr.projectVersionCurrentHint,
            (_, true) => tr.projectVersionPreviewedHint,
            _ => tr.projectVersionPreviewHint,
          },
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
      if (onDeleteRequested != null)
        TextButton(
          onPressed: onDeleteRequested,
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: Text(tr.projectVersionDeleteAction),
        ),
    ],
  );

  /// Builds the inline delete confirmation shown in place of the card's footer: the warning, then
  /// the two answers to it.
  Widget _buildDeleteConfirmation(BuildContext context, ThemeData theme, Tr tr) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr.projectVersionDeleteConfirmMessage,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: onDeleteCancelled,
            child: Text(tr.projectVersionDeleteCancelAction),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: onDeleteConfirmed,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(tr.projectVersionDeleteConfirmAction),
          ),
        ],
      ),
    ],
  );

  /// The card's own colour: the accent for the current version, the workspace's warning colour
  /// while this version is the one being previewed, and a muted outline for every other one.
  Color _accentColor(BuildContext context, ThemeData theme) {
    if (isPreviewed) {
      return ocptWarningColor(context);
    }

    return version.isCurrent ? theme.colorScheme.primary : theme.colorScheme.outline;
  }

  /// The badge this card carries, or null when it carries none.
  ///
  /// Previewing wins over being current, since the two can legitimately coincide for a moment (a
  /// version created and immediately previewed): the badge answers "what am I looking at?".
  String? _badgeLabel(Tr tr) {
    if (isPreviewed) {
      return tr.projectVersionPreviewBadge;
    }

    return version.isCurrent ? tr.projectVersionCurrentBadge : null;
  }
}

/// The small pill naming what a card is — `Current` or `Preview` — tinted with the card's own
/// accent colour.
class _OcptProjectVersionBadge extends StatelessWidget {
  /// The badge's text.
  final String label;

  /// The colour the badge is tinted with.
  final Color color;

  /// Class constructor
  const _OcptProjectVersionBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: ocptSelectedStateAlpha),
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    ),
  );
}
