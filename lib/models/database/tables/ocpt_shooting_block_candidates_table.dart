// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_role_candidates_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_day_blocks_table.dart';

/// Who is seen at this hour, and for which part: the link an `OcptShootingBlockKind.audition` block
/// carries, and **the one convocation in this app read off a block rather than off a slot**.
///
/// **ADR 0018 is applied here, not bent** (ADR 0024): you are convoked by what you are linked to,
/// and every clock about you is read off it. A candidate is not expected "on the unit today" — they
/// are expected at twenty past ten, for twenty minutes, which is exactly what an audition block
/// *is*. So the block is what they are linked to, and their arrival, their PAT band and their
/// departure are read off the audition blocks naming them
/// (`lib/utils/ocpt_shooting_convocations.dart`). It is also what makes ADR 0018's own cost
/// disappear: convoking twelve candidates at twenty-minute intervals is **one** slot carrying
/// twelve audition blocks, not twelve slots.
///
/// **A candidacy is named, not a person** — [roleCandidateId] rather than a `personId` — for the
/// same reason `OcptShootingSlotCastTable` names a role rather than an actor: somebody is seen *for
/// a part*, and one person read for two parts on one day is two convocations, each about a
/// different twenty minutes. The person, their photo and their phone number are read through that
/// candidacy's own `role_candidates.personId`.
///
/// **Several rows on one block is the point**, not an accident of the shape: two actors of two
/// different parts are regularly read together to see what they do to each other, and that is one
/// block carrying two rows. Four people seen twenty minutes each are four blocks carrying one row
/// apiece — and each of the four then has an hour of their own, which is the other half of why this
/// table exists.
///
/// A row whose candidacy has since been removed is **read defensively and drops out**, no cascade
/// being written for it — the same treatment a `shooting_slot_cast` row gets when its role is
/// deleted under it, and what an erased person's tombstoned candidacies get for free. This link
/// carries no `personId`, so it joins no erasure implementation: `role_candidates` stays the row an
/// erasure blanks.
@DataClassName('OcptShootingBlockCandidateRow')
class OcptShootingBlockCandidatesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShootingBlockCandidatesTable}
  @override
  String get tableName => 'shooting_block_candidates';

  /// The stable, unique id of this convocation (a UUID).
  TextColumn get id => text()();

  /// The audition block this convocation is read off.
  TextColumn get blockId => text().references(OcptShootingDayBlocksTable, #id)();

  /// The candidacy seen during the block — who, for which part.
  TextColumn get roleCandidateId => text().references(OcptRoleCandidatesTable, #id)();

  /// {@macro open_cine_prod_tools.sortKey}
  ///
  /// The order the block reads its candidacies in, which is the order the row's own chips draw them
  /// in — `shooting_slot_cast` carries one for the same reason, a convocation list being read down.
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// What this convocation says beside the hour, the sibling of `shooting_slot_cast.notes`.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
