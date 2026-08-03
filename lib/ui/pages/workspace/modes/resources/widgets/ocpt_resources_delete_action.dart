// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The destructive action a resources sheet carries at its very bottom, and the inline
/// confirmation it turns into — the role sheet's `Delete this role`, the location sheet's
/// `Delete this location`.
///
/// A [StatefulWidget] (the documented RFL1 exception) because it owns that ephemeral yes/no state:
/// nothing outside it needs to know a delete is being confirmed, and the bloc's own state carries
/// no such flag (unlike a project version's `versionPendingDeletionId`, this is never worth
/// surviving a rebuild triggered by something else). The question is answered inline rather than
/// through a dialog, exactly as a project version card asks its own — the person sheet's own
/// dialog is the odd one out, and it is the one erasing a whole address-book entry.
///
/// The caller owns the wording ([label], [confirmMessage]): what is being deleted, and what is lost
/// with it, is the one thing this widget cannot know. It only ever renders when the sheet may be
/// written to, so it takes a plain non-null callback rather than a nullable one.
class OcptResourcesDeleteAction extends StatefulWidget {
  /// The id of the record being deleted, watched so switching sheets closes an open question.
  final String ownerId;

  /// The action's own label, e.g. `Delete this location`.
  final String label;

  /// The line the confirmation states before asking, e.g. what is deleted along with the record.
  final String confirmMessage;

  /// Called once the confirmation is answered `Delete`.
  final VoidCallback onDeleteRequested;

  /// Class constructor
  const OcptResourcesDeleteAction({
    super.key,
    required this.ownerId,
    required this.label,
    required this.confirmMessage,
    required this.onDeleteRequested,
  });

  @override
  State<OcptResourcesDeleteAction> createState() => _OcptResourcesDeleteActionState();
}

/// The state of [OcptResourcesDeleteAction]: the inline delete confirmation's own flag.
class _OcptResourcesDeleteActionState extends State<OcptResourcesDeleteAction> {
  /// Whether the confirmation is shown in place of the action.
  bool _isConfirming = false;

  @override
  void didUpdateWidget(covariant OcptResourcesDeleteAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The sheet now shows another record: reopening the question later should ask again, not
    // resume where the previous one left off.
    if (widget.ownerId != oldWidget.ownerId) {
      _isConfirming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    if (!_isConfirming) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => setState(() => _isConfirming = true),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: Text(widget.label),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.confirmMessage,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _isConfirming = false),
              child: Text(tr.resourcesDeleteCancelAction),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: () {
                setState(() => _isConfirming = false);
                widget.onDeleteRequested();
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: Text(tr.resourcesDeleteConfirmAction),
            ),
          ],
        ),
      ],
    );
  }
}
