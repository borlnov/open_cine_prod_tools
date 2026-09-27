// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// What the user chose in a dialog shown through [OcptConfirmDialog.showWithAlternative] — the
/// three-button extension [OcptConfirmDialog] takes on for an irreversible action that offers a
/// middle ground between doing nothing and destroying everything (e.g. removing a floor-plan set
/// element from one sequence versus deleting it everywhere).
///
/// [OcptConfirmDialog.show], the plain two-button call 35 other call sites already rely on, keeps
/// returning a plain `bool?` and never produces this type.
enum OcptConfirmDialogResult {
  /// The user dismissed the dialog without acting — the cancel button, or dismissing it any other
  /// way (a click outside it, `Escape`).
  cancelled,

  /// The user pressed the (possibly destructive) confirm action.
  confirmed,

  /// The user pressed the alternative action — a third choice short of [confirmed], e.g. "remove
  /// from this sequence" rather than "delete everywhere".
  alternative,
}

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
///
/// [alternativeLabel], set only through [showWithAlternative], adds a third button between cancel
/// and confirm — **still the one confirmation widget** the whole app funnels through, never a
/// second dialog type: a caller that needs a middle ground (e.g. "remove from this sequence" next
/// to "delete everywhere") reaches for the very same class rather than rolling its own.
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

  /// The label of the third, alternative button, shown between [cancelLabel] and [confirmLabel]
  /// when set — only ever set by [showWithAlternative], which is also what makes every button pop
  /// a [OcptConfirmDialogResult] instead of the plain `bool` [show] pops. Null for every dialog
  /// [show] opens, which is the whole of this class's existing behaviour, unchanged.
  final String? alternativeLabel;

  /// Class constructor
  const OcptConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    this.isDestructive = true,
    this.alternativeLabel,
  });

  /// Shows the dialog and returns true if the user confirmed the action, false or null if they
  /// cancelled it.
  ///
  /// **Unchanged** — every one of this method's 35 existing call sites keeps working exactly as
  /// before; [showWithAlternative] is a separate entry point for the one case that needs a third
  /// button, never a change to this one's own signature or behaviour.
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

  /// Shows the dialog with a third, [alternativeLabel] button between cancel and confirm, and
  /// returns which of the three the user picked ([OcptConfirmDialogResult.cancelled] for a plain
  /// dismissal too, e.g. a click outside the dialog or `Escape`).
  ///
  /// For deleting a floor-plan set element used by two or more sequences
  /// (`docs/plans/storyboard.md`, §10.4): `Cancel` / `Remove from sequence <n>`
  /// ([OcptConfirmDialogResult.alternative]) / `Delete everywhere`
  /// ([OcptConfirmDialogResult.confirmed], destructive). A caller with only two choices keeps using
  /// [show] — this is additive, never a replacement.
  static Future<OcptConfirmDialogResult> showWithAlternative(
    BuildContext context, {
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
    required String alternativeLabel,
    bool isDestructive = true,
  }) async {
    final result = await showDialog<OcptConfirmDialogResult>(
      context: context,
      builder: (context) => OcptConfirmDialog(
        title: title,
        message: message,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
        isDestructive: isDestructive,
        alternativeLabel: alternativeLabel,
      ),
    );
    return result ?? OcptConfirmDialogResult.cancelled;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final alternativeLabel = this.alternativeLabel;
    final usesEnumResult = alternativeLabel != null;

    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => usesEnumResult
              ? globalGetIt().get<OcptRouterManager>().pop<OcptConfirmDialogResult>(
                  OcptConfirmDialogResult.cancelled,
                )
              : globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(cancelLabel),
        ),
        if (alternativeLabel != null)
          TextButton(
            onPressed: () => globalGetIt().get<OcptRouterManager>().pop<OcptConfirmDialogResult>(
              OcptConfirmDialogResult.alternative,
            ),
            child: Text(alternativeLabel),
          ),
        FilledButton(
          onPressed: () => usesEnumResult
              ? globalGetIt().get<OcptRouterManager>().pop<OcptConfirmDialogResult>(
                  OcptConfirmDialogResult.confirmed,
                )
              : globalGetIt().get<OcptRouterManager>().pop<bool>(true),
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
