// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_card.dart';

/// The `Versions` tab of the right dock: the project's named versions, newest first, with the
/// action that creates one.
///
/// Shown in **every** production mode's dock and built from
/// `MixinOcptProjectVersionsState` alone, because a version covers the whole project rather than
/// any one mode's data — which is exactly what the line under the header tells the user. Nothing
/// here knows which mode it is being shown in.
///
/// Deliberately not to be confused with the screenplay's automatic snapshots, which have no UI at
/// all: these are the permanent, named checkpoints the user creates on purpose.
class OcptProjectVersionsPanel extends StatelessWidget {
  /// The project's versions, newest first.
  final List<OcptProjectVersion> versions;

  /// The id of the version currently being previewed read-only, or null while the working copy is
  /// on screen.
  final String? previewedVersionId;

  /// The id of the version whose card shows its inline delete confirmation, or null while none
  /// does.
  final String? versionPendingDeletionId;

  /// The id of the version whose card shows its inline restore confirmation, or null while none
  /// does.
  final String? versionPendingRestoreId;

  /// Called when `Create a version` is clicked; null while creating one is refused (a version is
  /// being previewed, so the capture would record a state the user isn't looking at).
  final VoidCallback? onCreateRequested;

  /// Called with a version's id when its card is clicked to enter its read-only preview.
  final ValueChanged<String> onPreviewRequested;

  /// Called when the previewed version's card is clicked, to go back to the working copy.
  final VoidCallback onPreviewExitRequested;

  /// Called with a version's id when its `Restore this version` is clicked, which only asks for
  /// confirmation.
  final ValueChanged<String> onRestoreRequested;

  /// Called when an inline restore confirmation is cancelled.
  final VoidCallback onRestoreCancelled;

  /// Called with a version when its inline restore confirmation is confirmed.
  ///
  /// The whole version rather than its id alone, unlike every other callback here: restoring names
  /// the state it replaces after the version being restored, and that name is a localized string
  /// only the page can build.
  final ValueChanged<OcptProjectVersion> onRestoreConfirmed;

  /// Called with a version's id when its `Delete` is clicked, which only asks for confirmation.
  final ValueChanged<String> onDeleteRequested;

  /// Called when an inline delete confirmation is cancelled.
  final VoidCallback onDeleteCancelled;

  /// Called with a version's id when its inline delete confirmation is confirmed.
  final ValueChanged<String> onDeleteConfirmed;

  /// Class constructor
  const OcptProjectVersionsPanel({
    super.key,
    required this.versions,
    required this.previewedVersionId,
    required this.versionPendingDeletionId,
    required this.versionPendingRestoreId,
    required this.onCreateRequested,
    required this.onPreviewRequested,
    required this.onPreviewExitRequested,
    required this.onRestoreRequested,
    required this.onRestoreCancelled,
    required this.onRestoreConfirmed,
    required this.onDeleteRequested,
    required this.onDeleteCancelled,
    required this.onDeleteConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr.projectVersionsPanelTitle,
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 4),
        Text(
          tr.projectVersionsPanelSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCreateRequested,
            icon: const Icon(Icons.bookmark_add_outlined, size: 16),
            label: Text(tr.projectVersionsCreateAction),
          ),
        ),
        const SizedBox(height: 12),
        if (versions.isEmpty)
          Text(
            tr.projectVersionsEmptyHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          for (final version in versions) _buildCard(version),
      ],
    );
  }

  /// Builds [version]'s card, wiring the actions that depend on which of the three states it is in
  /// (see [OcptProjectVersionCard]'s own doc comment).
  Widget _buildCard(OcptProjectVersion version) {
    final isPreviewed = version.id == previewedVersionId;

    return OcptProjectVersionCard(
      key: ValueKey(version.id),
      version: version,
      isPreviewed: isPreviewed,
      isConfirmingDeletion: version.id == versionPendingDeletionId,
      isConfirmingRestore: version.id == versionPendingRestoreId,
      onTap: switch ((version.isBase, isPreviewed)) {
        (true, _) => null,
        (_, true) => onPreviewExitRequested,
        _ => () => onPreviewRequested(version.id),
      },
      // Restoring the version being previewed is legitimate — it is the obvious next move once the
      // user has read it — where deleting it is not: the preview reads from a database hydrated out
      // of that very row.
      onRestoreRequested: version.isBase ? null : () => onRestoreRequested(version.id),
      onRestoreConfirmed: () => onRestoreConfirmed(version),
      onRestoreCancelled: onRestoreCancelled,
      onDeleteRequested: version.isBase || isPreviewed
          ? null
          : () => onDeleteRequested(version.id),
      onDeleteConfirmed: () => onDeleteConfirmed(version.id),
      onDeleteCancelled: onDeleteCancelled,
    );
  }
}
