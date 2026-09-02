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
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:uuid/uuid.dart';

/// Resolves the address a hosted relay is advertised on, on the local network — the seam
/// [OcptRelayHostManager] resolves through by default with [NetworkInterface.list], and a test
/// replaces with a fixed [InternetAddress] it cannot otherwise construct one of.
typedef OcptLanAddressResolver = Future<InternetAddress?> Function();

/// Builds the [OcptRelayHostManager] instance registered by the global manager.
class OcptRelayHostManagerBuilder extends AbsLifeCycleFactory<OcptRelayHostManager> {
  /// Class constructor
  const OcptRelayHostManagerBuilder() : super(OcptRelayHostManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager, OcptSecretsManager];
}

/// Owns the lifecycle of **one** in-process relay — one `OcptRelayServer` over one
/// `OcptRelayStore` — at a time, for the "Héberger sur ce poste" sharing mode
/// (`docs/architecture/sync.md`): a small team's own laptop, on set or as the producer/director
/// hub, being the relay instead of a separate deployment.
///
/// This is desktop-only in use — [startHosting] refuses to bind a socket on
/// [PlatformManager.isMobile] — and, at this step, purely a lifecycle: [startHosting] brings the
/// server up and reports [OcptRelayHostOnline]; [stopHosting] tears it down. Nothing here yet
/// points this replica's own project at the relay it just started (self-seed/re-point), reconciles
/// it against an upstream, or restarts it automatically on a later launch — those are later
/// additions on top of this same manager.
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
  /// fake secure-storage channel instead.
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
  /// [InternetAddress] directly rather than the interface it came from, letting a test inject
  /// `InternetAddress('192.168.1.42')` with nothing further to fake.
  OcptRelayHostManager({
    PlatformManager? platformManager,
    OcptSecretsManager? secretsManager,
    InternetAddress? bindAddress,
    this.port = 0,
    OcptLanAddressResolver? lanAddressResolver,
  }) : _platformManager = platformManager ?? PlatformManager(),
       _secretsManager = secretsManager,
       _bindAddress = bindAddress ?? InternetAddress.anyIPv4,
       _lanAddressResolver = lanAddressResolver ?? _defaultLanAddress;

  final PlatformManager _platformManager;

  OcptSecretsManager? _secretsManager;

  /// The project's hosting enrolment secret, resolved lazily through `globalGetIt()` the first
  /// time it is actually needed — see this class's own constructor doc comment for why.
  OcptSecretsManager get _secrets => _secretsManager ??= globalGetIt().get<OcptSecretsManager>();

  /// The address [startHosting] binds its socket to.
  final InternetAddress _bindAddress;

  /// The port [startHosting] binds its socket to — `0` means the OS assigns a free one.
  final int port;

  /// Resolves the address advertised to peers as this hosted relay's own LAN base URI.
  final OcptLanAddressResolver _lanAddressResolver;

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

  /// Starts hosting [projectId] (whose project file sits at [projectFilePath]): opens a relay
  /// store beside the project file, serves it, and reports [OcptRelayHostOnline] once it is up.
  ///
  /// Throws [StateError] on [PlatformManager.isMobile] — a programmer error, not a bring-up
  /// failure: the UI never offers this on mobile, so reaching here on one means a caller ignored
  /// that. [stopHosting] runs first, so calling this again — for the same or a different project —
  /// is always safe and tears any previous instance down before bringing the new one up.
  ///
  /// In order: mints (once) or reuses [projectId]'s stable hosting enrolment secret through
  /// [OcptSecretsManager], so the enrolment QR a "Héberger sur ce poste" panel shows stays the same
  /// across restarts; opens an [OcptRelayStore] at `<projectFilePath>.relay.sqlite` — beside the
  /// project file, one relay database per project, kept in place even after [stopHosting] so the
  /// producer/director hub case can restart hosting without losing what was already relayed; and
  /// serves an [OcptRelayServer] over it on [_bindAddress]:[port]. The advertised
  /// [OcptRelayHostOnline.lanBaseUri] is built from [_lanAddressResolver]'s own non-loopback
  /// address when one exists, falling back to the loopback address (hosting still works on a
  /// single machine, just not for a peer to reach) — and from the socket's **actually bound**
  /// port, never [port] itself, since `0` means the OS picked one.
  ///
  /// A failure at any step tears down whatever was already opened, reports
  /// [OcptRelayHostFailed] with the error's own message, logs a warning when a global manager
  /// instance exists (mirroring `OcptSyncSession._logWarning`), and returns rather than rethrowing
  /// — a bring-up failure is a state to render, exactly like `OcptSyncStatus`, not an exception to
  /// propagate.
  Future<void> startHosting({required String projectId, required String projectFilePath}) async {
    if (_platformManager.isMobile) {
      throw StateError(
        'OcptRelayHostManager.startHosting was called on a mobile platform: hosting a relay is '
        'desktop-only, and the UI must never offer it there.',
      );
    }

    await stopHosting();
    _setState(const OcptRelayHostStarting());

    try {
      var secret = await _secrets.loadHostingEnrolmentSecret(projectId);
      if (secret == null) {
        secret = const Uuid().v4();
        await _secrets.saveHostingEnrolmentSecret(projectId: projectId, secret: secret);
      }

      final storePath = p.setExtension(projectFilePath, '.relay.sqlite');
      final store = OcptRelayStore(storePath);
      _store = store;

      final server = OcptRelayServer(store: store, enrolmentSecret: secret);
      final httpServer = await shelf_io.serve(server.handler, _bindAddress, port);
      _httpServer = httpServer;

      final lanAddress = await _lanAddressResolver();
      final host = lanAddress?.address ?? InternetAddress.loopbackIPv4.address;
      if (lanAddress == null) {
        _logWarning(
          'No non-loopback network interface was found while starting to host project '
          '$projectId: advertising the loopback address, which only this machine can reach.',
        );
      }
      final lanBaseUri = Uri(scheme: 'http', host: host, port: httpServer.port);

      _hostedProjectId = projectId;
      _setState(OcptRelayHostOnline(lanBaseUri: lanBaseUri, enrolmentSecret: secret));
    } catch (error, stackTrace) {
      await _teardown();
      _logWarning('Could not start hosting project $projectId: $error\n$stackTrace');
      _setState(OcptRelayHostFailed('Could not start hosting: $error'));
    }
  }

  /// Stops the currently hosted relay, if any: closes the socket and the store, and reports
  /// [OcptRelayHostStopped]. Safe to call when nothing is hosting.
  ///
  /// The `.relay.sqlite` file itself is left in place beside the project — hosting again later
  /// (the ephemeral, on-set case) reopens the very same store rather than starting from nothing.
  Future<void> stopHosting() async {
    await _teardown();
    _setState(const OcptRelayHostStopped());
  }

  /// Closes [_httpServer] and [_store] and clears every field they left behind, without touching
  /// [state] — the caller decides what state follows a teardown ([stopHosting]'s
  /// [OcptRelayHostStopped], or [startHosting]'s own [OcptRelayHostFailed] on a failed bring-up).
  Future<void> _teardown() async {
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

  /// The first non-loopback IPv4 address of this machine's own network interfaces, or null when
  /// none is found — [OcptLanAddressResolver]'s default implementation.
  static Future<InternetAddress?> _defaultLanAddress() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) {
          return address;
        }
      }
    }

    return null;
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
