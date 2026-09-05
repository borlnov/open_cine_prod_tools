// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:ocpt_sync_relay/ocpt_sync_relay.dart';
import 'package:open_cine_prod_tools/managers/ocpt_diagnostics_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_diagnostics_entry.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_reconcile_outcome.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:uuid/uuid.dart';

/// Resolves every address a hosted relay could be advertised on, on the local network — the seam
/// [OcptRelayHostManager] resolves through by default with [NetworkInterface.list], and a test
/// replaces with a fixed list of [InternetAddress]es it cannot otherwise construct one of. The
/// first entry (when any) is what [OcptRelayHostManager.startHosting] advertises by default; the
/// hosting panel's own address dropdown reads the full list through
/// [OcptRelayHostManager.availableLanAddresses] so a person can pick a different interface than the
/// default one.
typedef OcptLanAddressResolver = Future<List<InternetAddress>> Function();

/// Interface-name substrings (lower-cased) marking an address as a VPN or virtual adapter rather
/// than a machine's own internet-facing interface — checked by [rankLanAddresses].
const _virtualInterfaceMarkers = [
  'wsl',
  'veth',
  'virtual',
  'hyper-v',
  'docker',
  'vpn',
  'nord',
  'tap',
  'tun',
  'vmware',
  'vbox',
  'loopback',
];

/// Ranks [candidates] — every non-loopback IPv4 address this machine's network interfaces offer,
/// paired with the interface's own name — so the address a phone on the same LAN can actually reach
/// comes first, ahead of a VPN or virtual adapter's own address that [NetworkInterface.list] may
/// otherwise report first (a `10.5.0.2` tunnel, a WSL `172.20.x` bridge): a hosting panel that
/// advertises one of those in its QR shows a code the joining device cannot connect to.
///
/// Three groups, in order, each keeping the candidates' own relative order (a stable sort):
///
/// 1. The address equal to [primaryAddress] — a known default-route source address, when the caller
///    can supply one. `dart:io` exposes no portable way to read it, so `_defaultLanAddress` passes
///    none today and this group is empty in production; the parameter stays so a platform that can
///    resolve the true internet-facing address later ranks it first with no other change.
/// 2. Every other address whose own interface name, lower-cased, contains none of
///    [_virtualInterfaceMarkers] — the ordinary case for a machine with no VPN or virtualisation
///    software running at all.
/// 3. Every address whose interface name does match one of those markers — ranked last since it is
///    the one most likely unreachable from another device on the LAN.
///
/// [OcptRelayHostManager.startHosting] advertises whichever address ends up first; the hosting
/// panel's own address dropdown offers the full ranked list so a person can still pick a different
/// one by hand.
List<InternetAddress> rankLanAddresses(
  List<({InternetAddress address, String interfaceName})> candidates, {
  String? primaryAddress,
}) {
  final primary = <InternetAddress>[];
  final plain = <InternetAddress>[];
  final virtual = <InternetAddress>[];

  for (final candidate in candidates) {
    if (primaryAddress != null && candidate.address.address == primaryAddress) {
      primary.add(candidate.address);
      continue;
    }

    final lowerName = candidate.interfaceName.toLowerCase();
    final isVirtual = _virtualInterfaceMarkers.any(lowerName.contains);
    (isVirtual ? virtual : plain).add(candidate.address);
  }

  return [...primary, ...plain, ...virtual];
}

/// Opens the [OcptRelayStore] [OcptRelayHostManager.startHosting] serves — the seam a test
/// replaces to pre-seed the very store the live server ends up holding (a test cannot otherwise
/// reach into a store `startHosting` opens for itself), by returning an in-memory
/// `OcptRelayStore(':memory:')` it keeps its own reference to. Defaults to `OcptRelayStore.new`.
typedef OcptRelayStoreFactory = OcptRelayStore Function(String path);

/// The port [OcptRelayHostManager] binds its hosted relay to by default — a **fixed** port, not an
/// ephemeral one, so the advertised address (and the join/enrolment QR built from it) stays the
/// same across a restart of hosting: a peer that already holds an invite keeps reaching the relay,
/// rather than being stranded on a port the OS picked afresh. Uncommon enough to rarely collide;
/// when it is taken, the bind fails cleanly to [OcptRelayHostFailed], and the panel's own port
/// field lets a person choose another.
const ocptDefaultInAppHostingPort = 47600;

/// Builds the [OcptRelayHostManager] instance registered by the global manager.
class OcptRelayHostManagerBuilder extends AbsLifeCycleFactory<OcptRelayHostManager> {
  /// Class constructor
  const OcptRelayHostManagerBuilder() : super(OcptRelayHostManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() =>
      [LoggerManager, OcptSyncManager, OcptSecretsManager, OcptPropertiesManager];
}

/// Owns the lifecycle of **one** in-process relay — one `OcptRelayServer` over one
/// `OcptRelayStore` — at a time, for the "Héberger sur ce poste" sharing mode
/// (`docs/architecture/sync.md`): a small team's own laptop, on set or as the producer/director
/// hub, being the relay instead of a separate deployment.
///
/// This is desktop-only in use — [startHosting] refuses to bind a socket on
/// [PlatformManager.isMobile] — and it does two things once the socket is up: it brings the server
/// up and reports [OcptRelayHostOnline] ([stopHosting] tears it down), and it makes this replica
/// its own relay's first member by pointing the project at the socket it just bound, over
/// `localhost` — see [startHosting]'s own doc comment for exactly how. [maybeAutoStartHosting]
/// restarts a project's hosting automatically on a later open, when its own "host on launch"
/// preference asks for it.
///
/// [state]/[stateStream] follow the same contract as `OcptSyncSession.status`/`statusStream`
/// (`CLAUDE.md`'s own pitfalls list): [stateStream] never replays its current value to a new
/// listener, so a caller reads [state] first to seed a fresh subscriber.
class OcptRelayHostManager extends AbsWithLifeCycle {
  /// Class constructor
  ///
  /// [platformManager] is resolved directly (`platformManager ?? PlatformManager()`) rather than
  /// through `globalGetIt()`, exactly as `OcptExportManager`'s own constructor does and for the
  /// same reason: [PlatformManager]'s constructor is a synchronous, side-effect-free read of the
  /// real platform, so building one here is exactly as correct as the registered singleton would
  /// be, and it keeps a test that only needs the desktop guard from having to register one at all.
  ///
  /// [secretsManager] is stored nullable and resolved lazily through [_secrets], exactly as
  /// `OcptSyncManager.pairingService` resolves its own `OcptSecretsManager`: a caller with no
  /// reason to ever host a project never needs it registered, and a test hands one in built over a
  /// fake secure-storage channel instead. [syncManager] is stored nullable and resolved lazily
  /// through [_sync] for the very same reason: a test that only exercises the desktop guard never
  /// needs one registered, and a test that does needs a spy over `pairProjectToRelay`/
  /// `repointProjectToRelay` rather than the real thing. [propertiesManager] is stored nullable and
  /// resolved lazily through [_properties] for the same reason again: only [maybeAutoStartHosting]
  /// ever reads it, so a test exercising [startHosting]/[stopHosting]/[reconcileWithUpstream] alone
  /// never needs one registered.
  ///
  /// [bindAddress] is the socket [startHosting] binds: `InternetAddress.anyIPv4` (`0.0.0.0`) by
  /// default, so the relay is reachable from anywhere on the LAN, not just this machine; a test
  /// passes [InternetAddress.loopbackIPv4] instead. [port] defaults to `0` — an ephemeral port the
  /// OS assigns — so a restart, or two hosted projects on the same machine, never collide on a
  /// fixed port; the actually bound port is what [OcptRelayHostOnline.lanBaseUri] carries, never
  /// this default.
  ///
  /// [lanAddressResolver] defaults to [_defaultLanAddress], which reads real network interfaces —
  /// a test cannot construct a [NetworkInterface] of its own, so this seam returns the resolved
  /// [InternetAddress]es directly rather than the interfaces they came from, letting a test inject
  /// `[InternetAddress('192.168.1.42')]` with nothing further to fake.
  ///
  /// [storeFactory] defaults to `OcptRelayStore.new` and is what [startHosting] calls to open the
  /// store it serves and [reconcileWithUpstream] later reconciles — a test injects one returning
  /// an in-memory `OcptRelayStore(':memory:')` it holds its own reference to, so it can pre-seed
  /// the very store the live server ends up holding, which a test cannot otherwise reach into.
  OcptRelayHostManager({
    PlatformManager? platformManager,
    OcptSecretsManager? secretsManager,
    OcptSyncManager? syncManager,
    OcptPropertiesManager? propertiesManager,
    InternetAddress? bindAddress,
    this.port = ocptDefaultInAppHostingPort,
    OcptLanAddressResolver? lanAddressResolver,
    OcptRelayStoreFactory? storeFactory,
  }) : _platformManager = platformManager ?? PlatformManager(),
       _secretsManager = secretsManager,
       _syncManager = syncManager,
       _propertiesManager = propertiesManager,
       _bindAddress = bindAddress ?? InternetAddress.anyIPv4,
       _lanAddressResolver = lanAddressResolver ?? _defaultLanAddress,
       _storeFactory = storeFactory ?? OcptRelayStore.new;

  final PlatformManager _platformManager;

  OcptSecretsManager? _secretsManager;

  /// The project's hosting enrolment secret, resolved lazily through `globalGetIt()` the first
  /// time it is actually needed — see this class's own constructor doc comment for why.
  OcptSecretsManager get _secrets => _secretsManager ??= globalGetIt().get<OcptSecretsManager>();

  OcptSyncManager? _syncManager;

  /// The pairing/sync engine [startHosting] self-seeds this replica through, resolved lazily
  /// through `globalGetIt()` the first time it is actually needed — see this class's own
  /// constructor doc comment for why.
  OcptSyncManager get _sync => _syncManager ??= globalGetIt().get<OcptSyncManager>();

  OcptPropertiesManager? _propertiesManager;

  /// The per-project "host on launch" flag [maybeAutoStartHosting] reads, resolved lazily through
  /// `globalGetIt()` the first time it is actually needed — see this class's own constructor doc
  /// comment for why.
  OcptPropertiesManager get _properties =>
      _propertiesManager ??= globalGetIt().get<OcptPropertiesManager>();

  /// The address [startHosting] binds its socket to.
  final InternetAddress _bindAddress;

  /// The port [startHosting] binds its socket to when its own `port` argument is null — the fixed
  /// [ocptDefaultInAppHostingPort] by default (so a restart keeps the same advertised address), or
  /// whatever a caller passed the constructor. `0` means the OS assigns a free one — what a test
  /// passes to avoid contending for the fixed port.
  final int port;

  /// Resolves the address advertised to peers as this hosted relay's own LAN base URI.
  final OcptLanAddressResolver _lanAddressResolver;

  /// Opens the [OcptRelayStore] [startHosting] serves — see this class's own constructor doc
  /// comment for why this is a seam rather than a direct call.
  final OcptRelayStoreFactory _storeFactory;

  OcptRelayHostState _state = const OcptRelayHostStopped();
  final StreamController<OcptRelayHostState> _controller = StreamController<OcptRelayHostState>.broadcast();

  OcptRelayStore? _store;
  HttpServer? _httpServer;
  String? _hostedProjectId;

  /// This manager's current host state. [stateStream] never replays it to a new listener — read
  /// this first to seed a fresh subscriber, exactly as this class's own doc comment says.
  OcptRelayHostState get state => _state;

  /// Emits every host state this manager moves through from the moment a listener subscribes
  /// onward — never its current value at subscription time (see [state]).
  Stream<OcptRelayHostState> get stateStream => _controller.stream;

  /// The id of the project currently being hosted, or null when nothing is.
  String? get hostedProjectId => _hostedProjectId;

  /// Every non-loopback IPv4 address this machine's own network interfaces currently offer,
  /// straight off [_lanAddressResolver] — re-callable so the hosting panel's own address dropdown
  /// can re-detect a network switch (a Wi-Fi hop, a cable plugged in) on a fresh view entry,
  /// without restarting hosting to do it: the socket already binds [InternetAddress.anyIPv4] by
  /// default, so every one of these addresses already reaches it.
  Future<List<InternetAddress>> availableLanAddresses() => _lanAddressResolver();

  /// Starts hosting [database]'s own project (whose file sits at [projectFilePath]): opens a relay
  /// store beside the project file, serves it, makes this replica the relay's own first member
  /// over `localhost`, and reports [OcptRelayHostOnline] once all of that is up.
  ///
  /// Throws [StateError] on [PlatformManager.isMobile] — a programmer error, not a bring-up
  /// failure: the UI never offers this on mobile, so reaching here on one means a caller ignored
  /// that. [stopHosting] runs first, so calling this again — for the same or a different project —
  /// is always safe and tears any previous instance down before bringing the new one up.
  ///
  /// In order:
  ///
  /// 1. Reads [database]'s own `sync_pairings` row through [OcptSyncManager.loadPairedProjectId]:
  ///    a project already paired to some relay (the ordinary case — it was shared before, or is
  ///    being hosted again after a restart) is hosted under that same project id; a project never
  ///    paired to any relay (the producer/director hub topology, where no remote server has ever
  ///    been involved) gets a freshly minted one (`const Uuid().v4()`, the client's own to pick,
  ///    exactly as `OcptSharingBloc._onPairRequested` mints one for its own first pairing).
  /// 2. Mints (once) or reuses that project id's stable hosting enrolment secret through
  ///    [OcptSecretsManager], so the enrolment QR a "Héberger sur ce poste" panel shows stays the
  ///    same across restarts.
  /// 3. Opens an [OcptRelayStore] at `<projectFilePath>.relay.sqlite` — beside the project file,
  ///    one relay database per project, kept in place even after [stopHosting] so the
  ///    producer/director hub case can restart hosting without losing what was already relayed —
  ///    and serves an [OcptRelayServer] over it on [_bindAddress], on this call's own [port]
  ///    parameter when given, or this manager's own [port] field otherwise (see that parameter's
  ///    own doc comment below).
  /// 4. Self-seeds: points [database] at the socket just bound, over `http://localhost:<port>` —
  ///    the loopback address, since the host talks to its own relay over the very same machine,
  ///    unlike the LAN address peers use. An already-paired project is re-pointed
  ///    ([OcptSyncManager.repointProjectToRelay], reusing its existing token); a never-paired one
  ///    is paired for the first time ([OcptSyncManager.pairProjectToRelay], minting one). Either
  ///    call pushes this replica's own local edits into the relay, publishes a snapshot so a
  ///    joiner can bootstrap, and starts the ongoing sync session — which is also what starts
  ///    presence, so `OcptSyncManager.presenceRoster` goes live the moment hosting does.
  ///    [OcptSyncManager.pairProjectToRelay]'s own returned invite is not used here: the hosting
  ///    panel's own QR is built from the LAN address and the enrolment secret, not from a join
  ///    invite.
  /// 5. Computes the advertised [OcptRelayHostOnline.lanBaseUri] from [_lanAddressResolver]'s own
  ///    first address when the list is non-empty, falling back to the loopback address (hosting
  ///    still works on a single machine, just not for a peer to reach) — and from the socket's
  ///    **actually bound** port, never this call's own [port] parameter or this manager's own
  ///    [port] field, since `0` means the OS picked one.
  ///
  /// A failure at any step tears down whatever was already opened — ending the self-seeded sync
  /// session first, so it never talks to a socket that is already gone (see [_teardown]) —
  /// reports [OcptRelayHostFailed] with the error's own message, logs a warning when a global
  /// manager instance exists (mirroring `OcptSyncSession._logWarning`), and returns rather than
  /// rethrowing — a bring-up failure is a state to render, exactly like `OcptSyncStatus`, not an
  /// exception to propagate.
  ///
  /// This method's own [port] parameter, when non-null, binds that port instead of this manager's
  /// own [port] field default — what the hosting panel's own port field applies after
  /// "Appliquer": the socket already advertises whichever port it actually bound (see step 5
  /// above), so changing it is simply calling this again with a chosen port rather than a fresh
  /// ephemeral one. Every other caller — [maybeAutoStartHosting] included — passes nothing,
  /// keeping the ephemeral default.
  Future<void> startHosting({
    required OcptProjectDatabase database,
    required String projectFilePath,
    required String projectName,
    required String appVersion,
    required String deviceId,
    int? port,
  }) async {
    if (_platformManager.isMobile) {
      throw StateError(
        'OcptRelayHostManager.startHosting was called on a mobile platform: hosting a relay is '
        'desktop-only, and the UI must never offer it there.',
      );
    }

    await stopHosting();
    _setState(const OcptRelayHostStarting());
    OcptDiagnosticsManager.log(
      category: OcptDiagnosticsCategory.hosting,
      message: 'starting hosting: project="$projectName"',
    );

    try {
      final existingProjectId = await _sync.loadPairedProjectId(database);
      final isPaired = existingProjectId != null;
      final projectId = existingProjectId ?? const Uuid().v4();

      var secret = await _secrets.loadHostingEnrolmentSecret(projectId);
      if (secret == null) {
        secret = const Uuid().v4();
        await _secrets.saveHostingEnrolmentSecret(projectId: projectId, secret: secret);
      }

      final storePath = p.setExtension(projectFilePath, '.relay.sqlite');
      final store = _storeFactory(storePath);
      _store = store;

      final server = OcptRelayServer(
        store: store,
        enrolmentSecret: secret,
        onEvent: (message) => OcptDiagnosticsManager.log(
          category: OcptDiagnosticsCategory.relayServer,
          message: message,
        ),
      );
      final httpServer = await shelf_io.serve(server.handler, _bindAddress, port ?? this.port);
      _httpServer = httpServer;
      OcptDiagnosticsManager.log(
        category: OcptDiagnosticsCategory.hosting,
        message: 'relay socket bound: project=$projectId port=${httpServer.port}',
      );

      final localBaseUri = Uri(scheme: 'http', host: 'localhost', port: httpServer.port);
      if (isPaired) {
        await _sync.repointProjectToRelay(
          database: database,
          projectId: projectId,
          projectFilePath: projectFilePath,
          projectName: projectName,
          appVersion: appVersion,
          relayBaseUri: localBaseUri,
          enrolmentSecret: secret,
          deviceId: deviceId,
        );
      } else {
        await _sync.pairProjectToRelay(
          database: database,
          projectId: projectId,
          projectFilePath: projectFilePath,
          projectName: projectName,
          appVersion: appVersion,
          relayBaseUri: localBaseUri,
          enrolmentSecret: secret,
          deviceId: deviceId,
        );
      }

      final lanAddresses = await _lanAddressResolver();
      final host = lanAddresses.isNotEmpty
          ? lanAddresses.first.address
          : InternetAddress.loopbackIPv4.address;
      if (lanAddresses.isEmpty) {
        _logWarning(
          'No non-loopback network interface was found while starting to host project '
          '$projectId: advertising the loopback address, which only this machine can reach.',
        );
      }
      final lanBaseUri = Uri(scheme: 'http', host: host, port: httpServer.port);

      _hostedProjectId = projectId;
      _setState(OcptRelayHostOnline(lanBaseUri: lanBaseUri, enrolmentSecret: secret));
      OcptDiagnosticsManager.log(
        category: OcptDiagnosticsCategory.hosting,
        message: 'online: project=$projectId base=$lanBaseUri',
      );
    } catch (error, stackTrace) {
      await _teardown();
      _logWarning('Could not start hosting project: $error\n$stackTrace');
      OcptDiagnosticsManager.log(
        category: OcptDiagnosticsCategory.hosting,
        level: OcptDiagnosticsLevel.error,
        message: 'could not start hosting: $error',
      );
      _setState(OcptRelayHostFailed('Could not start hosting: $error'));
    }
  }

  /// Stops the currently hosted relay, if any: ends the self-seeded sync session, closes the
  /// socket and the store, and reports [OcptRelayHostStopped]. Safe to call when nothing is
  /// hosting.
  ///
  /// The `.relay.sqlite` file itself is left in place beside the project — hosting again later
  /// (the ephemeral, on-set case) reopens the very same store rather than starting from nothing.
  Future<void> stopHosting() async {
    final previousProjectId = _hostedProjectId;
    await _teardown();
    _setState(const OcptRelayHostStopped());
    if (previousProjectId != null) {
      OcptDiagnosticsManager.log(
        category: OcptDiagnosticsCategory.hosting,
        message: 'stopped: project=$previousProjectId',
      );
    }
  }

  /// Reconciles the **live** hosted store — never a second, separately opened handle onto
  /// `relay.sqlite` while [OcptRelayServer] already holds it — with the upstream relay named by
  /// [invite] (typically the production's prep relay, reached through an `ocpt://join` invite
  /// scanned or pasted into the hosting panel's "Réconcilier amont…" action): push what this
  /// store holds that the upstream does not, then pull what the upstream holds that this store
  /// does not, both deduped by `changesetId`, exactly as `docs/architecture/sync.md` describes for
  /// the CLI's own `reconcile` subcommand — [OcptRelayReconciler] and [OcptRelayUpstreamClient] are
  /// the very same classes, only reached here over the in-process store instead of a second file
  /// handle.
  ///
  /// [invite]'s own token authenticates every request; no enrolment secret is ever forwarded to
  /// the push, unlike the CLI's own `--enrolment-secret` flag: an `ocpt://join` invite is only ever
  /// issued for a project that already exists on that relay (it names a project already being
  /// shared, not one to create), so the upstream never needs to be told to create it.
  ///
  /// Returns [OcptReconcileSucceeded] with the counts a "Réconcilier amont…" action shows as
  /// "pushed N, pulled M", or [OcptReconcileFailed] with a human-readable detail — never throws
  /// across the UI boundary, so a caller renders either value the same way it renders
  /// [OcptRelayHostState]. Two situations fail before any network call is made: nothing is
  /// currently hosting ([_store] or [_hostedProjectId] is null), or [invite] names a different
  /// project than the one hosted — a project keeps one stable id across every relay it is ever
  /// pointed at, so a mismatch here means the invite was scanned for the wrong project. Any other
  /// failure — the upstream unreachable, or answering anything but `200`, which
  /// [OcptRelayUpstreamClient] surfaces as a thrown [StateError] — is caught here and reported as
  /// [OcptReconcileFailed] instead, and also logged as a warning through [_logWarning].
  Future<OcptReconcileOutcome> reconcileWithUpstream(OcptRelayInvite invite) async {
    final store = _store;
    final projectId = _hostedProjectId;
    if (store == null || projectId == null) {
      return const OcptReconcileFailed('Cannot reconcile: no project is being hosted right now.');
    }
    if (invite.projectId != projectId) {
      return const OcptReconcileFailed('The upstream invite is for a different project than the one being hosted.');
    }

    final upstream = OcptRelayUpstreamClient(baseUri: invite.relayBaseUri, token: invite.token);
    try {
      final reconciler = OcptRelayReconciler(store: store, upstream: upstream);
      final result = await reconciler.reconcileProject(projectId: projectId);

      return OcptReconcileSucceeded(pushed: result.pushed, pulled: result.pulled);
    } catch (error, stackTrace) {
      _logWarning('Reconcile with ${invite.relayBaseUri} failed: $error\n$stackTrace');

      return OcptReconcileFailed('Reconcile failed: $error');
    } finally {
      upstream.close();
    }
  }

  /// The manager-layer half of "réhéberger au démarrage" (`docs/architecture/sync.md`): a
  /// project-open caller (wired in a later step) hands this the project it just opened, and this
  /// starts hosting it again only when both hold: the project is paired — has a relay-side id, so
  /// [OcptSyncManager.loadPairedProjectId] returns one; a never-paired project was never hosted, so
  /// there is nothing to restart — AND its per-project [OcptPropertiesManager] "host on launch"
  /// flag ([OcptPropertiesManager.loadHostOnLaunch]) is set.
  ///
  /// A no-op, and never throws, in three cases: on [PlatformManager.isMobile] (hosting is
  /// desktop-only, and the flag is a per-device local value a mobile build's own UI never sets),
  /// on an unpaired project, and on a project whose flag is unset. Once it decides to start, it
  /// reuses [startHosting] verbatim with the very same arguments.
  Future<void> maybeAutoStartHosting({
    required OcptProjectDatabase database,
    required String projectFilePath,
    required String projectName,
    required String appVersion,
    required String deviceId,
  }) async {
    if (_platformManager.isMobile) {
      return;
    }

    final projectId = await _sync.loadPairedProjectId(database);
    if (projectId == null) {
      return;
    }

    // Already hosting this very project — do nothing. This is called afresh on every project open,
    // and the workspace is rebuilt on every navigation, so without this guard simply navigating
    // back to a project that is already being hosted would call [startHosting] again, which tears
    // the relay down and rebinds it on a fresh port — stranding every peer already connected to the
    // old one (`docs/architecture/sync.md`).
    if (_state is OcptRelayHostOnline && _hostedProjectId == projectId) {
      return;
    }

    if (!await _properties.loadHostOnLaunch(projectId)) {
      return;
    }

    await startHosting(
      database: database,
      projectFilePath: projectFilePath,
      projectName: projectName,
      appVersion: appVersion,
      deviceId: deviceId,
    );
  }

  /// Ends the self-seeded sync session, then closes [_httpServer] and [_store] and clears every
  /// field they left behind, without touching [state] — the caller decides what state follows a
  /// teardown ([stopHosting]'s [OcptRelayHostStopped], or [startHosting]'s own
  /// [OcptRelayHostFailed] on a failed bring-up).
  ///
  /// The session is stopped **before** the socket closes, so it never tries to talk to a relay
  /// that has already gone away — [OcptSyncManager.stopSyncSession] is documented safe to call
  /// with no session running, which covers every call here that starts with nothing hosted yet.
  Future<void> _teardown() async {
    await _sync.stopSyncSession();
    await _httpServer?.close(force: true);
    _httpServer = null;
    _store?.close();
    _store = null;
    _hostedProjectId = null;
  }

  void _setState(OcptRelayHostState state) {
    _state = state;
    if (!_controller.isClosed) {
      _controller.add(state);
    }
  }

  /// Logs [message] through `appLogger()` when a global manager instance actually exists, and does
  /// nothing otherwise — mirrors `OcptSyncSession._logWarning`'s own doc comment: a unit test
  /// builds this manager directly, with no app-wide `AbsGlobalManager` behind it at all.
  void _logWarning(String message) {
    if (AbsGlobalManager.instance != null) {
      appLogger().w(message);
    }
  }

  /// Every non-loopback IPv4 address of this machine's own network interfaces, deduplicated and
  /// ranked by [rankLanAddresses] so the address most likely reachable from a phone on the same LAN
  /// comes first, ahead of a VPN or virtual adapter's own address (a `10.5.0.2` tunnel, a WSL
  /// `172.20.x` bridge) that [NetworkInterface.list] may otherwise list first —
  /// [OcptLanAddressResolver]'s default implementation.
  ///
  /// The ranking is by **interface name** alone (see [rankLanAddresses]): `dart:io` exposes no
  /// portable way to read the machine's own default-route source address — a client [Socket]'s
  /// `address` is the address it connected *to*, not the local one it left from — so a real
  /// reachability probe is not possible here, and the heuristic deliberately errs on the side of
  /// offering the full ranked list to the panel's own dropdown, where a person can always pick a
  /// different interface by hand when the first guess is wrong.
  static Future<List<InternetAddress>> _defaultLanAddress() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    final seen = <String>{};
    final candidates = <({InternetAddress address, String interfaceName})>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback && seen.add(address.address)) {
          candidates.add((address: address, interfaceName: interface.name));
        }
      }
    }

    return rankLanAddresses(candidates);
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    await stopHosting();
    if (!_controller.isClosed) {
      await _controller.close();
    }

    return super.disposeLifeCycle();
  }
}
