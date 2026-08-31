// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The Rejoindre screen's camera-scan tab, mobile only — `MobileScanner` is instantiated **only**
/// while this widget is actually mounted, which the page itself gates on `PlatformManager.isMobile`
/// (`docs/plans/relay.md`, Phase C, commit 4): a desktop build never reaches this widget at all,
/// keeping it — and its tests — off the camera plugin entirely. `mobile_scanner` surfaces the OS
/// camera-permission prompt itself, so there is no permission plumbing to build here.
class OcptJoiningScannerView extends StatefulWidget {
  /// Called with the raw text a scanned QR code decoded to — not necessarily a valid invite, which
  /// the bloc is the one to decide.
  final void Function(String scannedText) onScanned;

  /// Class constructor
  const OcptJoiningScannerView({required this.onScanned, super.key});

  @override
  State<OcptJoiningScannerView> createState() => _OcptJoiningScannerViewState();
}

/// The state of [OcptJoiningScannerView].
class _OcptJoiningScannerViewState extends State<OcptJoiningScannerView> {
  /// Whether [OcptJoiningScannerView.onScanned] has already fired — `MobileScanner` keeps
  /// streaming detections of the same code for as long as it stays framed, and the invite must
  /// only be reported once.
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
              tr.joiningScannerHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// Reports the first detected barcode's raw value to [OcptJoiningScannerView.onScanned], then
  /// ignores every further detection: `MobileScanner` streams one callback per camera frame that
  /// still frames a decodable code, and the invite must only be reported once.
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
