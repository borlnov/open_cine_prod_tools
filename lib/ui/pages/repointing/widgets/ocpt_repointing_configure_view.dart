// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_enrolment.dart';

/// The maximum width of the ① Configure form, matching the Partager screen's own
/// `OcptSharingConfigureView`.
const _maxContentWidth = 560.0;

/// The repointing page's ① Configure state: the relay address and the enrolment secret, typed by
/// hand or read off another relay's own enrolment QR, and the primary action that moves the
/// project there.
///
/// A `StatefulWidget` for its own text fields and the scan/manual toggle alone — none of it is
/// project data to load, so none belongs in `OcptRepointingState`, exactly the reasoning
/// `OcptSharingConfigureView`'s own text controllers already follow. The relay address is
/// validated **here**, before [onRepointRequested] is even called: the bloc has no `Tr` to word a
/// malformed-URL message with (`docs/architecture/foundations.md`).
class OcptRepointingConfigureView extends StatefulWidget {
  /// Whether a "Switch relay" submission is currently in flight.
  final bool isRepointing;

  /// Called with the relay address, already parsed, and the enrolment secret once both have
  /// passed this widget's own validation — typed by hand, or scanned off a relay enrolment QR.
  final void Function(Uri relayBaseUri, String enrolmentSecret) onRepointRequested;

  /// Class constructor
  const OcptRepointingConfigureView({
    required this.isRepointing,
    required this.onRepointRequested,
    super.key,
  });

  @override
  State<OcptRepointingConfigureView> createState() => _OcptRepointingConfigureViewState();
}

/// The state of [OcptRepointingConfigureView].
class _OcptRepointingConfigureViewState extends State<OcptRepointingConfigureView> {
  /// The relay address field's own controller.
  final _relayAddressController = TextEditingController();

  /// The enrolment secret field's own controller.
  final _enrolmentSecretController = TextEditingController();

  /// Whether the enrolment secret is currently shown in the clear.
  bool _isSecretVisible = false;

  /// The relay address's own validation message, or null while it hasn't been submitted invalid
  /// yet.
  String? _relayAddressError;

  /// Whether the camera scanner is currently shown in place of the manual form — mobile only, the
  /// first operator on a desktop always types the two fields.
  bool _isScanning = false;

  /// Bumped every time a scanned code fails to parse as a relay enrolment, so the scanner card
  /// below is rebuilt with a fresh key and re-arms for another attempt — `MobileScanner` only ever
  /// reports its very first detection back (see [_OcptRepointingScannerCard]'s own doc comment).
  int _scannerGeneration = 0;

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
    final isMobile = globalGetIt().get<PlatformManager>().isMobile;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr.repointingConfigureIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              if (isMobile && _isScanning) ...[
                _OcptRepointingScannerCard(
                  key: ValueKey(_scannerGeneration),
                  onScanned: _onScanned,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: widget.isRepointing
                        ? null
                        : () => setState(() => _isScanning = false),
                    child: Text(tr.repointingEnterManuallyAction),
                  ),
                ),
              ] else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr.repointingRelayCardTitle, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _relayAddressController,
                          decoration: InputDecoration(
                            labelText: tr.repointingRelayAddressLabel,
                            hintText: tr.repointingRelayAddressHint,
                            errorText: _relayAddressError,
                          ),
                          keyboardType: TextInputType.url,
                          enabled: !widget.isRepointing,
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
                          enabled: !widget.isRepointing,
                          decoration: InputDecoration(
                            labelText: tr.repointingEnrolmentSecretLabel,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isSecretVisible ? Icons.visibility_off : Icons.visibility,
                              ),
                              mouseCursor: ocptClickableCursor,
                              onPressed: () =>
                                  setState(() => _isSecretVisible = !_isSecretVisible),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.isRepointing ? null : _onSubmitPressed,
                  child: widget.isRepointing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(tr.repointingSubmitAction),
                ),
                if (isMobile) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: widget.isRepointing
                        ? null
                        : () => setState(() => _isScanning = true),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(tr.repointingScanQrAction),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Validates the relay address, showing [_relayAddressError] and dispatching nothing when it
  /// isn't a well-formed absolute URI, otherwise calling
  /// [OcptRepointingConfigureView.onRepointRequested].
  void _onSubmitPressed() {
    final text = _relayAddressController.text.trim();
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      setState(() => _relayAddressError = Tr.of(context).repointingRelayAddressInvalidMessage);
      return;
    }

    setState(() => _relayAddressError = null);
    widget.onRepointRequested(uri, _enrolmentSecretController.text);
  }

  /// Handles a QR code scanned by [_OcptRepointingScannerCard]: a code that isn't a relay
  /// enrolment is ignored and the scanner re-armed for another attempt
  /// ([_scannerGeneration]) — never a crash — while a valid one fills the two fields and submits
  /// straight away, exactly as scanning the Partager screen's own invite QR joins straight away
  /// with no extra confirmation step.
  void _onScanned(String scannedText) {
    final enrolment = OcptRelayEnrolment.tryParse(scannedText);
    if (enrolment == null) {
      setState(() => _scannerGeneration++);
      return;
    }

    _relayAddressController.text = enrolment.relayBaseUri.toString();
    _enrolmentSecretController.text = enrolment.enrolmentSecret;
    setState(() => _isScanning = false);
    widget.onRepointRequested(enrolment.relayBaseUri, enrolment.enrolmentSecret);
  }
}

/// The repointing page's own camera-scan card, mobile only — mirrors `OcptJoiningScannerView`'s
/// own `MobileScanner` use, with wording specific to scanning a relay's own enrolment QR rather
/// than a teammate's project invite.
///
/// A separate, private widget rather than a reuse of `OcptJoiningScannerView`: the two screens
/// scan different QR shapes (`ocpt://relay` here, `ocpt://join` there) and need their own on-screen
/// hint text, which that widget has no way to override.
class _OcptRepointingScannerCard extends StatefulWidget {
  /// Called with the raw text a scanned QR code decoded to — not necessarily a valid enrolment,
  /// which [OcptRepointingConfigureView] is the one to decide.
  final void Function(String scannedText) onScanned;

  /// Class constructor
  const _OcptRepointingScannerCard({required this.onScanned, super.key});

  @override
  State<_OcptRepointingScannerCard> createState() => _OcptRepointingScannerCardState();
}

/// The state of [_OcptRepointingScannerCard].
class _OcptRepointingScannerCardState extends State<_OcptRepointingScannerCard> {
  /// Whether [_OcptRepointingScannerCard.onScanned] has already fired — `MobileScanner` keeps
  /// streaming detections of the same code for as long as it stays framed, and a detection must
  /// only be reported once per mounted instance of this card (a fresh instance, keyed by the
  /// parent's own generation counter, re-arms it).
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            AspectRatio(aspectRatio: 1, child: MobileScanner(onDetect: _onDetect)),
            const SizedBox(height: 14),
            Text(
              tr.repointingScannerHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// Reports the first detected barcode's raw value to [_OcptRepointingScannerCard.onScanned], then
  /// ignores every further detection — `OcptJoiningScannerView._onDetect`'s own reasoning.
  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) {
      return;
    }

    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null) {
      return;
    }

    setState(() => _hasScanned = true);
    widget.onScanned(rawValue);
  }
}
