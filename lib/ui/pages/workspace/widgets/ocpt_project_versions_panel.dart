// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_working_copy_card.dart';

/// The `Versions` tab of the right dock: the working copy on top, then the project's named
/// versions underneath, newest first.
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

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.workingCopy}
  final OcptProjectWorkingCopyState? workingCopy;

  /// The id of the version whose card shows its inline delete confirmation, or null while none
  /// does.
  final String? versionPendingDeletionId;

  /// The id of the version whose card shows its inline restore confirmation, or null while none
  /// does.
  final String? versionPendingRestoreId;

  /// The id of the version whose card shows its inline rename form, or null while none does.
  final String? versionPendingRenameId;

  /// Called when the working copy card's `Create a version` is clicked.
  final VoidCallback onCreateRequested;

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

  /// Called with a version's id when its `Rename` is clicked, which only opens its inline rename
  /// form.
  final ValueChanged<String> onRenameRequested;

  /// Called when an inline rename form is cancelled.
  final VoidCallback onRenameCancelled;

  /// Called with a version's id, its new name and its new note when its inline rename form's
  /// `Save` is clicked.
  final void Function(String versionId, String name, String note) onRenameConfirmed;

  /// Class constructor
  const OcptProjectVersionsPanel({
    super.key,
    required this.versions,
    required this.previewedVersionId,
    required this.workingCopy,
    required this.versionPendingDeletionId,
    required this.versionPendingRestoreId,
    required this.versionPendingRenameId,
    required this.onCreateRequested,
    required this.onPreviewRequested,
    required this.onPreviewExitRequested,
    required this.onRestoreRequested,
    required this.onRestoreCancelled,
    required this.onRestoreConfirmed,
    required this.onDeleteRequested,
    required this.onDeleteCancelled,
    required this.onDeleteConfirmed,
    required this.onRenameRequested,
    required this.onRenameCancelled,
    required this.onRenameConfirmed,
  });

  /// Build the project versions panel as a [ListView].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final workingCopy = this.workingCopy;

    final leading = <Widget>[
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
      if (workingCopy != null)
        OcptProjectWorkingCopyCard(
          workingCopy: workingCopy,
          baseVersionName: _baseVersionName(workingCopy.baseVersionId),
          onCreateRequested: onCreateRequested,
        ),
      if (versions.isEmpty)
        Text(
          tr.projectVersionsEmptyHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: leading.length + versions.length,
      // A card keeps its own state (a rename in progress) across a version being added or removed
      // above it, which only works when the list can find a keyed card's new index.
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) {
          return null;
        }

        final versionIndex = versions.indexWhere((version) => version.id == key.value);
        return versionIndex < 0 ? null : leading.length + versionIndex;
      },
      itemBuilder: (context, index) {
        if (index < leading.length) {
          return leading[index];
        }

        final version = versions[index - leading.length];
        return _OcptProjectVersionPanelEntry(
          key: ValueKey(version.id),
          panel: this,
          version: version,
        );
      },
    );
  }

  /// Get the name of the version [baseVersionId] names, resolved out of [versions] — the list
  /// already
  /// carries every version, the base included, so a second lookup path could only ever disagree
  /// with it. Null when [baseVersionId] is null, or names a version no longer in the list.
  String? _baseVersionName(String? baseVersionId) {
    if (baseVersionId == null) {
      return null;
    }

    for (final version in versions) {
      if (version.id == baseVersionId) {
        return version.name;
      }
    }

    return null;
  }
}

/// [version]'s card, wiring the actions that depend on which of its states it is in (see
/// [OcptProjectVersionCard]'s own doc comment) to the callbacks [panel] was given.
class _OcptProjectVersionPanelEntry extends StatelessWidget {
  /// The panel whose callbacks and selection state the card is wired to.
  final OcptProjectVersionsPanel panel;

  /// The version the card shows.
  final OcptProjectVersion version;

  /// Class constructor
  const _OcptProjectVersionPanelEntry({super.key, required this.panel, required this.version});

  /// Build the project version panel entry as an [OcptProjectVersionCard].
  @override
  Widget build(BuildContext context) {
    final isPreviewed = version.id == panel.previewedVersionId;

    return OcptProjectVersionCard(
      version: version,
      isPreviewed: isPreviewed,
      isConfirmingDeletion: version.id == panel.versionPendingDeletionId,
      isConfirmingRestore: version.id == panel.versionPendingRestoreId,
      isConfirmingRename: version.id == panel.versionPendingRenameId,
      onTap: isPreviewed
          ? panel.onPreviewExitRequested
          : () => panel.onPreviewRequested(version.id),
      onRestoreRequested: () => panel.onRestoreRequested(version.id),
      onRestoreConfirmed: () => panel.onRestoreConfirmed(version),
      onRestoreCancelled: panel.onRestoreCancelled,
      // Restoring the version being previewed is legitimate — it is the obvious next move once the
      // user has read it — where deleting it is not: the preview reads from a database hydrated out
      // of that very row.
      onDeleteRequested: isPreviewed ? null : () => panel.onDeleteRequested(version.id),
      onDeleteConfirmed: () => panel.onDeleteConfirmed(version.id),
      onDeleteCancelled: panel.onDeleteCancelled,
      onRenameRequested: () => panel.onRenameRequested(version.id),
      onRenameConfirmed: (name, note) => panel.onRenameConfirmed(version.id, name, note),
      onRenameCancelled: panel.onRenameCancelled,
    );
  }
}
