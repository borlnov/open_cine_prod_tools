// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:ui' as ui;

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_qr_code/act_qr_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/widgets/ocpt_sharing_chip.dart';

/// The maximum width of the ② Invite column, matching the mock-up's own ~620px column.
const _maxContentWidth = 620.0;

/// The side of the QR code drawn in the invite card.
const _qrSize = 140.0;

/// The sharing page's ② Invite state: the QR a teammate scans, the relay address and the masked
/// project token a manual join reads instead, and the footer's own live status and "stop sharing"
/// action.
///
/// A `StatefulWidget` for the one piece of state that belongs to this screen alone and nowhere in
/// `OcptSharingState`: whether the project token is currently shown in the clear.
class OcptSharingInviteView extends StatefulWidget {
  /// The current project's display name, used to name the QR image file a teammate saves.
  final String projectName;

  /// The current project's own relay invite.
  final OcptRelayInvite invite;

  /// Called when "Stop sharing…" is pressed — the page asks `OcptConfirmDialog` before dispatching
  /// anything, so this is a plain request, not a confirmation.
  final VoidCallback onUnshareRequested;

  /// Class constructor
  const OcptSharingInviteView({
    required this.projectName,
    required this.invite,
    required this.onUnshareRequested,
    super.key,
  });

  @override
  State<OcptSharingInviteView> createState() => _OcptSharingInviteViewState();
}

/// The state of [OcptSharingInviteView].
class _OcptSharingInviteViewState extends State<OcptSharingInviteView> {
  /// The key the QR's own `RepaintBoundary` is built with, so "Save the QR code…" has a render
  /// object to capture.
  final _qrBoundaryKey = GlobalKey();

  /// Whether the project token is currently shown in the clear.
  bool _isTokenVisible = false;

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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RepaintBoundary(
                        key: _qrBoundaryKey,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.white,
                          child: QrCodeImage(
                            text: widget.invite.toInviteString(),
                            color: Colors.black,
                            size: _qrSize,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr.sharingInviteCardTitle, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(tr.sharingInviteCardBody, style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: _onSaveQrPressed,
                                  child: Text(tr.sharingSaveQrAction),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      _copyToClipboard(widget.invite.toInviteString()),
                                  child: Text(tr.sharingCopyInviteLinkAction),
                                ),
                              ],
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
                      Text(tr.sharingConnectionCardTitle, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _OcptSharingConnectionRow(
                        label: tr.sharingRelayAddressLabel,
                        value: widget.invite.relayBaseUri.toString(),
                        onCopyPressed: () => _copyToClipboard(widget.invite.relayBaseUri.toString()),
                      ),
                      const SizedBox(height: 12),
                      _OcptSharingConnectionRow(
                        label: tr.sharingProjectTokenLabel,
                        value: _isTokenVisible ? widget.invite.token : _maskedToken,
                        onCopyPressed: () => _copyToClipboard(widget.invite.token),
                        trailing: IconButton(
                          tooltip: _isTokenVisible
                              ? tr.sharingHideTokenTooltip
                              : tr.sharingRevealTokenTooltip,
                          icon: Icon(_isTokenVisible ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _isTokenVisible = !_isTokenVisible),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OcptSharingChip(
                    label: tr.sharingStatusSyncedChip,
                    color: theme.colorScheme.primary,
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: widget.onUnshareRequested,
                    style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    child: Text(tr.sharingUnshareAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// [OcptRelayInvite.token], masked to a fixed run of dots — never a partial reading of it, unlike
  /// [OcptRelayInvite.toString]'s own log-friendly masking: nothing here is meant to narrow down
  /// what the hidden characters could be.
  String get _maskedToken => "•" * 24;

  /// Copies [text] to the clipboard — fire-and-forget, exactly like the screenplay editor's own
  /// "Copy as Fountain" action.
  void _copyToClipboard(String text) => unawaited(Clipboard.setData(ClipboardData(text: text)));

  /// Captures the QR card's own `RepaintBoundary` as a PNG and hands it to the native save dialog
  /// `FileSaverManager` opens — the same manager `OcptExportManager` builds every export's own save
  /// step on, so this stays consistent with "every export writes through a native save dialog"
  /// even though it isn't a project export.
  Future<void> _onSaveQrPressed() async {
    final renderObject = _qrBoundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return;
    }

    final image = await renderObject.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return;
    }

    await globalGetIt().get<FileSaverManager>().saveFileFromBytes(
      fileName: "${widget.projectName}-invite-qr.png",
      bytes: byteData.buffer.asUint8List(),
    );
  }
}

/// One row of [OcptSharingInviteView]'s own "Connection" card: a label, its read-only value, an
/// optional [trailing] control (the token's own reveal/hide toggle) and a copy button.
class _OcptSharingConnectionRow extends StatelessWidget {
  /// The label naming what [value] is.
  final String label;

  /// The value shown, read-only.
  final String value;

  /// Called when the copy button is pressed.
  final VoidCallback onCopyPressed;

  /// An extra control shown before the copy button, or null.
  final Widget? trailing;

  /// Class constructor
  const _OcptSharingConnectionRow({
    required this.label,
    required this.value,
    required this.onCopyPressed,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
        IconButton(
          tooltip: tr.sharingCopyTooltip,
          icon: const Icon(Icons.copy_outlined),
          onPressed: onCopyPressed,
        ),
      ],
    );
  }
}
