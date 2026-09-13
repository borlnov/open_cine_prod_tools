// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The Rejoindre screen's manual-entry tab: a single field for the invite link the Partager
/// screen's "Copy the invite link" button hands over, and the "Rejoindre" button submitting it.
///
/// A `StatefulWidget` for its own text controller alone — none of it is project data to load, so
/// none belongs in `OcptJoiningState`, exactly the reasoning `OcptSharingConfigureView`'s own text
/// controllers already follow. The field is **not** validated here: none of it needs a `Tr`
/// (`OcptJoiningBloc._onManualSubmitted`'s own doc comment), so the raw text is handed straight to
/// [onJoinRequested] and the bloc is what decides whether it was a well-formed invite link.
class OcptJoiningManualView extends StatefulWidget {
  /// Whether a join is currently in flight — the field and the button itself are disabled while
  /// it is.
  final bool isJoining;

  /// Called with the invite link field's own raw text once "Rejoindre" is pressed.
  final void Function(String inviteLinkText) onJoinRequested;

  /// Class constructor
  const OcptJoiningManualView({required this.isJoining, required this.onJoinRequested, super.key});

  @override
  State<OcptJoiningManualView> createState() => _OcptJoiningManualViewState();
}

/// The state of [OcptJoiningManualView].
class _OcptJoiningManualViewState extends State<OcptJoiningManualView> {
  /// The invite link field's own controller.
  final _inviteLinkController = TextEditingController();

  @override
  void dispose() {
    _inviteLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.joiningManualCardTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _inviteLinkController,
              enabled: !widget.isJoining,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(helperText: tr.joiningInviteLinkHelperText),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: widget.isJoining ? null : _onJoinPressed,
                child: widget.isJoining
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr.joiningJoinAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hands the invite link field's own raw text to [OcptJoiningManualView.onJoinRequested] as
  /// typed — see this class's own doc comment for why nothing is validated here.
  void _onJoinPressed() => widget.onJoinRequested(_inviteLinkController.text);
}
