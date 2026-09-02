// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_enrolment.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The default side of the QR code, matching `OcptRepointingQrView`'s own original `_qrSize`.
const _defaultSize = 140.0;

/// The bare QR code encoding an [OcptRelayEnrolment] — nothing else: no title, no address card, no
/// action button. This is the pure visual `OcptRepointingQrView` used to draw inline before it was
/// extracted here, so more than one screen (the repointing page's own ② QR code state, and the
/// Partager screen's "Héberger sur ce poste" panel) can show the same QR without also pulling in a
/// full page's own chrome — a page like `OcptRepointingQrView` is meant to be reached as its own
/// screen, never embedded inside another one's scrollable content.
///
/// White, padded, on a plain [Container]: a QR code needs a light quiet zone around its modules to
/// scan reliably, which is why this stays white even in dark theme, exactly like the paper-simulated
/// screenplay preview (`CLAUDE.md`'s own "white page even in dark theme").
class OcptEnrolmentQrCode extends StatelessWidget {
  /// The enrolment this QR code encodes.
  final OcptRelayEnrolment enrolment;

  /// The QR code's own side, in logical pixels.
  final double size;

  /// Class constructor
  const OcptEnrolmentQrCode({required this.enrolment, this.size = _defaultSize, super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    color: Colors.white,
    child: QrImageView(
      data: enrolment.toEnrolmentString(),
      size: size,
      eyeStyle: const QrEyeStyle(color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
    ),
  );
}
