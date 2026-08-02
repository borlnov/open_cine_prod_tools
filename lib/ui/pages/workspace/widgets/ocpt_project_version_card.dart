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
/// A card is clickable throughout — clicking any version but the previewed one enters its
/// read-only preview, and clicking the previewed one leaves it — and, badges aside, every card
/// offers the same three actions: `Rename`, `Restore this version` and `Delete`. Only `Delete` is
/// ever withheld, and only from the previewed card: the preview reads from a database hydrated out
/// of that very row, so deleting it from under itself is refused. Two badges mark what a card is,
/// mutually exclusive with previewing winning when the two coincide for a moment (a version created
/// and immediately previewed):
///
/// - `Base` — the working copy descends from this version. Its footer explains what that means
///   rather than repeating the generic "click to preview" every other card shows, since the click
///   still does exactly that.
/// - `Preview` — this version is the one currently on screen read-only, in the workspace's warning
///   colour.
///
/// `Rename`, `Restore this version` and `Delete` each start the inline mode this card shows itself
/// in place of its footer, instead of a dialog: the question — or the form — is about this card,
/// and the mock-up puts the answer where it applies. Only one of the three is ever shown at a time.
class OcptProjectVersionCard extends StatelessWidget {
  /// The version this card shows.
  final OcptProjectVersion version;

  /// Whether [version] is the one currently being previewed read-only.
  final bool isPreviewed;

  /// Whether this card currently shows its inline delete confirmation instead of its actions.
  final bool isConfirmingDeletion;

  /// Whether this card currently shows its inline restore confirmation instead of its actions.
  final bool isConfirmingRestore;

  /// Whether this card currently shows its inline rename form instead of its actions.
  final bool isConfirmingRename;

  /// Called when the card is clicked: enters this version's preview, or leaves it when it is
  /// already the one being previewed.
  final VoidCallback onTap;

  /// Called when `Restore this version` is clicked, which only asks for confirmation.
  final VoidCallback onRestoreRequested;

  /// Called when the inline confirmation's `Restore` is clicked, which rewrites the project.
  final VoidCallback onRestoreConfirmed;

  /// Called when the inline restore confirmation's `Cancel` is clicked.
  final VoidCallback onRestoreCancelled;

  /// Called when `Delete` is clicked, which only asks for confirmation; null on the previewed
  /// card, which may not be deleted.
  final VoidCallback? onDeleteRequested;

  /// Called when the inline confirmation's `Delete` is clicked, which deletes for good.
  final VoidCallback onDeleteConfirmed;

  /// Called when the inline confirmation's `Cancel` is clicked.
  final VoidCallback onDeleteCancelled;

  /// Called when `Rename` is clicked, which only opens the inline rename form. Renaming touches
  /// no project data, so this is never withheld, not even from the previewed card.
  final VoidCallback onRenameRequested;

  /// Called with the trimmed name and note when the inline rename form's `Save` is clicked.
  final void Function(String name, String note) onRenameConfirmed;

  /// Called when the inline rename form's `Cancel` is clicked.
  final VoidCallback onRenameCancelled;

  /// Class constructor
  const OcptProjectVersionCard({
    super.key,
    required this.version,
    required this.isPreviewed,
    required this.isConfirmingDeletion,
    required this.isConfirmingRestore,
    required this.isConfirmingRename,
    required this.onTap,
    required this.onRestoreRequested,
    required this.onRestoreConfirmed,
    required this.onRestoreCancelled,
    required this.onDeleteRequested,
    required this.onDeleteConfirmed,
    required this.onDeleteCancelled,
    required this.onRenameRequested,
    required this.onRenameConfirmed,
    required this.onRenameCancelled,
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
                ocptProjectVersionSummaryLine(
                  context,
                  summary: version.summary,
                  createdAt: version.createdAt,
                ),
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
              else if (isConfirmingRestore)
                _buildRestoreConfirmation(context, theme, tr)
              else if (isConfirmingRename)
                _OcptProjectVersionRenameForm(
                  initialName: version.name,
                  initialNote: version.note,
                  onSave: onRenameConfirmed,
                  onCancel: onRenameCancelled,
                )
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

  /// Builds what the card says under its counters when it isn't asking anything: the hint telling
  /// the user what clicking it does, then the three actions it offers — `Rename` and
  /// `Restore this version` on every card, `Delete` on every card but the previewed one.
  ///
  /// The hint and the actions sit on two lines rather than one: `Restore this version` is a long
  /// label, and the dock it lives in is narrow and resizable down to a third of the workspace.
  Widget _buildFooter(BuildContext context, ThemeData theme, Tr tr) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        switch ((version.isBase, isPreviewed)) {
          (true, false) => tr.projectVersionBaseHint,
          (_, true) => tr.projectVersionPreviewedHint,
          _ => tr.projectVersionPreviewHint,
        },
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      // A `Wrap` rather than a `Row`: `Restore this version` is a long label, the dock it lives
      // in is resizable down to a third of the workspace, and the actions then simply stack
      // instead of overflowing.
      Wrap(
        alignment: WrapAlignment.end,
        children: [
          TextButton(onPressed: onRenameRequested, child: Text(tr.projectVersionRenameAction)),
          TextButton(onPressed: onRestoreRequested, child: Text(tr.projectVersionRestoreAction)),
          if (onDeleteRequested != null)
            TextButton(
              onPressed: onDeleteRequested,
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: Text(tr.projectVersionDeleteAction),
            ),
        ],
      ),
    ],
  );

  /// Builds the inline restore confirmation shown in place of the card's footer: what restoring
  /// actually does to the project, then the two answers to it.
  ///
  /// The question says the page setup comes back too, and that the state being replaced is kept:
  /// both are consequences the user cannot see anywhere else, and the second is the one that makes
  /// the answer safe to give.
  Widget _buildRestoreConfirmation(BuildContext context, ThemeData theme, Tr tr) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr.projectVersionRestoreConfirmMessage, style: theme.textTheme.bodySmall),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: onRestoreCancelled,
            child: Text(tr.projectVersionRestoreCancelAction),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: onRestoreConfirmed,
            child: Text(tr.projectVersionRestoreConfirmAction),
          ),
        ],
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

  /// The card's own colour: the accent for the base version, the workspace's warning colour
  /// while this version is the one being previewed, and a muted outline for every other one.
  Color _accentColor(BuildContext context, ThemeData theme) {
    if (isPreviewed) {
      return ocptWarningColor(context);
    }

    return version.isBase ? theme.colorScheme.primary : theme.colorScheme.outline;
  }

  /// The badge this card carries, or null when it carries none.
  ///
  /// Previewing wins over being the base, since the two can legitimately coincide for a moment (a
  /// version created and immediately previewed): the badge answers "what am I looking at?".
  String? _badgeLabel(Tr tr) {
    if (isPreviewed) {
      return tr.projectVersionPreviewBadge;
    }

    return version.isBase ? tr.projectVersionBaseBadge : null;
  }
}

/// The small pill naming what a card is — `Base` or `Preview` — tinted with the card's own
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

/// The inline form a version card shows in place of its footer while [OcptProjectVersionCard.
/// isConfirmingRename] is true: a required name field and an optional note field, pre-filled from
/// the version being renamed, then `Cancel` and `Save`.
///
/// Kept as its own small stateful widget, holding the two [TextEditingController]s the form needs,
/// so the card itself stays a plain [StatelessWidget]: a fresh instance is created every time the
/// rename mode opens (the card only mounts this while [OcptProjectVersionCard.isConfirmingRename]
/// is true), which is what re-seeds the fields from the version's current name and note.
class _OcptProjectVersionRenameForm extends StatefulWidget {
  /// The version's name, seeding the name field.
  final String initialName;

  /// The version's note, seeding the note field.
  final String initialNote;

  /// Called with the trimmed name and note when `Save` is clicked.
  final void Function(String name, String note) onSave;

  /// Called when `Cancel` is clicked.
  final VoidCallback onCancel;

  /// Class constructor
  const _OcptProjectVersionRenameForm({
    required this.initialName,
    required this.initialNote,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_OcptProjectVersionRenameForm> createState() => _OcptProjectVersionRenameFormState();
}

/// The state of [_OcptProjectVersionRenameForm]: the two field controllers, and the name field's
/// emptiness the `Save` button's `onPressed` is rebuilt from.
class _OcptProjectVersionRenameFormState extends State<_OcptProjectVersionRenameForm> {
  /// The controller of the name field.
  late final TextEditingController _nameController;

  /// The controller of the note field.
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName)
      ..addListener(_onNameChanged);
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final isNameEmpty = _nameController.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nameController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: tr.projectVersionRenameNameLabel),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _noteController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(labelText: tr.projectVersionRenameNoteLabel),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: Text(tr.projectVersionRenameCancelAction),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: isNameEmpty ? null : _save,
              child: Text(tr.projectVersionRenameConfirmAction),
            ),
          ],
        ),
      ],
    );
  }

  /// Rebuilds the form so the `Save` button's `onPressed` reflects the name field's new emptiness.
  void _onNameChanged() => setState(() {});

  /// Reports the trimmed name and note to [_OcptProjectVersionRenameForm.onSave].
  void _save() => widget.onSave(_nameController.text.trim(), _noteController.text.trim());
}
