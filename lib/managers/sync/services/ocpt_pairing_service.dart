// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// A project's relay pairing, the two halves [OcptPairingService] keeps in step: the relay it is
/// paired with and the token authenticating every request to it.
///
/// This never carries the enrolment secret: that is a create-time-only value used once by the
/// transport to let it create the project on the relay the first time it is pushed there, and is
/// never persisted by anything — see `OcptRelayRemoteStorage`'s own doc comment.
class OcptProjectPairing extends Equatable {
  /// Class constructor
  const OcptProjectPairing({required this.relayBaseUri, required this.token});

  /// The relay this project is paired with, e.g. `https://relay.example.org/`.
  final Uri relayBaseUri;

  /// The bearer token authenticating every request this pairing's replica makes to
  /// [relayBaseUri] for this project.
  final String token;

  /// Class properties
  @override
  List<Object?> get props => [relayBaseUri, token];
}

/// Reads and writes a project's relay pairing, the one place both halves of it —
/// `sync_pairings.relayBaseUrl` and the project token held by [OcptSecretsManager] — are ever
/// touched together (`docs/plans/relay.md`, M4, Phase B).
///
/// The two halves live apart on purpose: the relay address is not a secret and belongs in the
/// `.ocpt` file like any other project data, while the token is a secret and must never land there
/// — see `OcptSyncPairingsTable`'s own doc comment. A pairing is considered to exist only when
/// **both** halves are present: a `sync_pairings` row whose token has gone missing from secure
/// storage (the user cleared it, a reinstall wiped it) is treated exactly like an unpaired project
/// rather than as a pairing with an empty token, which is never a valid state to hand a transport.
class OcptPairingService {
  /// Class constructor
  const OcptPairingService({required this.secretsManager});

  /// Where the project token half of a pairing is read from and written to.
  final OcptSecretsManager secretsManager;

  /// Upserts [database]'s `sync_pairings` row for [projectId] to [relayBaseUri] and stores [token]
  /// as its project token, replacing whatever pairing [projectId] had before.
  Future<void> savePairing({
    required OcptProjectDatabase database,
    required String projectId,
    required Uri relayBaseUri,
    required String token,
  }) async {
    await database
        .into(database.ocptSyncPairingsTable)
        .insertOnConflictUpdate(
          OcptSyncPairingsTableCompanion.insert(
            projectId: projectId,
            relayBaseUrl: relayBaseUri.toString(),
          ),
        );

    await secretsManager.saveProjectToken(projectId: projectId, token: token);
  }

  /// [projectId]'s current pairing against [database], or null when it is not paired — either
  /// because it has no `sync_pairings` row at all, or because that row's token is missing from
  /// secure storage (see this class's own doc comment).
  Future<OcptProjectPairing?> loadPairing({
    required OcptProjectDatabase database,
    required String projectId,
  }) async {
    final row = await (database.select(
      database.ocptSyncPairingsTable,
    )..where((table) => table.projectId.equals(projectId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    final token = await secretsManager.loadProjectToken(projectId);
    if (token == null) {
      return null;
    }

    return OcptProjectPairing(relayBaseUri: Uri.parse(row.relayBaseUrl), token: token);
  }

  /// Removes [projectId]'s `sync_pairings` row from [database] and deletes its project token from
  /// secure storage, unpairing it entirely.
  Future<void> clearPairing({
    required OcptProjectDatabase database,
    required String projectId,
  }) async {
    await (database.delete(
      database.ocptSyncPairingsTable,
    )..where((table) => table.projectId.equals(projectId))).go();

    await secretsManager.deleteProjectToken(projectId);
  }
}
