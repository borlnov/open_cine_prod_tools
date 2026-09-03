// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_scan_frame.dart';

/// The Rejoindre screen's camera-scan tab, mobile only — `MobileScanner` is instantiated **only**
/// while this widget is actually mounted, which the page itself gates on `PlatformManager.isMobile`
/// (`docs/plans/relay.md`, Phase C, commit 4): a desktop build never reaches this widget at all,
/// keeping it — and its tests — off the camera plugin entirely. `mobile_scanner` surfaces the OS
/// camera-permission prompt itself, so there is no permission plumbing to build here.
///
/// [status] paints [OcptJoiningScanFrame]'s own border around the camera preview — driven by the
/// page off `OcptJoiningBloc`'s state, not by this widget, which has no opinion of its own on
/// whether a scan led anywhere.
class OcptJoiningScannerView extends StatefulWidget {
  /// Called with the raw text a scanned QR code decoded to — not necessarily a valid invite, which
  /// the bloc is the one to decide.
  final void Function(String scannedText) onScanned;

  /// The frame's own current status — see [OcptJoiningScanFrame].
  final OcptJoiningScanStatus status;

  /// Class constructor
  const OcptJoiningScannerView({required this.onScanned, required this.status, super.key});

  @override
  State<OcptJoiningScannerView> createState() => _OcptJoiningScannerViewState();
}

/// The state of [OcptJoiningScannerView].
class _OcptJoiningScannerViewState extends State<OcptJoiningScannerView> {
  /// The raw value of the last code reported through [OcptJoiningScannerView.onScanned], or null
  /// before any has been. `MobileScanner` keeps streaming detections of the same code for as long
  /// as it stays framed, so a detection is only reported when it differs from this — which is also
  /// what lets the camera re-arm for a fresh attempt after an invalid code: nothing has to be reset
  /// by hand, framing a *different* code is enough to report it.
  String? _lastReportedValue;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: OcptJoiningScanFrame(
                status: widget.status,
                child: MobileScanner(onDetect: _onDetect),
              ),
            ),
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

  /// Reports a newly detected barcode's raw value to [OcptJoiningScannerView.onScanned], ignoring a
  /// repeat of [_lastReportedValue] — see that field's own doc comment for why this is also what
  /// re-arms the camera for a fresh attempt.
  void _onDetect(BarcodeCapture capture) {
    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null || rawValue == _lastReportedValue) {
      return;
    }

    _lastReportedValue = rawValue;
    widget.onScanned(rawValue);
  }
}
