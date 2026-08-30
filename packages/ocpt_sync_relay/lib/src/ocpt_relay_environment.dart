// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:ocpt_sync_relay/src/ocpt_relay_server.dart';
import 'package:ocpt_sync_relay/src/ocpt_relay_store.dart';

/// The environment variable naming the port the relay listens on. See [defaultRelayPort] for what
/// [buildRelayServerFromEnvironment] resolves to when it is unset.
///
/// Read only by [buildRelayServerFromEnvironment] — `bin/ocpt_sync_relay.dart` hands the resolved
/// [OcptRelayBinding.port] straight to `shelf_io.serve` and never reads this variable itself.
const relayPortEnvVar = 'OCPT_RELAY_PORT';

/// The port [buildRelayServerFromEnvironment] resolves to when [relayPortEnvVar] is not set.
const defaultRelayPort = 8080;

/// The environment variable naming the relay's instance enrolment secret
/// (`docs/adr/0009-offline-first-sync-through-a-domain-blind-relay.md`, and this package's own
/// README). Required: [buildRelayServerFromEnvironment] throws [StateError] when it is missing or
/// empty, since a relay with no enrolment secret can never have a project created on it. It is set
/// by the operator at deploy time and is never typed into the server by anyone else — see
/// `docs/plans/collaboration-and-sync.md` §5.2.
const relayEnrolmentSecretEnvVar = 'OCPT_RELAY_ENROLMENT_SECRET';

/// The environment variable naming the SQLite database file [buildRelayServerFromEnvironment]
/// opens its [OcptRelayStore] against. See [defaultRelayDbPath] for what it resolves to when
/// unset.
const relayDbPathEnvVar = 'OCPT_RELAY_DB_PATH';

/// The database file path [buildRelayServerFromEnvironment] resolves to when [relayDbPathEnvVar]
/// is not set — a plain relative path, so a process started from an arbitrary working directory
/// should always be given an explicit [relayDbPathEnvVar] of its own (the Dockerfile's runtime
/// image does).
const defaultRelayDbPath = 'relay.sqlite';

/// The [OcptRelayServer] and [OcptRelayStore] [buildRelayServerFromEnvironment] built together,
/// plus the port it resolved for them to listen on.
///
/// This class carries no socket of its own — binding [port] to a real one is
/// `bin/ocpt_sync_relay.dart`'s job, via `shelf_io.serve(binding.server.handler, ...)` — so this
/// wiring stays coverable by a plain test that never opens a socket either.
class OcptRelayBinding {
  /// Pairs [server] with the [store] backing it and the [port] it was resolved to listen on.
  const OcptRelayBinding({required this.server, required this.store, required this.port, required this.dbPath});

  /// The constructed relay server, ready to be handed to `shelf_io.serve`.
  final OcptRelayServer server;

  /// The store backing [server], kept here so a caller can [OcptRelayStore.close] it on shutdown
  /// without reaching back into [server] for it.
  final OcptRelayStore store;

  /// The port resolved from [relayPortEnvVar] (or [defaultRelayPort] when it was unset) — not yet
  /// bound to any socket.
  final int port;

  /// The SQLite database file path [store] was opened against, resolved from [relayDbPathEnvVar]
  /// (or [defaultRelayDbPath] when it was unset). Safe to log at startup — unlike the enrolment
  /// secret, it carries no credential.
  final String dbPath;
}

/// Reads [environment] (typically `Platform.environment`) and builds an [OcptRelayServer] and the
/// [OcptRelayStore] behind it together, so `bin/ocpt_sync_relay.dart` stays a thin loop around
/// `shelf_io.serve` and this wiring itself stays covered by a test that never opens a socket.
///
/// Reads three variables — see each one's own doc comment for what it means and what it defaults
/// to: [relayPortEnvVar], [relayEnrolmentSecretEnvVar] (required), [relayDbPathEnvVar].
///
/// Throws [StateError] when [relayEnrolmentSecretEnvVar] is missing or empty, and [ArgumentError]
/// when [relayPortEnvVar] is set but is not a valid port number (a non-negative integer no greater
/// than 65535).
OcptRelayBinding buildRelayServerFromEnvironment(Map<String, String> environment) {
  final enrolmentSecret = environment[relayEnrolmentSecretEnvVar];
  if (enrolmentSecret == null || enrolmentSecret.isEmpty) {
    throw StateError(
      '$relayEnrolmentSecretEnvVar must be set to a non-empty enrolment secret: a relay with none '
      'can never have a project created on it. Generate one and pass it as an environment '
      'variable when starting the relay.',
    );
  }

  final portText = environment[relayPortEnvVar];
  final port = portText == null ? defaultRelayPort : int.tryParse(portText);
  if (port == null || port < 0 || port > 65535) {
    throw ArgumentError(
      '$relayPortEnvVar must be a port number between 0 and 65535, got "$portText"',
    );
  }

  final dbPath = environment[relayDbPathEnvVar] ?? defaultRelayDbPath;
  final store = OcptRelayStore(dbPath);
  final server = OcptRelayServer(store: store, enrolmentSecret: enrolmentSecret);

  return OcptRelayBinding(server: server, store: store, port: port, dbPath: dbPath);
}
