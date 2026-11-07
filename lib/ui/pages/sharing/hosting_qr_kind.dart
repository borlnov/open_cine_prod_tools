// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which of the hosting panel's own two QR codes is currently shown — the panel's own
/// `SegmentedButton<OcptHostingQrKind>` selects between them, see
/// `lib/ui/pages/sharing/widgets/ocpt_hosting_panel.dart`.
enum OcptHostingQrKind {
  /// The `ocpt://join` invite a device with no local copy of the project scans to get one.
  join,

  /// The `ocpt://relay` enrolment a device that already has the project scans to point itself at
  /// this hosted relay instead of wherever it was pointed before.
  enrolment,
}
