// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_frame.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_reconcile_outcome.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/hosting_state.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_presence_color.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_qr_code.dart';

/// The maximum width of the hosting panel's own column, matching `OcptSharingConfigureView`'s own
/// ~560px column.
const _maxContentWidth = 560.0;

/// The Partager screen's "Héberger sur ce poste" panel (`docs/architecture/sync.md`): a pure
/// function of [state] and the callbacks below, exactly the shape
/// `OcptSharingConfigureView`/`OcptSharingInviteView` already follow — every write goes out through
/// a nullable `on…Requested` callback, never a manager reached into directly (RD/RFL).
///
/// The Marche/Arrêt switch and the "réhéberger au démarrage" checkbox always render; the
/// advertised-address dropdown, the port field, the QR-kind segmented button and its one QR, the
/// connected-peers list and the "Réconcilier amont…" action only render while `state.hostState` is
/// [OcptRelayHostOnline] — absent otherwise, per the approved layout's own "greyed/hidden when
/// stopped".
class OcptHostingPanel extends StatefulWidget {
  /// The state this panel renders.
  final OcptHostingState state;

  /// Called when the Marche/Arrêt switch is toggled, with the value it was set to.
  final ValueChanged<bool> onStartStopRequested;

  /// Called when the "réhéberger au démarrage" checkbox is toggled, with the value it was set to.
  final ValueChanged<bool> onAutoRestartChanged;

  /// Called when the reconcile form's own "Réconcilier" button is pressed, with the invite text
  /// typed or pasted into it.
  final ValueChanged<String> onReconcileRequested;

  /// Called once the panel has shown [state]'s own reconcile result (or invalid-invite message), so
  /// the bloc clears it and a later rebuild doesn't show it again.
  final VoidCallback onReconcileDismissed;

  /// Called when the advertised-address dropdown picks a different value, with the address just
  /// picked — one of `state.availableAddresses`.
  final ValueChanged<String> onAdvertisedAddressChanged;

  /// Called when the port field's own "Appliquer" is pressed, with the port typed into it.
  final ValueChanged<int> onPortChangeRequested;

  /// Called when the QR-kind segmented button picks a different kind.
  final ValueChanged<OcptHostingQrKind> onQrKindChanged;

  /// Class constructor
  const OcptHostingPanel({
    required this.state,
    required this.onStartStopRequested,
    required this.onAutoRestartChanged,
    required this.onReconcileRequested,
    required this.onReconcileDismissed,
    required this.onAdvertisedAddressChanged,
    required this.onPortChangeRequested,
    required this.onQrKindChanged,
    super.key,
  });

  @override
  State<OcptHostingPanel> createState() => _OcptHostingPanelState();
}

/// The state of [OcptHostingPanel]: whether the reconcile form is currently open, and its own text
/// field controller — neither is project data, exactly the reasoning
/// `OcptSharingConfigureView`/`OcptSharingInviteView`'s own throwaway form state already follows.
class _OcptHostingPanelState extends State<OcptHostingPanel> {
  bool _isReconcileFormOpen = false;
  final _inviteController = TextEditingController();
  late final TextEditingController _portController = TextEditingController(
    text: widget.state.boundPort?.toString() ?? '',
  );

  @override
  void didUpdateWidget(covariant OcptHostingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.boundPort != oldWidget.state.boundPort) {
      _portController.text = widget.state.boundPort?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _inviteController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final hostState = widget.state.hostState;
    final isOnline = hostState is OcptRelayHostOnline;
    final isStarting = hostState is OcptRelayHostStarting;
    final isFailed = hostState is OcptRelayHostFailed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr.hostingSwitchLabel, style: theme.textTheme.titleMedium),
                                const SizedBox(height: 2),
                                Text(
                                  _statusLabel(tr, hostState),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isFailed
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isOnline || isStarting,
                            onChanged: isStarting
                                ? null
                                : (value) => widget.onStartStopRequested(value),
                          ),
                        ],
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: widget.state.hostOnLaunch,
                        title: Text(tr.hostingAutoRestartLabel),
                        onChanged: widget.state.canSetAutoRestart
                            ? (value) => widget.onAutoRestartChanged(value ?? false)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              if (isOnline) ...[
                const SizedBox(height: 16),
                _OcptHostingAddressPortCard(
                  state: widget.state,
                  portController: _portController,
                  onAdvertisedAddressChanged: widget.onAdvertisedAddressChanged,
                  onPortChangeRequested: widget.onPortChangeRequested,
                ),
                const SizedBox(height: 16),
                _OcptHostingQrCard(state: widget.state, onQrKindChanged: widget.onQrKindChanged),
                const SizedBox(height: 16),
                _OcptHostingPeersCard(roster: widget.state.presenceRoster),
                const SizedBox(height: 16),
                _OcptHostingReconcileCard(
                  state: widget.state,
                  isFormOpen: _isReconcileFormOpen,
                  controller: _inviteController,
                  onOpenForm: () => setState(() => _isReconcileFormOpen = true),
                  onReconcileRequested: widget.onReconcileRequested,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// [hostState]'s own status subtitle, shown under [OcptHostingPanel]'s own switch label.
String _statusLabel(Tr tr, OcptRelayHostState hostState) => switch (hostState) {
  OcptRelayHostStopped() => tr.hostingStatusStopped,
  OcptRelayHostStarting() => tr.hostingStatusStarting,
  OcptRelayHostOnline() => tr.hostingStatusOnline,
  OcptRelayHostFailed() => tr.hostingStatusFailed,
};

/// The hosting panel's own advertised-address dropdown and port field: `state.availableAddresses`
/// (with `state.selectedAddress` appended when the resolver dropped the address the socket is
/// still advertising — a defensive fallback so the dropdown's own `value` always matches one of
/// its items) picks what [OcptHostingState.enrolment]/[OcptHostingState.joinInvite] encode as a
/// host, and the port field re-binds the socket itself through [onPortChangeRequested] once
/// "Appliquer" is pressed or the field is submitted — an invalid or empty port is silently ignored.
class _OcptHostingAddressPortCard extends StatelessWidget {
  /// Class constructor
  const _OcptHostingAddressPortCard({
    required this.state,
    required this.portController,
    required this.onAdvertisedAddressChanged,
    required this.onPortChangeRequested,
  });

  /// The state this card reads its own address/port facts off.
  final OcptHostingState state;

  /// The port field's own controller, owned by [OcptHostingPanel]'s own state so it survives a
  /// rebuild and is kept in step with [OcptHostingState.boundPort].
  final TextEditingController portController;

  /// Called when the dropdown picks a different address.
  final ValueChanged<String> onAdvertisedAddressChanged;

  /// Called when the port field is applied, with the parsed port.
  final ValueChanged<int> onPortChangeRequested;

  void _applyPort() {
    final parsed = int.tryParse(portController.text.trim());
    if (parsed != null) {
      onPortChangeRequested(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final selectedAddress = state.selectedAddress;
    final items = <String>[
      ...state.availableAddresses,
      if (selectedAddress != null && !state.availableAddresses.contains(selectedAddress))
        selectedAddress,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr.hostingAdvertisedAddressLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedAddress,
                    items: [
                      for (final address in items)
                        DropdownMenuItem(value: address, child: Text(address)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onAdvertisedAddressChanged(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: portController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr.hostingPortLabel),
                    onSubmitted: (_) => _applyPort(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _applyPort, child: Text(tr.hostingApplyPort)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The hosting panel's own QR-kind segmented button and the one QR it currently shows: a "join"
/// segment ([OcptHostingQrKind.join]) drawing [OcptHostingState.joinInvite], for a device that
/// doesn't have the project yet, and a "switch relay" segment ([OcptHostingQrKind.enrolment])
/// drawing [OcptHostingState.enrolment], for a device that already has the project and only needs
/// pointing here — each with its own caption clarifying which is which, and a copy-link button
/// copying the very same string the QR encodes.
class _OcptHostingQrCard extends StatelessWidget {
  /// Class constructor
  const _OcptHostingQrCard({required this.state, required this.onQrKindChanged});

  /// The state this card reads its own QR facts off.
  final OcptHostingState state;

  /// Called when the segmented button picks a different QR kind.
  final ValueChanged<OcptHostingQrKind> onQrKindChanged;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final kind = state.qrKind;
    final data = switch (kind) {
      OcptHostingQrKind.join => state.joinInvite?.toInviteString(),
      OcptHostingQrKind.enrolment => state.enrolment?.toEnrolmentString(),
    };
    final caption = switch (kind) {
      OcptHostingQrKind.join => tr.hostingQrJoinCaption,
      OcptHostingQrKind.enrolment => tr.hostingQrRepointCaption,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<OcptHostingQrKind>(
              segments: [
                ButtonSegment(value: OcptHostingQrKind.join, label: Text(tr.hostingQrKindJoin)),
                ButtonSegment(
                  value: OcptHostingQrKind.enrolment,
                  label: Text(tr.hostingQrKindRepoint),
                ),
              ],
              selected: {kind},
              onSelectionChanged: (selection) => onQrKindChanged(selection.first),
            ),
            if (data != null) ...[
              const SizedBox(height: 16),
              Center(child: OcptQrCode(data: data)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      caption,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr.hostingCopyLinkTooltip,
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: data))),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The hosting panel's own connected-peers card: [roster]'s own participants, each a small
/// [ocptPresenceColor] dot and a neutral `platform · <id fragment>` label — never a name, exactly
/// `OcptPresenceIndicator`'s own reasoning — or [Tr.hostingNoPeers] while [roster] is null or empty.
class _OcptHostingPeersCard extends StatelessWidget {
  /// Class constructor
  const _OcptHostingPeersCard({required this.roster});

  /// The roster this card draws, or null while none is known yet.
  final OcptPresenceRoster? roster;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final participants = roster?.participants ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.hostingPeersLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (participants.isEmpty)
              Text(
                tr.hostingNoPeers,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [for (final frame in participants) _OcptHostingPeerChip(frame: frame)],
              ),
          ],
        ),
      ),
    );
  }
}

/// One connected-peer chip: [ocptPresenceColor]'s own deterministic dot, and [frame]'s own neutral
/// `platform · <id fragment>` label.
class _OcptHostingPeerChip extends StatelessWidget {
  /// Class constructor
  const _OcptHostingPeerChip({required this.frame});

  /// The frame this chip represents.
  final OcptPresenceFrame frame;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: ocptPresenceColor(frame.deviceId), shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(_peerLabel(frame), style: theme.textTheme.bodySmall),
      ],
    );
  }

  /// [frame]'s own neutral label: its platform, capitalised, then a short, stable slice of its
  /// `deviceId` — `OcptPresenceIndicator._participantLabel`'s own shape, replicated here since that
  /// one is private to its own file.
  static String _peerLabel(OcptPresenceFrame frame) {
    final platform = frame.platform;
    final capitalised = platform.isEmpty
        ? platform
        : platform[0].toUpperCase() + platform.substring(1);
    final id = frame.deviceId;
    final fragment = id.length <= 3 ? id : id.substring(id.length - 3);

    return "$capitalised · $fragment";
  }
}

/// The hosting panel's own "Réconcilier amont…" card: closed, it is a single action button;
/// opened ([isFormOpen]), it reveals an inline text field for the upstream `ocpt://join` invite and
/// the "Réconcilier" button that runs it, plus [state]'s own result line once one exists.
class _OcptHostingReconcileCard extends StatelessWidget {
  /// Class constructor
  const _OcptHostingReconcileCard({
    required this.state,
    required this.isFormOpen,
    required this.controller,
    required this.onOpenForm,
    required this.onReconcileRequested,
  });

  /// The state this card reads its own reconcile facts off.
  final OcptHostingState state;

  /// Whether the inline invite field is currently shown.
  final bool isFormOpen;

  /// The invite field's own controller, owned by [OcptHostingPanel]'s own state.
  final TextEditingController controller;

  /// Called when the action button opens the inline form.
  final VoidCallback onOpenForm;

  /// Called when "Réconcilier" is pressed, with the field's own current text.
  final ValueChanged<String> onReconcileRequested;

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
            if (!isFormOpen)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: onOpenForm,
                  child: Text(tr.hostingReconcileAction),
                ),
              )
            else ...[
              Text(tr.hostingReconcileAction, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                enabled: !state.isReconciling,
                decoration: InputDecoration(hintText: tr.hostingReconcileInviteHint),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: state.isReconciling
                      ? null
                      : () => onReconcileRequested(controller.text),
                  child: state.isReconciling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(tr.hostingReconcileRun),
                ),
              ),
            ],
            if (state.reconcileInviteInvalid) ...[
              const SizedBox(height: 8),
              Text(
                tr.hostingReconcileInvalidInvite,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            if (state.reconcileOutcome case final outcome?) ...[
              const SizedBox(height: 8),
              _OcptHostingReconcileResultLine(outcome: outcome),
            ],
          ],
        ),
      ),
    );
  }
}

/// The reconcile card's own result line: the pushed/pulled counts on success, or a generic failure
/// line otherwise — [OcptReconcileFailed.message] is never shown directly, exactly
/// `OcptSharingState.pairingFailed`'s own reasoning (no `Tr` at the bloc layer to word it with).
class _OcptHostingReconcileResultLine extends StatelessWidget {
  /// Class constructor
  const _OcptHostingReconcileResultLine({required this.outcome});

  /// The outcome this line renders.
  final OcptReconcileOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final outcome = this.outcome;

    return switch (outcome) {
      OcptReconcileSucceeded(pushed: final pushed, pulled: final pulled) => Text(
        tr.hostingReconcileResult(pushed, pulled),
        style: theme.textTheme.bodySmall,
      ),
      OcptReconcileFailed() => Text(
        tr.hostingReconcileFailed,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
    };
  }
}
