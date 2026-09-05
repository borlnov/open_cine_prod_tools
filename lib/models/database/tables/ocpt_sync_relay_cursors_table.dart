// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';

/// This replica's delivery state against each relay it talks to: schema version 2's addition,
/// ahead of the changeset engine itself (`docs/plans/collaboration-and-sync.md`, M3).
///
/// A relay is domain-blind and stateless about who has read what — it only ever answers "give me
/// everything since sequence N" — so each replica has to remember, per relay, where it last left
/// off. [lastAppliedSequence] is that read side: the highest changeset sequence number this replica
/// has fetched from the relay and applied to its own tables. [outboxHighWaterMark] is the write
/// side: the highest local `row_field_versions.version` stamp already pushed to that relay, so the
/// next push sends only what is newer. The two are independent counters — a replica can be behind
/// on one and caught up on the other — which is why this is not a single column.
///
/// **This table is local and is never synchronised**, on the exact model of
/// `OcptProjectVersionsTable` and `OcptLocalErasuresTable` — read either one's own doc comment
/// first. A delivery cursor describes this replica's relationship to one relay, not a fact about
/// the project any other replica could ever agree or disagree with, so it carries no `isDeleted`,
/// no `sortKey` and no `row_field_versions` stamp, is never part of `OcptProjectVersionPayload`, and
/// plays no part in `OcptProjectVersionCodec.contentDigest`: two replicas holding the exact same
/// project content can legitimately disagree about every cursor here, and a version restore must
/// leave them alone rather than rewinding what has already been exchanged with a relay.
///
/// A device pairs with more than one relay over its lifetime (the on-set relay of one shoot day,
/// the production's own relay the rest of the time), and the same project can be behind two relays
/// on the same day (`docs/plans/collaboration-and-sync.md` §5.3) — hence one row per relay rather
/// than one row for the project.
@DataClassName('OcptSyncRelayCursorRow')
class OcptSyncRelayCursorsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptSyncRelayCursorsTable}
  @override
  String get tableName => 'sync_relay_cursors';

  /// The relay this cursor tracks: an opaque identifier for the relay instance (its address or a
  /// stable id it hands out), minted and read by the sync engine rather than by this table.
  TextColumn get relayId => text()();

  /// The highest changeset sequence number fetched from [relayId] and applied to this replica's own
  /// tables; `0` until the first changeset is ever pulled from it.
  IntColumn get lastAppliedSequence => integer().withDefault(const Constant(0))();

  /// The highest local `row_field_versions.version` stamp already pushed to [relayId]; `0` until
  /// this replica has ever pushed anything to it.
  IntColumn get outboxHighWaterMark => integer().withDefault(const Constant(0))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {relayId};
}
