// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_reconcile_outcome.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';

/// The state of `OcptHostingBloc` — the Partager screen's "Héberger sur ce poste" segment
/// (`docs/plans/in-app-relay-hosting.md`, Phase E).
///
/// Named "Hosting" throughout this bloc layer, rather than reusing `OcptRelayHostManager`'s own
/// `OcptRelayHostState` as a name, precisely to avoid the clash: [hostState] carries one of those
/// values, and this class wraps it with everything the panel needs besides — the "réhéberger au
/// démarrage" checkbox's own two facts ([hostOnLaunch], [canSetAutoRestart]), the connected-peers
/// roster ([presenceRoster], reused verbatim from `OcptSyncManager` — no hosting-specific presence
/// exists), and the in-app reconcile's own transient facts ([isReconciling], [reconcileOutcome],
/// [reconcileInviteInvalid]).
class OcptHostingState extends BlocStateForMixin<OcptHostingState> {
  /// Whether this state's own initial load — the manager's current host state, the project's own
  /// "host on launch" preference, and its relay-side id — is still in flight.
  final bool isLoading;

  /// The hosted relay's own lifecycle, straight off `OcptRelayHostManager.state`/`stateStream`.
  final OcptRelayHostState hostState;

  /// Whether the current project should start hosting itself again automatically the next time it
  /// is opened — the "réhéberger ce projet au démarrage" checkbox's own value.
  final bool hostOnLaunch;

  /// Whether [hostOnLaunch] can be changed right now — true once the project has a relay-side id of
  /// its own, either because it is already paired to some relay or because it is hosting right now
  /// (`OcptRelayHostManager.hostedProjectId`): a project that has never been paired or hosted has no
  /// id yet for the flag to be stored against, so the checkbox stays disabled until then.
  final bool canSetAutoRestart;

  /// Every replica currently connected to the hosted relay, or null while none is hosting (or the
  /// presence service hasn't reported yet) — `OcptSyncManager.presenceRoster`'s own contract.
  final OcptPresenceRoster? presenceRoster;

  /// Whether a "Réconcilier amont…" push-then-pull is currently in flight.
  final bool isReconciling;

  /// The last "Réconcilier amont…" run's own outcome, or null before one has ever run or after the
  /// panel has dismissed it.
  final OcptReconcileOutcome? reconcileOutcome;

  /// Whether the last "Réconcilier amont…" submission's own invite text could not even be parsed as
  /// an `ocpt://join` link — kept apart from [reconcileOutcome] since this never reaches
  /// `OcptRelayHostManager.reconcileWithUpstream` at all, and the panel words it with a dedicated,
  /// more specific message than [OcptReconcileFailed]'s own generic one.
  final bool reconcileInviteInvalid;

  /// Class constructor
  const OcptHostingState({
    required this.isLoading,
    required this.hostState,
    required this.hostOnLaunch,
    required this.canSetAutoRestart,
    required this.presenceRoster,
    required this.isReconciling,
    required this.reconcileOutcome,
    required this.reconcileInviteInvalid,
  });

  /// The initial state, shown for the brief moment before the load completes.
  const OcptHostingState.init()
    : isLoading = true,
      hostState = const OcptRelayHostStopped(),
      hostOnLaunch = false,
      canSetAutoRestart = false,
      presenceRoster = null,
      isReconciling = false,
      reconcileOutcome = null,
      reconcileInviteInvalid = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [presenceRoster] and [reconcileOutcome] legitimately go back to null (hosting stopped, or the
  /// panel dismissed the last reconcile result), so each has its own `clear…` flag rather than a
  /// bare nullable parameter, which could never tell "leave it alone" apart from "clear it" —
  /// exactly `OcptSharingState.clearInvite`'s own reasoning.
  @override
  OcptHostingState copyWith({
    bool? isLoading,
    OcptRelayHostState? hostState,
    bool? hostOnLaunch,
    bool? canSetAutoRestart,
    OcptPresenceRoster? presenceRoster,
    bool clearPresenceRoster = false,
    bool? isReconciling,
    OcptReconcileOutcome? reconcileOutcome,
    bool clearReconcileOutcome = false,
    bool? reconcileInviteInvalid,
  }) => OcptHostingState(
    isLoading: isLoading ?? this.isLoading,
    hostState: hostState ?? this.hostState,
    hostOnLaunch: hostOnLaunch ?? this.hostOnLaunch,
    canSetAutoRestart: canSetAutoRestart ?? this.canSetAutoRestart,
    presenceRoster: clearPresenceRoster ? null : (presenceRoster ?? this.presenceRoster),
    isReconciling: isReconciling ?? this.isReconciling,
    reconcileOutcome: clearReconcileOutcome ? null : (reconcileOutcome ?? this.reconcileOutcome),
    reconcileInviteInvalid: reconcileInviteInvalid ?? this.reconcileInviteInvalid,
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    hostState,
    hostOnLaunch,
    canSetAutoRestart,
    presenceRoster,
    isReconciling,
    reconcileOutcome,
    reconcileInviteInvalid,
  ];
}
