// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_event.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_state.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/widgets/ocpt_sharing_chip.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/widgets/ocpt_sharing_configure_view.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/widgets/ocpt_sharing_invite_view.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// The "Partager" (sharing) screen for the currently open project: pairing it to a relay so a team
/// can join it, and inviting them once it is (`docs/plans/relay.md`, Phase C, commit 3).
///
/// One screen, two states, told apart by [OcptSharingState.invite]: ① Configure — a relay address
/// and an enrolment secret, and the button that pairs the project and creates it on the relay — and
/// ② Invite — the QR code and the connection details a teammate's own Rejoindre screen reads
/// instead, and the way to stop sharing.
///
/// Reachable only while a project is open (`OcptRouterManager`'s guard, mirroring the workspace and
/// project settings routes' own).
class OcptSharingPage extends StatelessWidget {
  /// Class constructor
  const OcptSharingPage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptSharingBloc(), child: const OcptSharingView());
}

/// The content of [OcptSharingPage], separated from it so [OcptSharingPage] only wires the
/// [OcptSharingBloc] up (RFL3).
///
/// Public, like `OcptProjectSettingsView`, for the same reason: a widget test pumps it directly
/// with a `BlocProvider.value` wrapping an [OcptSharingBloc] built over injected managers.
class OcptSharingView extends StatelessWidget {
  /// Class constructor
  const OcptSharingView({super.key});

  @override
  Widget build(BuildContext context) => BlocConsumer<OcptSharingBloc, OcptSharingState>(
    listenWhen: (previous, current) => current.pairingFailed && !previous.pairingFailed,
    listener: _onPairingFailed,
    builder: (context, state) {
      if (state.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final tr = Tr.of(context);
      final theme = Theme.of(context);
      final isPaired = state.invite != null;

      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => globalGetIt().get<OcptRouterManager>().pop()),
          title: Text(tr.sharingPageTitle(state.projectName)),
          actions: [
            OcptSharingChip(
              label: isPaired ? tr.sharingStepInviteChip : tr.sharingStepConfigureChip,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            OcptSharingChip(
              label: isPaired ? tr.sharingStatusSyncedChip : tr.sharingStatusUnpairedChip,
              color: isPaired ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: switch (state.invite) {
          null => OcptSharingConfigureView(
            isPairing: state.isPairing,
            onPairRequested: (relayBaseUri, enrolmentSecret) => context
                .read<OcptSharingBloc>()
                .add(
                  OcptSharingPairRequestedEvent(
                    relayBaseUri: relayBaseUri,
                    enrolmentSecret: enrolmentSecret,
                  ),
                ),
          ),
          final invite => OcptSharingInviteView(
            projectName: state.projectName,
            invite: invite,
            onUnshareRequested: () => unawaited(_onUnshareRequested(context)),
          ),
        },
      );
    },
  );

  /// Shows [OcptSharingState.pairingFailed]'s own snack bar, then dispatches the event that clears
  /// it, so a later rebuild doesn't show it again — `EditorPage`'s own `hasSaveError` handling.
  void _onPairingFailed(BuildContext context, OcptSharingState state) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).sharingPairingErrorMessage)));
    context.read<OcptSharingBloc>().add(const OcptSharingPairingErrorDismissedEvent());
  }

  /// Asks `OcptConfirmDialog` whether sharing really is to stop, then dispatches the confirmed
  /// event if the user agreed.
  Future<void> _onUnshareRequested(BuildContext context) async {
    final bloc = context.read<OcptSharingBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.sharingUnshareConfirmTitle,
      message: tr.sharingUnshareConfirmMessage,
      cancelLabel: tr.sharingUnshareConfirmCancelAction,
      confirmLabel: tr.sharingUnshareConfirmConfirmAction,
    );
    if (confirmed != true) {
      return;
    }

    bloc.add(const OcptSharingUnpairConfirmedEvent());
  }
}
