// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Serves the relay assembled by `buildRelayServerFromEnvironment` over a real socket, and closes
/// it down cleanly on `SIGINT`/`SIGTERM` — or, given a `reconcile` subcommand, runs
/// [runReconcileCommand] instead and exits.
///
/// All wiring — reading `OCPT_RELAY_PORT`, `OCPT_RELAY_ENROLMENT_SECRET` and `OCPT_RELAY_DB_PATH`,
/// and constructing the [OcptRelayServer] and its [OcptRelayStore] — lives in
/// `buildRelayServerFromEnvironment` (`package:ocpt_sync_relay`) so it stays covered by a plain
/// test with no socket involved. This file's own job is only: dispatch `reconcile` when asked,
/// read the bind address, serve, log one startup line, and shut down cleanly. See this package's
/// own `README.md` for every environment variable and how to run this behind a reverse proxy.
library;

import 'dart:async';
import 'dart:io';

import 'package:ocpt_sync_relay/ocpt_sync_relay.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// The first positional argument that dispatches to [runReconcileCommand] instead of serving.
const _reconcileSubcommand = 'reconcile';

/// The environment variable naming the address the relay binds to. Read only here — the wiring
/// helper has no socket to bind, so it never needs a bind address of its own.
///
/// Defaults to [_defaultAddress] (all interfaces), which is what makes the relay reachable from
/// outside its own container. The relay is meant to sit behind a TLS-terminating reverse proxy,
/// never exposed to the network directly — see this package's own `README.md`.
const _addressEnvVar = 'OCPT_RELAY_ADDRESS';

/// The bind address used when [_addressEnvVar] is not set.
const _defaultAddress = '0.0.0.0';

Future<void> main(List<String> arguments) async {
  if (arguments.isNotEmpty && arguments.first == _reconcileSubcommand) {
    try {
      await runReconcileCommand(arguments.sublist(1), environment: Platform.environment, log: stdout.writeln);
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      exit(2);
    }

    return;
  }

  final binding = buildRelayServerFromEnvironment(Platform.environment);
  final address = Platform.environment[_addressEnvVar] ?? _defaultAddress;

  final httpServer = await shelf_io.serve(binding.server.handler, address, binding.port);

  // Never log the enrolment secret or any project token: this is the only line this binary ever
  // writes on its own, and an operator's log file outlives the process.
  stdout.writeln(
    'ocpt_sync_relay listening on ${httpServer.address.address}:${httpServer.port} '
    '(db: ${binding.dbPath})',
  );

  var shuttingDown = false;
  Future<void> shutdown() async {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;
    await httpServer.close(force: true);
    binding.store.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => unawaited(shutdown()));
  // SIGTERM is not supported on Windows; SIGINT always is. The relay's own Dockerfile is the only
  // deployment this binary documents, and that image is Linux.
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => unawaited(shutdown()));
  }
}
