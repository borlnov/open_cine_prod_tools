// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';

/// The events handled by `OcptHostingBloc`.
sealed class OcptHostingEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptHostingEvent();
}

/// Requests loading the current project's own hosting facts: the manager's current host state, its
/// "host on launch" preference and whether it can be set at all.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptHostingLoadRequestedEvent extends OcptHostingEvent {
  /// Class constructor
  const OcptHostingLoadRequestedEvent();
}

/// Reports a new value off `OcptRelayHostManager.stateStream` — the bloc's own subscription to it
/// forwards every state the manager moves through as one of these.
class OcptHostingHostStateChangedEvent extends OcptHostingEvent {
  /// The host state just reported.
  final OcptRelayHostState hostState;

  /// Class constructor
  const OcptHostingHostStateChangedEvent(this.hostState);

  /// Object properties
  @override
  List<Object?> get props => [...super.props, hostState];
}

/// Reports a new value off `OcptSyncManager.presenceRosterStream` — the bloc's own subscription to
/// it (kept alive only while hosting is online, since that stream itself is null otherwise) forwards
/// every roster the sync manager moves through as one of these.
class OcptHostingPresenceChangedEvent extends OcptHostingEvent {
  /// The presence roster just reported, or null when nobody (not even this replica) is left in it.
  final OcptPresenceRoster? presenceRoster;

  /// Class constructor
  const OcptHostingPresenceChangedEvent(this.presenceRoster);

  /// Object properties
  @override
  List<Object?> get props => [...super.props, presenceRoster];
}

/// Reports that the "Hébergement" switch was toggled: [start] is the value it was set to — true to
/// start hosting the current project, false to stop it.
class OcptHostingStartStopRequestedEvent extends OcptHostingEvent {
  /// Whether hosting should start (true) or stop (false).
  final bool start;

  /// Class constructor
  const OcptHostingStartStopRequestedEvent({required this.start});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, start];
}

/// Reports that the "Réhéberger ce projet au démarrage" checkbox was toggled to [value].
class OcptHostingAutoRestartChangedEvent extends OcptHostingEvent {
  /// The checkbox's own new value.
  final bool value;

  /// Class constructor
  const OcptHostingAutoRestartChangedEvent({required this.value});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, value];
}

/// Reports that the "Réconcilier amont…" action was run, with the invite text typed or pasted into
/// the panel's own inline field.
class OcptHostingReconcileRequestedEvent extends OcptHostingEvent {
  /// The invite text to parse as an `ocpt://join` link, exactly as typed.
  final String inviteText;

  /// Class constructor
  const OcptHostingReconcileRequestedEvent(this.inviteText);

  /// Object properties
  @override
  List<Object?> get props => [...super.props, inviteText];
}

/// Reports that the panel has shown `OcptHostingState.reconcileOutcome`'s own result line (or
/// `OcptHostingState.reconcileInviteInvalid`'s own message), so the bloc clears both and a later
/// rebuild doesn't show them again — the same one-shot-notice shape `OcptSharingBloc`'s own
/// `OcptSharingPairingErrorDismissedEvent` already follows.
class OcptHostingReconcileDismissedEvent extends OcptHostingEvent {
  /// Class constructor
  const OcptHostingReconcileDismissedEvent();
}
