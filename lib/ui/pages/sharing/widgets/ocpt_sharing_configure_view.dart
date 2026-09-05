// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The maximum width of the ① Configure form, matching the mock-up's own ~560px column.
const _maxContentWidth = 560.0;

/// The sharing page's ① Configure state: the relay address and the enrolment secret, and the
/// primary action that pairs the project and creates it on the relay.
///
/// A `StatefulWidget` for its own two text fields alone — neither is project data to load, so
/// neither belongs in `OcptSharingState`, exactly the reasoning every dialog collecting a
/// throwaway form value already follows (`OcptProjectVersionCreateDialog`'s own name field). The
/// relay address is validated **here**, before [onPairRequested] is even called: the bloc has no
/// `Tr` to word a malformed-URL message with (`docs/architecture/foundations.md`).
class OcptSharingConfigureView extends StatefulWidget {
  /// Whether a "Pair and create on the relay" submission is currently in flight.
  final bool isPairing;

  /// Called with the relay address, already parsed, and the enrolment secret once both have
  /// passed this widget's own validation.
  final void Function(Uri relayBaseUri, String enrolmentSecret) onPairRequested;

  /// Class constructor
  const OcptSharingConfigureView({
    required this.isPairing,
    required this.onPairRequested,
    super.key,
  });

  @override
  State<OcptSharingConfigureView> createState() => _OcptSharingConfigureViewState();
}

/// The state of [OcptSharingConfigureView].
class _OcptSharingConfigureViewState extends State<OcptSharingConfigureView> {
  /// The relay address field's own controller.
  final _relayAddressController = TextEditingController();

  /// The enrolment secret field's own controller.
  final _enrolmentSecretController = TextEditingController();

  /// Whether the enrolment secret is currently shown in the clear.
  bool _isSecretVisible = false;

  /// The relay address's own validation message, or null while it hasn't been submitted invalid
  /// yet.
  String? _relayAddressError;

  @override
  void dispose() {
    _relayAddressController.dispose();
    _enrolmentSecretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr.sharingConfigureIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr.sharingRelayCardTitle, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _relayAddressController,
                        decoration: InputDecoration(
                          labelText: tr.sharingRelayAddressLabel,
                          hintText: tr.sharingRelayAddressHint,
                          errorText: _relayAddressError,
                        ),
                        keyboardType: TextInputType.url,
                        enabled: !widget.isPairing,
                        onChanged: (_) {
                          if (_relayAddressError != null) {
                            setState(() => _relayAddressError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _enrolmentSecretController,
                        obscureText: !_isSecretVisible,
                        enabled: !widget.isPairing,
                        decoration: InputDecoration(
                          labelText: tr.sharingEnrolmentSecretLabel,
                          suffixIcon: IconButton(
                            icon: Icon(_isSecretVisible ? Icons.visibility_off : Icons.visibility),
                            mouseCursor: ocptClickableCursor,
                            onPressed: () => setState(() => _isSecretVisible = !_isSecretVisible),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha),
                  borderRadius: BorderRadius.circular(ocptRadiusMedium),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr.sharingTokenNoteText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: widget.isPairing ? null : _onPairPressed,
                child: widget.isPairing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr.sharingPairAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Validates the relay address, showing [_relayAddressError] and dispatching nothing when it
  /// isn't a well-formed absolute URI, otherwise calling [OcptSharingConfigureView.onPairRequested].
  void _onPairPressed() {
    final text = _relayAddressController.text.trim();
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      setState(() => _relayAddressError = Tr.of(context).sharingRelayAddressInvalidMessage);
      return;
    }

    setState(() => _relayAddressError = null);
    widget.onPairRequested(uri, _enrolmentSecretController.text);
  }
}
