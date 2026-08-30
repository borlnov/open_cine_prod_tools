// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_qr_code/act_qr_code.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The Rejoindre screen's camera-scan tab, mobile only — `QrCodeReader` is instantiated **only**
/// while this widget is actually mounted, which the page itself gates on `PlatformManager.isMobile`
/// (`docs/plans/relay.md`, Phase C, commit 4): a desktop build never reaches this widget at all,
/// keeping it — and its tests — off the camera plugin entirely.
class OcptJoiningScannerView extends StatelessWidget {
  /// Called with the raw text a scanned QR code decoded to — not necessarily a valid invite, which
  /// the bloc is the one to decide.
  final void Function(String scannedText) onScanned;

  /// Class constructor
  const OcptJoiningScannerView({required this.onScanned, super.key});

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
              // `QrCodeReader` is deprecated upstream ("needs to be reworked"), but it's still the
              // only camera reader `actlibs/act_qr_code` exposes, and its own doc comment plan says
              // to use it as-is for this commit.
              // ignore: deprecated_member_use
              child: QrCodeReader(
                onDataFound: onScanned,
                askPermissionInfo: AskPermissionInfo(
                  textAskingPermission: Text(tr.joiningCameraPermissionAskingMessage),
                  textWhenPermissionDenied: Text(tr.joiningCameraPermissionDeniedMessage),
                  permButton: ({VoidCallback onPressed = _doNothing}) => RawMaterialButton(
                    onPressed: onPressed,
                    fillColor: theme.colorScheme.primary,
                    child: Text(
                      tr.joiningCameraPermissionButtonLabel,
                      style: TextStyle(color: theme.colorScheme.onPrimary),
                    ),
                  ),
                ),
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

  /// `AskPermissionInfo.permButton`'s own type declares `onPressed` as optional, even though
  /// `QrCodeReader` always calls it with one — a default is only ever needed to satisfy that
  /// signature, never actually invoked.
  static void _doNothing() {}
}
