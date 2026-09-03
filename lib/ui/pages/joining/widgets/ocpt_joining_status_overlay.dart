// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_state.dart';

/// The Rejoindre screen's own blocking modal, covering the whole page for as long as a join is in
/// flight and for the success state that follows it.
///
/// A full-bleed layer over the rest of the page — meant to sit as the last child of a `Stack`, see
/// `OcptJoiningView` — rather than a `showDialog` route: it is driven entirely by
/// `OcptJoiningBloc`'s own state (appearing and disappearing as `isJoining`/`joinSucceeded`
/// change), and painting it as an ordinary widget layer keeps that one state stream the only thing
/// that decides whether it's on screen, with no separate open/close call to keep in sync with it.
/// It paints over the scanner and the manual form so neither can be triggered again while a join
/// is in flight or its result is waiting to be opened — Benoit's own mobile testing found both the
/// scanner staying live and a successful join dropping straight into the project with no
/// confirmation.
///
/// Two states, switched on [succeeded]:
/// - busy: a spinner, [step]'s own label, and an "Annuler" button — best-effort only, see
///   `OcptJoiningCancelledEvent`'s own doc comment for what it cannot stop.
/// - success: a check mark, "Projet récupéré", and an "Ouvrir" button. The page never navigates to
///   the workspace on its own once a join succeeds — only pressing this button does, through
///   `OcptJoiningOpenRequestedEvent`.
class OcptJoiningStatusOverlay extends StatelessWidget {
  /// The join's current phase, shown while busy. Null only for a frame that cannot actually occur
  /// in practice — `OcptJoiningBloc._join` always sets a step in the very same emit that raises
  /// `isJoining` — but is handled defensively rather than assumed away.
  final OcptJoinStep? step;

  /// Whether the join succeeded: switches the overlay from the busy state to the success one.
  final bool succeeded;

  /// Called when "Annuler" is pressed, busy state only.
  final VoidCallback onCancelRequested;

  /// Called when "Ouvrir" is pressed, success state only.
  final VoidCallback onOpenRequested;

  /// Class constructor
  const OcptJoiningStatusOverlay({
    required this.step,
    required this.succeeded,
    required this.onCancelRequested,
    required this.onOpenRequested,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: ColoredBox(
        color: theme.colorScheme.scrim.withValues(alpha: 0.45),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: succeeded ? _buildSuccess(context, theme) : _buildBusy(context, theme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The busy state: spinner, current step label, "Annuler".
  Widget _buildBusy(BuildContext context, ThemeData theme) {
    final tr = Tr.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(height: 16),
        Text(_stepLabel(tr), style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: onCancelRequested, child: Text(tr.joiningCancelAction)),
      ],
    );
  }

  /// The success state: check mark, "Projet récupéré", "Ouvrir".
  Widget _buildSuccess(BuildContext context, ThemeData theme) {
    final tr = Tr.of(context);
    final successColor =
        theme.extension<OcptSpecificColors>()?.shotStatusShot ?? theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 40, color: successColor),
        const SizedBox(height: 16),
        Text(
          tr.joiningSuccessTitle,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onOpenRequested, child: Text(tr.joiningOpenAction)),
      ],
    );
  }

  /// [step]'s own label, falling back to the generic "Retrieving the project…" wording for the
  /// null case this class's own doc comment explains cannot actually occur.
  String _stepLabel(Tr tr) => switch (step) {
    OcptJoinStep.connecting => tr.joiningStepConnecting,
    OcptJoinStep.downloading => tr.joiningStepDownloading,
    OcptJoinStep.opening => tr.joiningStepOpening,
    null => tr.joiningProgressTitle,
  };
}
