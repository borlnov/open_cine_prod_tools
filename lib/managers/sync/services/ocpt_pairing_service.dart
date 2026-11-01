// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_project_pairing.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// Reads and writes a project's relay pairing, the one place both halves of it —
/// `sync_pairings.relayBaseUrl` and the project token held by [OcptSecretsManager] — are ever
/// touched together.
///
/// The two halves live apart on purpose: the relay address is not a secret and belongs in the
/// `.ocpt` file like any other project data, while the token is a secret and must never land there
/// — see `OcptSyncPairingsTable`'s own doc comment. A pairing is considered to exist only when
/// **both** halves are present: a `sync_pairings` row whose token has gone missing from secure
/// storage (the user cleared it, a reinstall wiped it) is treated exactly like an unpaired project
/// rather than as a pairing with an empty token, which is never a valid state to hand a transport.
class OcptPairingService extends AbsOcptService {
  /// Where the project token half of a pairing is read from and written to.
  final OcptSecretsManager secretsManager;

  /// Class constructor
  const OcptPairingService({required super.logger, required this.secretsManager});

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
