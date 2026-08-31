// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:ocpt_sync_relay/src/ocpt_relay_environment.dart';
import 'package:ocpt_sync_relay/src/ocpt_relay_reconciler.dart';
import 'package:ocpt_sync_relay/src/ocpt_relay_store.dart';
import 'package:ocpt_sync_relay/src/ocpt_relay_upstream_client.dart';

/// Parses an `ocpt://join?r=<baseUri>&p=<projectId>&t=<token>` invite string into the upstream
/// base URI, project id and bearer token [runReconcileCommand] needs to reconcile against it.
///
/// This is a minimal, local parser for the same string the app's own `OcptRelayInvite` produces —
/// that model lives in `lib/models/sync/` and is not reachable from this pure-Dart package, so its
/// shape is repeated here rather than shared. Throws [FormatException] with a message naming what
/// is wrong when [invite] is not `scheme == 'ocpt'`, `host == 'join'`, or is missing a non-empty
/// `r`, `p` or `t` query parameter.
({Uri upstream, String projectId, String token}) parseReconcileInvite(String invite) {
  final Uri uri;
  try {
    uri = Uri.parse(invite);
  } on FormatException catch (error) {
    throw FormatException('not a valid URI: $error', invite);
  }

  if (uri.scheme != 'ocpt') {
    throw FormatException("invite must use the 'ocpt' scheme, got '${uri.scheme}'", invite);
  }
  if (uri.host != 'join') {
    throw FormatException("invite must have host 'join', got '${uri.host}'", invite);
  }

  final relayText = uri.queryParameters['r'];
  final projectId = uri.queryParameters['p'];
  final token = uri.queryParameters['t'];
  if (relayText == null || relayText.isEmpty) {
    throw FormatException("invite is missing a non-empty 'r' (relay URI) query parameter", invite);
  }
  if (projectId == null || projectId.isEmpty) {
    throw FormatException("invite is missing a non-empty 'p' (project id) query parameter", invite);
  }
  if (token == null || token.isEmpty) {
    throw FormatException("invite is missing a non-empty 't' (token) query parameter", invite);
  }

  final Uri upstream;
  try {
    upstream = Uri.parse(relayText);
  } on FormatException catch (error) {
    throw FormatException("invite's 'r' query parameter is not a valid URI: $error", invite);
  }

  return (upstream: upstream, projectId: projectId, token: token);
}

/// Runs the `reconcile` CLI subcommand: parses [args], opens the local store and an upstream
/// client, runs [OcptRelayReconciler.reconcileProject] once, logs a one-line summary through
/// [log], and closes both in a `finally` — see `bin/ocpt_sync_relay.dart` for how this is wired
/// into the binary's `main`.
///
/// Flags, parsed by hand (this package adds no dependency on `package:args` for one subcommand):
///
/// - `--invite <ocpt://join…>` — parsed by [parseReconcileInvite] into the upstream, project id
///   and token. Mutually exclusive with the trio below; exactly one of the two forms is required.
/// - `--upstream <uri> --project <id> --token <tok>` — the same three values, given directly.
/// - `--db-path <path>` — the local store's database file, defaulting to
///   `environment[relayDbPathEnvVar] ?? defaultRelayDbPath`, the same resolution the `serve` path
///   uses.
/// - `--enrolment-secret <s>` — forwarded to [OcptRelayReconciler.reconcileProject], for a project
///   the upstream has never seen before. Optional.
///
/// [openStore] and [openUpstream] default to the real [OcptRelayStore] and
/// [OcptRelayUpstreamClient] constructors; a test injects fakes to exercise this function's flag
/// parsing and logging with no real database file or socket involved.
///
/// Throws [FormatException] when the arguments are malformed or incomplete — an invite parsing
/// failure from [parseReconcileInvite] included — which `bin/ocpt_sync_relay.dart` catches to
/// print a message and exit non-zero rather than let a stack trace reach the operator's terminal.
Future<void> runReconcileCommand(
  List<String> args, {
  required Map<String, String> environment,
  OcptRelayStore Function(String dbPath)? openStore,
  OcptRelayUpstreamClient Function({required Uri baseUri, required String token})? openUpstream,
  required void Function(String) log,
}) async {
  Uri? upstreamUri;
  String? projectId;
  String? token;
  String? dbPath;
  String? enrolmentSecret;

  var index = 0;
  while (index < args.length) {
    final flag = args[index];
    String value() {
      if (index + 1 >= args.length) {
        throw FormatException("flag '$flag' expects a value");
      }
      index += 1;

      return args[index];
    }

    switch (flag) {
      case '--invite':
        final invite = parseReconcileInvite(value());
        upstreamUri = invite.upstream;
        projectId = invite.projectId;
        token = invite.token;
      case '--upstream':
        upstreamUri = Uri.parse(value());
      case '--project':
        projectId = value();
      case '--token':
        token = value();
      case '--db-path':
        dbPath = value();
      case '--enrolment-secret':
        enrolmentSecret = value();
      default:
        throw FormatException("unknown flag '$flag'");
    }
    index += 1;
  }

  if (upstreamUri == null || projectId == null || token == null) {
    throw const FormatException(
      "reconcile needs either '--invite <ocpt://join…>' or the trio "
      "'--upstream <uri> --project <id> --token <tok>'",
    );
  }

  final resolvedDbPath = dbPath ?? environment[relayDbPathEnvVar] ?? defaultRelayDbPath;
  final store = (openStore ?? OcptRelayStore.new)(resolvedDbPath);
  final upstream = (openUpstream ?? OcptRelayUpstreamClient.new)(baseUri: upstreamUri, token: token);

  try {
    final reconciler = OcptRelayReconciler(store: store, upstream: upstream);
    final result = await reconciler.reconcileProject(projectId: projectId, enrolmentSecret: enrolmentSecret);
    log('pushed ${result.pushed}, pulled ${result.pulled}');
  } finally {
    store.close();
    upstream.close();
  }
}
