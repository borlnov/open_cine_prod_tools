// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/hosting_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/hosting_event.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/hosting_state.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_event.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_state.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/widgets/ocpt_hosting_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/widgets/ocpt_sharing_chip.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/widgets/ocpt_sharing_configure_view.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/widgets/ocpt_sharing_invite_view.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// The Partager screen's own segments — the [SegmentedButton] at the top of its body, per
/// `docs/plans/in-app-relay-hosting.md`'s Phase E decision.
enum _OcptSharingSegment {
  /// The existing pair→invite flow against a remote relay — the screen's own historical, and only,
  /// content before this segment existed.
  remote,

  /// The "Héberger sur ce poste" panel, desktop only.
  host,
}

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
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (context) => OcptSharingBloc()),
      BlocProvider(create: (context) => OcptHostingBloc()),
    ],
    child: const OcptSharingView(),
  );
}

/// The content of [OcptSharingPage], separated from it so [OcptSharingPage] only wires the
/// [OcptSharingBloc] up (RFL3).
///
/// Public, like `OcptProjectSettingsView`, for the same reason: a widget test pumps it directly
/// with a `BlocProvider.value` wrapping an [OcptSharingBloc] built over injected managers.
class OcptSharingView extends StatelessWidget {
  /// Class constructor
  ///
  /// [platformManager] and [isReadOnly] are the injectable seams over `globalGetIt()` a widget
  /// test hands in instead — see [_isDesktop]/[_readOnly]'s own doc comments, exactly
  /// `OcptSyncStatusIndicator`'s own `syncManager`/`isReadOnly` reasoning.
  const OcptSharingView({super.key, PlatformManager? platformManager, bool? isReadOnly})
    : _platformManager = platformManager,
      _isReadOnly = isReadOnly;

  final PlatformManager? _platformManager;
  final bool? _isReadOnly;

  /// [_platformManager]'s own `isDesktop`, or the one `globalGetIt()` holds when there is an
  /// app-wide manager environment that actually registered one, or false otherwise — the segmented
  /// button (and the whole "Héberger sur ce poste" segment) never renders without a real desktop
  /// platform underneath it, whether that is because a mode's own widget test never registered one
  /// (harmless: nothing here tests hosting) or because the running build genuinely is mobile.
  bool _isDesktop(BuildContext context) {
    final override = _platformManager;
    if (override != null) {
      return override.isDesktop;
    }
    if (AbsGlobalManager.instance == null) {
      return false;
    }

    final managers = globalGetIt();
    return managers.isRegistered<PlatformManager>() && managers.get<PlatformManager>().isDesktop;
  }

  /// [_isReadOnly], or [OcptProjectsManager.currentProject]'s own `isReadOnly` when an app-wide
  /// manager environment registered one, or false otherwise — see [_isDesktop]'s own doc comment
  /// for why a missing registration reads as the harmless case rather than a crash.
  bool _readOnly(BuildContext context) {
    final override = _isReadOnly;
    if (override != null) {
      return override;
    }
    if (AbsGlobalManager.instance == null) {
      return false;
    }

    final managers = globalGetIt();
    if (!managers.isRegistered<OcptProjectsManager>()) {
      return false;
    }

    return managers.get<OcptProjectsManager>().currentProject?.isReadOnly ?? false;
  }

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
      final showHosting = _isDesktop(context) && !_readOnly(context);

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
        body: showHosting
            ? _OcptSharingSegmentedBody(remoteBody: _remoteBody(context, state))
            : _remoteBody(context, state),
      );
    },
  );

  /// The remote-relay segment's own content — the existing ① Configure / ② Invite switch, entirely
  /// unchanged by this segment's addition.
  Widget _remoteBody(BuildContext context, OcptSharingState state) => switch (state.invite) {
    null => OcptSharingConfigureView(
      isPairing: state.isPairing,
      onPairRequested: (relayBaseUri, enrolmentSecret) => context.read<OcptSharingBloc>().add(
        OcptSharingPairRequestedEvent(relayBaseUri: relayBaseUri, enrolmentSecret: enrolmentSecret),
      ),
    ),
    final invite => OcptSharingInviteView(
      projectName: state.projectName,
      invite: invite,
      onUnshareRequested: () => unawaited(_onUnshareRequested(context)),
    ),
  };

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

/// The Partager screen's own [SegmentedButton] and the segment-specific body it selects between —
/// [_OcptSharingSegment.remote] (unchanged) and [_OcptSharingSegment.host] (the "Héberger sur ce
/// poste" panel, driven by the very same [OcptHostingBloc] [OcptSharingPage] already provides).
///
/// A `StatefulWidget` for the one piece of state that belongs to this screen alone: which segment
/// is selected — defaulting to [_OcptSharingSegment.remote], per the approved layout.
class _OcptSharingSegmentedBody extends StatefulWidget {
  /// Class constructor
  const _OcptSharingSegmentedBody({required this.remoteBody});

  /// The remote-relay segment's own content, built once by [OcptSharingView] so it isn't rebuilt
  /// every time the segment selection itself changes.
  final Widget remoteBody;

  @override
  State<_OcptSharingSegmentedBody> createState() => _OcptSharingSegmentedBodyState();
}

/// The state of [_OcptSharingSegmentedBody].
class _OcptSharingSegmentedBodyState extends State<_OcptSharingSegmentedBody> {
  _OcptSharingSegment _segment = _OcptSharingSegment.remote;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<_OcptSharingSegment>(
            segments: [
              ButtonSegment(
                value: _OcptSharingSegment.remote,
                label: Text(tr.sharingSegmentRemote),
              ),
              ButtonSegment(value: _OcptSharingSegment.host, label: Text(tr.sharingSegmentHost)),
            ],
            selected: {_segment},
            onSelectionChanged: (selection) => setState(() => _segment = selection.first),
          ),
        ),
        Expanded(
          child: switch (_segment) {
            _OcptSharingSegment.remote => widget.remoteBody,
            _OcptSharingSegment.host => BlocBuilder<OcptHostingBloc, OcptHostingState>(
              builder: (context, state) => state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : OcptHostingPanel(
                      state: state,
                      onStartStopRequested: (start) => context.read<OcptHostingBloc>().add(
                        OcptHostingStartStopRequestedEvent(start: start),
                      ),
                      onAutoRestartChanged: (value) => context.read<OcptHostingBloc>().add(
                        OcptHostingAutoRestartChangedEvent(value: value),
                      ),
                      onReconcileRequested: (inviteText) => context.read<OcptHostingBloc>().add(
                        OcptHostingReconcileRequestedEvent(inviteText),
                      ),
                      onReconcileDismissed: () => context.read<OcptHostingBloc>().add(
                        const OcptHostingReconcileDismissedEvent(),
                      ),
                      onAdvertisedAddressChanged: (address) => context.read<OcptHostingBloc>().add(
                        OcptHostingAdvertisedAddressChangedEvent(address),
                      ),
                      onPortChangeRequested: (port) => context.read<OcptHostingBloc>().add(
                        OcptHostingPortChangeRequestedEvent(port),
                      ),
                      onQrKindChanged: (kind) => context.read<OcptHostingBloc>().add(
                        OcptHostingQrKindChangedEvent(kind),
                      ),
                    ),
            ),
          },
        ),
      ],
    );
  }
}
