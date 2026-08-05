// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// The dialog every irreversible action of the app is confirmed through — deleting a record,
/// removing a tag, replacing the screenplay with an imported file.
///
/// One dialog for all of them, and a **dialog** rather than an inline yes/no: an action that cannot
/// be undone must be answered the same way wherever it is asked from, so a user never has to work
/// out whether *this* particular question is the kind that acts straight away. Use [show] to display
/// it and get back whether the user confirmed; it is dismissed through `OcptRouterManager.pop`,
/// never `Navigator`.
///
/// The caller owns every word of it ([title], [message], [cancelLabel], [confirmLabel]): what is
/// about to happen, and what it costs, is the one thing this dialog cannot know. It also owns
/// [isDestructive], which is what tells apart "this destroys something" — the error-coloured
/// confirm button — from an irreversible action that only replaces one state by another.
class OcptConfirmDialog extends StatelessWidget {
  /// The question the dialog asks, e.g. `Delete this location?`.
  final String title;

  /// The line stating what the action costs, shown under [title].
  final String message;

  /// The label of the button dismissing the dialog without acting.
  final String cancelLabel;

  /// The label of the button confirming the action.
  final String confirmLabel;

  /// Whether the action destroys something, painting the confirm button in the theme's error
  /// colours rather than its ordinary filled ones.
  final bool isDestructive;

  /// Class constructor
  const OcptConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    this.isDestructive = true,
  });

  /// Shows the dialog and returns true if the user confirmed the action, false or null if they
  /// cancelled it.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
    bool isDestructive = true,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => OcptConfirmDialog(
      title: title,
      message: message,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      isDestructive: isDestructive,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop<bool>(true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
