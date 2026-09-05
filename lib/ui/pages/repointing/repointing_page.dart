// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/repointing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/repointing_event.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/repointing_state.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/widgets/ocpt_repointing_configure_view.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/widgets/ocpt_repointing_qr_view.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/widgets/ocpt_sharing_chip.dart';

/// The "Changer de relais" screen for the currently open project: moving its ongoing sync from the
/// relay it is paired to onto another one (`docs/plans/on-set-server.md`, Phase E).
///
/// One screen, two states, told apart by [OcptRepointingState.enrolment]: ① Configure — a relay
/// address and an enrolment secret, typed or scanned off another relay's own enrolment QR, and the
/// button that moves the project there — and ② QR code — the enrolment QR the next crew member
/// scans to do the very same thing, on the exact model of the Partager screen's own
/// Configure→Invite shape (`lib/ui/pages/sharing/`), except this screen always opens on ①, even
/// for a project already paired: re-pointing is a repeatable action, not a one-time setup.
///
/// Reachable only while a project is open (`OcptRouterManager`'s guard, mirroring the sharing
/// route's own).
class OcptRepointingPage extends StatelessWidget {
  /// Class constructor
  const OcptRepointingPage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptRepointingBloc(), child: const OcptRepointingView());
}

/// The content of [OcptRepointingPage], separated from it so [OcptRepointingPage] only wires the
/// [OcptRepointingBloc] up (RFL3).
///
/// Public, like `OcptSharingView`, for the same reason: a widget test pumps it directly with a
/// `BlocProvider.value` wrapping an [OcptRepointingBloc] built over injected managers.
class OcptRepointingView extends StatelessWidget {
  /// Class constructor
  const OcptRepointingView({super.key});

  @override
  Widget build(BuildContext context) => BlocConsumer<OcptRepointingBloc, OcptRepointingState>(
    listenWhen: (previous, current) => current.repointFailed && !previous.repointFailed,
    listener: _onRepointFailed,
    builder: (context, state) {
      if (state.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final tr = Tr.of(context);
      final theme = Theme.of(context);
      final isDone = state.enrolment != null;

      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => globalGetIt().get<OcptRouterManager>().pop()),
          title: Text(tr.repointingPageTitle(state.projectName)),
          actions: [
            OcptSharingChip(
              label: isDone ? tr.repointingStepQrChip : tr.repointingStepConfigureChip,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: switch (state.enrolment) {
          null => OcptRepointingConfigureView(
            isRepointing: state.isRepointing,
            onRepointRequested: (relayBaseUri, enrolmentSecret) => context
                .read<OcptRepointingBloc>()
                .add(
                  OcptRepointingRequestedEvent(
                    relayBaseUri: relayBaseUri,
                    enrolmentSecret: enrolmentSecret,
                  ),
                ),
          ),
          final enrolment => OcptRepointingQrView(enrolment: enrolment),
        },
      );
    },
  );

  /// Shows [OcptRepointingState.repointFailed]'s own snack bar, then dispatches the event that
  /// clears it, so a later rebuild doesn't show it again — `OcptSharingView`'s own
  /// `_onPairingFailed`.
  void _onRepointFailed(BuildContext context, OcptRepointingState state) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).repointingErrorMessage)));
    context.read<OcptRepointingBloc>().add(const OcptRepointingErrorDismissedEvent());
  }
}
