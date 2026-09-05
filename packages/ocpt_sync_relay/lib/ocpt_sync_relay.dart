// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The domain-blind sync relay (`docs/adr/0009-offline-first-sync-through-a-domain-blind-relay.md`):
/// a self-hostable server speaking `package:ocpt_sync_protocol` over storage that only ever holds
/// opaque payloads.
///
/// This library contains no table name and no domain type — see each file's own doc comment for
/// what that means for it. It has no Flutter dependency; storage is a plain `sqlite3` database
/// file, and the HTTP and WebSocket routes are assembled by `OcptRelayServer`. `bin/` is the
/// entrypoint that serves it over a real socket, built on `buildRelayServerFromEnvironment`.
library;

export 'src/ocpt_relay_environment.dart';
export 'src/ocpt_relay_reconcile_command.dart';
export 'src/ocpt_relay_reconciler.dart';
export 'src/ocpt_relay_server.dart';
export 'src/ocpt_relay_store.dart';
export 'src/ocpt_relay_upstream_client.dart';
