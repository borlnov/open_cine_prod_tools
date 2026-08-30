// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The Rejoindre screen's manual-entry tab: the relay address, the project id and the project
/// token, typed by hand instead of scanned, and the "Rejoindre" button submitting them.
///
/// A `StatefulWidget` for its own three text fields alone — none of it is project data to load, so
/// none belongs in `OcptJoiningState`, exactly the reasoning `OcptSharingConfigureView`'s own text
/// controllers already follow. Unlike that form, the three fields are **not** validated here: none
/// of it needs a `Tr` (`OcptJoiningBloc._onManualSubmitted`'s own doc comment), so the raw text is
/// handed straight to [onJoinRequested] and the bloc is what decides whether it was well-formed.
class OcptJoiningManualView extends StatefulWidget {
  /// Whether a join is currently in flight — every field and the button itself are disabled while
  /// it is.
  final bool isJoining;

  /// Called with the three fields' own raw text once "Rejoindre" is pressed.
  final void Function(String relayAddressText, String projectIdText, String tokenText)
  onJoinRequested;

  /// Class constructor
  const OcptJoiningManualView({required this.isJoining, required this.onJoinRequested, super.key});

  @override
  State<OcptJoiningManualView> createState() => _OcptJoiningManualViewState();
}

/// The state of [OcptJoiningManualView].
class _OcptJoiningManualViewState extends State<OcptJoiningManualView> {
  /// The relay address field's own controller.
  final _relayAddressController = TextEditingController();

  /// The project id field's own controller.
  final _projectIdController = TextEditingController();

  /// The project token field's own controller.
  final _tokenController = TextEditingController();

  /// Whether the project token is currently shown in the clear.
  bool _isTokenVisible = false;

  @override
  void dispose() {
    _relayAddressController.dispose();
    _projectIdController.dispose();
    _tokenController.dispose();
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
              controller: _relayAddressController,
              enabled: !widget.isJoining,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr.sharingRelayAddressLabel,
                hintText: tr.sharingRelayAddressHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _projectIdController,
              enabled: !widget.isJoining,
              decoration: InputDecoration(labelText: tr.joiningProjectIdLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              obscureText: !_isTokenVisible,
              enabled: !widget.isJoining,
              decoration: InputDecoration(
                labelText: tr.sharingProjectTokenLabel,
                suffixIcon: IconButton(
                  icon: Icon(_isTokenVisible ? Icons.visibility_off : Icons.visibility),
                  mouseCursor: ocptClickableCursor,
                  onPressed: () => setState(() => _isTokenVisible = !_isTokenVisible),
                ),
              ),
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

  /// Hands the three fields' own raw text to [OcptJoiningManualView.onJoinRequested] as typed —
  /// see this class's own doc comment for why nothing is validated here.
  void _onJoinPressed() => widget.onJoinRequested(
    _relayAddressController.text,
    _projectIdController.text,
    _tokenController.text,
  );
}
