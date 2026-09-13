// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';

/// Where a project is paired to sync through: schema version 2's own addition, alongside
/// `OcptSyncRelayCursorsTable` (`docs/plans/collaboration-and-sync.md`, M4).
///
/// A project pairs with at most one relay at a time — [relayBaseUrl] is the address the pairing
/// screen collected (`docs/plans/relay.md`, Phase C, commit 1) and `OcptRelayRemoteStorage` is
/// opened against. **The project token authenticating every request to that relay is never stored
/// here**: it is a secret and lives through `OcptSecretsManager` instead
/// (`act_local_storage_manager`'s `AbstractSecretsManager`), keyed by [projectId] — see
/// `OcptPairingService`, which is the only place both halves of a pairing are read or written
/// together.
///
/// **This table is local and is never synchronised**, on the exact model of
/// `OcptSyncRelayCursorsTable` — read its own doc comment first. Whether *this* replica of the
/// project happens to be paired with a relay, and which one, is not a fact about the project any
/// other replica could ever agree or disagree with, so it carries no `isDeleted`, no `sortKey` and
/// no `row_field_versions` stamp, is never part of `OcptProjectVersionPayload`, and plays no part in
/// `OcptProjectVersionCodec.contentDigest`: a version restore must leave it alone rather than
/// unpairing or re-pairing the project.
@DataClassName('OcptSyncPairingRow')
class OcptSyncPairingsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptSyncPairingsTable}
  @override
  String get tableName => 'sync_pairings';

  /// The project this row pairs, matching `project_info.id`.
  TextColumn get projectId => text()();

  /// The relay this project is paired with, e.g. `https://relay.example.org/`.
  TextColumn get relayBaseUrl => text()();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {projectId};
}
