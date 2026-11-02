// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_enrolment.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_connection_row.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_invite_column.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_qr_code.dart';

/// The repointing page's ② QR code state: the `ocpt://relay` enrolment QR the next crew member
/// scans to move their own project to the very same relay, the relay address and the masked
/// enrolment secret, a copy button, and a "Terminé" action closing the screen.
///
/// Unlike `OcptSharingInviteView`, there is no destructive action here at all — re-pointing is not
/// "stop sharing" — so this is a plain `StatelessWidget` with nothing of its own to hold beyond
/// [enrolment].
class OcptRepointingQrView extends StatelessWidget {
  /// The enrolment this project was just re-pointed to.
  final OcptRelayEnrolment enrolment;

  /// Get [enrolment]'s own secret, masked to a fixed run of dots —
  /// `OcptSharingInviteView._maskedToken`'s own reasoning: nothing here is meant to narrow down
  /// what the hidden characters could be.
  String get _maskedSecret => "•" * 24;

  /// Class constructor
  const OcptRepointingQrView({required this.enrolment, super.key});

  /// Build the repointing QR view as a [Center].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return OcptInviteColumn(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OcptQrCode(data: enrolment.toEnrolmentString()),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr.repointingQrCardTitle, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(tr.repointingQrCardBody, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _copyToClipboard(enrolment.toEnrolmentString()),
                        child: Text(tr.repointingCopyEnrolmentAction),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OcptConnectionRow(
                  label: tr.repointingRelayAddressLabel,
                  value: enrolment.relayBaseUri.toString(),
                  onCopyPressed: () => _copyToClipboard(enrolment.relayBaseUri.toString()),
                ),
                const SizedBox(height: 12),
                OcptConnectionRow(
                  label: tr.repointingEnrolmentSecretLabel,
                  value: _maskedSecret,
                  onCopyPressed: () => _copyToClipboard(enrolment.enrolmentSecret),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
            child: Text(tr.repointingDoneAction),
          ),
        ),
      ],
    );
  }

  /// Copy [text] to the clipboard — fire-and-forget, exactly like `OcptSharingInviteView`'s own
  /// `_copyToClipboard`.
  void _copyToClipboard(String text) => unawaited(Clipboard.setData(ClipboardData(text: text)));
}
