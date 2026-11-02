// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_reconcile_outcome.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_enrolment.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';

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

/// The state of `OcptHostingBloc` — the Partager screen's "Héberger sur ce poste" segment
/// (`docs/architecture/sync.md`).
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
  /// (`OcptRelayHostManager.hostedProjectId`): a project that has never been paired or hosted has
  /// no id yet for the flag to be stored against, so the checkbox stays disabled until then.
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

  /// Every advertised-address choice the hosting panel's own dropdown offers, straight off
  /// `OcptRelayHostManager.availableLanAddresses` — empty while hosting is offline or before the
  /// first load has completed.
  final List<String> availableAddresses;

  /// The address currently advertised — the host half of both [enrolment]'s and [joinInvite]'s own
  /// `relayBaseUri`, and the dropdown's own selected value. Null while hosting is offline.
  final String? selectedAddress;

  /// The port the hosted relay's socket is actually bound to right now — the port half of both
  /// [enrolment]'s and [joinInvite]'s own `relayBaseUri`, and what the panel's own port field is
  /// pre-filled with. Null while hosting is offline.
  final int? boundPort;

  /// The `ocpt://relay` enrolment built from [selectedAddress]/[boundPort] and the manager's own
  /// enrolment secret — what a device that already has the project scans to re-point here. Null
  /// while hosting is offline.
  final OcptRelayEnrolment? enrolment;

  /// The `ocpt://join` invite built from [selectedAddress]/[boundPort] and the hosted project's own
  /// pairing token — what a device with no local copy of the project scans to get one. Null while
  /// hosting is offline, or when the token could not be loaded (the panel still shows [enrolment]
  /// in that case).
  final OcptRelayInvite? joinInvite;

  /// Which of [enrolment]/[joinInvite] the panel's own QR currently shows.
  final OcptHostingQrKind qrKind;

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
    required this.availableAddresses,
    required this.selectedAddress,
    required this.boundPort,
    required this.enrolment,
    required this.joinInvite,
    required this.qrKind,
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
      reconcileInviteInvalid = false,
      availableAddresses = const [],
      selectedAddress = null,
      boundPort = null,
      enrolment = null,
      joinInvite = null,
      qrKind = OcptHostingQrKind.join;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [presenceRoster] and [reconcileOutcome] legitimately go back to null (hosting stopped, or the
  /// panel dismissed the last reconcile result), so each has its own `clear…` flag rather than a
  /// bare nullable parameter, which could never tell "leave it alone" apart from "clear it" —
  /// exactly `OcptSharingState.forceInviteValue`'s own reasoning. [selectedAddress], [boundPort],
  /// [enrolment] and [joinInvite] follow the very same shape, going back to null once hosting
  /// stops.
  @override
  OcptHostingState copyWith({
    bool? isLoading,
    OcptRelayHostState? hostState,
    bool? hostOnLaunch,
    bool? canSetAutoRestart,
    OcptPresenceRoster? presenceRoster,
    bool forcePresenceRosterValue = false,
    bool? isReconciling,
    OcptReconcileOutcome? reconcileOutcome,
    bool forceReconcileOutcomeValue = false,
    bool? reconcileInviteInvalid,
    List<String>? availableAddresses,
    String? selectedAddress,
    bool forceSelectedAddressValue = false,
    int? boundPort,
    bool forceBoundPortValue = false,
    OcptRelayEnrolment? enrolment,
    bool forceEnrolmentValue = false,
    OcptRelayInvite? joinInvite,
    bool forceJoinInviteValue = false,
    OcptHostingQrKind? qrKind,
  }) => OcptHostingState(
    isLoading: isLoading ?? this.isLoading,
    hostState: hostState ?? this.hostState,
    hostOnLaunch: hostOnLaunch ?? this.hostOnLaunch,
    canSetAutoRestart: canSetAutoRestart ?? this.canSetAutoRestart,
    presenceRoster: presenceRoster ?? (forcePresenceRosterValue ? null : this.presenceRoster),
    isReconciling: isReconciling ?? this.isReconciling,
    reconcileOutcome:
        reconcileOutcome ?? (forceReconcileOutcomeValue ? null : this.reconcileOutcome),
    reconcileInviteInvalid: reconcileInviteInvalid ?? this.reconcileInviteInvalid,
    availableAddresses: availableAddresses ?? this.availableAddresses,
    selectedAddress: selectedAddress ?? (forceSelectedAddressValue ? null : this.selectedAddress),
    boundPort: boundPort ?? (forceBoundPortValue ? null : this.boundPort),
    enrolment: enrolment ?? (forceEnrolmentValue ? null : this.enrolment),
    joinInvite: joinInvite ?? (forceJoinInviteValue ? null : this.joinInvite),
    qrKind: qrKind ?? this.qrKind,
  );

  /// Copy this state as loaded in [hostState], with the hosting preferences and, when the relay is
  /// online, its addresses, port, enrolment and join invite.
  OcptHostingState copyToLoaded({
    required OcptRelayHostState hostState,
    required OcptPresenceRoster? presenceRoster,
    required bool canSetAutoRestart,
    required bool hostOnLaunch,
    required List<String> availableAddresses,
    required String? selectedAddress,
    required int? boundPort,
    required OcptRelayEnrolment? enrolment,
    required OcptRelayInvite? joinInvite,
  }) => copyWith(
    isLoading: false,
    hostState: hostState,
    presenceRoster: presenceRoster,
    forcePresenceRosterValue: presenceRoster == null,
    canSetAutoRestart: canSetAutoRestart,
    hostOnLaunch: hostOnLaunch,
    availableAddresses: availableAddresses,
    selectedAddress: selectedAddress,
    forceSelectedAddressValue: selectedAddress == null,
    boundPort: boundPort,
    forceBoundPortValue: boundPort == null,
    enrolment: enrolment,
    forceEnrolmentValue: enrolment == null,
    joinInvite: joinInvite,
    forceJoinInviteValue: joinInvite == null,
  );

  /// Copy this state with the relay online in [hostState], and the addresses, port, enrolment and
  /// join invite it advertises.
  OcptHostingState copyWithHostOnline({
    required OcptRelayHostState hostState,
    required bool hostOnLaunch,
    required OcptPresenceRoster? presenceRoster,
    required List<String> availableAddresses,
    required String selectedAddress,
    required int boundPort,
    required OcptRelayEnrolment enrolment,
    required OcptRelayInvite? joinInvite,
  }) => copyWith(
    hostState: hostState,
    canSetAutoRestart: true,
    hostOnLaunch: hostOnLaunch,
    presenceRoster: presenceRoster,
    forcePresenceRosterValue: presenceRoster == null,
    availableAddresses: availableAddresses,
    selectedAddress: selectedAddress,
    boundPort: boundPort,
    enrolment: enrolment,
    joinInvite: joinInvite,
    forceJoinInviteValue: joinInvite == null,
  );

  /// Copy this state with the relay no longer online in [hostState], and everything it advertised
  /// forgotten.
  OcptHostingState copyWithHostOffline({required OcptRelayHostState hostState}) => copyWith(
    hostState: hostState,
    forcePresenceRosterValue: true,
    forceSelectedAddressValue: true,
    forceBoundPortValue: true,
    forceEnrolmentValue: true,
    forceJoinInviteValue: true,
  );

  /// Copy this state with the peers' [presenceRoster], null when there is none.
  OcptHostingState copyWithPresenceRoster({required OcptPresenceRoster? presenceRoster}) =>
      copyWith(presenceRoster: presenceRoster, forcePresenceRosterValue: presenceRoster == null);

  /// Copy this state with the choice of hosting on launch set to [hostOnLaunch].
  OcptHostingState copyWithHostOnLaunch({required bool hostOnLaunch}) =>
      copyWith(hostOnLaunch: hostOnLaunch);

  /// Copy this state with the invite typed for a reconciliation flagged as invalid.
  OcptHostingState copyWithReconcileInviteInvalid() => copyWith(
    reconcileInviteInvalid: true,
    isReconciling: false,
    forceReconcileOutcomeValue: true,
  );

  /// Copy this state with a reconciliation under way and the previous outcome forgotten.
  OcptHostingState copyWithReconciling() => copyWith(
    isReconciling: true,
    reconcileInviteInvalid: false,
    forceReconcileOutcomeValue: true,
  );

  /// Copy this state with the reconciliation ended on [reconcileOutcome].
  OcptHostingState copyWithReconcileOutcome({required OcptReconcileOutcome reconcileOutcome}) =>
      copyWith(isReconciling: false, reconcileOutcome: reconcileOutcome);

  /// Copy this state with the reconciliation outcome and the invalid-invite flag dismissed.
  OcptHostingState copyWithReconcileDismissed() =>
      copyWith(forceReconcileOutcomeValue: true, reconcileInviteInvalid: false);

  /// Copy this state with [selectedAddress] picked, and the [enrolment] and [joinInvite] rebuilt
  /// against it.
  OcptHostingState copyWithSelectedAddress({
    required String selectedAddress,
    required OcptRelayEnrolment enrolment,
    required OcptRelayInvite? joinInvite,
  }) => copyWith(
    selectedAddress: selectedAddress,
    enrolment: enrolment,
    joinInvite: joinInvite,
    forceJoinInviteValue: joinInvite == null,
  );

  /// Copy this state with the QR code of the given [qrKind] shown.
  OcptHostingState copyWithQrKind({required OcptHostingQrKind qrKind}) => copyWith(qrKind: qrKind);

  /// Copy this state with the [availableAddresses] read again and [selectedAddress] kept or moved
  /// to one of them.
  OcptHostingState copyWithRefreshedAddresses({
    required List<String> availableAddresses,
    required String? selectedAddress,
  }) => copyWith(
    availableAddresses: availableAddresses,
    selectedAddress: selectedAddress,
    forceSelectedAddressValue: selectedAddress == null,
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
    availableAddresses,
    selectedAddress,
    boundPort,
    enrolment,
    joinInvite,
    qrKind,
  ];
}
